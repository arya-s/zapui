//! Text rendering system for zapui using stb_truetype.
//! Handles font loading, glyph rasterization, and text shaping.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const atlas_mod = @import("renderer/atlas.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Atlas = atlas_mod.Atlas;
const AtlasTile = atlas_mod.AtlasTile;

// stb_truetype C bindings
const stb = @cImport({
    @cInclude("vendor/stb_truetype.h");
});

/// Font identifier
pub const FontId = u32;

/// Glyph identifier (codepoint)
pub const GlyphId = u32;

/// Font weight
pub const FontWeight = enum {
    thin,
    extra_light,
    light,
    normal,
    medium,
    semi_bold,
    bold,
    extra_bold,
    black,

    pub fn toNumeric(self: FontWeight) u16 {
        return switch (self) {
            .thin => 100,
            .extra_light => 200,
            .light => 300,
            .normal => 400,
            .medium => 500,
            .semi_bold => 600,
            .bold => 700,
            .extra_bold => 800,
            .black => 900,
        };
    }
};

/// Font style
pub const FontStyle = enum {
    normal,
    italic,
    oblique,
};

/// Font metrics at a specific size
pub const FontMetrics = struct {
    ascent: Pixels,
    descent: Pixels,
    line_gap: Pixels,
    line_height: Pixels,

    pub fn baseline(self: FontMetrics) Pixels {
        return self.ascent;
    }
};

/// A shaped glyph ready for rendering
pub const ShapedGlyph = struct {
    glyph_id: GlyphId,
    codepoint: u32,
    x_offset: Pixels,
    y_offset: Pixels,
    x_advance: Pixels,
    y_advance: Pixels,
    atlas_bounds: ?Bounds(f32) = null, // UV coordinates in atlas
    pixel_bounds: ?Bounds(Pixels) = null, // Pixel bounds of glyph
};

/// A run of shaped glyphs
pub const ShapedRun = struct {
    font_id: FontId,
    font_size: Pixels,
    glyphs: []ShapedGlyph,
    width: Pixels,
    metrics: FontMetrics,
};

/// Cache key for rasterized glyphs
const GlyphCacheKey = struct {
    font_id: FontId,
    glyph_id: GlyphId,
    size_x10: u32, // Size * 10 to allow fractional sizes

    pub fn hash(self: GlyphCacheKey) u64 {
        var h: u64 = 0;
        h = h *% 31 +% self.font_id;
        h = h *% 31 +% self.glyph_id;
        h = h *% 31 +% self.size_x10;
        return h;
    }

    pub fn eql(a: GlyphCacheKey, b: GlyphCacheKey) bool {
        return a.font_id == b.font_id and a.glyph_id == b.glyph_id and a.size_x10 == b.size_x10;
    }
};

/// Cached glyph data
const CachedGlyph = struct {
    atlas_bounds: Bounds(f32), // UV coordinates
    pixel_bounds: Bounds(Pixels), // Glyph bounds relative to origin
    advance: Pixels,
};

/// Internal font data
const FontData = struct {
    data: []const u8, // Raw TTF data (must stay alive)
    info: stb.stbtt_fontinfo,
    owned: bool, // Whether we own the data buffer
};

/// Text rendering system
pub const TextSystem = struct {
    allocator: Allocator,
    fonts: std.ArrayListUnmanaged(FontData),
    glyph_cache: std.AutoHashMapUnmanaged(GlyphCacheKey, CachedGlyph),
    atlas: ?*Atlas,
    temp_bitmap: []u8,
    temp_bitmap_size: usize,

    const TEMP_BITMAP_SIZE = 256 * 256;

    pub fn init(allocator: Allocator) TextSystem {
        const temp = allocator.alloc(u8, TEMP_BITMAP_SIZE) catch @panic("OOM");
        return .{
            .allocator = allocator,
            .fonts = .{ .items = &.{}, .capacity = 0 },
            .glyph_cache = .{},
            .atlas = null,
            .temp_bitmap = temp,
            .temp_bitmap_size = TEMP_BITMAP_SIZE,
        };
    }

    pub fn deinit(self: *TextSystem) void {
        for (self.fonts.items) |font| {
            if (font.owned) {
                self.allocator.free(font.data);
            }
        }
        self.fonts.deinit(self.allocator);
        self.glyph_cache.deinit(self.allocator);
        self.allocator.free(self.temp_bitmap);
    }

    /// Set the atlas for glyph caching
    pub fn setAtlas(self: *TextSystem, atlas: *Atlas) void {
        self.atlas = atlas;
    }

    /// Load a font from a file path
    pub fn loadFontFile(self: *TextSystem, path: []const u8) !FontId {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, 16 * 1024 * 1024);
        return self.loadFontData(data, true);
    }

    /// Load a font from memory (data must remain valid)
    pub fn loadFontMem(self: *TextSystem, data: []const u8) !FontId {
        return self.loadFontData(data, false);
    }

    fn loadFontData(self: *TextSystem, data: []const u8, owned: bool) !FontId {
        var font_data = FontData{
            .data = data,
            .info = undefined,
            .owned = owned,
        };

        const result = stb.stbtt_InitFont(&font_data.info, data.ptr, 0);
        if (result == 0) {
            if (owned) self.allocator.free(data);
            return error.InvalidFont;
        }

        const id: FontId = @intCast(self.fonts.items.len);
        try self.fonts.append(self.allocator, font_data);
        return id;
    }

    /// Get font metrics at a specific size
    pub fn getFontMetrics(self: *const TextSystem, font_id: FontId, size: Pixels) FontMetrics {
        if (font_id >= self.fonts.items.len) {
            return FontMetrics{ .ascent = size, .descent = 0, .line_gap = 0, .line_height = size };
        }

        const font = &self.fonts.items[font_id];
        const scale = stb.stbtt_ScaleForPixelHeight(&font.info, size);

        var ascent: c_int = 0;
        var descent: c_int = 0;
        var line_gap: c_int = 0;
        stb.stbtt_GetFontVMetrics(&font.info, &ascent, &descent, &line_gap);

        const asc: Pixels = @as(Pixels, @floatFromInt(ascent)) * scale;
        const desc: Pixels = @as(Pixels, @floatFromInt(descent)) * scale;
        const gap: Pixels = @as(Pixels, @floatFromInt(line_gap)) * scale;

        return FontMetrics{
            .ascent = asc,
            .descent = desc,
            .line_gap = gap,
            .line_height = asc - desc + gap,
        };
    }

    /// Shape text into glyphs (basic left-to-right shaping)
    pub fn shapeText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) !ShapedRun {
        if (font_id >= self.fonts.items.len) {
            return error.InvalidFont;
        }

        const font = &self.fonts.items[font_id];
        const scale = stb.stbtt_ScaleForPixelHeight(&font.info, size);
        const metrics = self.getFontMetrics(font_id, size);

        // Count codepoints
        var codepoint_count: usize = 0;
        var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        while (iter.nextCodepoint()) |_| {
            codepoint_count += 1;
        }

        // Allocate glyphs
        const glyphs = try self.allocator.alloc(ShapedGlyph, codepoint_count);

        // Shape glyphs
        var x: Pixels = 0;
        var i: usize = 0;
        iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        var prev_codepoint: ?u32 = null;

        while (iter.nextCodepoint()) |codepoint| {
            const glyph_index = stb.stbtt_FindGlyphIndex(&font.info, @intCast(codepoint));

            // Get advance width
            var advance_width: c_int = 0;
            var left_bearing: c_int = 0;
            stb.stbtt_GetGlyphHMetrics(&font.info, glyph_index, &advance_width, &left_bearing);

            // Apply kerning
            var kern: Pixels = 0;
            if (prev_codepoint) |prev| {
                const kern_advance = stb.stbtt_GetCodepointKernAdvance(&font.info, @intCast(prev), @intCast(codepoint));
                kern = @as(Pixels, @floatFromInt(kern_advance)) * scale;
            }

            const x_advance = @as(Pixels, @floatFromInt(advance_width)) * scale;

            glyphs[i] = .{
                .glyph_id = @intCast(glyph_index),
                .codepoint = codepoint,
                .x_offset = @as(Pixels, @floatFromInt(left_bearing)) * scale,
                .y_offset = 0,
                .x_advance = x_advance,
                .y_advance = 0,
            };

            x += kern + x_advance;
            prev_codepoint = codepoint;
            i += 1;
        }

        return ShapedRun{
            .font_id = font_id,
            .font_size = size,
            .glyphs = glyphs,
            .width = x,
            .metrics = metrics,
        };
    }

    /// Free a shaped run
    pub fn freeShapedRun(self: *TextSystem, run: *ShapedRun) void {
        self.allocator.free(run.glyphs);
    }

    /// Rasterize a glyph and add it to the atlas
    pub fn rasterizeGlyph(self: *TextSystem, font_id: FontId, glyph_id: GlyphId, size: Pixels) ?CachedGlyph {
        const cache_key = GlyphCacheKey{
            .font_id = font_id,
            .glyph_id = glyph_id,
            .size_x10 = @intFromFloat(size * 10),
        };

        // Check cache
        if (self.glyph_cache.get(cache_key)) |cached| {
            return cached;
        }

        if (font_id >= self.fonts.items.len) return null;
        const atlas = self.atlas orelse return null;

        const font = &self.fonts.items[font_id];
        const scale = stb.stbtt_ScaleForPixelHeight(&font.info, size);

        // Get glyph bounds
        var x0: c_int = 0;
        var y0: c_int = 0;
        var x1: c_int = 0;
        var y1: c_int = 0;
        stb.stbtt_GetGlyphBitmapBox(&font.info, @intCast(glyph_id), scale, scale, &x0, &y0, &x1, &y1);

        const glyph_w: u32 = @intCast(@max(0, x1 - x0));
        const glyph_h: u32 = @intCast(@max(0, y1 - y0));

        if (glyph_w == 0 or glyph_h == 0) {
            // Space or empty glyph
            const cached = CachedGlyph{
                .atlas_bounds = Bounds(f32).zero,
                .pixel_bounds = Bounds(Pixels).fromXYWH(
                    @floatFromInt(x0),
                    @floatFromInt(y0),
                    0,
                    0,
                ),
                .advance = 0,
            };
            self.glyph_cache.put(self.allocator, cache_key, cached) catch {};
            return cached;
        }

        // Rasterize to temp buffer
        if (glyph_w * glyph_h > self.temp_bitmap_size) {
            return null; // Glyph too large
        }

        @memset(self.temp_bitmap, 0);
        stb.stbtt_MakeGlyphBitmap(
            &font.info,
            self.temp_bitmap.ptr,
            @intCast(glyph_w),
            @intCast(glyph_h),
            @intCast(glyph_w),
            scale,
            scale,
            @intCast(glyph_id),
        );

        // Allocate in atlas
        const tile_opt = atlas.allocate(.{ .width = glyph_w, .height = glyph_h }) catch return null;
        const tile = tile_opt orelse return null;

        // Upload to atlas
        atlas.upload(tile, self.temp_bitmap[0 .. glyph_w * glyph_h]);

        const cached = CachedGlyph{
            .atlas_bounds = tile.uv_bounds,
            .pixel_bounds = Bounds(Pixels).fromXYWH(
                @floatFromInt(x0),
                @floatFromInt(y0),
                @floatFromInt(glyph_w),
                @floatFromInt(glyph_h),
            ),
            .advance = 0,
        };

        self.glyph_cache.put(self.allocator, cache_key, cached) catch {};
        return cached;
    }

    /// Convenience method to render text directly to a scene
    pub fn renderText(
        self: *TextSystem,
        scene: *@import("scene.zig").Scene,
        text_str: []const u8,
        x: Pixels,
        y: Pixels,
        size: Pixels,
        text_color: @import("color.zig").Hsla,
    ) !void {
        const font_id: FontId = 0; // Default to first loaded font

        // Shape the text
        var run = try self.shapeText(text_str, font_id, size);
        defer self.freeShapedRun(&run);

        // Render each glyph
        var glyph_x = x;
        for (run.glyphs) |glyph| {
            if (self.rasterizeGlyph(font_id, glyph.glyph_id, size)) |cached| {
                if (cached.pixel_bounds.size.width > 0 and cached.pixel_bounds.size.height > 0) {
                    try scene.insertMonoSprite(.{
                        .bounds = Bounds(Pixels).fromXYWH(
                            glyph_x + glyph.x_offset + cached.pixel_bounds.origin.x,
                            y + cached.pixel_bounds.origin.y,
                            cached.pixel_bounds.size.width,
                            cached.pixel_bounds.size.height,
                        ),
                        .color = text_color,
                        .tile_bounds = cached.atlas_bounds,
                    });
                }
            }
            glyph_x += glyph.x_advance;
        }
    }

    /// Measure text width without shaping
    pub fn measureText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) Pixels {
        if (font_id >= self.fonts.items.len) return 0;

        const font = &self.fonts.items[font_id];
        const scale = stb.stbtt_ScaleForPixelHeight(&font.info, size);

        var width: Pixels = 0;
        var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        var prev_codepoint: ?u32 = null;

        while (iter.nextCodepoint()) |codepoint| {
            var advance_width: c_int = 0;
            var left_bearing: c_int = 0;
            stb.stbtt_GetCodepointHMetrics(&font.info, @intCast(codepoint), &advance_width, &left_bearing);

            if (prev_codepoint) |prev| {
                const kern = stb.stbtt_GetCodepointKernAdvance(&font.info, @intCast(prev), @intCast(codepoint));
                width += @as(Pixels, @floatFromInt(kern)) * scale;
            }

            width += @as(Pixels, @floatFromInt(advance_width)) * scale;
            prev_codepoint = codepoint;
        }

        return width;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TextSystem basic init" {
    const allocator = std.testing.allocator;
    var ts = TextSystem.init(allocator);
    defer ts.deinit();

    try std.testing.expectEqual(@as(usize, 0), ts.fonts.items.len);
}

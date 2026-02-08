//! Text rendering system for zapui using FreeType.
//! Handles font loading, glyph rasterization, and text shaping.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const atlas_mod = @import("renderer/atlas.zig");
const freetype = @import("freetype");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Atlas = atlas_mod.Atlas;
const GlAtlas = atlas_mod.GlAtlas;
const AtlasTile = atlas_mod.AtlasTile;

const FT_Library = freetype.Library;
const FT_Face = freetype.Face;

/// Font identifier
pub const FontId = u32;

/// Glyph identifier (glyph index, not codepoint)
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
    face: FT_Face,
    owned: bool, // Whether we own the data buffer

    /// Cached metrics for different sizes (size_x10 -> metrics)
    cached_metrics: std.AutoHashMapUnmanaged(u32, FontMetrics) = .{},
};

/// Text rendering system using FreeType
pub const TextSystem = struct {
    allocator: Allocator,
    ft_lib: FT_Library,
    fonts: std.ArrayListUnmanaged(FontData),
    glyph_cache: std.AutoHashMapUnmanaged(GlyphCacheKey, CachedGlyph),
    atlas: ?*GlAtlas,
    temp_bitmap: []u8,
    temp_bitmap_size: usize,

    const TEMP_BITMAP_SIZE = 512 * 512; // Larger buffer for FreeType

    pub fn init(allocator: Allocator) !TextSystem {
        const ft_lib = FT_Library.init() catch return error.FreeTypeInitFailed;
        const temp = try allocator.alloc(u8, TEMP_BITMAP_SIZE);
        return .{
            .allocator = allocator,
            .ft_lib = ft_lib,
            .fonts = .{},
            .glyph_cache = .{},
            .atlas = null,
            .temp_bitmap = temp,
            .temp_bitmap_size = TEMP_BITMAP_SIZE,
        };
    }

    pub fn deinit(self: *TextSystem) void {
        for (self.fonts.items) |*font| {
            font.face.deinit();
            font.cached_metrics.deinit(self.allocator);
            if (font.owned) {
                self.allocator.free(font.data);
            }
        }
        self.fonts.deinit(self.allocator);
        self.glyph_cache.deinit(self.allocator);
        self.allocator.free(self.temp_bitmap);
        self.ft_lib.deinit();
    }

    /// Set the atlas for glyph caching
    pub fn setAtlas(self: *TextSystem, atlas: *GlAtlas) void {
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
        const face = self.ft_lib.initMemoryFace(data, 0) catch {
            if (owned) self.allocator.free(data);
            return error.InvalidFont;
        };
        errdefer face.deinit();

        // Select Unicode charmap
        face.selectCharmap(.unicode) catch {
            // Font might not have Unicode charmap, continue anyway
        };

        const id: FontId = @intCast(self.fonts.items.len);
        try self.fonts.append(self.allocator, .{
            .data = data,
            .face = face,
            .owned = owned,
        });
        return id;
    }

    /// Get font metrics at a specific size
    pub fn getFontMetrics(self: *TextSystem, font_id: FontId, size: Pixels) FontMetrics {
        if (font_id >= self.fonts.items.len) {
            return FontMetrics{ .ascent = size, .descent = 0, .line_gap = 0, .line_height = size };
        }

        const size_x10: u32 = @intFromFloat(size * 10);
        var font = &self.fonts.items[font_id];

        // Check cache
        if (font.cached_metrics.get(size_x10)) |cached| {
            return cached;
        }

        // Set pixel size
        font.face.setPixelSizes(0, @intFromFloat(size)) catch {
            return FontMetrics{ .ascent = size, .descent = 0, .line_gap = 0, .line_height = size };
        };

        // Get metrics from FreeType face
        const face_handle = font.face.handle;
        const size_metrics = face_handle.*.size.*.metrics;

        // FreeType uses 26.6 fixed-point format (divide by 64)
        const ascent: Pixels = @as(Pixels, @floatFromInt(size_metrics.ascender)) / 64.0;
        const descent: Pixels = @as(Pixels, @floatFromInt(size_metrics.descender)) / 64.0;
        const height: Pixels = @as(Pixels, @floatFromInt(size_metrics.height)) / 64.0;

        // Line gap is height - (ascent - descent)
        const line_gap = height - (ascent - descent);

        const metrics = FontMetrics{
            .ascent = ascent,
            .descent = descent,
            .line_gap = line_gap,
            .line_height = height,
        };

        // Cache for next time
        font.cached_metrics.put(self.allocator, size_x10, metrics) catch {};

        return metrics;
    }

    /// Shape text into glyphs (basic left-to-right shaping)
    /// Note: This is simple codepoint-by-codepoint shaping. Phase 3 will add HarfBuzz.
    pub fn shapeText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) !ShapedRun {
        if (font_id >= self.fonts.items.len) {
            return error.InvalidFont;
        }

        var font = &self.fonts.items[font_id];
        const metrics = self.getFontMetrics(font_id, size);

        // Set pixel size for this shaping operation
        font.face.setPixelSizes(0, @intFromFloat(size)) catch return error.InvalidFont;

        // Count codepoints
        var codepoint_count: usize = 0;
        var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        while (iter.nextCodepoint()) |_| {
            codepoint_count += 1;
        }

        // Allocate glyphs
        const glyphs = try self.allocator.alloc(ShapedGlyph, codepoint_count);
        errdefer self.allocator.free(glyphs);

        // Shape glyphs
        var x: Pixels = 0;
        var i: usize = 0;
        iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        var prev_glyph_index: ?u32 = null;

        const face_handle = font.face.handle;
        const has_kerning = (face_handle.*.face_flags & 0x40) != 0; // FT_FACE_FLAG_KERNING

        while (iter.nextCodepoint()) |codepoint| {
            const glyph_index = font.face.getCharIndex(codepoint) orelse 0;

            // Load glyph to get metrics
            font.face.loadGlyph(glyph_index, .{}) catch {
                // Skip glyph if loading fails
                glyphs[i] = .{
                    .glyph_id = glyph_index,
                    .codepoint = codepoint,
                    .x_offset = 0,
                    .y_offset = 0,
                    .x_advance = 0,
                    .y_advance = 0,
                };
                i += 1;
                prev_glyph_index = glyph_index;
                continue;
            };

            const glyph_slot = face_handle.*.glyph;
            const glyph_metrics = glyph_slot.*.metrics;

            // FreeType advance is in 26.6 fixed-point
            const x_advance: Pixels = @as(Pixels, @floatFromInt(glyph_slot.*.advance.x)) / 64.0;
            const left_bearing: Pixels = @as(Pixels, @floatFromInt(glyph_metrics.horiBearingX)) / 64.0;

            // Apply kerning if available
            var kern: Pixels = 0;
            if (has_kerning) {
                if (prev_glyph_index) |prev| {
                    var delta: freetype.c.FT_Vector = undefined;
                    const kern_result = freetype.c.FT_Get_Kerning(
                        face_handle,
                        prev,
                        glyph_index,
                        0, // FT_KERNING_DEFAULT
                        &delta,
                    );
                    if (kern_result == 0) {
                        kern = @as(Pixels, @floatFromInt(delta.x)) / 64.0;
                    }
                }
            }

            glyphs[i] = .{
                .glyph_id = glyph_index,
                .codepoint = codepoint,
                .x_offset = left_bearing,
                .y_offset = 0,
                .x_advance = x_advance,
                .y_advance = 0,
            };

            x += kern + x_advance;
            prev_glyph_index = glyph_index;
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

        var font = &self.fonts.items[font_id];

        // Set pixel size
        font.face.setPixelSizes(0, @intFromFloat(size)) catch return null;

        // Load glyph with rendering
        font.face.loadGlyph(glyph_id, .{ .render = true }) catch return null;

        const face_handle = font.face.handle;
        const glyph_slot = face_handle.*.glyph;
        const bitmap = glyph_slot.*.bitmap;
        const glyph_metrics = glyph_slot.*.metrics;

        const glyph_w: u32 = bitmap.width;
        const glyph_h: u32 = bitmap.rows;

        // Calculate bearing for positioning
        const bearing_x: Pixels = @as(Pixels, @floatFromInt(glyph_metrics.horiBearingX)) / 64.0;
        const bearing_y: Pixels = @as(Pixels, @floatFromInt(glyph_metrics.horiBearingY)) / 64.0;
        const advance: Pixels = @as(Pixels, @floatFromInt(glyph_slot.*.advance.x)) / 64.0;

        if (glyph_w == 0 or glyph_h == 0) {
            // Space or empty glyph
            const cached = CachedGlyph{
                .atlas_bounds = Bounds(f32).zero,
                .pixel_bounds = Bounds(Pixels).fromXYWH(bearing_x, -bearing_y, 0, 0),
                .advance = advance,
            };
            self.glyph_cache.put(self.allocator, cache_key, cached) catch {};
            return cached;
        }

        // Check if bitmap fits in temp buffer
        if (glyph_w * glyph_h > self.temp_bitmap_size) {
            return null; // Glyph too large
        }

        // Copy bitmap data (FreeType bitmap may have padding)
        const pitch: usize = @intCast(@abs(bitmap.pitch));
        for (0..glyph_h) |row| {
            const src_offset = row * pitch;
            const dst_offset = row * glyph_w;
            @memcpy(
                self.temp_bitmap[dst_offset..][0..glyph_w],
                bitmap.buffer[src_offset..][0..glyph_w],
            );
        }

        // Allocate in atlas
        const tile_opt = atlas.allocate(.{ .width = glyph_w, .height = glyph_h }) catch return null;
        const tile = tile_opt orelse return null;

        // Upload to atlas
        atlas.upload(tile, self.temp_bitmap[0 .. glyph_w * glyph_h]);

        const cached = CachedGlyph{
            .atlas_bounds = tile.uv_bounds,
            .pixel_bounds = Bounds(Pixels).fromXYWH(
                bearing_x,
                -bearing_y, // Y is inverted (bearing_y is distance from baseline to top)
                @floatFromInt(glyph_w),
                @floatFromInt(glyph_h),
            ),
            .advance = advance,
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
                            glyph_x + cached.pixel_bounds.origin.x,
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

    /// Measure text width
    pub fn measureText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) Pixels {
        if (font_id >= self.fonts.items.len) return 0;

        var font = &self.fonts.items[font_id];

        // Set pixel size
        font.face.setPixelSizes(0, @intFromFloat(size)) catch return 0;

        var width: Pixels = 0;
        var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        var prev_glyph_index: ?u32 = null;

        const face_handle = font.face.handle;
        const has_kerning = (face_handle.*.face_flags & 0x40) != 0;

        while (iter.nextCodepoint()) |codepoint| {
            const glyph_index = font.face.getCharIndex(codepoint) orelse 0;

            // Load glyph to get advance
            font.face.loadGlyph(glyph_index, .{}) catch continue;

            const glyph_slot = face_handle.*.glyph;
            const x_advance: Pixels = @as(Pixels, @floatFromInt(glyph_slot.*.advance.x)) / 64.0;

            // Apply kerning
            if (has_kerning) {
                if (prev_glyph_index) |prev| {
                    var delta: freetype.c.FT_Vector = undefined;
                    const kern_result = freetype.c.FT_Get_Kerning(
                        face_handle,
                        prev,
                        glyph_index,
                        0,
                        &delta,
                    );
                    if (kern_result == 0) {
                        width += @as(Pixels, @floatFromInt(delta.x)) / 64.0;
                    }
                }
            }

            width += x_advance;
            prev_glyph_index = glyph_index;
        }

        return width;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TextSystem basic init" {
    const allocator = std.testing.allocator;
    var ts = try TextSystem.init(allocator);
    defer ts.deinit();

    try std.testing.expectEqual(@as(usize, 0), ts.fonts.items.len);
}

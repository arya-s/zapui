//! Text rendering system for zapui using FreeType + HarfBuzz.
//! Handles font loading, glyph rasterization, and text shaping.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const atlas_mod = @import("renderer/atlas.zig");
const freetype = @import("freetype");
const harfbuzz = @import("harfbuzz");

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
const HB_Buffer = harfbuzz.Buffer;
const HB_Font = harfbuzz.Font;

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
    is_color: bool = false, // true if stored in color atlas (emoji)
    scale: f32 = 1.0, // Scale factor for bitmap fonts (requested_size / native_size)
};

/// Internal font data
const FontData = struct {
    data: []const u8, // Raw TTF data (must stay alive)
    face: FT_Face,
    hb_font: HB_Font,
    owned: bool, // Whether we own the data buffer

    /// Cached metrics for different sizes (size_x10 -> metrics)
    cached_metrics: std.AutoHashMapUnmanaged(u32, FontMetrics) = .{},
};

/// Text rendering system using FreeType + HarfBuzz
pub const TextSystem = struct {
    allocator: Allocator,
    ft_lib: FT_Library,
    hb_buf: HB_Buffer,
    fonts: std.ArrayListUnmanaged(FontData),
    glyph_cache: std.AutoHashMapUnmanaged(GlyphCacheKey, CachedGlyph),
    atlas: ?*GlAtlas, // Grayscale atlas for regular glyphs
    color_atlas: ?*GlAtlas, // BGRA atlas for color emoji
    temp_bitmap: []u8,
    temp_bitmap_size: usize,

    const TEMP_BITMAP_SIZE = 512 * 512;

    pub fn init(allocator: Allocator) !TextSystem {
        const ft_lib = FT_Library.init() catch return error.FreeTypeInitFailed;
        errdefer ft_lib.deinit();

        var hb_buf = HB_Buffer.create() catch return error.HarfBuzzInitFailed;
        errdefer hb_buf.destroy();

        const temp = try allocator.alloc(u8, TEMP_BITMAP_SIZE);
        return .{
            .allocator = allocator,
            .ft_lib = ft_lib,
            .hb_buf = hb_buf,
            .fonts = .{},
            .glyph_cache = .{},
            .atlas = null,
            .color_atlas = null,
            .temp_bitmap = temp,
            .temp_bitmap_size = TEMP_BITMAP_SIZE,
        };
    }

    pub fn deinit(self: *TextSystem) void {
        for (self.fonts.items) |*font| {
            font.hb_font.destroy();
            font.face.deinit();
            font.cached_metrics.deinit(self.allocator);
            if (font.owned) {
                self.allocator.free(font.data);
            }
        }
        self.fonts.deinit(self.allocator);
        self.glyph_cache.deinit(self.allocator);
        self.allocator.free(self.temp_bitmap);
        self.hb_buf.destroy();
        self.ft_lib.deinit();
    }

    /// Set the atlases for glyph caching
    pub fn setAtlas(self: *TextSystem, atlas: *GlAtlas) void {
        self.atlas = atlas;
    }

    /// Set the color atlas for emoji
    pub fn setColorAtlas(self: *TextSystem, atlas: *GlAtlas) void {
        self.color_atlas = atlas;
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

        // Create HarfBuzz font from FreeType face
        const hb_font = harfbuzz.freetype.createFont(face.handle) catch {
            if (owned) self.allocator.free(data);
            return error.HarfBuzzFontFailed;
        };

        const id: FontId = @intCast(self.fonts.items.len);
        try self.fonts.append(self.allocator, .{
            .data = data,
            .face = face,
            .hb_font = hb_font,
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

    /// Shape text into glyphs using HarfBuzz
    pub fn shapeText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) !ShapedRun {
        if (font_id >= self.fonts.items.len) {
            return error.InvalidFont;
        }

        var font = &self.fonts.items[font_id];
        const metrics = self.getFontMetrics(font_id, size);

        // Set pixel size for shaping
        // For bitmap fonts (like emoji), we need to select a strike instead
        const face_handle = font.face.handle;
        const is_scalable = (face_handle.*.face_flags & 0x1) != 0; // FT_FACE_FLAG_SCALABLE
        
        // For bitmap fonts, calculate scale factor to render at requested size
        var bitmap_scale: Pixels = 1.0;
        if (is_scalable) {
            font.face.setPixelSizes(0, @intFromFloat(size)) catch return error.InvalidFont;
        } else if (font.face.hasFixedSizes()) {
            // Bitmap font - select the best available strike
            font.face.selectSize(0) catch return error.InvalidFont;
            // Get the native size of the bitmap strike
            const native_size: Pixels = @as(Pixels, @floatFromInt(face_handle.*.size.*.metrics.height)) / 64.0;
            if (native_size > 0) {
                bitmap_scale = size / native_size;
            }
        } else {
            return error.InvalidFont;
        }

        // Notify HarfBuzz that the FreeType face changed size
        harfbuzz.freetype.fontChanged(font.hb_font);

        // Reset and configure HarfBuzz buffer
        self.hb_buf.reset();
        self.hb_buf.addUTF8(text);
        self.hb_buf.guessSegmentProperties();

        // Shape the text
        harfbuzz.shape(font.hb_font, self.hb_buf, null);

        // Get shaped glyphs
        const glyph_infos = self.hb_buf.getGlyphInfos();
        const glyph_positions = self.hb_buf.getGlyphPositions() orelse return error.ShapingFailed;
        


        // Allocate output glyphs
        const glyphs = try self.allocator.alloc(ShapedGlyph, glyph_infos.len);
        errdefer self.allocator.free(glyphs);

        // After calling hb_ft_font_changed, HarfBuzz positions are in 26.6 fixed-point
        // (same as FreeType), so divide by 64 to get pixels, then scale for bitmap fonts
        var total_advance: Pixels = 0;
        for (glyph_infos, glyph_positions, 0..) |info, pos, i| {
            const x_advance: Pixels = @as(Pixels, @floatFromInt(pos.x_advance)) / 64.0 * bitmap_scale;
            const y_advance: Pixels = @as(Pixels, @floatFromInt(pos.y_advance)) / 64.0 * bitmap_scale;
            const x_offset: Pixels = @as(Pixels, @floatFromInt(pos.x_offset)) / 64.0 * bitmap_scale;
            const y_offset: Pixels = @as(Pixels, @floatFromInt(pos.y_offset)) / 64.0 * bitmap_scale;

            glyphs[i] = .{
                .glyph_id = info.codepoint, // After shaping, this is the glyph index
                .codepoint = info.cluster, // Cluster maps back to original text
                .x_offset = x_offset,
                .y_offset = y_offset,
                .x_advance = x_advance,
                .y_advance = y_advance,
            };

            total_advance += x_advance;
        }

        return ShapedRun{
            .font_id = font_id,
            .font_size = size,
            .glyphs = glyphs,
            .width = total_advance,
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
        const mono_atlas = self.atlas orelse return null;

        var font = &self.fonts.items[font_id];
        const face_handle = font.face.handle;

        // Check if font has color glyphs (emoji)
        const has_color = font.face.hasColor();
        const is_scalable = (face_handle.*.face_flags & 0x1) != 0; // FT_FACE_FLAG_SCALABLE

        // Set pixel size - bitmap fonts need selectSize instead
        // For bitmap fonts, calculate scale factor to render at requested size
        var bitmap_scale: f32 = 1.0;
        if (is_scalable) {
            font.face.setPixelSizes(0, @intFromFloat(size)) catch return null;
        } else if (font.face.hasFixedSizes()) {
            font.face.selectSize(0) catch return null;
            // Get the native size of the bitmap strike
            const native_size: f32 = @as(f32, @floatFromInt(face_handle.*.size.*.metrics.height)) / 64.0;
            if (native_size > 0) {
                bitmap_scale = size / native_size;
            }
        } else {
            return null;
        }

        // Load glyph - use FT_LOAD_COLOR for color fonts to get BGRA bitmaps
        // For bitmap fonts, we just need default loading (they're already rendered)
        const load_flags: freetype.LoadFlags = if (has_color and !is_scalable)
            .{ .color = true } // Bitmap color font - no render needed
        else if (has_color)
            .{ .render = true, .color = true } // Scalable color font
        else
            .{ .render = true, .target = .light }; // Regular scalable font

        font.face.loadGlyph(glyph_id, load_flags) catch return null;

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
                .pixel_bounds = Bounds(Pixels).fromXYWH(bearing_x * bitmap_scale, -bearing_y * bitmap_scale, 0, 0),
                .advance = advance * bitmap_scale,
                .scale = bitmap_scale,
            };
            self.glyph_cache.put(self.allocator, cache_key, cached) catch {};
            return cached;
        }

        // Detect if this glyph is actually color (BGRA bitmap)
        // FT_PIXEL_MODE_BGRA = 7
        const is_color_glyph = bitmap.pixel_mode == 7;
        

        


        // Choose which atlas to use
        const target_atlas = if (is_color_glyph)
            self.color_atlas orelse mono_atlas
        else
            mono_atlas;

        const bytes_per_pixel: u32 = if (is_color_glyph) 4 else 1;
        const bitmap_size = glyph_w * glyph_h * bytes_per_pixel;

        // Check if bitmap fits in temp buffer
        if (bitmap_size > self.temp_bitmap_size) {
            return null; // Glyph too large
        }

        // Copy bitmap data (FreeType bitmap may have padding)
        const pitch: usize = @intCast(@abs(bitmap.pitch));
        if (is_color_glyph) {
            // BGRA bitmap - copy with BGRA→RGBA swizzle
            for (0..glyph_h) |row| {
                const src_row = bitmap.buffer + row * pitch;
                const dst_offset = row * glyph_w * 4;
                for (0..glyph_w) |col| {
                    const src_offset = col * 4;
                    const dst_col = dst_offset + col * 4;
                    // BGRA → RGBA
                    self.temp_bitmap[dst_col + 0] = src_row[src_offset + 2]; // R
                    self.temp_bitmap[dst_col + 1] = src_row[src_offset + 1]; // G
                    self.temp_bitmap[dst_col + 2] = src_row[src_offset + 0]; // B
                    self.temp_bitmap[dst_col + 3] = src_row[src_offset + 3]; // A
                }
            }
        } else {
            // Grayscale bitmap
            for (0..glyph_h) |row| {
                const src_offset = row * pitch;
                const dst_offset = row * glyph_w;
                @memcpy(
                    self.temp_bitmap[dst_offset..][0..glyph_w],
                    bitmap.buffer[src_offset..][0..glyph_w],
                );
            }
        }

        // Allocate in atlas
        const tile_opt = target_atlas.allocate(.{ .width = glyph_w, .height = glyph_h }) catch return null;
        const tile = tile_opt orelse return null;

        // Upload to atlas
        target_atlas.upload(tile, self.temp_bitmap[0..bitmap_size]);

        const cached = CachedGlyph{
            .atlas_bounds = tile.uv_bounds,
            .pixel_bounds = Bounds(Pixels).fromXYWH(
                bearing_x * bitmap_scale,
                -bearing_y * bitmap_scale, // Y is inverted (bearing_y is distance from baseline to top)
                @as(Pixels, @floatFromInt(glyph_w)) * bitmap_scale,
                @as(Pixels, @floatFromInt(glyph_h)) * bitmap_scale,
            ),
            .advance = advance * bitmap_scale,
            .is_color = is_color_glyph,
            .scale = bitmap_scale,
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
        try self.renderTextWithFont(scene, text_str, x, y, size, text_color, 0);
    }

    /// Render text with a specific font
    pub fn renderTextWithFont(
        self: *TextSystem,
        scene: *@import("scene.zig").Scene,
        text_str: []const u8,
        x: Pixels,
        y: Pixels,
        size: Pixels,
        text_color: @import("color.zig").Hsla,
        font_id: FontId,
    ) !void {

        // Shape the text
        var run = try self.shapeText(text_str, font_id, size);
        defer self.freeShapedRun(&run);

        // Render each glyph with pixel-aligned positions for crisp rendering
        var glyph_x = x;
        for (run.glyphs) |glyph| {
            if (self.rasterizeGlyph(font_id, glyph.glyph_id, size)) |cached| {
                if (cached.pixel_bounds.size.width > 0 and cached.pixel_bounds.size.height > 0) {
                    // Round positions to nearest pixel for crisp text
                    const px_x = @round(glyph_x + glyph.x_offset + cached.pixel_bounds.origin.x);
                    const px_y = @round(y + glyph.y_offset + cached.pixel_bounds.origin.y);
                    const bounds = Bounds(Pixels).fromXYWH(
                        px_x,
                        px_y,
                        cached.pixel_bounds.size.width,
                        cached.pixel_bounds.size.height,
                    );

                    if (cached.is_color) {
                        // Color emoji - use poly sprite (no tint)
                        try scene.insertPolySprite(.{
                            .bounds = bounds,
                            .tile_bounds = cached.atlas_bounds,
                        });
                    } else {
                        // Regular glyph - use mono sprite with color tint
                        try scene.insertMonoSprite(.{
                            .bounds = bounds,
                            .color = text_color,
                            .tile_bounds = cached.atlas_bounds,
                        });
                    }
                }
            }
            glyph_x += glyph.x_advance;
        }
    }

    /// Measure text width using HarfBuzz shaping
    pub fn measureText(self: *TextSystem, text: []const u8, font_id: FontId, size: Pixels) Pixels {
        var run = self.shapeText(text, font_id, size) catch return 0;
        defer self.freeShapedRun(&run);
        return run.width;
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

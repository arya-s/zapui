//! Shared Glyph Cache
//!
//! Handles FreeType glyph rasterization and caching.
//! Used by both TextSystem (for measurement) and renderers (for display).
//! Renderer uploads the bitmap data to GPU textures.

const std = @import("std");
const freetype = @import("freetype");
const geometry = @import("geometry.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;

/// Font identifier
pub const FontId = u32;

/// Glyph identifier  
pub const GlyphId = u32;

/// Font metrics for a specific size
pub const FontMetrics = struct {
    ascent: Pixels,
    descent: Pixels,
    line_height: Pixels,
    underline_position: Pixels,
    underline_thickness: Pixels,

    pub fn baseline(self: FontMetrics) Pixels {
        return self.ascent;
    }
};

/// Cache key for rasterized glyphs
pub const GlyphKey = struct {
    font_id: FontId,
    glyph_id: GlyphId,
    size_x10: u32,

    pub const HashContext = struct {
        pub fn hash(_: HashContext, key: GlyphKey) u64 {
            var h: u64 = 0;
            h = h *% 31 +% key.font_id;
            h = h *% 31 +% key.glyph_id;
            h = h *% 31 +% key.size_x10;
            return h;
        }

        pub fn eql(_: HashContext, a: GlyphKey, b: GlyphKey) bool {
            return a.font_id == b.font_id and a.glyph_id == b.glyph_id and a.size_x10 == b.size_x10;
        }
    };
};

/// Rasterized glyph data (CPU-side)
pub const RasterizedGlyph = struct {
    /// Bitmap data (grayscale or BGRA)
    bitmap: []const u8,
    width: u32,
    height: u32,
    /// Glyph metrics
    bearing_x: i32,
    bearing_y: i32,
    advance: Pixels,
    /// True if BGRA (color emoji), false if grayscale
    is_color: bool,
};

/// Cached glyph with atlas location
pub const CachedGlyph = struct {
    /// UV coordinates in atlas (set by renderer after upload)
    uv_bounds: Bounds(f32) = Bounds(f32).zero,
    /// Pixel bounds relative to baseline
    pixel_bounds: Bounds(Pixels),
    /// Horizontal advance
    advance: Pixels,
    /// True if color glyph
    is_color: bool = false,
    /// True if uploaded to GPU atlas
    uploaded: bool = false,
};

/// Internal font data
const FontData = struct {
    data: []const u8,
    face: freetype.Face,
    owned: bool,
    metrics_cache: std.AutoHashMapUnmanaged(u32, FontMetrics) = .{},
};

/// Shared glyph cache
pub const GlyphCache = struct {
    allocator: Allocator,
    ft_lib: freetype.Library,
    fonts: std.ArrayListUnmanaged(FontData),
    glyphs: std.HashMapUnmanaged(GlyphKey, CachedGlyph, GlyphKey.HashContext, 80),
    
    /// Temporary bitmap buffer for rasterization
    temp_bitmap: []u8,
    temp_bitmap_capacity: usize,

    const TEMP_BITMAP_SIZE = 256 * 256 * 4; // Max glyph size

    pub fn init(allocator: Allocator) !GlyphCache {
        const ft_lib = freetype.Library.init() catch return error.FreeTypeInitFailed;
        errdefer ft_lib.deinit();

        const temp = try allocator.alloc(u8, TEMP_BITMAP_SIZE);

        return .{
            .allocator = allocator,
            .ft_lib = ft_lib,
            .fonts = .{},
            .glyphs = .{},
            .temp_bitmap = temp,
            .temp_bitmap_capacity = TEMP_BITMAP_SIZE,
        };
    }

    pub fn deinit(self: *GlyphCache) void {
        for (self.fonts.items) |*font| {
            font.face.deinit();
            font.metrics_cache.deinit(self.allocator);
            if (font.owned) {
                self.allocator.free(font.data);
            }
        }
        self.fonts.deinit(self.allocator);
        self.glyphs.deinit(self.allocator);
        self.allocator.free(self.temp_bitmap);
        self.ft_lib.deinit();
    }

    /// Load a font from memory
    pub fn loadFont(self: *GlyphCache, data: []const u8) !FontId {
        const face = self.ft_lib.initMemoryFace(data, 0) catch return error.FontLoadFailed;
        errdefer face.deinit();

        const id: FontId = @intCast(self.fonts.items.len);
        try self.fonts.append(self.allocator, .{
            .data = data,
            .face = face,
            .owned = false,
        });

        return id;
    }

    /// Get font metrics for a specific size
    pub fn getFontMetrics(self: *GlyphCache, font_id: FontId, size: Pixels) FontMetrics {
        if (font_id >= self.fonts.items.len) {
            return .{ .ascent = size, .descent = 0, .line_height = size * 1.2, .underline_position = 0, .underline_thickness = 1 };
        }

        var font = &self.fonts.items[font_id];
        const size_key: u32 = @intFromFloat(size * 10);

        if (font.metrics_cache.get(size_key)) |cached| {
            return cached;
        }

        font.face.setPixelSizes(0, @intFromFloat(size)) catch {
            return .{ .ascent = size, .descent = 0, .line_height = size * 1.2, .underline_position = 0, .underline_thickness = 1 };
        };

        const face = font.face.handle;
        const metrics = FontMetrics{
            .ascent = @as(Pixels, @floatFromInt(face.*.size.*.metrics.ascender)) / 64.0,
            .descent = @as(Pixels, @floatFromInt(face.*.size.*.metrics.descender)) / 64.0,
            .line_height = @as(Pixels, @floatFromInt(face.*.size.*.metrics.height)) / 64.0,
            .underline_position = @as(Pixels, @floatFromInt(face.*.underline_position)) / 64.0,
            .underline_thickness = @as(Pixels, @floatFromInt(face.*.underline_thickness)) / 64.0,
        };

        font.metrics_cache.put(self.allocator, size_key, metrics) catch {};
        return metrics;
    }

    /// Get glyph index for a character
    pub fn getGlyphIndex(self: *GlyphCache, font_id: FontId, codepoint: u32) ?GlyphId {
        if (font_id >= self.fonts.items.len) return null;
        return self.fonts.items[font_id].face.getCharIndex(@intCast(codepoint));
    }

    /// Get cached glyph, rasterizing if needed
    pub fn getGlyph(self: *GlyphCache, font_id: FontId, glyph_id: GlyphId, size: Pixels) ?*CachedGlyph {
        const key = GlyphKey{
            .font_id = font_id,
            .glyph_id = glyph_id,
            .size_x10 = @intFromFloat(size * 10),
        };

        // Return cached if exists
        if (self.glyphs.getPtr(key)) |cached| {
            return cached;
        }

        // Rasterize
        const rasterized = self.rasterizeGlyph(font_id, glyph_id, size) orelse return null;

        // Cache it
        const cached = CachedGlyph{
            .pixel_bounds = Bounds(Pixels).fromXYWH(
                @floatFromInt(rasterized.bearing_x),
                -@as(Pixels, @floatFromInt(rasterized.bearing_y)),
                @floatFromInt(rasterized.width),
                @floatFromInt(rasterized.height),
            ),
            .advance = rasterized.advance,
            .is_color = rasterized.is_color,
            .uploaded = false,
        };

        self.glyphs.put(self.allocator, key, cached) catch return null;
        return self.glyphs.getPtr(key);
    }

    /// Rasterize a glyph to temp_bitmap
    pub fn rasterizeGlyph(self: *GlyphCache, font_id: FontId, glyph_id: GlyphId, size: Pixels) ?RasterizedGlyph {
        if (font_id >= self.fonts.items.len) return null;

        var font = &self.fonts.items[font_id];
        font.face.setPixelSizes(0, @intFromFloat(size)) catch return null;
        font.face.loadGlyph(glyph_id, .{ .render = true }) catch return null;

        const glyph = font.face.handle.*.glyph;
        const bitmap = &glyph.*.bitmap;

        const w = bitmap.width;
        const h = bitmap.rows;

        if (w == 0 or h == 0) {
            return RasterizedGlyph{
                .bitmap = &[_]u8{},
                .width = 0,
                .height = 0,
                .bearing_x = glyph.*.bitmap_left,
                .bearing_y = glyph.*.bitmap_top,
                .advance = @as(Pixels, @floatFromInt(glyph.*.advance.x)) / 64.0,
                .is_color = false,
            };
        }

        const is_color = bitmap.pixel_mode == 7; // FT_PIXEL_MODE_BGRA
        const bpp: u32 = if (is_color) 4 else 1;
        const bitmap_size = w * h * bpp;

        if (bitmap_size > self.temp_bitmap_capacity) return null;

        // Copy bitmap data
        const pitch: u32 = @intCast(@abs(bitmap.pitch));
        const src: [*]const u8 = @ptrCast(bitmap.buffer);

        for (0..h) |row| {
            const dst_offset = row * w * bpp;
            const src_offset = row * pitch;
            for (0..w * bpp) |col| {
                self.temp_bitmap[dst_offset + col] = src[src_offset + col];
            }
        }

        return RasterizedGlyph{
            .bitmap = self.temp_bitmap[0..bitmap_size],
            .width = w,
            .height = h,
            .bearing_x = glyph.*.bitmap_left,
            .bearing_y = glyph.*.bitmap_top,
            .advance = @as(Pixels, @floatFromInt(glyph.*.advance.x)) / 64.0,
            .is_color = is_color,
        };
    }

    /// Mark a glyph as uploaded with UV coordinates
    pub fn setGlyphUV(self: *GlyphCache, font_id: FontId, glyph_id: GlyphId, size: Pixels, uv_bounds: Bounds(f32)) void {
        const key = GlyphKey{
            .font_id = font_id,
            .glyph_id = glyph_id,
            .size_x10 = @intFromFloat(size * 10),
        };

        if (self.glyphs.getPtr(key)) |cached| {
            cached.uv_bounds = uv_bounds;
            cached.uploaded = true;
        }
    }
};

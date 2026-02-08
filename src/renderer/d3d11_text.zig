//! D3D11 Text Renderer
//!
//! Text rendering using shared GlyphCache for rasterization and D3D11 for display.
//! Uploads glyphs to a D3D11 texture atlas on demand.

const std = @import("std");
const d3d11_renderer = @import("d3d11_renderer.zig");
const glyph_cache_mod = @import("../glyph_cache.zig");
const geometry = @import("../geometry.zig");

const d3d11 = d3d11_renderer.d3d11;
const D3D11Renderer = d3d11_renderer.D3D11Renderer;
const SpriteInstance = d3d11_renderer.SpriteInstance;
const GlyphCache = glyph_cache_mod.GlyphCache;
const FontId = glyph_cache_mod.FontId;
const Bounds = geometry.Bounds;
const Pixels = geometry.Pixels;

pub const D3D11TextRenderer = struct {
    allocator: std.mem.Allocator,
    glyph_cache: *GlyphCache,
    device: *d3d11.ID3D11Device,
    font_id: FontId,
    font_size: Pixels,

    // Atlas
    atlas_texture: ?*d3d11.ID3D11Texture2D,
    atlas_srv: ?*d3d11.ID3D11ShaderResourceView,
    atlas_data: []u8,
    atlas_size: u32,
    next_x: u32,
    next_y: u32,
    row_height: u32,
    dirty: bool,

    // Track which ASCII chars are uploaded
    ascii_uploaded: [128]bool,

    pub fn init(
        allocator: std.mem.Allocator,
        renderer: *D3D11Renderer,
        glyph_cache: *GlyphCache,
        font_id: FontId,
        font_size: u32,
    ) !D3D11TextRenderer {
        const atlas_size: u32 = 512;
        const atlas_data = try allocator.alloc(u8, atlas_size * atlas_size);
        @memset(atlas_data, 0);

        var self = D3D11TextRenderer{
            .allocator = allocator,
            .glyph_cache = glyph_cache,
            .device = renderer.device,
            .font_id = font_id,
            .font_size = @floatFromInt(font_size),
            .atlas_texture = null,
            .atlas_srv = null,
            .atlas_data = atlas_data,
            .atlas_size = atlas_size,
            .next_x = 1,
            .next_y = 1,
            .row_height = 0,
            .dirty = false,
            .ascii_uploaded = [_]bool{false} ** 128,
        };

        // Pre-cache ASCII printable characters
        for (32..127) |c| {
            _ = self.ensureGlyphUploaded(@intCast(c));
        }

        // Create D3D11 texture
        try self.createAtlasTexture(renderer);

        return self;
    }

    /// Initialize with font data (loads font into glyph cache)
    pub fn initWithFont(
        allocator: std.mem.Allocator,
        renderer: *D3D11Renderer,
        glyph_cache: *GlyphCache,
        font_data: []const u8,
        font_size: u32,
    ) !D3D11TextRenderer {
        const font_id = try glyph_cache.loadFont(font_data);
        return init(allocator, renderer, glyph_cache, font_id, font_size);
    }

    pub fn deinit(self: *D3D11TextRenderer) void {
        if (self.atlas_srv) |srv| {
            _ = srv.IUnknown.vtable.Release(&srv.IUnknown);
        }
        if (self.atlas_texture) |tex| {
            _ = tex.IUnknown.vtable.Release(&tex.IUnknown);
        }
        self.allocator.free(self.atlas_data);
    }

    fn ensureGlyphUploaded(self: *D3D11TextRenderer, char: u8) bool {
        if (char >= 128) return false;
        if (self.ascii_uploaded[char]) return true;

        const glyph_id = self.glyph_cache.getGlyphIndex(self.font_id, char) orelse return false;

        // Get or create cached glyph (this handles rasterization)
        const glyph = self.glyph_cache.getGlyph(self.font_id, glyph_id, self.font_size) orelse return false;

        // Already uploaded?
        if (glyph.uploaded) {
            self.ascii_uploaded[char] = true;
            return true;
        }

        const w: u32 = @intFromFloat(glyph.pixel_bounds.size.width);
        const h: u32 = @intFromFloat(glyph.pixel_bounds.size.height);

        if (w == 0 or h == 0) {
            // Space or empty - mark as uploaded but with no bitmap
            glyph.uploaded = true;
            self.ascii_uploaded[char] = true;
            return true;
        }

        // Need to re-rasterize to get bitmap data (getGlyph only caches metrics)
        const rasterized = self.glyph_cache.rasterizeGlyph(self.font_id, glyph_id, self.font_size) orelse return false;

        // Allocate space in atlas
        if (self.next_x + w + 1 > self.atlas_size) {
            self.next_x = 1;
            self.next_y += self.row_height + 1;
            self.row_height = 0;
        }

        if (self.next_y + h + 1 > self.atlas_size) {
            return false; // Atlas full
        }

        const x = self.next_x;
        const y = self.next_y;

        // Copy to atlas data
        for (0..h) |row| {
            const dst_offset = (y + row) * self.atlas_size + x;
            const src_offset = row * w;
            for (0..w) |col| {
                self.atlas_data[dst_offset + col] = rasterized.bitmap[src_offset + col];
            }
        }

        // Update UV in cached glyph
        const atlas_f: f32 = @floatFromInt(self.atlas_size);
        glyph.uv_bounds = Bounds(f32).fromXYWH(
            @as(f32, @floatFromInt(x)) / atlas_f,
            @as(f32, @floatFromInt(y)) / atlas_f,
            @as(f32, @floatFromInt(w)) / atlas_f,
            @as(f32, @floatFromInt(h)) / atlas_f,
        );
        glyph.uploaded = true;

        // Update tracking
        self.next_x += w + 1;
        if (h > self.row_height) {
            self.row_height = h;
        }

        self.ascii_uploaded[char] = true;
        self.dirty = true;
        return true;
    }

    fn createAtlasTexture(self: *D3D11TextRenderer, renderer: *D3D11Renderer) !void {
        var desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
        desc.Width = self.atlas_size;
        desc.Height = self.atlas_size;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = .R8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.Usage = .DEFAULT;
        desc.BindFlags = .{ .SHADER_RESOURCE = 1 };

        var init_data = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
        init_data.pSysMem = self.atlas_data.ptr;
        init_data.SysMemPitch = self.atlas_size;

        var texture: ?*d3d11.ID3D11Texture2D = null;
        const tex_hr = renderer.device.vtable.CreateTexture2D(
            renderer.device,
            &desc,
            &init_data,
            @ptrCast(&texture),
        );
        if (tex_hr != 0 or texture == null) {
            return error.CreateTextureFailed;
        }
        self.atlas_texture = texture;

        var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
        srv_desc.Format = .R8_UNORM;
        srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
        srv_desc.Anonymous.Texture2D.MostDetailedMip = 0;
        srv_desc.Anonymous.Texture2D.MipLevels = 1;

        var srv: ?*d3d11.ID3D11ShaderResourceView = null;
        const srv_hr = renderer.device.vtable.CreateShaderResourceView(
            renderer.device,
            @ptrCast(texture),
            &srv_desc,
            @ptrCast(&srv),
        );
        if (srv_hr != 0 or srv == null) {
            return error.CreateSRVFailed;
        }
        self.atlas_srv = srv;
        self.dirty = false;
    }

    /// Measure text width
    pub fn measureText(self: *D3D11TextRenderer, str: []const u8) f32 {
        var width: f32 = 0;
        for (str) |c| {
            if (c >= 128) continue;
            const glyph_id = self.glyph_cache.getGlyphIndex(self.font_id, c) orelse continue;
            if (self.glyph_cache.getGlyph(self.font_id, glyph_id, self.font_size)) |glyph| {
                width += glyph.advance;
            }
        }
        return width;
    }

    /// Draw text centered at (cx, baseline)
    pub fn drawCentered(self: *D3D11TextRenderer, renderer: *D3D11Renderer, str: []const u8, cx: f32, baseline: f32, color: [4]f32) void {
        const width = self.measureText(str);
        self.draw(renderer, str, cx - width / 2, baseline, color);
    }

    /// Draw text at (x, baseline)
    pub fn draw(self: *D3D11TextRenderer, renderer: *D3D11Renderer, str: []const u8, start_x: f32, baseline: f32, color: [4]f32) void {
        const srv = self.atlas_srv orelse return;

        var sprites: [256]SpriteInstance = undefined;
        var count: usize = 0;
        var x = start_x;

        for (str) |c| {
            if (c >= 128) continue;

            // Ensure uploaded
            _ = self.ensureGlyphUploaded(c);

            const glyph_id = self.glyph_cache.getGlyphIndex(self.font_id, c) orelse continue;
            const glyph = self.glyph_cache.getGlyph(self.font_id, glyph_id, self.font_size) orelse continue;

            if (glyph.pixel_bounds.size.width > 0 and glyph.pixel_bounds.size.height > 0 and glyph.uploaded and count < sprites.len) {
                sprites[count] = .{
                    .bounds = .{
                        x + glyph.pixel_bounds.origin.x,
                        baseline + glyph.pixel_bounds.origin.y,
                        glyph.pixel_bounds.size.width,
                        glyph.pixel_bounds.size.height,
                    },
                    .uv_bounds = .{
                        glyph.uv_bounds.origin.x,
                        glyph.uv_bounds.origin.y,
                        glyph.uv_bounds.size.width,
                        glyph.uv_bounds.size.height,
                    },
                    .color = color,
                    .content_mask = .{ 0, 0, 0, 0 },
                };
                count += 1;
            }
            x += glyph.advance;
        }

        if (count > 0) {
            renderer.drawSprites(sprites[0..count], srv, true);
        }
    }

    /// Get atlas size
    pub fn getAtlasSize(self: *D3D11TextRenderer) u32 {
        return self.atlas_size;
    }

    /// Get glyph cache (for sharing with TextSystem)
    pub fn getGlyphCache(self: *D3D11TextRenderer) *GlyphCache {
        return self.glyph_cache;
    }
};

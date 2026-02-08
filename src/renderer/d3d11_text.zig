//! D3D11 Text Renderer
//!
//! Text rendering using FreeType for glyph rasterization and D3D11 for display.
//! Caches glyphs in a texture atlas for efficient rendering.
//!
//! Can be used standalone or integrated with TextSystem for scene-based rendering.

const std = @import("std");
const freetype = @import("freetype");
const d3d11_renderer = @import("d3d11_renderer.zig");
const geometry = @import("../geometry.zig");

const d3d11 = d3d11_renderer.d3d11;
const D3D11Renderer = d3d11_renderer.D3D11Renderer;
const SpriteInstance = d3d11_renderer.SpriteInstance;
const Bounds = geometry.Bounds;

pub const D3D11TextRenderer = struct {
    allocator: std.mem.Allocator,
    ft_lib: freetype.Library,
    face: freetype.Face,
    device: *d3d11.ID3D11Device,
    
    // Glyph cache
    glyphs: [128]Glyph,
    atlas_texture: ?*d3d11.ID3D11Texture2D,
    atlas_srv: ?*d3d11.ID3D11ShaderResourceView,
    atlas_size: u32,
    atlas_data: []u8,
    next_x: u32,
    next_y: u32,
    row_height: u32,

    pub const Glyph = struct {
        x: u32 = 0,      // Atlas x position (pixels)
        y: u32 = 0,      // Atlas y position (pixels)  
        w: u32 = 0,      // Width (pixels)
        h: u32 = 0,      // Height (pixels)
        bearing_x: i32 = 0,
        bearing_y: i32 = 0,
        advance: i32 = 0,
        cached: bool = false,
    };

    pub fn init(allocator: std.mem.Allocator, renderer: *D3D11Renderer, font_data: []const u8, font_size: u32) !D3D11TextRenderer {
        // Initialize FreeType
        const ft_lib = freetype.Library.init() catch return error.FreeTypeInitFailed;
        errdefer ft_lib.deinit();

        const face = ft_lib.initMemoryFace(font_data, 0) catch return error.FontLoadFailed;
        errdefer face.deinit();

        face.setPixelSizes(0, font_size) catch return error.FontSizeFailed;

        // Allocate atlas
        const atlas_size: u32 = 512;
        const atlas_data = try allocator.alloc(u8, atlas_size * atlas_size);
        @memset(atlas_data, 0);

        var self = D3D11TextRenderer{
            .allocator = allocator,
            .ft_lib = ft_lib,
            .face = face,
            .device = renderer.device,
            .glyphs = [_]Glyph{.{}} ** 128,
            .atlas_texture = null,
            .atlas_srv = null,
            .atlas_size = atlas_size,
            .atlas_data = atlas_data,
            .next_x = 2,
            .next_y = 2,
            .row_height = 0,
        };

        // Pre-cache ASCII printable characters
        for (32..127) |c| {
            _ = self.cacheGlyph(@intCast(c));
        }

        // Create D3D11 texture
        try self.createAtlasTexture(renderer);

        return self;
    }

    pub fn deinit(self: *D3D11TextRenderer) void {
        if (self.atlas_srv) |srv| {
            _ = srv.IUnknown.vtable.Release(&srv.IUnknown);
        }
        if (self.atlas_texture) |tex| {
            _ = tex.IUnknown.vtable.Release(&tex.IUnknown);
        }
        self.allocator.free(self.atlas_data);
        self.face.deinit();
        self.ft_lib.deinit();
    }

    fn cacheGlyph(self: *D3D11TextRenderer, char: u8) bool {
        if (char >= 128) return false;
        if (self.glyphs[char].cached) return true;

        const glyph_index = self.face.getCharIndex(char) orelse return false;
        self.face.loadGlyph(glyph_index, .{ .render = true }) catch return false;

        const glyph = self.face.handle.*.glyph;
        const bitmap = &glyph.*.bitmap;

        const w = bitmap.width;
        const h = bitmap.rows;

        // Check if we need to move to next row
        if (self.next_x + w + 2 > self.atlas_size) {
            self.next_x = 2;
            self.next_y += self.row_height + 2;
            self.row_height = 0;
        }

        // Check if atlas is full
        if (self.next_y + h + 2 > self.atlas_size) {
            return false;
        }

        // Copy bitmap to atlas
        if (w > 0 and h > 0) {
            const src: [*]const u8 = @ptrCast(bitmap.buffer);
            const pitch: u32 = @intCast(if (bitmap.pitch < 0) -bitmap.pitch else bitmap.pitch);

            for (0..h) |row| {
                const dst_offset = (self.next_y + row) * self.atlas_size + self.next_x;
                const src_offset = row * pitch;
                for (0..w) |col| {
                    self.atlas_data[dst_offset + col] = src[src_offset + col];
                }
            }
        }

        self.glyphs[char] = .{
            .x = self.next_x,
            .y = self.next_y,
            .w = w,
            .h = h,
            .bearing_x = glyph.*.bitmap_left,
            .bearing_y = glyph.*.bitmap_top,
            .advance = @intCast(glyph.*.advance.x >> 6),
            .cached = true,
        };

        self.next_x += w + 2;
        if (h > self.row_height) {
            self.row_height = h;
        }

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
            renderer.device, &desc, &init_data, @ptrCast(&texture)
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
            renderer.device, @ptrCast(texture), &srv_desc, @ptrCast(&srv)
        );
        if (srv_hr != 0 or srv == null) {
            return error.CreateSRVFailed;
        }
        self.atlas_srv = srv;
    }

    /// Measure the width of a string in pixels
    pub fn measureText(self: *D3D11TextRenderer, str: []const u8) f32 {
        var width: f32 = 0;
        for (str) |c| {
            if (c < 128 and self.glyphs[c].cached) {
                width += @floatFromInt(self.glyphs[c].advance);
            }
        }
        return width;
    }

    /// Get glyph info for scene-based rendering
    /// Returns UV bounds in atlas coordinates (0-1)
    pub const GlyphInfo = struct {
        uv_bounds: Bounds(f32), // UV coordinates in atlas
        pixel_bounds: Bounds(f32), // Pixel size and bearing
        advance: f32,
        valid: bool,
    };

    pub fn getGlyphInfo(self: *D3D11TextRenderer, char: u8) GlyphInfo {
        if (char >= 128 or !self.glyphs[char].cached) {
            return .{ .uv_bounds = Bounds(f32).zero, .pixel_bounds = Bounds(f32).zero, .advance = 0, .valid = false };
        }

        const g = self.glyphs[char];
        const atlas_f: f32 = @floatFromInt(self.atlas_size);
        const gw: f32 = @floatFromInt(g.w);
        const gh: f32 = @floatFromInt(g.h);

        return .{
            .uv_bounds = Bounds(f32).fromXYWH(
                @as(f32, @floatFromInt(g.x)) / atlas_f,
                @as(f32, @floatFromInt(g.y)) / atlas_f,
                gw / atlas_f,
                gh / atlas_f,
            ),
            .pixel_bounds = Bounds(f32).fromXYWH(
                @floatFromInt(g.bearing_x),
                -@as(f32, @floatFromInt(g.bearing_y)),
                gw,
                gh,
            ),
            .advance = @floatFromInt(g.advance),
            .valid = true,
        };
    }

    /// Get atlas size
    pub fn getAtlasSize(self: *D3D11TextRenderer) u32 {
        return self.atlas_size;
    }

    /// Draw text centered at (cx, baseline)
    pub fn drawCentered(self: *D3D11TextRenderer, renderer: *D3D11Renderer, str: []const u8, cx: f32, baseline: f32, color: [4]f32) void {
        const width = self.measureText(str);
        self.draw(renderer, str, cx - width / 2, baseline, color);
    }

    /// Draw text at (x, baseline) - x is left edge
    pub fn draw(self: *D3D11TextRenderer, renderer: *D3D11Renderer, str: []const u8, start_x: f32, baseline: f32, color: [4]f32) void {
        const srv = self.atlas_srv orelse return;
        const atlas_f: f32 = @floatFromInt(self.atlas_size);

        var sprites: [256]SpriteInstance = undefined;
        var count: usize = 0;
        var x = start_x;

        for (str) |c| {
            if (c >= 128) continue;
            const g = self.glyphs[c];
            if (!g.cached) continue;

            if (g.w > 0 and g.h > 0 and count < sprites.len) {
                const gx = x + @as(f32, @floatFromInt(g.bearing_x));
                const gy = baseline - @as(f32, @floatFromInt(g.bearing_y));
                const gw: f32 = @floatFromInt(g.w);
                const gh: f32 = @floatFromInt(g.h);

                sprites[count] = .{
                    .bounds = .{ gx, gy, gw, gh },
                    .uv_bounds = .{
                        @as(f32, @floatFromInt(g.x)) / atlas_f,
                        @as(f32, @floatFromInt(g.y)) / atlas_f,
                        gw / atlas_f,
                        gh / atlas_f,
                    },
                    .color = color,
                    .content_mask = .{ 0, 0, 0, 0 },
                };
                count += 1;
            }
            x += @floatFromInt(g.advance);
        }

        if (count > 0) {
            renderer.drawSprites(sprites[0..count], srv, true);
        }
    }
};

//! Hello World - Port of GPUI's hello_world.rs example
//!
//! Win32 + D3D11 implementation.
//! See hello_world.rs for original GPUI source.

const std = @import("std");
const zapui = @import("zapui");
const freetype = @import("freetype");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const S_OK = zapui.renderer.d3d11_renderer.S_OK;

const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;

fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

// Embedded font
const font_data = @embedFile("LiberationSans-Regular.ttf");

// ============================================================================
// Colors - matching GPUI example
// ============================================================================

const bg_color = [4]f32{ 0.314, 0.314, 0.314, 1.0 }; // rgb(0x505050)
const red_color = [4]f32{ 1.0, 0.0, 0.0, 1.0 };
const green_color = [4]f32{ 0.0, 0.5, 0.0, 1.0 }; // GPUI's green
const blue_color = [4]f32{ 0.0, 0.0, 1.0, 1.0 };
const yellow_color = [4]f32{ 1.0, 1.0, 0.0, 1.0 };
const black_color = [4]f32{ 0.0, 0.0, 0.0, 1.0 };
const white_color = [4]f32{ 1.0, 1.0, 1.0, 1.0 };

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize FreeType for text rendering
    const ft_lib = freetype.Library.init() catch {
        std.debug.print("Failed to initialize FreeType\n", .{});
        return error.FreeTypeInitFailed;
    };
    defer ft_lib.deinit();

    const face = ft_lib.initMemoryFace(font_data, 0) catch {
        std.debug.print("Failed to load font\n", .{});
        return error.FontLoadFailed;
    };
    defer face.deinit();

    // Set font size (text_xl = 20px)
    face.setPixelSizes(0, 20) catch {
        std.debug.print("Failed to set font size\n", .{});
        return error.FontSizeFailed;
    };

    // Initialize Win32 platform
    var plat = try win32_platform.init();
    defer plat.deinit();

    // Create 500x500 window to match GPUI example
    const window = try win32_platform.createWindow(&plat, .{
        .width = 500,
        .height = 500,
        .title = "Hello World - ZapUI (Win32 + D3D11)",
    });
    defer window.destroy();

    std.debug.print("Hello World - ZapUI (Win32 + D3D11)\n", .{});
    std.debug.print("Press ESC to exit\n", .{});

    // Initialize D3D11 renderer
    var renderer = D3D11Renderer.init(allocator, window.hwnd.?, 500, 500) catch |err| {
        std.debug.print("Failed to initialize D3D11: {}\n", .{err});
        return err;
    };
    defer renderer.deinit();

    // Create glyph atlas texture
    const atlas_size: u32 = 256;
    var atlas_data = try allocator.alloc(u8, atlas_size * atlas_size);
    defer allocator.free(atlas_data);
    @memset(atlas_data, 0);

    // Render "Hello, World!" glyphs into atlas
    const text = "Hello, World!";
    var glyph_x: u32 = 2;
    const glyph_y: u32 = 2;

    const GlyphInfo = struct {
        atlas_x: u32,
        atlas_y: u32,
        width: u32,
        height: u32,
        bearing_x: i32,
        bearing_y: i32,
        advance: i32,
    };

    var glyph_infos: [text.len]GlyphInfo = undefined;

    for (text, 0..) |char, i| {
        const glyph_index = face.getCharIndex(char) orelse continue;
        face.loadGlyph(glyph_index, .{ .render = true }) catch continue;

        const glyph = face.handle.*.glyph;
        const bitmap = &glyph.*.bitmap;

        if (bitmap.width > 0 and bitmap.rows > 0) {
            const src: [*]const u8 = @ptrCast(bitmap.buffer);
            const w = bitmap.width;
            const h = bitmap.rows;
            const pitch = @as(u32, @intCast(if (bitmap.pitch < 0) -bitmap.pitch else bitmap.pitch));

            for (0..h) |row| {
                const dst_row = (glyph_y + row) * atlas_size + glyph_x;
                const src_row = row * pitch;
                for (0..w) |col| {
                    atlas_data[dst_row + col] = src[src_row + col];
                }
            }

            glyph_infos[i] = .{
                .atlas_x = glyph_x,
                .atlas_y = glyph_y,
                .width = w,
                .height = h,
                .bearing_x = glyph.*.bitmap_left,
                .bearing_y = glyph.*.bitmap_top,
                .advance = @intCast(glyph.*.advance.x >> 6),
            };

            glyph_x += w + 2;
        } else {
            glyph_infos[i] = .{
                .atlas_x = 0,
                .atlas_y = 0,
                .width = 0,
                .height = 0,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance = @intCast(glyph.*.advance.x >> 6),
            };
        }
    }

    // Create D3D11 texture for atlas
    var tex_desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
    tex_desc.Width = atlas_size;
    tex_desc.Height = atlas_size;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = .R8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = .DEFAULT;
    tex_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };

    var init_data = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    init_data.pSysMem = atlas_data.ptr;
    init_data.SysMemPitch = atlas_size;

    var atlas_texture: ?*d3d11.ID3D11Texture2D = null;
    const tex_hr = renderer.device.vtable.CreateTexture2D(renderer.device, &tex_desc, &init_data, @ptrCast(&atlas_texture));
    if (tex_hr != S_OK or atlas_texture == null) {
        std.debug.print("Failed to create atlas texture\n", .{});
        return error.CreateTextureFailed;
    }
    defer if (atlas_texture) |t| release(d3d11.ID3D11Texture2D, t);

    // Create SRV for atlas
    var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
    srv_desc.Format = .R8_UNORM;
    srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
    srv_desc.Anonymous.Texture2D.MostDetailedMip = 0;
    srv_desc.Anonymous.Texture2D.MipLevels = 1;

    var atlas_srv: ?*d3d11.ID3D11ShaderResourceView = null;
    const srv_hr = renderer.device.vtable.CreateShaderResourceView(renderer.device, @ptrCast(atlas_texture), &srv_desc, @ptrCast(&atlas_srv));
    if (srv_hr != S_OK or atlas_srv == null) {
        std.debug.print("Failed to create atlas SRV\n", .{});
        return error.CreateSRVFailed;
    }
    defer if (atlas_srv) |s| release(d3d11.ID3D11ShaderResourceView, s);

    // Main loop
    while (!window.shouldClose()) {
        const events = window.pollEvents();

        for (events) |event| {
            switch (event) {
                .key => |k| {
                    if (k.key == .escape and k.action == .press) {
                        return;
                    }
                },
                .resize => |r| {
                    renderer.resize(r.width, r.height) catch {};
                },
                else => {},
            }
        }

        // Render frame
        renderer.beginFrame();
        renderer.clear(bg_color[0], bg_color[1], bg_color[2], bg_color[3]);

        // Layout calculations matching GPUI:
        // - gap_3 = 12px between text and boxes
        // - size_8 = 32px boxes, gap_2 = 8px between boxes
        const box_size: f32 = 32;
        const gap_2: f32 = 8;
        const gap_3: f32 = 12;
        const text_height: f32 = 20;
        const total_content_height = text_height + gap_3 + box_size;
        const content_start_y: f32 = (500 - total_content_height) / 2;
        const total_boxes_width = 6 * box_size + 5 * gap_2;
        const boxes_x = (500 - total_boxes_width) / 2;
        const boxes_y = content_start_y + text_height + gap_3;

        // Draw colored boxes
        var quads: [6]QuadInstance = undefined;

        const colors = [_][4]f32{ red_color, green_color, blue_color, yellow_color, black_color, white_color };
        const border_colors = [_][4]f32{ white_color, white_color, white_color, white_color, white_color, black_color };

        for (0..6) |i| {
            const fi: f32 = @floatFromInt(i);
            quads[i] = .{
                .bounds = .{ boxes_x + fi * (box_size + gap_2), boxes_y, box_size, box_size },
                .background_color = colors[i],
                .border_color = border_colors[i],
                .border_widths = .{ 1, 1, 1, 1 },
                .corner_radii = .{ 6, 6, 6, 6 }, // rounded_md
                .content_mask = .{ 0, 0, 0, 0 },
                .border_style = .{ 1, 0, 0, 0 }, // dashed
            };
        }

        renderer.drawQuads(&quads);

        // Draw text
        var text_width: f32 = 0;
        for (glyph_infos) |info| {
            text_width += @floatFromInt(info.advance);
        }

        const text_x = (500 - text_width) / 2;
        const baseline_y = content_start_y + 16;

        var sprites: [text.len]SpriteInstance = undefined;
        var cursor_x = text_x;
        var sprite_count: usize = 0;
        const atlas_size_f: f32 = @floatFromInt(atlas_size);

        for (glyph_infos) |info| {
            if (info.width > 0 and info.height > 0) {
                const gx = cursor_x + @as(f32, @floatFromInt(info.bearing_x));
                const gy = baseline_y - @as(f32, @floatFromInt(info.bearing_y));

                sprites[sprite_count] = .{
                    .bounds = .{ gx, gy, @floatFromInt(info.width), @floatFromInt(info.height) },
                    .uv_bounds = .{
                        @as(f32, @floatFromInt(info.atlas_x)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.atlas_y)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.width)) / atlas_size_f,
                        @as(f32, @floatFromInt(info.height)) / atlas_size_f,
                    },
                    .color = white_color,
                    .content_mask = .{ 0, 0, 0, 0 },
                };
                sprite_count += 1;
            }
            cursor_x += @floatFromInt(info.advance);
        }

        if (sprite_count > 0) {
            renderer.drawSprites(sprites[0..sprite_count], atlas_srv.?, true);
        }

        renderer.present(true);
    }
}

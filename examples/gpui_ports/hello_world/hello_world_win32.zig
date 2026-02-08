//! Hello World - Native Win32 + DirectX 11 version
//!
//! This is the same hello_world example but using native Win32 windowing
//! and D3D11 rendering. This matches how GPUI works on Windows.

const std = @import("std");
const zapui = @import("zapui");

const d3d11 = zapui.renderer.d3d11_renderer.d3d11;
const S_OK = zapui.renderer.d3d11_renderer.S_OK;

// Use Win32 platform
const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;
const SpriteInstance = zapui.renderer.d3d11_renderer.SpriteInstance;

const platform = zapui.platform;

fn release(comptime T: type, obj: *T) void {
    _ = obj.IUnknown.vtable.Release(&obj.IUnknown);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize Win32 platform
    var plat = try win32_platform.init();
    defer plat.deinit();

    // Create window
    const window = try win32_platform.createWindow(&plat, .{
        .width = 500,
        .height = 500,
        .title = "Hello World - ZapUI (Win32 + D3D11)",
    });
    defer window.destroy();

    std.debug.print("Hello World - ZapUI (Win32 + D3D11)\n", .{});
    std.debug.print("Press ESC or close window to exit\n", .{});

    // Initialize D3D11 renderer
    var renderer = D3D11Renderer.init(allocator, window.hwnd.?, 500, 500) catch |err| {
        std.debug.print("Failed to initialize D3D11: {}\n", .{err});
        return err;
    };
    defer renderer.deinit();
    
    // Create a simple test texture (8x8 checkerboard pattern)
    const tex_size: u32 = 64;
    var tex_data: [tex_size * tex_size]u8 = undefined;
    for (0..tex_size) |y| {
        for (0..tex_size) |x| {
            const checker = ((x / 8) + (y / 8)) % 2 == 0;
            tex_data[y * tex_size + x] = if (checker) 255 else 128;
        }
    }
    
    // Create D3D11 texture
    var tex_desc = std.mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
    tex_desc.Width = tex_size;
    tex_desc.Height = tex_size;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = .R8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = .DEFAULT;
    tex_desc.BindFlags = .{ .SHADER_RESOURCE = 1 };
    
    var init_data = std.mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    init_data.pSysMem = &tex_data;
    init_data.SysMemPitch = tex_size;
    
    var test_texture: ?*d3d11.ID3D11Texture2D = null;
    const tex_hr = renderer.device.vtable.CreateTexture2D(renderer.device, &tex_desc, &init_data, @ptrCast(&test_texture));
    if (tex_hr != S_OK or test_texture == null) {
        std.debug.print("Failed to create test texture\n", .{});
        return error.CreateTextureFailed;
    }
    defer if (test_texture) |t| release(d3d11.ID3D11Texture2D, t);
    
    // Create SRV for test texture
    var srv_desc = std.mem.zeroes(d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
    srv_desc.Format = .R8_UNORM;
    srv_desc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
    srv_desc.Anonymous.Texture2D.MostDetailedMip = 0;
    srv_desc.Anonymous.Texture2D.MipLevels = 1;
    
    var test_srv: ?*d3d11.ID3D11ShaderResourceView = null;
    const srv_hr = renderer.device.vtable.CreateShaderResourceView(renderer.device, @ptrCast(test_texture), &srv_desc, @ptrCast(&test_srv));
    if (srv_hr != S_OK or test_srv == null) {
        std.debug.print("Failed to create test SRV\n", .{});
        return error.CreateSRVFailed;
    }
    defer if (test_srv) |s| release(d3d11.ID3D11ShaderResourceView, s);

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
        renderer.clear(0.1, 0.1, 0.1, 1.0); // Dark gray background
        
        // Draw the main container (centered gray box with blue border)
        const container_size: f32 = 400;
        const container_x = (@as(f32, @floatFromInt(renderer.width)) - container_size) / 2;
        const container_y = (@as(f32, @floatFromInt(renderer.height)) - container_size) / 2;
        
        // Draw colored boxes like in hello_world
        const box_size: f32 = 32;
        const gap: f32 = 8;
        const total_width = 6 * box_size + 5 * gap;
        const boxes_x = container_x + (container_size - total_width) / 2;
        const boxes_y = container_y + container_size / 2 + 20;
        
        var quads: [7]QuadInstance = undefined;
        
        // Main container
        quads[0] = .{
            .bounds = .{ container_x, container_y, container_size, container_size },
            .background_color = .{ 0.31, 0.31, 0.31, 1.0 }, // rgb(0x505050)
            .border_color = .{ 0.0, 0.0, 1.0, 1.0 }, // blue
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 0, 0, 0, 0 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 0, 0, 0, 0 },
        };
        
        // Red box
        quads[1] = .{
            .bounds = .{ boxes_x + 0 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 0.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 }, // dashed
        };
        
        // Green box
        quads[2] = .{
            .bounds = .{ boxes_x + 1 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.5, 0.0, 1.0 }, // GPUI green
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Blue box
        quads[3] = .{
            .bounds = .{ boxes_x + 2 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.0, 1.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Yellow box
        quads[4] = .{
            .bounds = .{ boxes_x + 3 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 1.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // Black box
        quads[5] = .{
            .bounds = .{ boxes_x + 4 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 0.0, 0.0, 0.0, 1.0 },
            .border_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        // White box
        quads[6] = .{
            .bounds = .{ boxes_x + 5 * (box_size + gap), boxes_y, box_size, box_size },
            .background_color = .{ 1.0, 1.0, 1.0, 1.0 },
            .border_color = .{ 0.0, 0.0, 0.0, 1.0 }, // black border
            .border_widths = .{ 1, 1, 1, 1 },
            .corner_radii = .{ 4, 4, 4, 4 },
            .content_mask = .{ 0, 0, 0, 0 },
            .border_style = .{ 1, 0, 0, 0 },
        };
        
        renderer.drawQuads(&quads);
        
        // Draw test sprites using the checkerboard texture
        // These simulate "Hello, World!" text
        const text = "Hello, World!";
        const char_width: f32 = 14;
        const char_height: f32 = 20;
        const text_width = @as(f32, @floatFromInt(text.len)) * char_width;
        const text_x = container_x + (container_size - text_width) / 2;
        const text_y = container_y + container_size / 2 - 50;
        
        var sprites: [text.len]SpriteInstance = undefined;
        for (0..text.len) |i| {
            const fi: f32 = @floatFromInt(i);
            const c = text[i];
            sprites[i] = .{
                .bounds = .{ text_x + fi * char_width, text_y, char_width - 2, char_height },
                .uv_bounds = .{ 0, 0, 1, 1 }, // Full texture
                .color = .{ 1.0, 1.0, 1.0, if (c == ' ' or c == ',') 0.0 else 1.0 }, // White tint, hide space/comma
                .content_mask = .{ 0, 0, 0, 0 },
            };
        }
        
        renderer.drawSprites(&sprites, test_srv.?, true); // mono mode

        renderer.present(true);
    }
}

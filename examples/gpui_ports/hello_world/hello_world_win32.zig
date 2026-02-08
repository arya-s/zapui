//! Hello World - Native Win32 + DirectX 11 version
//!
//! This is the same hello_world example but using native Win32 windowing
//! and D3D11 rendering. This matches how GPUI works on Windows.

const std = @import("std");
const zapui = @import("zapui");

// Use Win32 platform
const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const QuadInstance = zapui.renderer.d3d11_renderer.QuadInstance;

const platform = zapui.platform;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    _ = allocator;

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
    var renderer = D3D11Renderer.init(std.heap.page_allocator, window.hwnd.?, 500, 500) catch |err| {
        std.debug.print("Failed to initialize D3D11: {}\n", .{err});
        return err;
    };
    defer renderer.deinit();

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
        
        // "Hello, World!" text placeholder - draw letter rectangles
        // In a full implementation, these would be glyph sprites from the atlas
        const text = "Hello, World!";
        const char_width: f32 = 12;
        const char_height: f32 = 20;
        const text_width = @as(f32, @floatFromInt(text.len)) * char_width;
        const text_x = container_x + (container_size - text_width) / 2;
        const text_y = container_y + container_size / 2 - 40;
        
        var quads: [7 + text.len]QuadInstance = undefined;
        
        // Add text character placeholders (white rectangles for now)
        for (0..text.len) |i| {
            const fi: f32 = @floatFromInt(i);
            quads[7 + i] = .{
                .bounds = .{ text_x + fi * char_width, text_y, char_width - 2, char_height },
                .background_color = .{ 1.0, 1.0, 1.0, if (text[i] == ' ') 0.0 else 0.8 },
                .border_color = .{ 0, 0, 0, 0 },
                .border_widths = .{ 0, 0, 0, 0 },
                .corner_radii = .{ 2, 2, 2, 2 },
                .content_mask = .{ 0, 0, 0, 0 },
                .border_style = .{ 0, 0, 0, 0 },
            };
        }
        
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

        renderer.present(true);
    }
}

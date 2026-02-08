//! Hello World - Native Win32 + DirectX 11 version
//!
//! This is the same hello_world example but using native Win32 windowing
//! and D3D11 rendering. This matches how GPUI works on Windows.

const std = @import("std");
const zapui = @import("zapui");

// Use Win32 platform
const win32_platform = zapui.platform.Win32Backend;
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;

const platform = zapui.platform;

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

        // Clear to dark gray background (like GPUI hello_world)
        renderer.beginFrame();
        renderer.clear(0.1, 0.1, 0.1, 1.0);

        // TODO: Render scene with D3D11

        renderer.present(true);
    }
}

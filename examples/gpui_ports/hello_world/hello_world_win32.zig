//! Hello World - Native Win32 + DirectX 11 version
//!
//! This is the same hello_world example but using native Win32 windowing
//! instead of GLFW. This matches how GPUI works on Windows.

const std = @import("std");
const zapui = @import("zapui");

// Use Win32 platform
const win32_platform = zapui.platform.Win32Backend;

const Scene = zapui.Scene;
const zaffy = zapui.zaffy;
const Pixels = zapui.Pixels;

// GPUI-style API
const div = zapui.elements.div.div;
const h_flex = zapui.elements.div.h_flex;
const reset = zapui.elements.div.reset;
const px = zapui.elements.div.px;

// Colors
const bg_color = zapui.rgb(0x505050);
const border_color = zapui.rgb(0x0000ff);
const text_color = zapui.rgb(0xffffff);
const red = zapui.rgb(0xff0000);
const green = zapui.hsla(0.333, 1.0, 0.25, 1.0);
const blue = zapui.rgb(0x0000ff);
const yellow = zapui.rgb(0xffff00);
const black = zapui.rgb(0x000000);
const white = zapui.rgb(0xffffff);

fn renderHelloWorld(tree: *zaffy.Zaffy, scene: *Scene, text_system: *zapui.TextSystem, name: []const u8) !void {
    reset();

    const rem: Pixels = 16.0;

    var greeting_buf: [64]u8 = undefined;
    const greeting = std.fmt.bufPrint(&greeting_buf, "Hello, {s}!", .{name}) catch "Hello, World!";

    const root = div()
        .flex()
        .flex_col()
        .gap_3()
        .bg(bg_color)
        .size(px(500))
        .justify_center()
        .items_center()
        .shadow_lg()
        .border_1()
        .border_color(border_color)
        .text_xl()
        .text_color(text_color)
        .child(div().child_text(greeting))
        .child(h_flex()
            .gap_2()
            .child(div().size_8().bg(red).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(green).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(blue).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(yellow).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(black).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(white).border_1().border_dashed().rounded_md().border_color(black)));

    try root.buildWithTextSystem(tree, rem, text_system);
    tree.computeLayoutWithSize(root.node_id.?, 500, 500);
    root.paint(scene, text_system, 0, 0, tree, null, null);
}

pub fn main() !void {
    // Initialize Win32 platform
    var platform = try win32_platform.init();
    defer platform.deinit();

    // Create window
    const window = try win32_platform.createWindow(&platform, .{
        .width = 500,
        .height = 500,
        .title = "Hello World - ZapUI (Win32)",
    });
    defer window.destroy();

    // TODO: Initialize D3D11 renderer
    // For now, we'll just show the window works

    std.debug.print("Hello World - ZapUI (Win32 Native)\n", .{});
    std.debug.print("Press ESC or close window to exit\n", .{});

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
                else => {},
            }
        }

        // TODO: Render with D3D11
        // For now, just show the window

        std.Thread.sleep(16 * std.time.ns_per_ms); // ~60 FPS
    }
}

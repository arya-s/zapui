//! Hello World - Port of GPUI's hello_world.rs example
//!
//! This version uses ZapUI's div element system, matching GPUI's API closely.

const std = @import("std");
const zapui = @import("zapui");

// Element system
const div_mod = zapui.elements.div;
const div = div_mod.div;
const px = div_mod.px;

// Layout
const zaffy = zapui.zaffy;

// Rendering
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const D3D11TextRenderer = zapui.renderer.d3d11_text.D3D11TextRenderer;
const Scene = zapui.scene.Scene;

// Platform
const Win32 = zapui.platform.Win32Backend;

// Colors (matches GPUI's color functions)
const color = zapui.color;
const rgb = color.rgb;
const red = color.red;
const green = color.green;
const blue = color.blue;
const yellow = color.yellow;
const black = color.black;
const white = color.white;

// ============================================================================
// HelloWorld
// ============================================================================

const HelloWorld = struct {
    text: []const u8,

    // Port of GPUI's Render trait:
    //
    // fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
    //     div()
    //         .flex()
    //         .flex_col()
    //         .gap_3()
    //         .bg(rgb(0x505050))
    //         .size(px(500.0))
    //         .justify_center()
    //         .items_center()
    //         .text_xl()
    //         .text_color(rgb(0xffffff))
    //         .child(format!("Hello, {}!", &self.text))
    //         .child(
    //             div()
    //                 .flex()
    //                 .gap_2()
    //                 .child(div().size_8().bg(gpui::red()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
    //                 .child(div().size_8().bg(gpui::green()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
    //                 .child(div().size_8().bg(gpui::blue()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
    //                 .child(div().size_8().bg(gpui::yellow()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
    //                 .child(div().size_8().bg(gpui::black()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
    //                 .child(div().size_8().bg(gpui::white()).border_1().border_dashed().rounded_md().border_color(gpui::black()))
    //         )
    // }
    //
    fn render(self: *HelloWorld, allocator: std.mem.Allocator, label_buf: []u8) !*div_mod.Div {
        _ = allocator;

        // Format the text (into provided buffer for lifetime)
        const label = std.fmt.bufPrint(label_buf, "Hello, {s}!", .{self.text}) catch "Hello!";

        // Build the UI tree (matches GPUI exactly)
        // Note: In GPUI, .child("text") creates a text child element.
        // In ZapUI, we use a div with child_text() for the same effect.
        return div()
            .flex()
            .flex_col()
            .gap_3()
            .bg(rgb(0x505050))
            .size(px(500))
            .justify_center()
            .items_center()
            .text_xl()
            .text_color(rgb(0xffffff))
            .child(div().child_text(label))  // text as a child div
            .child(
                div()
                    .flex()
                    .gap_2()
                    .child(div().size_8().bg(red()).border_1().border_dashed().rounded_md().border_color(white()))
                    .child(div().size_8().bg(green()).border_1().border_dashed().rounded_md().border_color(white()))
                    .child(div().size_8().bg(blue()).border_1().border_dashed().rounded_md().border_color(white()))
                    .child(div().size_8().bg(yellow()).border_1().border_dashed().rounded_md().border_color(white()))
                    .child(div().size_8().bg(black()).border_1().border_dashed().rounded_md().border_color(white()))
                    .child(div().size_8().bg(white()).border_1().border_dashed().rounded_md().border_color(black()))
            );
    }
};

// ============================================================================
// Text Rendering Helper
// ============================================================================

/// Recursively draw text for div tree using D3D11TextRenderer
fn drawTextForDiv(
    d: *const div_mod.Div,
    layout_tree: *const zaffy.Zaffy,
    text_renderer: *D3D11TextRenderer,
    renderer: *D3D11Renderer,
    parent_x: f32,
    parent_y: f32,
) void {
    const nid = d.node_id orelse return;
    const lay = layout_tree.getLayout(nid);
    const x = parent_x + lay.location.x;
    const y = parent_y + lay.location.y;

    // Draw text content if present
    if (d.text_content_val) |text| {
        const text_w = text_renderer.measureText(text);
        // Center horizontally, vertically (accounting for font baseline)
        const tx = x + (lay.size.width - text_w) / 2;
        const ty = y + lay.size.height / 2 + 6; // baseline offset
        const text_color = d.text_color_val;
        text_renderer.draw(renderer, text, tx, ty, .{
            text_color.toRgba().r,
            text_color.toRgba().g,
            text_color.toRgba().b,
            text_color.toRgba().a,
        });
    }

    // Recurse into children
    for (d.children[0..d.child_count]) |maybe_child| {
        if (maybe_child) |child| {
            drawTextForDiv(child, layout_tree, text_renderer, renderer, x, y);
        }
    }
}

// ============================================================================
// Main
// ============================================================================

const font_data = @embedFile("LiberationSans-Regular.ttf");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Platform
    var platform = try Win32.init();
    defer platform.deinit();

    const window = try Win32.createWindow(&platform, .{
        .width = 500,
        .height = 500,
        .title = "Hello World",
    });
    defer window.destroy();

    // Renderer
    var renderer = try D3D11Renderer.init(allocator, window.hwnd.?, 500, 500);
    defer renderer.deinit();

    // Text system (for measuring and rendering text)
    var text_system = try zapui.text_system.TextSystem.init(allocator);
    defer text_system.deinit();

    // Load font into text system
    _ = try text_system.loadFontMem(font_data);

    // Text renderer (D3D11 specific)
    var text_renderer = try D3D11TextRenderer.init(allocator, &renderer, font_data, 20);
    defer text_renderer.deinit();

    // Layout engine
    var layout = zaffy.Zaffy.init(allocator);
    defer layout.deinit();

    // Scene (collects primitives for rendering)
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // Application state
    var state = HelloWorld{ .text = "World" };

    while (!window.shouldClose()) {
        for (window.pollEvents()) |e| {
            switch (e) {
                .key => |k| if (k.key == .escape) return,
                .resize => |r| renderer.resize(r.width, r.height) catch {},
                else => {},
            }
        }

        // Reset element storage for this frame
        div_mod.reset();

        // Build UI tree (use static buffer for text lifetime)
        var label_buf: [64]u8 = undefined;
        const root = try state.render(allocator, &label_buf);

        // Layout
        try root.buildWithTextSystem(&layout, 16, &text_system);
        layout.computeLayoutWithSize(root.node_id.?, 500, 500);

        // Render
        renderer.beginFrame();
        renderer.clear(0.314, 0.314, 0.314, 1.0); // rgb(0x505050)

        scene.clear();
        root.paint(&scene, &text_system, 0, 0, &layout, null, null);
        scene.finish();

        renderer.drawScene(&scene);

        // Draw text separately using D3D11TextRenderer
        // (scene MonochromeSprites need atlas integration with D3D11)
        drawTextForDiv(root, &layout, &text_renderer, &renderer, 0, 0);

        renderer.present(true);
    }
}

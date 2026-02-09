//! Hello World - Port of GPUI's hello_world.rs example

const std = @import("std");
const zapui = @import("zapui");

// Rendering
const D3D11Renderer = zapui.renderer.d3d11_renderer.D3D11Renderer;
const D3D11TextRenderer = zapui.renderer.d3d11_text.D3D11TextRenderer;
const D3D11SceneContext = zapui.renderer.d3d11_scene.D3D11SceneContext;
const GlyphCache = zapui.glyph_cache.GlyphCache;
const Scene = zapui.scene.Scene;

// Platform
const Win32 = zapui.platform.Win32Backend;

// Layout
const zaffy = zapui.zaffy;
const text_system = zapui.text_system;

// Div system (GPUI-compatible API)
const div_mod = zapui.elements.div;
const div = div_mod.div;
const px = div_mod.px;

// Colors (GPUI-compatible API)
const color = zapui.color;
const rgb = color.rgb;
const black = color.black;
const blue = color.blue;
const green = color.green;
const red = color.red;
const white = color.white;
const yellow = color.yellow;

// ============================================================================
// HelloWorld
// ============================================================================

const HelloWorld = struct {
    text: []const u8,

    fn render(self: *HelloWorld, label_buf: []u8) *div_mod.Div {
        const label = std.fmt.bufPrint(label_buf, "Hello, {s}!", .{self.text}) catch "Hello!";

        return div()
            .flex()
            .flex_col()
            .gap_3()
            .bg(rgb(0x505050))
            .size(px(500))
            .justify_center()
            .items_center()
            .shadow_lg()
            .border_1()
            .border_color(rgb(0x0000ff))
            .text_xl()
            .text_color(rgb(0xffffff))
            .child(div().child_text(label))
            .child(div().flex().gap_2()
                .child(div().size_8().bg(red()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(green()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(blue()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(yellow()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(black()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(white()).border_1().border_dashed().rounded_md().border_color(black())));
    }
};

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

    // Text system (for layout measurement)
    var ts = try text_system.TextSystem.init(allocator);
    defer ts.deinit();
    _ = try ts.loadFontMem(font_data);

    // Glyph cache (for text rasterization)
    var glyph_cache = try GlyphCache.init(allocator);
    defer glyph_cache.deinit();
    const font_id = try glyph_cache.loadFont(font_data);

    // Text renderer (for D3D11 rendering)
    var text_renderer = try D3D11TextRenderer.init(allocator, &renderer, &glyph_cache, font_id, 20);
    defer text_renderer.deinit();

    // Scene context (combines renderer + text renderer)
    var scene_ctx = D3D11SceneContext{
        .renderer = &renderer,
        .text_renderer = &text_renderer,
    };

    // Layout engine
    var layout = zaffy.Zaffy.init(allocator);
    defer layout.deinit();

    // Scene for quad batching
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // State
    var state = HelloWorld{ .text = "World" };

    while (!window.shouldClose()) {
        for (window.pollEvents()) |e| {
            switch (e) {
                .key => |k| if (k.key == .escape) return,
                .resize => |r| renderer.resize(r.width, r.height) catch {},
                else => {},
            }
        }

        // Build UI
        div_mod.reset();
        var label_buf: [256]u8 = undefined;
        const root = state.render(&label_buf);

        // Layout
        try root.buildWithTextSystem(&layout, 16, &ts);
        layout.computeLayoutWithSize(root.node_id.?, 500, 500);

        // Render
        renderer.beginFrame();
        const bg = rgb(0x505050).toRgba();
        renderer.clear(bg.r, bg.g, bg.b, bg.a);
        scene_ctx.renderDiv(root, &layout, &scene);
        renderer.present(true);
    }
}

//! Shadow - Port of GPUI's shadow.rs example

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
const relative = div_mod.relative;
const Div = div_mod.Div;

// Style types
const style = zapui.style;
const BoxShadow = style.BoxShadow;

// Colors (GPUI-compatible API)
const color = zapui.color;
const rgb = color.rgb;
const hsla = color.hsla;

// ============================================================================
// Shape builders (matches GPUI's impl Shadow)
// ============================================================================

fn base() *Div {
    return div()
        .size_16()
        .bg(rgb(0xffffff))
        .rounded_full()
        .border_1()
        .border_color(hsla(0.0, 0.0, 0.0, 0.1));
}

fn square() *Div {
    return div()
        .size_16()
        .bg(rgb(0xffffff))
        .border_1()
        .border_color(hsla(0.0, 0.0, 0.0, 0.1));
}

fn rounded_small() *Div {
    return div()
        .size_16()
        .bg(rgb(0xffffff))
        .rounded(px(4))
        .border_1()
        .border_color(hsla(0.0, 0.0, 0.0, 0.1));
}

fn rounded_medium() *Div {
    return div()
        .size_16()
        .bg(rgb(0xffffff))
        .rounded(px(8))
        .border_1()
        .border_color(hsla(0.0, 0.0, 0.0, 0.1));
}

fn rounded_large() *Div {
    return div()
        .size_16()
        .bg(rgb(0xffffff))
        .rounded(px(12))
        .border_1()
        .border_color(hsla(0.0, 0.0, 0.0, 0.1));
}

// ============================================================================
// Example cell (matches GPUI's example() function exactly)
// ============================================================================

fn example(label: []const u8, ex: *Div) *Div {
    return div()
        .flex()
        .flex_col()
        .justify_center()
        .items_center()
        .w(relative(1.0 / 6.0))
        .border_r_1()
        .border_color(hsla(0.0, 0.0, 0.0, 1.0))
        .child(
            div()
                .flex()
                .items_center()
                .justify_center()
                .flex_1()
                .py_12()
                .child(ex),
        )
        .child(
            div()
                .w_full()
                .border_t_1()
                .border_color(hsla(0.0, 0.0, 0.0, 1.0))
                .p_1()
                .flex()
                .items_center()
                .child(label),
        );
}

// ============================================================================
// Shadow
// ============================================================================

const Shadow = struct {
    fn render(self: *Shadow) *Div {
        _ = self;

        return div()
            .bg(rgb(0xffffff))
            .size_full()
            .text_xs()
            .text_color(rgb(0x000000))
            .child(div().flex().flex_col().w_full().children(&.{
                // Row 1: Different shapes
                div()
                    .border_b_1()
                    .border_color(hsla(0.0, 0.0, 0.0, 1.0))
                    .flex()
                    .flex_row()
                    .children(&.{
                        example("Square", square().shadow(BoxShadow{
                            .color = hsla(0.0, 0.5, 0.5, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Rounded 4", rounded_small().shadow(BoxShadow{
                            .color = hsla(0.0, 0.5, 0.5, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Rounded 8", rounded_medium().shadow(BoxShadow{
                            .color = hsla(0.0, 0.5, 0.5, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Rounded 16", rounded_large().shadow(BoxShadow{
                            .color = hsla(0.0, 0.5, 0.5, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Circle", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.5, 0.5, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                    }),
                // Row 2: Shadow presets
                div()
                    .border_b_1()
                    .border_color(hsla(0.0, 0.0, 0.0, 1.0))
                    .flex()
                    .w_full()
                    .children(&.{
                        example("None", base()),
                        example("2X Small", base().shadow_2xs()),
                        example("Extra Small", base().shadow_xs()),
                        example("Small", base().shadow_sm()),
                        example("Medium", base().shadow_md()),
                        example("Large", base().shadow_lg()),
                        example("Extra Large", base().shadow_xl()),
                        example("2X Large", base().shadow_2xl()),
                    }),
                // Row 3: Blur values
                div()
                    .border_b_1()
                    .border_color(hsla(0.0, 0.0, 0.0, 1.0))
                    .flex()
                    .children(&.{
                        example("Blur 0", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 0,
                            .spread_radius = 0,
                        })),
                        example("Blur 2", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 2,
                            .spread_radius = 0,
                        })),
                        example("Blur 4", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 4,
                            .spread_radius = 0,
                        })),
                        example("Blur 8", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Blur 16", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 16,
                            .spread_radius = 0,
                        })),
                    }),
                // Row 4: Spread values
                div()
                    .border_b_1()
                    .border_color(hsla(0.0, 0.0, 0.0, 1.0))
                    .flex()
                    .children(&.{
                        example("Spread 0", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 0,
                        })),
                        example("Spread 2", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 2,
                        })),
                        example("Spread 4", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 4,
                        })),
                        example("Spread 8", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 8,
                        })),
                        example("Spread 16", base().shadow(BoxShadow{
                            .color = hsla(0.0, 0.0, 0.0, 0.3),
                            .offset = .{ .x = 0, .y = 8 },
                            .blur_radius = 8,
                            .spread_radius = 16,
                        })),
                    }),
            }));
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
        .width = 1000,
        .height = 800,
        .title = "Shadow",
    });
    defer window.destroy();

    // Renderer
    var renderer = try D3D11Renderer.init(allocator, window.hwnd.?, 1000, 800);
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
    var text_renderer = try D3D11TextRenderer.init(allocator, &renderer, &glyph_cache, font_id, 12);
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
    var state = Shadow{};

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
        const root = state.render();

        // Layout
        try root.buildWithTextSystem(&layout, 12, &ts);
        layout.computeLayoutWithSize(root.node_id.?, 1000, 800);

        // Render
        renderer.beginFrame();
        const bg_color = rgb(0xffffff).toRgba();
        renderer.clear(bg_color.r, bg_color.g, bg_color.b, bg_color.a);
        scene_ctx.renderDiv(root, &layout, &scene);
        renderer.present(true);
    }
}

---
name: port-gpui
description: Port GPUI (Rust) examples to ZapUI (Zig) using Win32 + D3D11. Use when porting Zed's GPUI examples, creating visual comparisons between GPUI and ZapUI, or implementing D3D11 rendering that matches GPUI output.
---

# Port GPUI Example to ZapUI

## Workflow

### 1. Generate skeleton
```bash
make port-gpui EXAMPLE=<name>
```

This creates:
```
examples/gpui_ports/<name>/
├── <name>.zig                  # D3D11 skeleton to implement
├── <name>.rs                   # Original GPUI source
├── report.html                 # Comparison report
├── LiberationSans-Regular.ttf  # Embedded font
└── screenshots/                # For visual comparisons
```

### 2. Add build target to build.zig

Copy the hello_world pattern:
```zig
const <name>_mod = b.createModule(.{
    .root_source_file = b.path("examples/gpui_ports/<name>/<name>.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{
        .{ .name = "zapui", .module = zapui_mod },
        .{ .name = "freetype", .module = freetype_mod },
    },
});
// ... add exe setup
```

### 3. Implement render() using ZapUI's div system

ZapUI has a GPUI-compatible div element system. The API matches closely:

**GPUI → ZapUI mapping:**

| GPUI | ZapUI |
|------|-------|
| `div()` | `div()` |
| `.flex()` | `.flex()` |
| `.flex_col()` | `.flex_col()` |
| `.gap_3()` | `.gap_3()` |
| `.bg(rgb(0x505050))` | `.bg(rgb(0x505050))` |
| `.size(px(500.0))` | `.size(px(500))` |
| `.justify_center()` | `.justify_center()` |
| `.items_center()` | `.items_center()` |
| `.text_xl()` | `.text_xl()` |
| `.text_color(rgb(0xffffff))` | `.text_color(rgb(0xffffff))` |
| `.child("text")` | `.child(div().child_text("text"))` |
| `.child(div()...)` | `.child(div()...)` |
| `.size_8()` | `.size_8()` |
| `.border_1()` | `.border_1()` |
| `.border_dashed()` | `.border_dashed()` |
| `.rounded_md()` | `.rounded_md()` |
| `.border_color(white())` | `.border_color(white())` |
| `gpui::red()` | `red()` (from `zapui.color`) |
| `format!("...", val)` | `std.fmt.bufPrint(&buf, "...", .{val})` |

**Key difference:** In GPUI, `.child("text")` accepts a string directly. In ZapUI, wrap text in a div: `.child(div().child_text("text"))`.

### 4. Build
```bash
make windows
```

### 5. Capture screenshots
```bash
make capture-both EXAMPLE=<name>
```

### 6. Generate comparison
```bash
make compare EXAMPLE=<name>
```

Creates diff.png, toggle.gif, and updates report.html.

## Example: hello_world

**Rust (GPUI):**
```rust
impl Render for HelloWorld {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .flex_col()
            .gap_3()
            .bg(rgb(0x505050))
            .size(px(500.0))
            .justify_center()
            .items_center()
            .text_xl()
            .text_color(rgb(0xffffff))
            .child(format!("Hello, {}!", &self.text))
            .child(
                div()
                    .flex()
                    .gap_2()
                    .child(div().size_8().bg(gpui::red()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
                    .child(div().size_8().bg(gpui::green()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
                    // ...
            )
    }
}
```

**Zig (ZapUI):**
```zig
const div_mod = zapui.elements.div;
const div = div_mod.div;
const px = div_mod.px;
const color = zapui.color;
const rgb = color.rgb;
const red = color.red;
const white = color.white;
// ...

fn render(self: *HelloWorld, allocator: std.mem.Allocator, label_buf: []u8) !*div_mod.Div {
    const label = std.fmt.bufPrint(label_buf, "Hello, {s}!", .{self.text}) catch "Hello!";

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
        .child(div().child_text(label))  // text wrapped in div
        .child(
            div()
                .flex()
                .gap_2()
                .child(div().size_8().bg(red()).border_1().border_dashed().rounded_md().border_color(white()))
                .child(div().size_8().bg(green()).border_1().border_dashed().rounded_md().border_color(white()))
                // ...
        );
}
```

## Main loop structure

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Platform & window
    var platform = try Win32.init();
    defer platform.deinit();
    const window = try Win32.createWindow(&platform, .{ .width = 500, .height = 500, .title = "..." });
    defer window.destroy();

    // Renderer
    var renderer = try D3D11Renderer.init(allocator, window.hwnd.?, 500, 500);
    defer renderer.deinit();

    // Text systems
    var text_system = try zapui.text_system.TextSystem.init(allocator);
    defer text_system.deinit();
    _ = try text_system.loadFontMem(font_data);

    var text_renderer = try D3D11TextRenderer.init(allocator, &renderer, font_data, 20);
    defer text_renderer.deinit();

    // Layout & scene
    var layout = zaffy.Zaffy.init(allocator);
    defer layout.deinit();
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // State
    var state = MyState{ ... };

    while (!window.shouldClose()) {
        for (window.pollEvents()) |e| { ... }

        // Build UI
        div_mod.reset();
        var label_buf: [64]u8 = undefined;
        const root = try state.render(allocator, &label_buf);

        // Layout
        try root.buildWithTextSystem(&layout, 16, &text_system);
        layout.computeLayoutWithSize(root.node_id.?, 500, 500);

        // Render
        renderer.beginFrame();
        renderer.clear(...);

        scene.clear();
        root.paint(&scene, &text_system, 0, 0, &layout, null, null);
        scene.finish();
        renderer.drawScene(&scene);

        // Text (drawn separately for now)
        drawTextForDiv(root, &layout, &text_renderer, &renderer, 0, 0);

        renderer.present(true);
    }
}
```

## Notes

- ZapUI's div API matches GPUI's fluent builder pattern
- Text rendering uses D3D11TextRenderer separately (scene sprites need atlas integration)
- Use `div_mod.reset()` at the start of each frame
- Pass a buffer for formatted strings (Zig doesn't have automatic string allocation like Rust)
- Colors use `zapui.color` functions: `rgb()`, `red()`, `green()`, `blue()`, `yellow()`, `black()`, `white()`

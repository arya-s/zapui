---
name: port-gpui
description: Port GPUI (Rust) examples to ZapUI (Zig) using Win32 + D3D11. Use when porting Zed's GPUI examples, creating visual comparisons between GPUI and ZapUI, or implementing D3D11 rendering that matches GPUI output.
---

# Port GPUI Example to ZapUI

**IMPORTANT:** Always run through ALL steps automatically. Do not stop and list "next steps" for the user. Complete the entire workflow including screenshot capture and comparison.

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

**Note:** Don't include GPUI Rust code as comments in the Zig file. The original Rust source is kept in `<name>.rs` and the report shows side-by-side comparison.

### 4. Build
```bash
make windows
```

### 5. Build GPUI example (if needed)

The GPUI Rust example must be built via PowerShell (not WSL) since it targets Windows:

```bash
powershell.exe -Command "cd C:\src\zed; cargo build -p gpui --example <name>"
```

### 6. Capture screenshots
```bash
make capture-both EXAMPLE=<name>
```

Uses ShareX CLI to automatically capture the active window. Requires ShareX installed at `C:\Program Files\ShareX\`.

**How the capture works:**
1. Launch the executable via PowerShell
2. Wait 1 second for the window to render
3. Activate the window using `SetForegroundWindow` (ensures correct window is captured)
4. Wait 1 second
5. Run ShareX with `-ActiveWindow -silent` to capture
6. ShareX saves to its default `Documents\ShareX\Screenshots` folder (ignores `-ImagePath` for WSL paths)
7. Script finds the most recent screenshot and copies it to the example's `screenshots/` folder

### 7. Generate comparison with code analysis
```bash
make compare EXAMPLE=<name>
```

This creates:
- `diff.png` - Pixel difference visualization
- `toggle.gif` - Animated comparison
- `report.html` - Full report with **UI code overlap analysis**

### 8. View results

Open the HTML report in a browser:
```
examples/gpui_ports/<name>/report.html
```

Or on Windows:
```bash
explorer.exe "$(wslpath -w examples/gpui_ports/<name>/report.html)"
```

## Report Features

The generated report includes:

### Screenshots
- GPUI screenshot
- ZapUI screenshot  
- Pixel difference image
- Animated toggle GIF

### UI Code Overlap Analysis
- **API Similarity Score** - Percentage of shared UI methods
- **Method Comparison**:
  - ✓ Methods used by both (e.g., `.flex()`, `.bg()`, `.child()`)
  - Rust-only methods (features not yet ported)
  - Zig-only methods (Zig-specific additions)
- **Color Comparison** - Shared colors with visual swatches
- **Render Function Extraction** - Side-by-side comparison of just the render() code

### Source Code
- Full Rust source
- Full Zig source
- Links to original GPUI repo

## Example: hello_world

**Rust (GPUI):**
```rust
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
                // ...
        )
}
```

**Zig (ZapUI):**
```zig
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
        .text_xl()
        .text_color(rgb(0xffffff))
        .child(div().child_text(label))
        .child(div().flex().gap_2()
            .child(div().size_8().bg(red()).border_1().border_dashed().rounded_md().border_color(white()))
            // ...
        );
}
```

**Analysis output:**
```
API Similarity: 89%
Methods: 16 shared, 1 Rust-only, 1 Zig-only
Colors: 8 shared
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

    // Shared glyph cache (FreeType rasterization)
    var glyph_cache = try zapui.glyph_cache.GlyphCache.init(allocator);
    defer glyph_cache.deinit();
    const font_id = try glyph_cache.loadFont(font_data);

    // Text system (for layout measurement)
    var text_system = try zapui.text_system.TextSystem.init(allocator);
    defer text_system.deinit();
    _ = try text_system.loadFontMem(font_data);

    // Text renderer (uses shared glyph cache)
    var text_renderer = try D3D11TextRenderer.init(allocator, &renderer, &glyph_cache, font_id, 20);
    defer text_renderer.deinit();

    // Scene context (combines renderer + text renderer)
    var scene_ctx = D3D11SceneContext{
        .renderer = &renderer,
        .text_renderer = &text_renderer,
    };

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
        const root = state.render(&label_buf);

        // Layout
        try root.buildWithTextSystem(&layout, 16, &text_system);
        layout.computeLayoutWithSize(root.node_id.?, 500, 500);

        // Render (single call for quads + text)
        renderer.beginFrame();
        renderer.clear(...);
        scene_ctx.renderDiv(root, &layout, &scene);
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

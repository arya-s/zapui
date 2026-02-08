# Port GPUI Example to ZapUI

Use this skill when porting a GPUI (Rust) example to ZapUI (Zig).

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

### 3. Implement render() in <name>.zig

The skeleton has a struct with a `render()` method. Port the GPUI code:

**GPUI → ZapUI mapping:**
| GPUI | ZapUI |
|------|-------|
| `div().bg(rgb(0xNNNNNN))` | `renderer.clear(rgb(0xNNNNNN))` |
| `div().size_8().bg(color).border_1().border_dashed().rounded_md().border_color(border)` | `quad(x, y, 32, color, border)` |
| `.child("text")` | `text_renderer.draw(renderer, "text", x, y, color)` |
| `format!("...", val)` | `std.fmt.bufPrint(&buf, "...", .{val})` |
| `gpui::red()` | `const red = [4]f32{ 1, 0, 0, 1 };` |
| `gpui::green()` | `const green = [4]f32{ 0, 0.5, 0, 1 };` |
| `rgb(0xNNNNNN)` | `fn rgb(hex: u24) [4]f32 { ... }` |

**Layout constants:**
- `size_8` = 32px
- `gap_2` = 8px
- `gap_3` = 12px
- `text_xl` = 20px
- `rounded_md` = 6px corner radius

### 4. Build
```bash
make windows
```

### 5. Capture screenshots
```bash
make capture-both EXAMPLE=<name>
```

This captures both ZapUI and GPUI windows.

### 6. Generate comparison
```bash
make compare EXAMPLE=<name>
```

Creates diff.png, toggle.gif, and updates report.html.

### 7. View results

Open `examples/gpui_ports/<name>/report.html` in a browser to see:
- Side-by-side screenshots
- Animated toggle comparison
- Source code comparison (Rust vs Zig)

## Example: hello_world

**Rust (GPUI):**
```rust
struct HelloWorld { text: SharedString }

impl Render for HelloWorld {
    fn render(&mut self, ...) -> impl IntoElement {
        div()
            .flex().flex_col().gap_3()
            .bg(rgb(0x505050))
            .child(format!("Hello, {}!", &self.text))
            .child(div().flex().gap_2()
                .child(div().size_8().bg(gpui::red())...)
            )
    }
}
```

**Zig (ZapUI):**
```zig
const HelloWorld = struct {
    text: []const u8,

    fn render(self: *HelloWorld, renderer: *D3D11Renderer, text_renderer: anytype) void {
        const bg = rgb(0x505050);
        renderer.clear(bg[0], bg[1], bg[2], bg[3]);

        // Layout calculations for centering
        const y = (500 - content_h) / 2;
        const x = (500 - row_w) / 2;

        // Text
        var buf: [64]u8 = undefined;
        const label = std.fmt.bufPrint(&buf, "Hello, {s}!", .{self.text}) catch "Hello!";
        text_renderer.draw(renderer, label, 250, y + 16, white);

        // Colored boxes
        const quads = [_]QuadInstance{
            quad(x + 0 * 40, row_y, 32, red, white),
            // ...
        };
        renderer.drawQuads(&quads);
    }
};
```

## Notes

- The skeleton includes TextRenderer boilerplate (GPUI handles text internally)
- Include GPUI code as comments in the Zig to show the mapping
- The `quad()` helper matches `div().size_8().bg().border_1().border_dashed().rounded_md().border_color()`
- Colors are `[4]f32{ r, g, b, a }` with values 0-1

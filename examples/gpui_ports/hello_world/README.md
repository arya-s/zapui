# Hello World

Port of GPUI's `hello_world.rs` example to ZapUI.

## Files

- `../../playground/hello_world.zig` - ZapUI port (in playground for now)
- `hello_world.rs` - Original GPUI source (Rust)
- `screenshots/` - Visual comparison

## Status

✅ **Complete** - This example is fully ported and matches GPUI's output.

## Features Demonstrated

- Flexbox layout (column, centered)
- Text rendering
- Background colors
- Borders (solid and dashed)
- Rounded corners
- Box shadows
- Color boxes with different styles

## Build & Run

```bash
# ZapUI (Zig)
make hello-world
# or
zig build hello-world
./zig-out/bin/hello_world

# GPUI (Rust) - requires Zed repo
cd /path/to/zed
cargo run --example hello_world -p gpui
```

## API Comparison

### Rust (GPUI)
```rust
div()
    .flex()
    .flex_col()
    .gap_3()
    .bg(rgb(0x505050))
    .size(px(500.0))
    .justify_center()
    .items_center()
    .shadow_lg()
    .border_1()
    .border_color(rgb(0x0000ff))
    .text_xl()
    .text_color(rgb(0xffffff))
    .child(format!("Hello, {}!", &self.text))
    .child(div().flex().gap_2()
        .child(div().size_8().bg(gpui::red()).border_1().border_dashed()...))
```

### Zig (ZapUI)
```zig
div()
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
    .child(h_flex().gap_2()
        .child(div().size_8().bg(red).border_1().border_dashed()...))
```

## Differences

| Aspect | GPUI (Rust) | ZapUI (Zig) |
|--------|-------------|-------------|
| Text children | `.child("text")` | `.child(div().child_text("text"))` |
| Format strings | `format!("...", x)` | `std.fmt.bufPrint(...)` |
| Colors | `gpui::red()` | `red` (const) |
| Flex helper | `div().flex()` | `h_flex()` / `v_flex()` |

## Original

- [View on GitHub](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/hello_world.rs)

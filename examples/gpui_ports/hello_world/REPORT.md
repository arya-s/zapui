# Hello World - Comparison Report

## Overview

| Metric | Value |
|--------|-------|
| Example | `hello_world` |
| Rust LOC | 106 |
| Div chains found | 2 |
| Colors used | 9 |
| Warnings | 3 |

## Translation Warnings

- Format strings: use std.fmt.bufPrint
- Context/state: needs manual conversion
- Render trait: convert to render function

## Side-by-Side API Comparison

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
            .child(
                div()
                    .flex()
                    .gap_2()
                    .child(
                        div()
                            .size_8()
                            .bg(gpui::red())
                            .border_1()
                            .border_dashed()
                            .rounded_md()
                            .border_color(gpui::white()),
                    )
                    .child(
                        div()
                            .size_8()
                            .bg(gpui::green())
                            .border_1()
                            .border_dashed()
                            .rounded_md()
                            .border_color(gpui::white()),
                    )
                    .child(
                        div()
                            .size_8()
                            .bg(gpui::blue())
                            .border_1()
                            .border_dashed()
                            .rounded_md()
                            .border_col
```

### Zig (ZapUI)

```zig
// See hello_world.zig for full implementation
// Key differences:
// - Text children: .child("text") → .child(div().child_text("text"))
// - Format strings: format!() → std.fmt.bufPrint()
// - Colors: gpui::red() → red (const)
// - Method chains are nearly identical
```

## API Mapping

| GPUI (Rust) | ZapUI (Zig) | Status |
|-------------|-------------|--------|
| `div()` | `div()` | ✅ |
| `.flex()` | `.flex()` | ✅ |
| `.flex_col()` | `.flex_col()` | ✅ |
| `.flex_row()` | `.flex_row()` | ✅ |
| `.gap_N()` | `.gap_N()` | ✅ |
| `.bg(rgb(0x...))` | `.bg(zapui.rgb(0x...))` | ✅ |
| `.bg(gpui::red())` | `.bg(red)` | ✅ |
| `.size(px(N))` | `.size(px(N))` | ✅ |
| `.size_N()` | `.size_N()` | ✅ |
| `.w(px(N))` | `.w(px(N))` | ✅ |
| `.h(px(N))` | `.h(px(N))` | ✅ |
| `.justify_center()` | `.justify_center()` | ✅ |
| `.items_center()` | `.items_center()` | ✅ |
| `.border_N()` | `.border_N()` | ✅ |
| `.border_color(...)` | `.border_color(...)` | ✅ |
| `.border_dashed()` | `.border_dashed()` | ✅ |
| `.rounded_md()` | `.rounded_md()` | ✅ |
| `.shadow_lg()` | `.shadow_lg()` | ✅ |
| `.text_xl()` | `.text_xl()` | ✅ |
| `.text_color(...)` | `.text_color(...)` | ✅ |
| `.child("text")` | `.child(div().child_text("text"))` | ⚠️ Wrapper needed |
| `.child(element)` | `.child(element)` | ✅ |
| `.on_click(...)` | *not yet* | ❌ |
| `.opacity(N)` | *not yet* | ❌ |
| `canvas(...)` | *not yet* | ❌ |
| `img(...)` | *not yet* | ❌ |
| `svg(...)` | *not yet* | ❌ |

## Screenshots

*Run `make capture-both EXAMPLE=hello_world` then `make compare EXAMPLE=hello_world` to generate screenshots.*

### GPUI (Rust)

![GPUI](screenshots/gpui.png)

### ZapUI (Zig)

![ZapUI](screenshots/zapui.png)

### Animated Toggle

![Toggle](screenshots/toggle.gif)

### Pixel Diff

![Diff](screenshots/diff.png)

## Build Instructions

### ZapUI (Zig)

```bash
# From zapui root directory
zig build hello_world
./zig-out/bin/hello_world
```

### GPUI (Rust)

```bash
# From zed repository
cargo run --example hello_world -p gpui
```

## Links

- [Original GPUI source](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/hello_world.rs)
- [ZapUI Documentation](../../README.md)

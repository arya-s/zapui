# Hello World - Comparison Report

## Overview

| Metric | Value |
|--------|-------|
| Example | `hello_world` |
| Status | ✅ **Complete** |
| Rust LOC | ~90 |
| Zig LOC | ~100 |
| Visual Match | ✅ Yes |

## Translation Warnings

None - this example is fully ported and working!

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
            .child(div().size_8().bg(gpui::red()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
            .child(div().size_8().bg(gpui::green()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
            .child(div().size_8().bg(gpui::blue()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
            .child(div().size_8().bg(gpui::yellow()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
            .child(div().size_8().bg(gpui::black()).border_1().border_dashed().rounded_md().border_color(gpui::white()))
            .child(div().size_8().bg(gpui::white()).border_1().border_dashed().rounded_md().border_color(gpui::black()))
    )
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
    .child(h_flex()
        .gap_2()
        .child(div().size_8().bg(red).border_1().border_dashed().rounded_md().border_color(white))
        .child(div().size_8().bg(green).border_1().border_dashed().rounded_md().border_color(white))
        .child(div().size_8().bg(blue).border_1().border_dashed().rounded_md().border_color(white))
        .child(div().size_8().bg(yellow).border_1().border_dashed().rounded_md().border_color(white))
        .child(div().size_8().bg(black).border_1().border_dashed().rounded_md().border_color(white))
        .child(div().size_8().bg(white).border_1().border_dashed().rounded_md().border_color(black)))
```

## Key Differences

| Aspect | GPUI (Rust) | ZapUI (Zig) | Notes |
|--------|-------------|-------------|-------|
| Text children | `.child("text")` | `.child(div().child_text("text"))` | Zig needs wrapper |
| Format strings | `format!("...", x)` | `std.fmt.bufPrint(...)` | Zig syntax |
| Colors | `gpui::red()` | `red` (const) | Pre-defined |
| Green color | `gpui::green()` | `hsla(0.333, 1.0, 0.25, 1.0)` | GPUI uses darker green |
| Flex row | `div().flex()` | `h_flex()` | Convenience helper |
| Inline nesting | Natural | Works with proper formatting | Same capability |

## API Mapping

| GPUI (Rust) | ZapUI (Zig) | Status |
|-------------|-------------|--------|
| `div()` | `div()` | ✅ Identical |
| `.flex()` | `.flex()` | ✅ Identical |
| `.flex_col()` | `.flex_col()` | ✅ Identical |
| `.gap_3()` | `.gap_3()` | ✅ Identical |
| `.bg(rgb(0x...))` | `.bg(zapui.rgb(0x...))` | ✅ Same pattern |
| `.size(px(500.0))` | `.size(px(500))` | ✅ Same pattern |
| `.justify_center()` | `.justify_center()` | ✅ Identical |
| `.items_center()` | `.items_center()` | ✅ Identical |
| `.shadow_lg()` | `.shadow_lg()` | ✅ Identical |
| `.border_1()` | `.border_1()` | ✅ Identical |
| `.border_color(...)` | `.border_color(...)` | ✅ Identical |
| `.border_dashed()` | `.border_dashed()` | ✅ Identical |
| `.rounded_md()` | `.rounded_md()` | ✅ Identical |
| `.text_xl()` | `.text_xl()` | ✅ Identical |
| `.text_color(...)` | `.text_color(...)` | ✅ Identical |
| `.size_8()` | `.size_8()` | ✅ Identical |
| `.child(element)` | `.child(element)` | ✅ Identical |

## Screenshots

| Version | Screenshot |
|---------|------------|
| GPUI (Rust) | `screenshots/gpui.png` |
| ZapUI (Zig) | `screenshots/zapui.png` |
| Comparison | `screenshots/comparison.png` |

## Build Instructions

### ZapUI (Zig)

```bash
cd zapui
make hello-world
# or
zig build hello-world
./zig-out/bin/hello_world
```

### GPUI (Rust)

```bash
cd zed
cargo run --example hello_world -p gpui
```

## Links

- [Original GPUI source](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/hello_world.rs)
- [ZapUI port](../../playground/hello_world.zig)

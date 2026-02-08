# Hello World - Comparison Report

## Overview

| Metric | Value |
|--------|-------|
| Example | `hello_world` |
| Rust LOC | 106 |
| Colors used | 9 |
| Warnings | 3 |

## Translation Warnings

- Format strings: use std.fmt.bufPrint
- Render trait: convert to render function
- Context/state: needs manual conversion

## Rust (GPUI) Source

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

## Screenshots

### GPUI (Rust)

![GPUI](screenshots/gpui.png)

### ZapUI (Zig)

![ZapUI](screenshots/zapui.png)

### Animated Toggle

![Toggle](screenshots/toggle.gif)

### Pixel Diff

![Diff](screenshots/diff.png)

## Build & Capture

```bash
# Build
make windows

# Capture both screenshots
make capture-both EXAMPLE=hello_world

# Generate comparison
make compare EXAMPLE=hello_world
```

## Links

- [Original GPUI source](https://github.com/zed-industries/zed/blob/main/crates/gpui/examples/hello_world.rs)

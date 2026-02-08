# ZapUI vs GPUI - Side by Side Comparison

## Button Component

<table>
<tr><th>ZapUI (Zig)</th><th>GPUI (Rust)</th></tr>
<tr><td>

```zig
fn button(label: []const u8, color: Hsla, id: usize) *Div {
    const hovered = isHovered(id);
    const bg_color = if (hovered) color.lighten(0.1) else color;
    return div()
        .w(px(100)).h(px(40))
        .bg(bg_color)
        .rounded(px(8))
        .id(id)
        .justify_center().items_center()
        .child_text(label)
        .text_color(C.white);
}
```
</td><td>

```rust
fn button(label: &str, color: Hsla) -> impl IntoElement {
    div()
        .w(px(100.)).h(px(40.))
        .bg(color)
        .rounded(px(8.))
        .justify_center().items_center()
        .hover(|s| s.bg(color.lighten(0.1)))
        .child(label)
        .text_color(white())
}
```
</td></tr>
</table>

## Toggle Component

<table>
<tr><th>ZapUI (Zig)</th><th>GPUI (Rust)</th></tr>
<tr><td>

```zig
fn toggle(enabled: bool, id: usize) *Div {
    const hovered = isHovered(id);
    const track_color = if (enabled) C.primary
        else if (hovered) C.bg_hover
        else C.bg_elevated;
    const knob_x: Pixels = if (enabled) 26 else 4;
    
    const track = div()
        .w(px(48)).h(px(26))
        .bg(track_color)
        .rounded_full()
        .id(id);
    const knob = div()
        .w(px(18)).h(px(18))
        .bg(C.white)
        .rounded_full()
        .absolute()
        .left(px(knob_x)).top(px(4));
    
    return track.child(knob);
}
```
</td><td>

```rust
fn toggle(enabled: bool) -> impl IntoElement {
    let track_color = if enabled { primary() }
        else { bg_elevated() };
    let knob_x = if enabled { 26. } else { 4. };
    
    div()
        .w(px(48.)).h(px(26.))
        .bg(track_color)
        .rounded_full()
        .hover(|s| s.bg(bg_hover()))
        .child(
            div()
                .w(px(18.)).h(px(18.))
                .bg(white())
                .rounded_full()
                .absolute()
                .left(px(knob_x)).top(px(4.))
        )
}
```
</td></tr>
</table>

## Slider Component

<table>
<tr><th>ZapUI (Zig)</th><th>GPUI (Rust)</th></tr>
<tr><td>

```zig
fn slider(value: f32, id: usize) *Div {
    const track_w: Pixels = 200;
    const knob_size: Pixels = 20;
    const filled_w = track_w * value;
    const knob_x = @max(0, track_w * value - knob_size / 2);
    
    const track_bg = div()
        .w(px(track_w)).h(px(8))
        .bg(C.bg_elevated).rounded(px(4))
        .absolute().top(px(8));
    const filled = div()
        .w(px(filled_w)).h(px(8))
        .bg(C.primary).rounded(px(4))
        .absolute().top(px(8));
    const knob = div()
        .w(px(knob_size)).h(px(knob_size))
        .bg(C.primary).rounded_full()
        .border_3().border_color(C.white)
        .absolute().left(px(knob_x)).top(px(2));
    
    return div().w(px(track_w)).h(px(24)).id(id)
        .child(track_bg).child(filled).child(knob);
}
```
</td><td>

```rust
fn slider(value: f32) -> impl IntoElement {
    let track_w = 200.;
    let knob_size = 20.;
    let filled_w = track_w * value;
    let knob_x = (track_w * value - knob_size / 2.).max(0.);
    
    div()
        .w(px(track_w)).h(px(24.))
        .child(div().w(px(track_w)).h(px(8.))
            .bg(bg_elevated()).rounded(px(4.))
            .absolute().top(px(8.)))
        .child(div().w(px(filled_w)).h(px(8.))
            .bg(primary()).rounded(px(4.))
            .absolute().top(px(8.)))
        .child(div().w(px(knob_size)).h(px(knob_size))
            .bg(primary()).rounded_full()
            .border_3().border_color(white())
            .absolute().left(px(knob_x)).top(px(2.)))
}
```
</td></tr>
</table>

## Main Layout

<table>
<tr><th>ZapUI (Zig)</th><th>GPUI (Rust)</th></tr>
<tr><td>

```zig
const header = div()
    .h(px(70))
    .bg(C.bg_card)
    .justify_center()
    .px(px(24))
    .child(div()
        .child_text("Demo")
        .text_2xl()
        .text_color(C.primary));

const content = v_flex()
    .gap(px(24)).p(px(24)).flex_1()
    .child(btn_section);

const root = v_flex()
    .w(px(width)).h(px(height))
    .bg(C.bg_dark)
    .child(header)
    .child(content);
```
</td><td>

```rust
let header = div()
    .h(px(70.))
    .bg(bg_card())
    .justify_center()
    .px(px(24.))
    .child("Demo".text_2xl().text_color(primary()));

let content = v_flex()
    .gap(px(24.)).p(px(24.)).flex_1()
    .child(btn_section);

v_flex()
    .size_full()
    .bg(bg_dark())
    .child(header)
    .child(content)
```
</td></tr>
</table>

---

## Key Differences

| Aspect | ZapUI (Zig) | GPUI (Rust) |
|--------|-------------|-------------|
| Float literals | `px(100)` | `px(100.)` |
| Text child | `.child_text("hi")` | `.child("hi")` |
| Hover styling | `.hover_bg(color)`, `.hover_border_color(c)`, `.hover_text_color(c)` | `.hover(\|s\| s.bg(color))` |
| Click handling | `.id(id)` + manual hitbox | `.on_click(\|_, cx\| ...)` |
| Conditionals | `.when(cond, fn)` | `.when(cond, \|this\| ...)` |
| Color access | `C.primary` | `primary()` |
| Return type | `*Div` | `impl IntoElement` |

## Identical API Methods

| Category | Methods |
|----------|---------|
| Containers | `div()`, `v_flex()`, `h_flex()` |
| Size | `.w(px(...))`, `.h(px(...))`, `.size_full()`, `.w_full()`, `.h_full()` |
| Padding | `.p(...)`, `.px(...)`, `.py(...)`, `.pt(...)`, `.pr(...)`, `.pb(...)`, `.pl(...)` |
| Margin | `.m(...)`, `.mx(...)`, `.my(...)`, `.mt(...)`, `.mr(...)`, `.mb(...)`, `.ml(...)` |
| Gap | `.gap(...)`, `.gap_x(...)`, `.gap_y(...)` |
| Flex | `.flex_1()`, `.flex_grow()`, `.flex_shrink()`, `.flex_col()`, `.flex_row()` |
| Alignment | `.justify_center()`, `.justify_between()`, `.items_center()`, `.items_start()` |
| Background | `.bg(...)` |
| Border | `.border_1()`, `.border_2()`, `.border_3()`, `.border_color(...)` |
| Corners | `.rounded(...)`, `.rounded_sm()`, `.rounded_md()`, `.rounded_lg()`, `.rounded_full()` |
| Text | `.text_color(...)`, `.text_sm()`, `.text_lg()`, `.text_xl()`, `.text_2xl()` |
| Position | `.absolute()`, `.relative()`, `.top(...)`, `.left(...)`, `.right(...)`, `.bottom(...)` |
| Children | `.child(...)` |

# ZapUI TODO

## Current State

The GPUI-compatible Div API is working with:
- Fluent builder: `div().w(px(100)).h(px(40)).bg(color).rounded(px(8))`
- Layout: Taffy flexbox engine ported to Zig
- Hover: `hover_bg()`, `hover_border_color()`, `hover_text_color()`
- Conditionals: `when(condition, fn)`
- Helpers: `v_flex()`, `h_flex()`, `px()`

## TODO

### High Priority

1. **Move Div from playground to library properly**
   - Currently `src/elements/div.zig` has the new API but uses global storage
   - Need to integrate with the existing element/entity system
   - Consider arena allocator instead of global array

2. **Click handling**
   - Currently: `.id(id)` + manual hitbox checking in playground
   - Goal: `.on_click(fn)` or similar declarative API
   - Challenge: Zig doesn't have closures, need workaround

3. **Text measurement**
   - Currently text width is approximated as `len * size * 0.55`
   - Need proper glyph measurement from TextSystem
   - Required for intrinsic sizing and text wrapping

4. **Only rebuild layout on changes**
   - Currently rebuilds entire Taffy tree every frame
   - Should diff and only update changed nodes
   - Track dirty state per element

### Medium Priority

5. **Scrolling/overflow**
   - `overflow_hidden()` exists but doesn't clip
   - Need scissor rect support in renderer
   - Scroll containers with `overflow_scroll()`

6. **Focus handling**
   - Tab navigation between interactive elements
   - Focus ring styling
   - Keyboard event routing

7. **Animation support**
   - Interpolate style values over time
   - Easing functions
   - Transition API: `.transition_bg(duration)`

8. **More hover properties**
   - `hover_rounded()`, `hover_border_width()`, etc.
   - Or implement the comptime function approach

### Low Priority

9. **Grid layout**
   - Taffy supports CSS Grid, we only exposed flexbox
   - Add grid methods to Div API

10. **Shadow/effects**
    - Box shadows (partially implemented in scene)
    - Blur effects

11. **Images**
    - Load and render images
    - Image element with sizing modes

12. **Text features**
    - Multi-line text with wrapping
    - Text selection
    - Rich text (multiple styles)

## API Differences from GPUI

| Feature | GPUI | ZapUI | Notes |
|---------|------|-------|-------|
| Hover | `.hover(\|s\| s.bg(c))` | `.hover_bg(c)` | No closures in Zig |
| Click | `.on_click(\|_, cx\| ...)` | `.id(id)` + manual | Need workaround |
| Text child | `.child("text")` | `.child_text("text")` | Can't overload |
| Conditionals | `.when(cond, \|this\| ...)` | `.when(cond, fn)` | Works with struct fn |

## Files Overview

```
src/
  elements/
    div.zig        # Main Div API (GPUI-compatible)
    text.zig       # Text element (old API)
    button.zig     # Button element (old API)
    ...            # Other elements (old API)
  taffy/
    taffy.zig      # Taffy layout engine
    flexbox.zig    # Flexbox algorithm
    tree.zig       # Layout tree
    style.zig      # Taffy styles
    geometry.zig   # Taffy geometry types
  style.zig        # Unified Style struct with toTaffy()
  scene.zig        # Render primitives
  renderer/        # OpenGL rendering
  text_system.zig  # Font loading and glyph rendering

playground/
  main.zig         # Demo app using Div API

docs/
  zapui-vs-gpui.md # API comparison
```

## Next Session

Start with:
1. Run `zig build run` to see current state
2. Pick a TODO item
3. Check `docs/zapui-vs-gpui.md` for API reference

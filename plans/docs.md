# zapui Documentation

zapui is a GPU-accelerated UI framework for Zig. It's embeddable — you provide an OpenGL 3.3 context and forward input events, zapui handles layout, styling, and rendering.

---

## Quick Start

```zig
const std = @import("std");
const zapui = @import("zapui");

// You provide your own windowing (GLFW, SDL, etc.)
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));

pub fn main() !void {
    // 1. Create your GL context however you like
    _ = glfw.glfwInit();
    defer glfw.glfwTerminate();
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    const window = glfw.glfwCreateWindow(800, 600, "My App", null, null);
    glfw.glfwMakeContextCurrent(window);

    // 2. Initialize zapui
    var ui = zapui.Ui.init(.{
        .viewport_width = 800,
        .viewport_height = 600,
        .scale_factor = 1.0,
    });
    defer ui.deinit();

    // 3. Load a font
    const font = try ui.loadFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
    _ = font;

    // 4. Main loop
    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        // Forward input events to zapui (see Input section)
        // ...

        if (ui.needsRedraw()) {
            ui.beginFrame();

            // Build and render your UI
            ui.render(
                ui.div()
                    .flexCol().itemsCenter().justifyCenter()
                    .bg(zapui.rgb(0x1e1e2e))
                    .sizeFull()
                    .child(ui.text("Hello, zapui!"))
                    .build(),
            );

            ui.endFrame();
            glfw.glfwSwapBuffers(window);
        }
    }
}
```

---

## Core Concepts

### The Frame Loop

zapui uses a **retained-mode API with per-frame rebuilds**. Every frame, you build an element tree from scratch. zapui then lays it out, resolves styles, and renders it via OpenGL.

```
beginFrame()  →  build element tree  →  render()  →  endFrame()
     ↑                                                    ↓
  reset arena                                     GL draw calls
```

- `beginFrame()` — Resets the per-frame arena allocator and clears the scene.
- `render(root_element)` — Takes a root `AnyElement`, runs layout, prepaint, and paint.
- `endFrame()` — Sorts primitives by draw order and issues OpenGL draw calls.

All element allocations use a frame arena that resets each frame, so there's no per-element cleanup needed.

### Redraw Model

zapui only renders when something changes. Two things trigger a redraw:

1. **Input events** — calling `processEvent()` automatically sets the redraw flag.
2. **Explicit request** — calling `requestRedraw()` from any thread.

```zig
// In your main loop:
if (ui.needsRedraw()) {
    ui.beginFrame();
    // ... build UI ...
    ui.endFrame();
}
```

`needsRedraw()` atomically checks and clears the flag, so it's safe to call from the main thread while background threads call `requestRedraw()`.

---

## Elements

Elements are the building blocks of zapui's UI. Every visible thing on screen is an element.

### div

The primary container element. Analogous to an HTML `<div>` — it's a box that can contain children, has a background, border, shadow, and participates in flexbox layout.

```zig
ui.div()
    .bg(zapui.rgb(0x313244))
    .child(ui.text("inside a box"))
    .build()
```

### text

Renders a string of text. Shaped with Harfbuzz, rasterized with Freetype, cached in a texture atlas.

```zig
ui.text("Hello, World!")
```

Text inherits `text_color` and `font_size` from its parent div's style.

### img

Renders an image from pixel data.

```zig
ui.img(image_data, width, height)
```

### canvas

A custom-draw element. You provide a paint callback that receives the element's bounds and can issue raw drawing commands.

```zig
ui.canvas(struct {
    fn paint(bounds: zapui.Bounds(zapui.Pixels), scene: *zapui.Scene) void {
        scene.insertQuad(.{
            .bounds = bounds,
            .background = .{ .solid = zapui.rgb(0xff0000) },
            // ...
        });
    }
}.paint)
```

---

## Styling

Styles are applied to `div` elements via a fluent builder API. Methods return `*Div` so they can be chained.

### Layout

```zig
ui.div()
    // Display mode (default is .flex)
    .flex()                    // display: flex
    .block()                   // display: block
    .hidden()                  // display: none

    // Flex direction
    .flexRow()                 // flex-direction: row (default)
    .flexCol()                 // flex-direction: column

    // Flex wrapping
    .flexWrap()                // flex-wrap: wrap
    .flexNoWrap()              // flex-wrap: nowrap (default)

    // Alignment
    .itemsStart()              // align-items: flex-start
    .itemsCenter()             // align-items: center
    .itemsEnd()                // align-items: flex-end
    .itemsStretch()            // align-items: stretch
    .itemsBaseline()           // align-items: baseline

    // Justification
    .justifyStart()            // justify-content: flex-start
    .justifyCenter()           // justify-content: center
    .justifyEnd()              // justify-content: flex-end
    .justifyBetween()          // justify-content: space-between
    .justifyAround()           // justify-content: space-around
    .justifyEvenly()           // justify-content: space-evenly

    // Flex item properties
    .flexGrow(value)           // flex-grow: <f32>
    .flexShrink(value)         // flex-shrink: <f32>
    .flexBasis(length)         // flex-basis: <Length>

    // Positioning
    .relative()                // position: relative (default)
    .absolute()                // position: absolute
    .build()
```

### Sizing

```zig
ui.div()
    // Explicit size
    .w(zapui.px(200))          // width: 200px
    .h(zapui.px(100))          // height: 100px
    .size(zapui.px(200))       // width + height: 200px

    // Percentage sizing
    .wPct(50)                  // width: 50%
    .hPct(100)                 // height: 100%

    // Full size (100% of parent)
    .sizeFull()                // width: 100%, height: 100%

    // Min/max constraints
    .minW(zapui.px(100))       // min-width: 100px
    .maxW(zapui.px(500))       // max-width: 500px
    .minH(zapui.px(50))        // min-height: 50px
    .maxH(zapui.px(300))       // max-height: 300px

    .build()
```

### Spacing

Spacing uses a Tailwind-like scale: `0` = 0px, `1` = 4px, `2` = 8px, `3` = 12px, `4` = 16px, `5` = 20px, `6` = 24px, `8` = 32px, `10` = 40px, `12` = 48px, `16` = 64px.

```zig
ui.div()
    // Gap (space between children)
    .gap1()                    // gap: 4px
    .gap2()                    // gap: 8px
    .gap3()                    // gap: 12px
    .gap4()                    // gap: 16px
    .gap(zapui.px(7))          // gap: 7px (custom)

    // Padding (inside the border)
    .p1()                      // padding: 4px (all sides)
    .p2()                      // padding: 8px
    .p3()                      // padding: 12px
    .p4()                      // padding: 16px
    .px2()                     // padding-left + padding-right: 8px
    .py3()                     // padding-top + padding-bottom: 12px
    .pt1()                     // padding-top: 4px
    .pr2()                     // padding-right: 8px
    .pb3()                     // padding-bottom: 12px
    .pl4()                     // padding-left: 16px
    .p(zapui.px(7))            // padding: 7px (custom, all sides)

    // Margin (outside the border)
    .m1()                      // margin: 4px (all sides)
    .m2()                      // margin: 8px
    .mx2()                     // margin-left + margin-right: 8px
    .my3()                     // margin-top + margin-bottom: 12px
    .mt1()                     // margin-top: 4px
    .mAuto()                   // margin: auto (all sides)

    .build()
```

### Appearance

```zig
ui.div()
    // Background
    .bg(zapui.rgb(0x313244))           // solid background color

    // Borders
    .border1()                          // border-width: 1px (all sides)
    .border2()                          // border-width: 2px
    .borderColor(zapui.rgb(0x585b70))  // border color

    // Corner radii
    .rounded(zapui.px(4))              // border-radius: 4px (all corners)
    .roundedSm()                        // border-radius: 2px
    .roundedMd()                        // border-radius: 6px
    .roundedLg()                        // border-radius: 8px
    .roundedXl()                        // border-radius: 12px
    .roundedFull()                      // border-radius: 9999px (pill shape)

    // Shadows
    .shadowSm()                         // small drop shadow
    .shadowMd()                         // medium drop shadow
    .shadowLg()                         // large drop shadow

    // Opacity
    .opacity(0.5)                       // 50% transparent

    // Overflow
    .overflowHidden()                   // clip children to bounds
    .overflowScroll()                   // clip + scrollable

    // Z-index
    .zIndex(10)                         // stacking order

    .build()
```

### Text Styling

Text styles are set on the parent div and inherited by child text elements.

```zig
ui.div()
    .textColor(zapui.rgb(0xcdd6f4))    // text color
    .textXs()                           // font-size: 12px
    .textSm()                           // font-size: 14px
    .textBase()                         // font-size: 16px
    .textLg()                           // font-size: 18px
    .textXl()                           // font-size: 20px
    .text2xl()                          // font-size: 24px
    .text3xl()                          // font-size: 30px
    .fontSize(zapui.px(22))            // font-size: 22px (custom)
    .child(ui.text("Styled text"))
    .build()
```

---

## Colors

### Hex Colors

```zig
zapui.rgb(0x1e1e2e)              // Hsla from RGB hex (alpha = 1.0)
zapui.rgba(0x1e1e2eff)           // Hsla from RGBA hex
```

### HSL Colors

```zig
zapui.hsla(0.66, 0.5, 0.3, 1.0) // hue [0-1], saturation, lightness, alpha
```

### Named Colors

```zig
zapui.red()
zapui.green()
zapui.blue()
zapui.white()
zapui.black()
zapui.transparent()
```

### Color Operations

```zig
const color = zapui.rgb(0x1e1e2e);
color.withAlpha(0.5)             // same color, 50% alpha
color.lighten(0.1)               // increase lightness by 10%
color.darken(0.1)                // decrease lightness by 10%
color.toRgba()                   // convert to Rgba struct
```

---

## Units

```zig
zapui.px(16)                     // 16 pixels
zapui.rems(1.0)                  // 1 rem (relative to root font size, default 16px)
zapui.pct(50)                    // 50%
zapui.auto                       // auto sizing
```

The `Length` type is the union of all unit types:

```zig
const Length = union(enum) {
    px: Pixels,
    rems: Rems,
    percent: f32,
    auto,
};
```

---

## Layout

zapui uses **CSS Flexbox** for layout, ported from Taffy. If you know CSS flexbox, you know zapui layout.

### Row Layout (default)

Children laid out horizontally:

```zig
ui.div()
    .flexRow()     // default, can omit
    .gap2()
    .child(ui.div().w(zapui.px(100)).h(zapui.px(50)).bg(zapui.red()).build())
    .child(ui.div().w(zapui.px(100)).h(zapui.px(50)).bg(zapui.green()).build())
    .child(ui.div().w(zapui.px(100)).h(zapui.px(50)).bg(zapui.blue()).build())
    .build()
// Result: [RED] [GREEN] [BLUE]  (horizontal, 8px gaps)
```

### Column Layout

Children laid out vertically:

```zig
ui.div()
    .flexCol()
    .gap2()
    .child(ui.div().w(zapui.px(200)).h(zapui.px(50)).bg(zapui.red()).build())
    .child(ui.div().w(zapui.px(200)).h(zapui.px(50)).bg(zapui.green()).build())
    .build()
// Result:
// [RED      ]
// [GREEN    ]
```

### Centering

```zig
ui.div()
    .sizeFull()
    .justifyCenter()    // center on main axis
    .itemsCenter()      // center on cross axis
    .child(ui.text("Perfectly centered"))
    .build()
```

### Flex Grow / Shrink

```zig
ui.div()
    .flexRow().sizeFull()
    .child(ui.div().w(zapui.px(100)).bg(zapui.red()).build())          // fixed 100px
    .child(ui.div().flexGrow(1).bg(zapui.green()).build())             // takes remaining space
    .child(ui.div().w(zapui.px(100)).bg(zapui.blue()).build())         // fixed 100px
    .build()
// Result: [RED:100px] [GREEN:fills remaining] [BLUE:100px]
```

### Wrapping

```zig
ui.div()
    .flexRow().flexWrap()
    .w(zapui.px(300)).gap2()
    .child(ui.div().w(zapui.px(150)).h(zapui.px(50)).bg(zapui.red()).build())
    .child(ui.div().w(zapui.px(150)).h(zapui.px(50)).bg(zapui.green()).build())
    .child(ui.div().w(zapui.px(150)).h(zapui.px(50)).bg(zapui.blue()).build())
    .build()
// Result (wraps because 150+150+150 > 300):
// [RED   ] [GREEN ]
// [BLUE  ]
```

### Absolute Positioning

Absolute elements are positioned relative to their nearest positioned ancestor:

```zig
ui.div()
    .relative().w(zapui.px(400)).h(zapui.px(300))
    .child(
        ui.div()
            .absolute()
            .top(zapui.px(10)).right(zapui.px(10))
            .w(zapui.px(30)).h(zapui.px(30))
            .bg(zapui.red())
            .build()
    )
    .build()
// Red square in top-right corner, 10px from edges
```

---

## Input & Events

### Forwarding Events

zapui doesn't create windows or capture input. You forward events from your windowing library:

```zig
// Mouse events
ui.processEvent(.{ .mouse_down = .{
    .button = .left,
    .position = .{ .x = mouse_x, .y = mouse_y },
    .click_count = 1,
    .modifiers = .{},
}});

ui.processEvent(.{ .mouse_move = .{
    .position = .{ .x = mouse_x, .y = mouse_y },
    .modifiers = .{},
}});

ui.processEvent(.{ .scroll_wheel = .{
    .delta = .{ .x = 0, .y = scroll_y },
}});

// Keyboard events
ui.processEvent(.{ .key_down = .{
    .key = .a,
    .modifiers = .{ .ctrl = true },
}});
```

Calling `processEvent` automatically sets the redraw flag.

### Handling Events on Elements

Attach event handlers to divs using the fluent builder:

```zig
ui.div()
    .bg(zapui.rgb(0x313244))
    .p3().roundedMd()
    .onClick(struct {
        fn handler(event: zapui.MouseDownEvent, app: *zapui.App) void {
            _ = event;
            std.debug.print("clicked!\n", .{});
            // Update app state here
        }
    }.handler)
    .child(ui.text("Click me"))
    .build()
```

### Available Event Handlers

```zig
.onClick(fn(MouseDownEvent, *App) void)       // mouse down inside element
.onMouseDown(fn(MouseDownEvent, *App) void)    // mouse button pressed
.onMouseUp(fn(MouseUpEvent, *App) void)        // mouse button released
.onHover(fn(bool, *App) void)                  // hover state changed (true=entered, false=left)
.onScroll(fn(ScrollWheelEvent, *App) void)     // scroll wheel inside element
```

### Hit Testing

During the prepaint phase, elements that have event handlers register **hitboxes** — rectangular regions that respond to input. On mouse events, zapui tests the mouse position against registered hitboxes back-to-front (highest z-order first). The first matching hitbox receives the event.

---

## Entities & State Management

Entities are zapui's state containers. They hold your application data, support observation (react to changes), and integrate with the rendering cycle.

### Creating Entities

```zig
const Counter = struct {
    count: i32,
};

// Create an entity
const counter = ui.app.new(Counter, struct {
    fn build(ctx: *zapui.Context(Counter)) Counter {
        _ = ctx;
        return .{ .count = 0 };
    }
}.build);
```

### Reading Entity State

```zig
const state = ui.app.read(Counter, counter);
std.debug.print("count = {}\n", .{state.count});
```

### Updating Entity State

```zig
ui.app.update(Counter, counter, struct {
    fn update(self: *Counter, ctx: *zapui.Context(Counter)) void {
        _ = ctx;
        self.count += 1;
    }
}.update);
```

Calling `update` on an entity automatically queues a notification, which triggers observers and a redraw.

### Observing Changes

```zig
_ = ui.app.observe(counter.asAny(), struct {
    fn changed(app: *zapui.App) void {
        std.debug.print("counter changed!\n", .{});
        _ = app;
    }
}.changed);
```

Observers fire during `flushNotifications()`, which happens automatically at the start of each frame.

### Global State

For state that doesn't belong to a specific entity (themes, settings, etc.):

```zig
const Theme = struct {
    bg: zapui.Hsla,
    fg: zapui.Hsla,
};

ui.app.setGlobal(Theme, .{
    .bg = zapui.rgb(0x1e1e2e),
    .fg = zapui.rgb(0xcdd6f4),
});

const theme = ui.app.global(Theme);
```

---

## Views

A **view** is an entity that knows how to render itself into an element tree. This is the primary pattern for building UI components.

```zig
const TodoList = struct {
    items: std.ArrayList([]const u8),
    selected: ?usize,

    pub fn render(self: *TodoList, ui: *zapui.Ui) zapui.AnyElement {
        var list = ui.div().flexCol().gap1().p2();

        for (self.items.items, 0..) |item, i| {
            const is_selected = self.selected == i;
            const item_idx = i;

            list = list.child(
                ui.div()
                    .flexRow().p2().roundedMd()
                    .bg(if (is_selected) zapui.rgb(0x45475a) else zapui.transparent())
                    .textColor(zapui.rgb(0xcdd6f4))
                    .onClick(struct {
                        fn handler(event: zapui.MouseDownEvent, app: *zapui.App) void {
                            _ = event;
                            // Update selected index via entity system
                            _ = app;
                            _ = item_idx;
                        }
                    }.handler)
                    .child(ui.text(item))
                    .build()
            );
        }

        return list.build();
    }
};
```

### Rendering a View

```zig
var todo = TodoList{
    .items = items,
    .selected = null,
};

// In the frame loop:
ui.beginFrame();
ui.render(todo.render(&todo, &ui));
ui.endFrame();
```

---

## Viewport & Scaling

### Setting the Viewport

Call `setViewport` when the window resizes:

```zig
ui.setViewport(new_width, new_height, scale_factor);
```

- `width`, `height` — logical size in pixels
- `scale_factor` — for HiDPI displays (e.g., 2.0 on Retina). zapui renders at `width * scale` x `height * scale` physical pixels.

### Responding to Resize

```zig
// GLFW example
glfw.glfwSetFramebufferSizeCallback(window, struct {
    fn callback(_: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        // Get the Ui pointer somehow (global, user pointer, etc.)
        global_ui.setViewport(
            @floatFromInt(width),
            @floatFromInt(height),
            getScaleFactor(),
        );
    }
}.callback);
```

---

## Async & Background Work

zapui does not own an event loop or thread pool. You manage async work yourself. When background work completes and UI state has changed, signal zapui to re-render:

```zig
// On a background thread:
const result = try httpClient.get(url);

mutex.lock();
defer mutex.unlock();
shared_state.data = result;

// Tell zapui to re-render (thread-safe)
ui.requestRedraw();
```

```zig
// Main loop picks it up:
while (!should_close) {
    pollEvents();

    if (ui.needsRedraw()) {
        ui.beginFrame();

        mutex.lock();
        const data = shared_state.data;
        mutex.unlock();

        ui.render(buildUiFromData(data, &ui));
        ui.endFrame();
        swapBuffers();
    } else {
        // Sleep or wait to avoid busy-looping
        std.time.sleep(1_000_000); // 1ms
    }
}
```

The pattern is:
1. Do work on any thread
2. Update your shared state (with your own synchronization)
3. Call `ui.requestRedraw()`
4. Main loop sees `needsRedraw() == true`, builds and renders the frame

---

## Fonts

### Loading Fonts

```zig
const font_id = try ui.loadFont("/path/to/font.ttf");
```

Fonts are loaded via Freetype and shaped via Harfbuzz. Glyph bitmaps are rasterized on demand and cached in a texture atlas.

### Using Fonts

Currently, the first loaded font is used as the default. Font selection per-element is planned for a future release.

---

## Geometry Types

These generic types are used throughout the API:

```zig
zapui.Point(T)     // { x: T, y: T }
zapui.Size(T)      // { width: T, height: T }
zapui.Bounds(T)    // { origin: Point(T), size: Size(T) }
zapui.Edges(T)     // { top: T, right: T, bottom: T, left: T }
zapui.Corners(T)   // { top_left: T, top_right: T, bottom_right: T, bottom_left: T }
```

Common instantiations:
- `Bounds(Pixels)` — layout results, hit testing
- `Bounds(ScaledPixels)` — rendering (after DPI scaling)
- `Edges(Length)` — padding, margin in styles
- `Corners(Pixels)` — border radii

### Bounds Operations

```zig
const b = zapui.Bounds(f32){
    .origin = .{ .x = 10, .y = 20 },
    .size = .{ .width = 100, .height = 50 },
};

b.contains(.{ .x = 50, .y = 30 })  // true — point inside bounds
b.intersect(other_bounds)            // intersection of two bounds, or null
b.union(other_bounds)                // smallest bounds containing both
b.inset(edges)                       // shrink by edges (padding)
b.outset(edges)                      // grow by edges (margin)
b.center()                           // Point at center of bounds
```

---

## Complete Example: Counter App

```zig
const std = @import("std");
const zapui = @import("zapui");
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));

const CounterApp = struct {
    count: i32 = 0,

    pub fn render(self: *CounterApp, ui: *zapui.Ui) zapui.AnyElement {
        const self_ptr = self;

        return ui.div()
            .flexCol().gap4().p4()
            .itemsCenter().justifyCenter()
            .sizeFull()
            .bg(zapui.rgb(0x1e1e2e))
            .child(
                // Title
                ui.div()
                    .text3xl().textColor(zapui.rgb(0xcdd6f4))
                    .child(ui.text("Counter"))
                    .build()
            )
            .child(
                // Count display
                ui.div()
                    .text2xl().textColor(zapui.rgb(0xa6e3a1))
                    .child(ui.textFmt("{}", .{self.count}))
                    .build()
            )
            .child(
                // Button row
                ui.div()
                    .flexRow().gap2()
                    .child(
                        // Decrement button
                        ui.div()
                            .px4().py2().roundedMd()
                            .bg(zapui.rgb(0x45475a))
                            .textColor(zapui.rgb(0xcdd6f4))
                            .onClick(struct {
                                fn handler(_: zapui.MouseDownEvent, _: *zapui.App) void {
                                    // In practice, use entity system to update state
                                    self_ptr.count -= 1;
                                }
                            }.handler)
                            .child(ui.text("-"))
                            .build()
                    )
                    .child(
                        // Increment button
                        ui.div()
                            .px4().py2().roundedMd()
                            .bg(zapui.rgb(0x89b4fa))
                            .textColor(zapui.rgb(0x1e1e2e))
                            .onClick(struct {
                                fn handler(_: zapui.MouseDownEvent, _: *zapui.App) void {
                                    self_ptr.count += 1;
                                }
                            }.handler)
                            .child(ui.text("+"))
                            .build()
                    )
                    .build()
            )
            .build();
    }
};

pub fn main() !void {
    _ = glfw.glfwInit();
    defer glfw.glfwTerminate();
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    const window = glfw.glfwCreateWindow(800, 600, "Counter", null, null);
    glfw.glfwMakeContextCurrent(window);

    var ui = zapui.Ui.init(.{});
    defer ui.deinit();

    _ = try ui.loadFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");

    var app = CounterApp{};

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();
        if (ui.needsRedraw()) {
            ui.beginFrame();
            ui.render(app.render(&app, &ui));
            ui.endFrame();
            glfw.glfwSwapBuffers(window);
        } else {
            std.time.sleep(1_000_000);
        }
    }
}
```

---

## API Reference Summary

### `zapui.Ui`

| Method | Description |
|--------|-------------|
| `init(opts: InitOptions) Ui` | Create a new UI context |
| `deinit()` | Free all resources |
| `beginFrame()` | Start a new frame (resets arena, clears scene) |
| `render(root: AnyElement)` | Layout and paint the element tree |
| `endFrame()` | Sort primitives and issue GL draw calls |
| `processEvent(event: InputEvent)` | Forward an input event (sets redraw flag) |
| `setViewport(w, h, scale)` | Update viewport dimensions and DPI scale |
| `requestRedraw()` | Thread-safe: signal that a redraw is needed |
| `needsRedraw() bool` | Check and clear the redraw flag |
| `div() *Div` | Create a div element (arena-allocated) |
| `text(content) AnyElement` | Create a text element |
| `textFmt(fmt, args) AnyElement` | Create a formatted text element |
| `loadFont(path) !FontId` | Load a .ttf/.otf font file |

### `zapui.App`

| Method | Description |
|--------|-------------|
| `new(T, build_fn) Entity(T)` | Create a new entity |
| `read(T, handle) *const T` | Read entity state |
| `update(T, handle, callback)` | Mutate entity state (queues notification) |
| `observe(entity, callback) Subscription` | React to entity changes |
| `setGlobal(T, value)` | Set a global singleton |
| `global(T) *const T` | Read a global singleton |
| `notify(id)` | Manually queue a notification |
| `flushNotifications()` | Dispatch all pending observer callbacks |

### `zapui.Div` (fluent builder)

See the [Styling](#styling) section for the full list of builder methods. Key structural methods:

| Method | Description |
|--------|-------------|
| `.child(element: AnyElement) *Div` | Add a child element |
| `.children(elements: []AnyElement) *Div` | Add multiple children |
| `.build() AnyElement` | Finalize into an AnyElement for rendering |

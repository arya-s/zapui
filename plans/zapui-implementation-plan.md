# zapui - Zig Port of GPUI

## Context

Zed's GPUI is a GPU-accelerated UI framework in Rust that powers the Zed editor. We're building **zapui**, a Zig reimplementation of GPUI's core architecture. zapui will be an **embeddable library** (like Dear ImGui) - users provide their own OpenGL 3.3 context and forward input events; zapui handles layout, styling, and rendering.

**Key decisions:**
- OpenGL 3.3 rendering backend (cross-platform compatibility)
- Embeddable: no windowing code, user provides GL context + events
- Freetype + Harfbuzz for text (via `@cImport`)
- Taffy-equivalent flexbox layout ported to Zig
- Full element pipeline: entities, elements, layout, rendering, events
- Async: user-driven (Option 3) — zapui exposes `requestRedraw()` (thread-safe atomic flag), user manages their own threads/async and pokes zapui when state changes. No executor owned by zapui.

---

## Project Structure

```
zapui/
├── build.zig
├── build.zig.zon
├── playground/                # Development sandbox for testing the library
│   └── main.zig               # Quick experiments and manual testing
├── src/
│   ├── zapui.zig              # Public API root
│   ├── app.zig                # App context, entity storage, observers
│   ├── entity.zig             # Entity handles, SlotMap, reservations
│   ├── element.zig            # Element interface (vtable), AnyElement
│   ├── view.zig               # View/Render interface, AnyView
│   ├── style.zig              # Style struct + Styled fluent builder
│   ├── layout.zig             # Taffy-equivalent flexbox engine
│   ├── scene.zig              # Scene graph, rendering primitives
│   ├── geometry.zig           # Point, Size, Bounds, Edges, Corners
│   ├── color.zig              # Hsla, Rgba, color helpers
│   ├── input.zig              # Input events, hit testing, focus
│   ├── text_system.zig        # Font loading, shaping, glyph cache
│   ├── renderer/
│   │   ├── gl_renderer.zig    # OpenGL 3.3 renderer
│   │   ├── atlas.zig          # Texture atlas (glyph + image packing)
│   │   └── shaders.zig        # Embedded GLSL shaders
│   ├── elements/
│   │   ├── div.zig            # Div element (primary building block)
│   │   ├── text.zig           # Text element
│   │   ├── img.zig            # Image element
│   │   └── canvas.zig         # Custom draw callback element
│   └── shaders/
│       ├── quad.vert.glsl
│       ├── quad.frag.glsl
│       ├── shadow.vert.glsl
│       ├── shadow.frag.glsl
│       ├── sprite.vert.glsl
│       ├── sprite.frag.glsl
│       ├── path.vert.glsl
│       └── path.frag.glsl
├── examples/
│   ├── hello_world.zig        # Minimal example with GLFW
│   └── build.zig              # Example build config
└── deps/                      # C dependency source (freetype, harfbuzz, stb)
```

---

## Phase 1: Foundation — Geometry, Color, Style

**Goal:** Core types that everything else depends on. Zero dependencies, pure Zig.

### Files & Key Types

**`src/geometry.zig`**
```zig
pub fn Point(comptime T: type) type { ... }    // { x: T, y: T }
pub fn Size(comptime T: type) type { ... }     // { width: T, height: T }
pub fn Bounds(comptime T: type) type { ... }   // { origin: Point(T), size: Size(T) }
pub fn Edges(comptime T: type) type { ... }    // { top, right, bottom, left: T }
pub fn Corners(comptime T: type) type { ... }  // { top_left, top_right, bottom_right, bottom_left: T }
pub const Pixels = f32;
pub const ScaledPixels = f32;
pub const Rems = f32;
pub fn px(value: f32) Pixels { ... }
pub fn rems(value: f32) Rems { ... }
```

**`src/color.zig`**
```zig
pub const Hsla = struct { h: f32, s: f32, l: f32, a: f32 };
pub const Rgba = struct { r: f32, g: f32, b: f32, a: f32 };
pub fn rgb(hex: u32) Hsla { ... }
pub fn rgba(hex: u32) Hsla { ... }
pub fn hsla(h: f32, s: f32, l: f32, a: f32) Hsla { ... }
// Named colors: red(), green(), blue(), white(), black(), transparent()
```

**`src/style.zig`**
```zig
pub const Display = enum { flex, block, none };
pub const Position = enum { relative, absolute };
pub const Overflow = enum { visible, hidden, scroll };
pub const FlexDirection = enum { row, row_reverse, column, column_reverse };
pub const AlignItems = enum { flex_start, flex_end, center, stretch, baseline };
pub const JustifyContent = enum { flex_start, flex_end, center, space_between, space_around, space_evenly };

pub const Length = union(enum) { px: Pixels, rems: Rems, percent: f32, auto };

pub const Style = struct {
    display: Display = .flex,
    position: Position = .relative,
    overflow: Point(Overflow) = .{ .x = .visible, .y = .visible },
    flex_direction: FlexDirection = .row,
    flex_wrap: FlexWrap = .no_wrap,
    align_items: ?AlignItems = null,
    justify_content: ?JustifyContent = null,
    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,
    flex_basis: Length = .auto,
    gap: Size(Length) = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } },
    size: Size(Length) = ...,
    min_size: Size(Length) = ...,
    max_size: Size(Length) = ...,
    padding: Edges(Length) = ...,
    margin: Edges(Length) = ...,
    border_widths: Edges(Pixels) = ...,
    border_color: ?Hsla = null,
    corner_radii: Corners(Pixels) = ...,
    background: ?Background = null,
    text_color: ?Hsla = null,
    font_size: ?Pixels = null,
    opacity: f32 = 1.0,
    z_index: ?i32 = null,
    // ... (more as needed)
};

pub const Background = union(enum) { solid: Hsla, /* gradient later */ };
```

**Verify:** Unit tests for geometry math (bounds intersection, edges, etc.) and color conversions.

---

## Phase 2: Scene Graph & OpenGL Renderer

**Goal:** Render quads, shadows, and sprites to screen via OpenGL 3.3.

### Files & Key Types

**`src/scene.zig`**
```zig
pub const DrawOrder = u32;

pub const Quad = struct {
    order: DrawOrder,
    bounds: Bounds(ScaledPixels),
    background: Background,
    border_color: Hsla,
    border_widths: Edges(ScaledPixels),
    corner_radii: Corners(ScaledPixels),
    content_mask: Bounds(ScaledPixels),
};

pub const Shadow = struct {
    order: DrawOrder,
    bounds: Bounds(ScaledPixels),
    corner_radii: Corners(ScaledPixels),
    blur_radius: ScaledPixels,
    color: Hsla,
    content_mask: Bounds(ScaledPixels),
};

pub const MonochromeSprite = struct { ... };  // For text glyphs
pub const PolychromeSprite = struct { ... };  // For images
pub const PathVertex = struct { ... };        // For vector paths

pub const Primitive = union(enum) { quad: Quad, shadow: Shadow, mono_sprite: MonochromeSprite, ... };
pub const PrimitiveBatch = union(enum) { quads: []const Quad, shadows: []const Shadow, ... };

pub const Scene = struct {
    quads: std.ArrayList(Quad),
    shadows: std.ArrayList(Shadow),
    // ...

    pub fn insertQuad(self: *Scene, quad: Quad) void { ... }
    pub fn finish(self: *Scene) void { ... }  // Sort by draw order
    pub fn batches(self: *const Scene) BatchIterator { ... }
    pub fn clear(self: *Scene) void { ... }
};
```

**`src/renderer/atlas.zig`**
```zig
pub const AtlasTile = struct { tex_id: u32, bounds: Bounds(f32) };
pub const Atlas = struct {
    texture: gl.GLuint,
    width: u32,
    height: u32,
    // Shelf-packing or etagere algorithm
    pub fn allocate(self: *Atlas, size: Size(u32)) ?AtlasTile { ... }
    pub fn upload(self: *Atlas, tile: AtlasTile, data: []const u8) void { ... }
};
```

**`src/renderer/shaders.zig`**
- Embeds GLSL source at comptime via `@embedFile`
- Shader compilation/linking helpers

**`src/shaders/quad.vert.glsl`** + **`quad.frag.glsl`**
- Vertex shader: transform quad bounds to clip space (instanced rendering, one draw call per batch)
- Fragment shader: rounded corners via SDF, border rendering, background fill, content masking

**`src/shaders/shadow.vert.glsl`** + **`shadow.frag.glsl`**
- Gaussian blur shadow via SDF

**`src/shaders/sprite.vert.glsl`** + **`sprite.frag.glsl`**
- Textured quad for glyphs and images

**`src/renderer/gl_renderer.zig`**
```zig
pub const GlRenderer = struct {
    quad_pipeline: ShaderProgram,
    shadow_pipeline: ShaderProgram,
    sprite_pipeline: ShaderProgram,
    atlas: Atlas,
    quad_vao: gl.GLuint,
    quad_vbo: gl.GLuint,  // Instance buffer
    viewport_size: Size(f32),
    scale_factor: f32,

    pub fn init() GlRenderer { ... }
    pub fn deinit(self: *GlRenderer) void { ... }
    pub fn setViewport(self: *GlRenderer, size: Size(f32), scale: f32) void { ... }
    pub fn drawScene(self: *GlRenderer, scene: *const Scene) void { ... }
    // Internal: drawQuadBatch, drawShadowBatch, drawSpriteBatch
};
```

**OpenGL 3.3 strategy:**
- One VAO per primitive type (quad, shadow, sprite)
- Instance buffers for batched rendering (upload all quads in one buffer, draw instanced)
- Uniforms for viewport size and global params
- Fragment SDF for rounded corners: `float dist = roundedBoxSDF(pos, halfSize, cornerRadii)`

**Verify:** Standalone test that creates a GL context (via GLFW in examples/), pushes quads/shadows into a Scene, renders them. Should see colored rounded rectangles with borders and shadows.

---

## Phase 3: Text Rendering

**Goal:** Render text using Freetype + Harfbuzz, cached in the texture atlas.

### Files

**`src/text_system.zig`**
```zig
pub const FontId = u32;
pub const GlyphId = u32;

pub const Font = struct {
    family: []const u8,
    weight: FontWeight = .normal,
    style: FontStyle = .normal,
};

pub const FontMetrics = struct {
    ascent: f32,
    descent: f32,
    line_height: f32,
    // ...
};

pub const ShapedGlyph = struct {
    glyph_id: GlyphId,
    position: Point(f32),
    atlas_tile: ?AtlasTile,
};

pub const ShapedRun = struct {
    font_id: FontId,
    glyphs: []ShapedGlyph,
};

pub const TextSystem = struct {
    ft_library: freetype.FT_Library,
    faces: std.ArrayList(freetype.FT_Face),
    hb_fonts: std.ArrayList(harfbuzz.hb_font_t),
    glyph_cache: std.HashMap(GlyphCacheKey, AtlasTile),
    atlas: *Atlas,

    pub fn init(atlas: *Atlas) TextSystem { ... }
    pub fn loadFont(self: *TextSystem, path: []const u8) !FontId { ... }
    pub fn shapeText(self: *TextSystem, text: []const u8, font: FontId, size: f32) ShapedRun { ... }
    pub fn rasterizeGlyph(self: *TextSystem, font: FontId, glyph: GlyphId, size: f32) AtlasTile { ... }
};
```

**`build.zig`** additions:
- Compile freetype2 from source (or link system lib)
- Compile harfbuzz from source (or link system lib)
- `@cImport` for both

**Verify:** Render "Hello, World!" text to screen with proper shaping and glyph atlas caching.

---

## Phase 4: Flexbox Layout Engine (Taffy Port)

**Goal:** CSS flexbox layout that computes `Bounds(Pixels)` for each node from `Style`.

### Files

**`src/layout.zig`**
```zig
pub const LayoutId = u32;
pub const AvailableSpace = union(enum) { definite: Pixels, min_content, max_content };

pub const LayoutEngine = struct {
    nodes: SlotMap(LayoutNode),

    pub fn init(allocator: Allocator) LayoutEngine { ... }
    pub fn clear(self: *LayoutEngine) void { ... }

    /// Create a layout node from a style with children
    pub fn requestLayout(self: *LayoutEngine, style: Style, children: []const LayoutId) LayoutId { ... }

    /// Create a leaf node with a custom measure function
    pub fn requestMeasuredLayout(
        self: *LayoutEngine,
        style: Style,
        measure: *const fn(Size(?Pixels), Size(AvailableSpace)) Size(Pixels),
    ) LayoutId { ... }

    /// Compute layout for the tree rooted at `id`
    pub fn computeLayout(self: *LayoutEngine, id: LayoutId, available: Size(AvailableSpace)) void { ... }

    /// Get computed bounds for a node
    pub fn bounds(self: *const LayoutEngine, id: LayoutId) Bounds(Pixels) { ... }
};

const LayoutNode = struct {
    style: LayoutStyle,        // Simplified style for layout only
    children: []LayoutId,
    measure: ?MeasureFn,
    // Computed:
    computed_bounds: Bounds(Pixels),
    computed_size: Size(Pixels),
};
```

**Flexbox algorithm** (ported from Taffy):
1. Determine available space
2. Determine flex container's main/cross axis
3. Generate anonymous flex items
4. Determine each item's base size (`flex_basis`)
5. Resolve flexible lengths (grow/shrink)
6. Determine main axis position (justify-content)
7. Determine cross axis position (align-items/align-self)
8. Handle wrapping (`flex_wrap`)
9. Handle `position: absolute` items

This is the most complex phase. Taffy's source is ~3000 lines of Rust for the flexbox algorithm. We port the core logic.

**Verify:** Unit tests matching Taffy's test suite outputs. Given a tree of styles, verify computed bounds match expected values for common flex patterns (row, column, wrap, grow, shrink, centering, etc.).

---

## Phase 5: Entity System & App Context

**Goal:** State management with entities, observers, and the app context.

### Files

**`src/entity.zig`**
```zig
pub const EntityId = struct { index: u32, generation: u32 };

pub fn Entity(comptime T: type) type {
    return struct {
        id: EntityId,
        // Read/update via App context
    };
}

pub const AnyEntity = struct {
    id: EntityId,
    type_id: TypeId,
};

/// Generational arena / slot map for entity storage
pub const EntityStore = struct {
    slots: std.ArrayList(Slot),
    // ...
    pub fn insert(self: *EntityStore, value: anytype) EntityId { ... }
    pub fn get(self: *EntityStore, comptime T: type, id: EntityId) ?*T { ... }
    pub fn remove(self: *EntityStore, id: EntityId) void { ... }
};
```

**`src/app.zig`**
```zig
pub const App = struct {
    entities: EntityStore,
    observers: ObserverMap,        // entity_id -> list of callbacks
    global_observers: ObserverMap, // type_id -> list of callbacks
    pending_notifications: std.ArrayList(EntityId),
    allocator: Allocator,

    pub fn new(comptime T: type, self: *App, build: fn(*Context(T)) T) Entity(T) { ... }
    pub fn read(self: *const App, comptime T: type, handle: Entity(T)) *const T { ... }
    pub fn update(self: *App, comptime T: type, handle: Entity(T), callback: fn(*T, *Context(T)) void) void { ... }
    pub fn observe(self: *App, handle: AnyEntity, callback: fn(*App) void) Subscription { ... }
    pub fn setGlobal(self: *App, comptime T: type, value: T) void { ... }
    pub fn global(self: *const App, comptime T: type) *const T { ... }
    pub fn notify(self: *App, id: EntityId) void { ... }
    pub fn flushNotifications(self: *App) void { ... }
};

pub fn Context(comptime T: type) type {
    return struct {
        app: *App,
        entity_id: EntityId,
        // Provides scoped access to the entity being built/updated
    };
}
```

**Verify:** Create entities, update them, observe changes, verify observers fire.

---

## Phase 6: Element System & Div

**Goal:** The Element interface, AnyElement, and the `div` element with full styling.

### Files

**`src/element.zig`**
```zig
/// Element vtable - dynamic dispatch for elements
pub const ElementVTable = struct {
    request_layout: *const fn(self: *anyopaque, window: *Window, app: *App) LayoutId,
    prepaint: *const fn(self: *anyopaque, bounds: Bounds(Pixels), window: *Window, app: *App) void,
    paint: *const fn(self: *anyopaque, bounds: Bounds(Pixels), window: *Window, app: *App) void,
    deinit: *const fn(self: *anyopaque) void,
};

pub const AnyElement = struct {
    ptr: *anyopaque,
    vtable: *const ElementVTable,
    layout_id: ?LayoutId = null,

    pub fn requestLayout(self: *AnyElement, window: *Window, app: *App) LayoutId { ... }
    pub fn prepaint(self: *AnyElement, bounds: Bounds(Pixels), window: *Window, app: *App) void { ... }
    pub fn paint(self: *AnyElement, bounds: Bounds(Pixels), window: *Window, app: *App) void { ... }
};

/// Convert any concrete element to AnyElement. Concrete elements implement:
///   fn requestLayout(*Self, *Window, *App) LayoutId
///   fn prepaint(*Self, Bounds(Pixels), *Window, *App) void
///   fn paint(*Self, Bounds(Pixels), *Window, *App) void
pub fn intoAnyElement(comptime T: type, ptr: *T, arena: *ArenaAllocator) AnyElement { ... }
```

**`src/view.zig`**
```zig
/// A view is an entity that implements render
pub fn View(comptime T: type) type {
    return struct {
        entity: Entity(T),
        // render produces an element tree from current state
    };
}
```

**`src/elements/div.zig`**
```zig
pub const Div = struct {
    style: Style,
    children: std.ArrayList(AnyElement),

    // Fluent builder methods (returns *Div for chaining)
    pub fn flex(self: *Div) *Div { self.style.display = .flex; return self; }
    pub fn flexCol(self: *Div) *Div { self.style.flex_direction = .column; return self; }
    pub fn bg(self: *Div, color: Hsla) *Div { self.style.background = .{ .solid = color }; return self; }
    pub fn border1(self: *Div) *Div { self.style.border_widths = Edges(Pixels).all(1); return self; }
    pub fn borderColor(self: *Div, c: Hsla) *Div { self.style.border_color = c; return self; }
    pub fn roundedMd(self: *Div) *Div { self.style.corner_radii = Corners(Pixels).all(6); return self; }
    pub fn size(self: *Div, s: Length) *Div { ... }
    pub fn gap3(self: *Div) *Div { ... }
    pub fn justifyCenter(self: *Div) *Div { ... }
    pub fn itemsCenter(self: *Div) *Div { ... }
    pub fn textXl(self: *Div) *Div { ... }
    pub fn textColor(self: *Div, c: Hsla) *Div { ... }
    pub fn shadowLg(self: *Div) *Div { ... }
    pub fn child(self: *Div, element: AnyElement) *Div { ... }
    pub fn build(self: *Div) AnyElement { ... }

    // Element interface
    pub fn requestLayout(self: *Div, window: *Window, app: *App) LayoutId { ... }
    pub fn prepaint(self: *Div, bounds: Bounds(Pixels), window: *Window, app: *App) void { ... }
    pub fn paint(self: *Div, bounds: Bounds(Pixels), window: *Window, app: *App) void { ... }
};
```

**`src/elements/text.zig`**
```zig
pub const Text = struct {
    content: []const u8,
    style: TextStyle,
    shaped_run: ?ShapedRun = null,

    pub fn requestLayout(self: *Text, window: *Window, app: *App) LayoutId {
        // Use text system to measure, return measured layout
    }
    pub fn paint(self: *Text, bounds: Bounds(Pixels), window: *Window, app: *App) void {
        // Paint glyphs as sprites
    }
};
```

**Verify:** Build a tree of div elements with children, run layout, paint to screen. The hello_world example should render.

---

## Phase 7: Input & Events

**Goal:** Mouse/keyboard input, hit testing, event handling on elements.

### Files

**`src/input.zig`**
```zig
pub const MouseButton = enum { left, right, middle };
pub const MouseDownEvent = struct { button: MouseButton, position: Point(Pixels), click_count: u32, modifiers: Modifiers };
pub const MouseUpEvent = struct { ... };
pub const MouseMoveEvent = struct { position: Point(Pixels), modifiers: Modifiers };
pub const ScrollWheelEvent = struct { delta: Point(Pixels), ... };
pub const KeyDownEvent = struct { key: Key, modifiers: Modifiers, ... };
pub const KeyUpEvent = struct { ... };

pub const InputEvent = union(enum) {
    mouse_down: MouseDownEvent,
    mouse_up: MouseUpEvent,
    mouse_move: MouseMoveEvent,
    scroll_wheel: ScrollWheelEvent,
    key_down: KeyDownEvent,
    key_up: KeyUpEvent,
};

pub const Hitbox = struct {
    id: HitboxId,
    bounds: Bounds(Pixels),
    // Registered during prepaint by elements that want to receive events
};
```

**Event flow:**
1. User forwards platform events to `ui.processEvent(event)`
2. zapui translates to internal event types
3. During prepaint, elements register hitboxes
4. On mouse events: hit test against registered hitboxes, dispatch to matching elements
5. Events bubble up through the element tree

**Div event handlers (added to div.zig):**
```zig
pub fn onMouseDown(self: *Div, handler: fn(MouseDownEvent, *App) void) *Div { ... }
pub fn onMouseUp(self: *Div, handler: fn(MouseUpEvent, *App) void) *Div { ... }
pub fn onClick(self: *Div, handler: fn(MouseDownEvent, *App) void) *Div { ... }
pub fn onHover(self: *Div, handler: fn(bool, *App) void) *Div { ... }
```

**Verify:** Click on elements, hover state changes, keyboard events dispatched.

---

## Phase 8: Window Context & Frame Orchestration

**Goal:** The `Window` struct that ties everything together, manages frame lifecycle.

**`src/zapui.zig`** (public API)
```zig
pub const Ui = struct {
    app: App,
    window: Window,
    renderer: GlRenderer,
    scene: Scene,
    layout_engine: LayoutEngine,
    text_system: TextSystem,
    frame_arena: ArenaAllocator,  // Reset each frame
    redraw_flag: std.atomic.Value(bool),  // Thread-safe redraw signal

    pub fn init(opts: InitOptions) Ui { ... }
    pub fn deinit(self: *Ui) void { ... }

    /// Thread-safe: call from any thread to signal that state has changed
    /// and zapui should re-render on the next frame.
    pub fn requestRedraw(self: *Ui) void {
        self.redraw_flag.store(true, .release);
    }

    /// Check if a redraw was requested (clears the flag).
    /// User calls this in their main loop to decide whether to render.
    pub fn needsRedraw(self: *Ui) bool {
        return self.redraw_flag.swap(false, .acquire);
    }

    pub fn processEvent(self: *Ui, event: InputEvent) void { ... }
    pub fn setViewport(self: *Ui, width: f32, height: f32, scale: f32) void { ... }

    pub fn beginFrame(self: *Ui) void {
        // Reset frame arena, clear scene
    }

    pub fn render(self: *Ui, root_view: anytype) void {
        // 1. Call root_view.render() to build element tree
        // 2. request_layout on root element (populates layout engine)
        // 3. layout_engine.computeLayout()
        // 4. prepaint (register hitboxes, compute positions)
        // 5. paint (emit primitives to scene)
    }

    pub fn endFrame(self: *Ui) void {
        // scene.finish() - sort primitives
        // renderer.drawScene(&scene) - issue GL draw calls
    }

    // Element constructors (convenience)
    pub fn div(self: *Ui) *Div { ... }       // Allocate from frame arena
    pub fn text(self: *Ui, content: []const u8) AnyElement { ... }
};

pub const Window = struct {
    scene: *Scene,
    layout_engine: *LayoutEngine,
    text_system: *TextSystem,
    viewport_size: Size(Pixels),
    scale_factor: f32,
    hitboxes: std.ArrayList(Hitbox),
    // ...
};

pub const InitOptions = struct {
    viewport_width: f32 = 800,
    viewport_height: f32 = 600,
    scale_factor: f32 = 1.0,
    allocator: ?Allocator = null,
};
```

**Verify:** Full hello_world example renders and responds to input.

---

## Phase 9: Hello World Example

**`examples/hello_world.zig`**
```zig
const std = @import("std");
const zapui = @import("zapui");
const glfw = @cImport(@cInclude("GLFW/glfw3.h"));

const HelloWorld = struct {
    text: []const u8,

    pub fn render(self: *HelloWorld, ui: *zapui.Ui) zapui.AnyElement {
        return ui.div()
            .flex().flexCol().gap3()
            .bg(zapui.rgb(0x505050))
            .size(zapui.px(500))
            .justifyCenter().itemsCenter()
            .shadowLg()
            .border1().borderColor(zapui.rgb(0x0000ff))
            .textXl().textColor(zapui.rgb(0xffffff))
            .child(ui.text(std.fmt.allocPrint("Hello, {s}!", .{self.text})))
            .build();
    }
};

pub fn main() !void {
    // GLFW + GL setup
    _ = glfw.glfwInit();
    const window = glfw.glfwCreateWindow(800, 600, "zapui hello", null, null);
    glfw.glfwMakeContextCurrent(window);

    var ui = zapui.Ui.init(.{});
    defer ui.deinit();
    var app = HelloWorld{ .text = "World" };

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        // Only re-render when something changed (input events or
        // background work called ui.requestRedraw())
        if (ui.needsRedraw()) {
            ui.beginFrame();
            ui.render(&app);
            ui.endFrame();
            glfw.glfwSwapBuffers(window);
        }
    }
}
```

---

## Build Configuration

**`build.zig`** — Key aspects:
- `@cImport` for freetype2 and harfbuzz
- Compile C deps from source OR link system libraries (configurable)
- GLSL shaders embedded via `@embedFile`
- Example targets link GLFW for windowing (but zapui itself does NOT depend on GLFW)
- OpenGL loaded via Zig's `@cImport` of GL headers (or a small gl loader)

**`build.zig.zon`** — Dependencies:
- No Zig package dependencies initially
- C source for freetype, harfbuzz vendored in `deps/` or fetched via build.zig.zon

---

## Implementation Order & Dependencies

```
Phase 1: geometry, color, style          (no deps)
   ↓
Phase 2: scene, renderer, shaders       (depends on Phase 1)
   ↓
Phase 3: text_system                     (depends on Phase 2 for atlas)
   ↓
Phase 4: layout engine                   (depends on Phase 1 for style/geometry)
   ↓
Phase 5: entity system, app context      (depends on Phase 1)
   ↓
Phase 6: element system, div, text elem  (depends on Phases 2-5)
   ↓
Phase 7: input & events                  (depends on Phase 6)
   ↓
Phase 8: window context, frame orchestration (depends on all above)
   ↓
Phase 9: hello_world example             (depends on all above)
```

Note: Phases 3, 4, and 5 can be worked on **in parallel** since they're independent.

---

## Verification Plan

| Phase | How to verify |
|-------|--------------|
| 1 | `zig build test` — unit tests for geometry ops, color conversion |
| 2 | Standalone GL test: render colored rounded rects with borders and shadows |
| 3 | Render shaped text ("Hello World") to screen with proper glyph rendering |
| 4 | Unit tests: compute layout for flex row/col/wrap/grow/shrink, compare bounds to expected |
| 5 | Unit tests: create/read/update entities, observer notifications fire correctly |
| 6 | Render a tree of styled divs with text children — visual output matches expected |
| 7 | Click/hover on elements triggers registered callbacks |
| 8 | Full frame loop: events → layout → render works end-to-end |
| 9 | `zig build run-example` shows the hello world window |

---

## Key Zig Design Decisions

1. **Element interface via vtable**: Since Zig doesn't have trait objects, we use `*anyopaque` + `ElementVTable` struct (function pointers). Comptime helper `intoAnyElement` generates the vtable for any concrete element type.

2. **Per-frame arena allocator**: Element trees are rebuilt every frame (like GPUI). All element allocations go to a frame arena that gets reset at `beginFrame()`. This makes the immediate-mode-ish pattern efficient.

3. **Fluent builder via pointer returns**: Zig doesn't have Rust's ownership/move semantics, but we can return `*Div` from each builder method since divs are arena-allocated. This gives us the chainable `.flex().bg().child()` API.

4. **Comptime generics for Entity(T)**: `Entity(T)` is a comptime generic struct wrapping an `EntityId`. Type safety at compile time, type-erased storage at runtime.

5. **No async executor — user-driven redraw**: zapui does not own an async executor or event loop. Instead, it exposes a thread-safe `requestRedraw()` (atomic flag) and `needsRedraw()`. Users manage their own threads/async work, mutate shared state with their own synchronization, and call `requestRedraw()` to tell zapui to re-render. The main loop checks `needsRedraw()` to decide whether to run a frame. This keeps zapui fully embeddable — it never blocks, never spawns threads, and never owns the event loop.

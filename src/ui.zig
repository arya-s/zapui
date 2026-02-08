//! UI orchestration for zapui.
//! The Ui struct ties together all components and manages the frame lifecycle.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const scene_mod = @import("scene.zig");
const layout_mod = @import("layout.zig");
const app_mod = @import("app.zig");
const element_mod = @import("element.zig");
const input_mod = @import("input.zig");
const renderer_mod = @import("renderer/gl_renderer.zig");
const div_mod = @import("elements/div.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Hsla = color.Hsla;
const Scene = scene_mod.Scene;
const LayoutEngine = layout_mod.LayoutEngine;
const AvailableSpace = layout_mod.AvailableSpace;
const App = app_mod.App;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const HitTestEngine = input_mod.HitTestEngine;
const InputEvent = input_mod.InputEvent;
const MouseState = input_mod.MouseState;
const Cursor = input_mod.Cursor;
const GlRenderer = renderer_mod.GlRenderer;
const Div = div_mod.Div;

/// Initialization options for the UI
pub const InitOptions = struct {
    viewport_width: Pixels = 800,
    viewport_height: Pixels = 600,
    scale_factor: f32 = 1.0,
    rem_size: Pixels = 16.0,
    allocator: ?Allocator = null,
};

/// The main UI orchestrator
pub const Ui = struct {
    allocator: Allocator,
    app: App,
    scene: Scene,
    layout_engine: LayoutEngine,
    hit_test: HitTestEngine,
    renderer: ?GlRenderer,
    frame_arena: std.heap.ArenaAllocator,

    // Viewport state
    viewport_size: Size(Pixels),
    scale_factor: f32,
    rem_size: Pixels,

    // Input state
    mouse_state: MouseState,
    current_cursor: Cursor,

    // Redraw state
    redraw_requested: std.atomic.Value(bool),
    needs_layout: bool,

    pub fn init(options: InitOptions) !Ui {
        const allocator = options.allocator orelse std.heap.page_allocator;

        return .{
            .allocator = allocator,
            .app = App.init(allocator),
            .scene = Scene.init(allocator),
            .layout_engine = LayoutEngine.init(allocator),
            .hit_test = HitTestEngine.init(allocator),
            .renderer = null, // Initialized separately after GL context
            .frame_arena = std.heap.ArenaAllocator.init(allocator),

            .viewport_size = .{ .width = options.viewport_width, .height = options.viewport_height },
            .scale_factor = options.scale_factor,
            .rem_size = options.rem_size,

            .mouse_state = .{},
            .current_cursor = .default,

            .redraw_requested = std.atomic.Value(bool).init(true),
            .needs_layout = true,
        };
    }

    pub fn deinit(self: *Ui) void {
        self.frame_arena.deinit();
        if (self.renderer) |*r| {
            r.deinit();
        }
        self.hit_test.deinit();
        self.layout_engine.deinit();
        self.scene.deinit();
        self.app.deinit();
    }

    /// Initialize the renderer (call after GL context is ready)
    pub fn initRenderer(self: *Ui) !void {
        self.renderer = try GlRenderer.init(self.allocator);
    }

    /// Thread-safe: request a redraw on the next frame
    pub fn requestRedraw(self: *Ui) void {
        self.redraw_requested.store(true, .release);
    }

    /// Check if a redraw was requested (clears the flag)
    pub fn needsRedraw(self: *Ui) bool {
        return self.redraw_requested.swap(false, .acquire);
    }

    /// Update viewport size and scale
    pub fn setViewport(self: *Ui, width: Pixels, height: Pixels, scale: f32) void {
        if (self.viewport_size.width != width or
            self.viewport_size.height != height or
            self.scale_factor != scale)
        {
            self.viewport_size = .{ .width = width, .height = height };
            self.scale_factor = scale;
            self.needs_layout = true;
            self.requestRedraw();
        }

        if (self.renderer) |*r| {
            r.setViewport(width, height, scale);
        }
    }

    /// Process an input event
    pub fn processEvent(self: *Ui, event: InputEvent) void {
        switch (event) {
            .mouse_move => |e| {
                self.mouse_state.position = e.position;

                // Hit test for hover
                if (self.hit_test.hitTest(e.position)) |result| {
                    if (self.mouse_state.hovered_hitbox != result.hitbox_id) {
                        self.mouse_state.hovered_hitbox = result.hitbox_id;
                        self.current_cursor = result.cursor;
                        self.requestRedraw();
                    }
                } else {
                    if (self.mouse_state.hovered_hitbox != null) {
                        self.mouse_state.hovered_hitbox = null;
                        self.current_cursor = .default;
                        self.requestRedraw();
                    }
                }
            },
            .mouse_down => |e| {
                self.mouse_state.position = e.position;
                self.mouse_state.setButtonDown(e.button, true);
                self.requestRedraw();
            },
            .mouse_up => |e| {
                self.mouse_state.position = e.position;
                self.mouse_state.setButtonDown(e.button, false);
                self.requestRedraw();
            },
            .scroll_wheel => {
                self.requestRedraw();
            },
            .key_down, .key_up, .text_input => {
                self.requestRedraw();
            },
            .focus => {
                self.requestRedraw();
            },
        }
    }

    /// Begin a new frame
    pub fn beginFrame(self: *Ui) void {
        _ = self.frame_arena.reset(.retain_capacity);
        self.scene.clear();
        self.layout_engine.clear();
        self.hit_test.clear();
    }

    /// Get a render context for this frame
    pub fn getRenderContext(self: *Ui) RenderContext {
        return .{
            .allocator = self.frame_arena.allocator(),
            .layout_engine = &self.layout_engine,
            .scene = &self.scene,
            .app = &self.app,
            .hit_test = &self.hit_test,
            .scale_factor = self.scale_factor,
            .rem_size = self.rem_size,
        };
    }

    /// Render a root element
    pub fn renderElement(self: *Ui, root: *AnyElement) void {
        var ctx = self.getRenderContext();

        // 1. Request layout
        const root_id = root.requestLayout(&ctx);

        // 2. Compute layout
        self.layout_engine.computeLayout(root_id, .{
            .width = .{ .definite = self.viewport_size.width },
            .height = .{ .definite = self.viewport_size.height },
        });

        // 3. Get root bounds
        const root_layout = self.layout_engine.getLayout(root_id);
        const root_bounds = Bounds(Pixels).init(root_layout.origin, root_layout.size);

        // 4. Prepaint (register hitboxes)
        root.prepaint(root_bounds, &ctx);

        // 5. Paint (emit primitives)
        root.paint(root_bounds, &ctx);
    }

    /// End the frame and render to screen
    pub fn endFrame(self: *Ui, clear_color: Hsla) !void {
        self.scene.finish();

        if (self.renderer) |*r| {
            r.clear(clear_color);
            try r.drawScene(&self.scene);
        }

        self.needs_layout = false;
    }

    /// Get the current cursor style
    pub fn getCursor(self: *const Ui) Cursor {
        return self.current_cursor;
    }

    /// Get the app context
    pub fn getApp(self: *Ui) *App {
        return &self.app;
    }

};

// ============================================================================
// Tests
// ============================================================================

test "Ui basic lifecycle" {
    var ui = try Ui.init(.{});
    defer ui.deinit();

    try std.testing.expect(ui.needsRedraw());
    try std.testing.expect(!ui.needsRedraw()); // Cleared

    ui.requestRedraw();
    try std.testing.expect(ui.needsRedraw());
}

test "Ui viewport changes trigger redraw" {
    var ui = try Ui.init(.{});
    defer ui.deinit();

    _ = ui.needsRedraw(); // Clear initial flag

    ui.setViewport(1024, 768, 2.0);
    try std.testing.expect(ui.needsRedraw());
}

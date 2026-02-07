//! Element system for zapui.
//! Provides the Element interface and AnyElement type-erased wrapper.

const std = @import("std");
const geometry = @import("geometry.zig");
const layout_mod = @import("layout.zig");
const scene_mod = @import("scene.zig");
const app_mod = @import("app.zig");
const input_mod = @import("input.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const LayoutId = layout_mod.LayoutId;
const LayoutEngine = layout_mod.LayoutEngine;
const Scene = scene_mod.Scene;
const App = app_mod.App;
const HitTestEngine = input_mod.HitTestEngine;
const Cursor = input_mod.Cursor;
const HitboxId = input_mod.HitboxId;

/// Render context passed to elements during layout/paint
pub const RenderContext = struct {
    allocator: Allocator,
    layout_engine: *LayoutEngine,
    scene: *Scene,
    app: *App,
    hit_test: ?*HitTestEngine = null,
    scale_factor: f32 = 1.0,
    rem_size: Pixels = 16.0,

    /// Register a hitbox during prepaint
    pub fn registerHitbox(self: *RenderContext, bounds: Bounds(Pixels), cursor: Cursor) ?HitboxId {
        if (self.hit_test) |ht| {
            return ht.registerHitbox(bounds, cursor, true) catch null;
        }
        return null;
    }
};

/// Element vtable for dynamic dispatch
pub const ElementVTable = struct {
    request_layout: *const fn (self: *anyopaque, ctx: *RenderContext) LayoutId,
    prepaint: *const fn (self: *anyopaque, bounds: Bounds(Pixels), ctx: *RenderContext) void,
    paint: *const fn (self: *anyopaque, bounds: Bounds(Pixels), ctx: *RenderContext) void,
    deinit: *const fn (self: *anyopaque, allocator: Allocator) void,
};

/// Type-erased element that can hold any concrete element type
pub const AnyElement = struct {
    ptr: *anyopaque,
    vtable: *const ElementVTable,
    layout_id: ?LayoutId = null,

    /// Request layout for this element
    pub fn requestLayout(self: *AnyElement, ctx: *RenderContext) LayoutId {
        const id = self.vtable.request_layout(self.ptr, ctx);
        self.layout_id = id;
        return id;
    }

    /// Prepaint phase - register hitboxes, compute derived state
    pub fn prepaint(self: *AnyElement, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        self.vtable.prepaint(self.ptr, bounds, ctx);
    }

    /// Paint the element
    pub fn paint(self: *AnyElement, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        self.vtable.paint(self.ptr, bounds, ctx);
    }

    /// Clean up the element
    pub fn deinit(self: *AnyElement, allocator: Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }

    /// Get the layout bounds for this element
    pub fn getLayoutBounds(self: *const AnyElement, ctx: *RenderContext) ?Bounds(Pixels) {
        if (self.layout_id) |id| {
            return ctx.layout_engine.getLayout(id);
        }
        return null;
    }
};

/// Convert a concrete element to AnyElement
/// The concrete element type must implement:
///   fn requestLayout(*Self, *RenderContext) LayoutId
///   fn prepaint(*Self, Bounds(Pixels), *RenderContext) void
///   fn paint(*Self, Bounds(Pixels), *RenderContext) void
///   fn deinit(*Self, Allocator) void (optional)
pub fn intoAnyElement(comptime T: type, ptr: *T) AnyElement {
    const vtable = comptime blk: {
        var vt: ElementVTable = undefined;

        vt.request_layout = @ptrCast(&struct {
            fn requestLayout(self: *anyopaque, ctx: *RenderContext) LayoutId {
                const typed: *T = @ptrCast(@alignCast(self));
                return typed.requestLayout(ctx);
            }
        }.requestLayout);

        vt.prepaint = @ptrCast(&struct {
            fn prepaint(self: *anyopaque, bounds: Bounds(Pixels), ctx: *RenderContext) void {
                const typed: *T = @ptrCast(@alignCast(self));
                typed.prepaint(bounds, ctx);
            }
        }.prepaint);

        vt.paint = @ptrCast(&struct {
            fn paint(self: *anyopaque, bounds: Bounds(Pixels), ctx: *RenderContext) void {
                const typed: *T = @ptrCast(@alignCast(self));
                typed.paint(bounds, ctx);
            }
        }.paint);

        // Check if type has deinit method
        if (@hasDecl(T, "deinit")) {
            vt.deinit = @ptrCast(&struct {
                fn deinitFn(self: *anyopaque, allocator: Allocator) void {
                    const typed: *T = @ptrCast(@alignCast(self));
                    typed.deinit(allocator);
                }
            }.deinitFn);
        } else {
            vt.deinit = &struct {
                fn noop(_: *anyopaque, _: Allocator) void {}
            }.noop;
        }

        break :blk vt;
    };

    const static_vtable = struct {
        var v: ElementVTable = vtable;
    };

    return .{
        .ptr = ptr,
        .vtable = &static_vtable.v,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "intoAnyElement basic" {
    const TestElement = struct {
        const Self = @This();
        value: i32,
        layout_called: bool = false,
        paint_called: bool = false,

        pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
            _ = ctx;
            self.layout_called = true;
            return 0;
        }

        pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

        pub fn paint(self: *Self, _: Bounds(Pixels), _: *RenderContext) void {
            self.paint_called = true;
        }
    };

    var elem = TestElement{ .value = 42 };
    var any = intoAnyElement(TestElement, &elem);

    // Create minimal context for testing
    const allocator = std.testing.allocator;
    var layout_engine = LayoutEngine.init(allocator);
    defer layout_engine.deinit();
    var scene = Scene.init(allocator);
    defer scene.deinit();
    var app = @import("app.zig").App.init(allocator);
    defer app.deinit();

    var ctx = RenderContext{
        .allocator = allocator,
        .layout_engine = &layout_engine,
        .scene = &scene,
        .app = &app,
    };

    _ = any.requestLayout(&ctx);
    try std.testing.expect(elem.layout_called);

    any.paint(Bounds(Pixels).zero, &ctx);
    try std.testing.expect(elem.paint_called);
}

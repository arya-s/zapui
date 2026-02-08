//! Window - Integrates Zaffy layout with rendering
//!
//! This module provides the core integration between Zaffy layout and zapui rendering.
//! Elements request layout from Zaffy, then paint themselves using the computed bounds.

const std = @import("std");
const zaffy = @import("zaffy.zig");
const scene_mod = @import("scene.zig");
const geometry = @import("geometry.zig");
const color_mod = @import("color.zig");
const style_mod = @import("style.zig");

const Allocator = std.mem.Allocator;
const Scene = scene_mod.Scene;
const Bounds = geometry.Bounds;
const Point = geometry.Point;
const Size = geometry.Size;
const Pixels = geometry.Pixels;
const Hsla = color_mod.Hsla;

/// Layout ID - references a node in the Zaffy tree
pub const LayoutId = zaffy.NodeId;

/// Available space for layout  
pub const AvailableSpace = zaffy.AvailableSpace;
pub const ZaffySize = zaffy.Size;

/// The Window context passed to elements during layout and painting
pub const Window = struct {
    allocator: Allocator,
    layout_engine: LayoutEngine,
    scene: *Scene,
    mouse_position: Point(Pixels),
    
    // Hitbox tracking
    hitboxes: std.ArrayListUnmanaged(Hitbox),
    next_hitbox_id: HitboxId,
    
    pub fn init(allocator: Allocator, scene: *Scene) Window {
        return .{
            .allocator = allocator,
            .layout_engine = LayoutEngine.init(allocator),
            .scene = scene,
            .mouse_position = .{ .x = 0, .y = 0 },
            .hitboxes = .{ .items = &.{}, .capacity = 0 },
            .next_hitbox_id = 0,
        };
    }
    
    pub fn deinit(self: *Window) void {
        self.layout_engine.deinit();
        self.hitboxes.deinit(self.allocator);
    }
    
    /// Request layout for a styled element with children
    pub fn requestLayout(
        self: *Window,
        style: zaffy.Style,
        children: []const LayoutId,
    ) !LayoutId {
        return self.layout_engine.requestLayout(style, children);
    }
    
    /// Request layout for a leaf element (no children)
    pub fn requestLeafLayout(self: *Window, style: zaffy.Style) !LayoutId {
        return self.layout_engine.requestLayout(style, &.{});
    }
    
    /// Compute layout for the entire tree
    pub fn computeLayout(self: *Window, root: LayoutId, available_space: ZaffySize(AvailableSpace)) void {
        self.layout_engine.computeLayout(root, available_space);
    }
    
    /// Get the computed bounds for a layout node
    pub fn layoutBounds(self: *const Window, layout_id: LayoutId) Bounds(Pixels) {
        return self.layout_engine.layoutBounds(layout_id);
    }
    
    /// Register a hitbox for mouse interaction
    pub fn insertHitbox(self: *Window, bounds: Bounds(Pixels), is_opaque: bool) !HitboxId {
        const id = self.next_hitbox_id;
        self.next_hitbox_id += 1;
        try self.hitboxes.append(self.allocator, .{
            .id = id,
            .bounds = bounds,
            .is_opaque = is_opaque,
        });
        return id;
    }
    
    /// Check if a hitbox is hovered
    pub fn isHovered(self: *const Window, hitbox_id: HitboxId) bool {
        // Find the topmost hitbox at mouse position
        var i: usize = self.hitboxes.items.len;
        while (i > 0) {
            i -= 1;
            const hitbox = self.hitboxes.items[i];
            if (hitbox.bounds.contains(self.mouse_position)) {
                return hitbox.id == hitbox_id;
            }
        }
        return false;
    }
    
    /// Get the hitbox at the current mouse position
    pub fn hitboxAtMouse(self: *const Window) ?HitboxId {
        var i: usize = self.hitboxes.items.len;
        while (i > 0) {
            i -= 1;
            const hitbox = self.hitboxes.items[i];
            if (hitbox.bounds.contains(self.mouse_position)) {
                return hitbox.id;
            }
        }
        return null;
    }
    
    /// Clear hitboxes for next frame
    pub fn clearHitboxes(self: *Window) void {
        self.hitboxes.clearRetainingCapacity();
        self.next_hitbox_id = 0;
    }
    
    /// Set mouse position
    pub fn setMousePosition(self: *Window, x: Pixels, y: Pixels) void {
        self.mouse_position = .{ .x = x, .y = y };
    }
};

/// Hitbox ID for mouse interaction
pub const HitboxId = u32;

/// A hitbox for mouse interaction
pub const Hitbox = struct {
    id: HitboxId,
    bounds: Bounds(Pixels),
    is_opaque: bool,
};

/// Layout engine wrapping Zaffy
pub const LayoutEngine = struct {
    tree: zaffy.Zaffy,
    
    pub fn init(allocator: Allocator) LayoutEngine {
        return .{
            .tree = zaffy.Zaffy.init(allocator),
        };
    }
    
    pub fn deinit(self: *LayoutEngine) void {
        self.tree.deinit();
    }
    
    pub fn clear(self: *LayoutEngine) void {
        self.tree.clear();
    }
    
    pub fn requestLayout(self: *LayoutEngine, style: zaffy.Style, children: []const LayoutId) !LayoutId {
        if (children.len == 0) {
            return try self.tree.newLeaf(style);
        } else {
            return try self.tree.newWithChildren(style, children);
        }
    }
    
    pub fn computeLayout(self: *LayoutEngine, root: LayoutId, available_space: ZaffySize(AvailableSpace)) void {
        self.tree.computeLayout(root, available_space);
    }
    
    pub fn layoutBounds(self: *const LayoutEngine, layout_id: LayoutId) Bounds(Pixels) {
        const layout = self.tree.getLayout(layout_id);
        return Bounds(Pixels).fromXYWH(
            layout.location.x,
            layout.location.y,
            layout.size.width,
            layout.size.height,
        );
    }
};

// ============================================================================
// Element trait
// ============================================================================

/// The Element trait - all UI elements implement this
pub fn Element(comptime Self: type) type {
    return struct {
        /// Request layout from Taffy. Returns a LayoutId.
        pub const requestLayout = if (@hasDecl(Self, "requestLayout"))
            Self.requestLayout
        else
            defaultRequestLayout;
        
        /// Paint the element using the computed bounds
        pub const paint = if (@hasDecl(Self, "paint"))
            Self.paint
        else
            defaultPaint;
        
        fn defaultRequestLayout(_: *Self, _: *Window) !LayoutId {
            @compileError("Element must implement requestLayout");
        }
        
        fn defaultPaint(_: *Self, _: Bounds(Pixels), _: *Window) void {
            // Default: do nothing
        }
    };
}

/// Helper to render an element tree
pub fn renderElement(comptime T: type, element: *T, window: *Window, available_space: Size(AvailableSpace)) !void {
    const E = Element(T);
    
    // Phase 1: Request layout
    const layout_id = try E.requestLayout(element, window);
    
    // Phase 2: Compute layout
    window.computeLayout(layout_id, available_space);
    
    // Phase 3: Paint
    const bounds = window.layoutBounds(layout_id);
    E.paint(element, bounds, window);
}

// ============================================================================
// Tests  
// ============================================================================

test "Window basic" {
    const allocator = std.testing.allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();
    
    var window = Window.init(allocator, &scene);
    defer window.deinit();
    
    // Request a simple layout
    const root = try window.requestLeafLayout(.{
        .size = .{ .width = .{ .length = 100 }, .height = .{ .length = 50 } },
    });
    
    window.computeLayout(root, .{ .width = .max_content, .height = .max_content });
    
    const bounds = window.layoutBounds(root);
    try std.testing.expectEqual(@as(Pixels, 100), bounds.size.width);
    try std.testing.expectEqual(@as(Pixels, 50), bounds.size.height);
}

test "Hitbox tracking" {
    const allocator = std.testing.allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();
    
    var window = Window.init(allocator, &scene);
    defer window.deinit();
    
    const hitbox1 = try window.insertHitbox(Bounds(Pixels).fromXYWH(0, 0, 100, 100), true);
    const hitbox2 = try window.insertHitbox(Bounds(Pixels).fromXYWH(50, 50, 100, 100), true);
    
    // Mouse at (75, 75) should hit hitbox2 (topmost)
    window.setMousePosition(75, 75);
    try std.testing.expect(window.isHovered(hitbox2));
    try std.testing.expect(!window.isHovered(hitbox1));
    
    // Mouse at (25, 25) should hit hitbox1
    window.setMousePosition(25, 25);
    try std.testing.expect(window.isHovered(hitbox1));
    try std.testing.expect(!window.isHovered(hitbox2));
}

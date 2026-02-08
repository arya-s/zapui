//! View system for zapui.
//!
//! This module provides the core abstraction for building interactive UIs.
//! Views are lightweight descriptors that get converted into a renderable
//! element tree with automatic layout and hit testing.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const style_mod = @import("style.zig");
const layout_mod = @import("layout.zig");
const scene_mod = @import("scene.zig");
const input_mod = @import("input.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Edges = geometry.Edges;
const Hsla = color.Hsla;
const Scene = scene_mod.Scene;
const LayoutEngine = layout_mod.LayoutEngine;
const LayoutId = layout_mod.LayoutId;
const LayoutStyle = layout_mod.LayoutStyle;
const Length = style_mod.Length;
const Cursor = input_mod.Cursor;

// ============================================================================
// Event Types
// ============================================================================

pub const MouseButton = input_mod.MouseButton;

pub const ClickEvent = struct {
    position: Point(Pixels),
    button: MouseButton,
};

pub const HoverEvent = struct {
    position: Point(Pixels),
    entered: bool,
};

pub const DragEvent = struct {
    position: Point(Pixels),
    delta: Point(Pixels),
};

pub const ChangeEvent = struct {
    // Generic change event for inputs, sliders, etc.
};

// ============================================================================
// Event Handlers
// ============================================================================

pub const ClickHandler = *const fn (*ViewContext, ClickEvent) void;
pub const HoverHandler = *const fn (*ViewContext, HoverEvent) void;
pub const DragHandler = *const fn (*ViewContext, DragEvent) void;
pub const ChangeHandler = *const fn (*ViewContext, ChangeEvent) void;

// ============================================================================
// View Node - The core building block
// ============================================================================

pub const ViewNode = struct {
    const Self = @This();

    // Identity
    id: ?[]const u8 = null,

    // Layout style
    style: LayoutStyle = .{},

    // Visual style
    background: ?Hsla = null,
    border_color: ?Hsla = null,
    border_width: Pixels = 0,
    corner_radius: Pixels = 0,
    shadow_blur: Pixels = 0,
    shadow_color: Hsla = color.black().withAlpha(0.2),

    // Text content (if leaf node)
    text: ?[]const u8 = null,
    text_color: Hsla = color.white(),
    font_size: Pixels = 14,

    // Children
    children: []const ViewNode = &.{},

    // Interaction
    cursor: Cursor = .default,
    on_click: ?ClickHandler = null,
    on_hover: ?HoverHandler = null,
    on_drag: ?DragHandler = null,

    // User data for handlers
    user_data: ?*anyopaque = null,

    // Computed during layout (filled in by the system)
    computed_bounds: Bounds(Pixels) = Bounds(Pixels).zero,
    layout_id: LayoutId = 0,
};

// ============================================================================
// View Context - Passed to event handlers
// ============================================================================

pub const ViewContext = struct {
    allocator: Allocator,
    
    // For triggering re-renders
    needs_redraw: bool = false,

    // Mouse state
    mouse_position: Point(Pixels) = .{ .x = 0, .y = 0 },
    mouse_down: bool = false,

    // Currently hovered/focused nodes
    hovered_node: ?*ViewNode = null,
    focused_node: ?*ViewNode = null,
    drag_node: ?*ViewNode = null,
    drag_start: Point(Pixels) = .{ .x = 0, .y = 0 },

    pub fn requestRedraw(self: *ViewContext) void {
        self.needs_redraw = true;
    }
};

// ============================================================================
// View Tree - Manages the entire UI
// ============================================================================

pub const ViewTree = struct {
    const Self = @This();

    allocator: Allocator,
    layout_engine: LayoutEngine,
    context: ViewContext,
    root: ?*ViewNode = null,

    // Flat list of nodes for hit testing (populated after layout)
    hit_test_list: std.ArrayListUnmanaged(HitTestEntry) = .{ .items = &.{}, .capacity = 0 },

    const HitTestEntry = struct {
        node: *ViewNode,
        bounds: Bounds(Pixels),
        z_index: u32,
    };

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .layout_engine = LayoutEngine.init(allocator),
            .context = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.layout_engine.deinit();
        if (self.hit_test_list.capacity > 0) {
            self.hit_test_list.deinit(self.allocator);
        }
    }

    /// Set the root view
    pub fn setRoot(self: *Self, root: *ViewNode) void {
        self.root = root;
    }

    /// Compute layout for the entire tree
    pub fn layout(self: *Self, viewport: Size(Pixels)) void {
        self.layout_engine.clear();
        self.hit_test_list.clearRetainingCapacity();

        if (self.root) |root| {
            root.layout_id = self.layoutNode(root);
            self.layout_engine.computeLayout(root.layout_id, .{
                .width = .{ .definite = viewport.width },
                .height = .{ .definite = viewport.height },
            });
            self.computeBounds(root, .{ .x = 0, .y = 0 }, 0);
        }
    }

    fn layoutNode(self: *Self, node: *ViewNode) LayoutId {
        // Create layout IDs for children first
        var child_ids = std.ArrayListUnmanaged(LayoutId){ .items = &.{}, .capacity = 0 };
        defer if (child_ids.capacity > 0) child_ids.deinit(self.allocator);

        for (node.children) |*child| {
            // Need mutable pointer - cast away const for internal mutation
            const mutable_child = @as(*ViewNode, @ptrCast(@constCast(child)));
            const child_id = self.layoutNode(mutable_child);
            mutable_child.layout_id = child_id;
            child_ids.append(self.allocator, child_id) catch continue;
        }

        return self.layout_engine.createNode(node.style, child_ids.items) catch 0;
    }

    fn computeBounds(self: *Self, node: *ViewNode, parent_origin: Point(Pixels), z_index: u32) void {
        const layout_result = self.layout_engine.getLayout(node.layout_id);
        
        node.computed_bounds = Bounds(Pixels).init(
            .{
                .x = parent_origin.x + layout_result.origin.x,
                .y = parent_origin.y + layout_result.origin.y,
            },
            layout_result.size,
        );

        // Add to hit test list if interactive
        if (node.on_click != null or node.on_hover != null or node.on_drag != null) {
            self.hit_test_list.append(self.allocator, .{
                .node = node,
                .bounds = node.computed_bounds,
                .z_index = z_index,
            }) catch {};
        }

        // Process children
        for (node.children, 0..) |*child, i| {
            const mutable_child = @as(*ViewNode, @ptrCast(@constCast(child)));
            self.computeBounds(mutable_child, node.computed_bounds.origin, z_index + @as(u32, @intCast(i)) + 1);
        }
    }

    /// Render the tree to a scene
    pub fn render(self: *Self, scene: *Scene, text_system: anytype) void {
        if (self.root) |root| {
            self.renderNode(root, scene, text_system);
        }
    }

    fn renderNode(self: *Self, node: *ViewNode, scene: *Scene, text_system: anytype) void {
        const bounds = node.computed_bounds;

        // Shadow
        if (node.shadow_blur > 0) {
            scene.insertShadow(.{
                .bounds = bounds,
                .corner_radii = Corners(Pixels).all(node.corner_radius),
                .blur_radius = node.shadow_blur,
                .color = node.shadow_color,
            }) catch {};
        }

        // Background/border
        if (node.background != null or node.border_width > 0) {
            scene.insertQuad(.{
                .bounds = bounds,
                .background = if (node.background) |bg| .{ .solid = bg } else null,
                .corner_radii = Corners(Pixels).all(node.corner_radius),
                .border_widths = if (node.border_width > 0) Edges(Pixels).all(node.border_width) else Edges(Pixels).zero,
                .border_color = node.border_color,
            }) catch {};
        }

        // Text
        if (node.text) |text_content| {
            // Center text vertically
            const text_y = bounds.origin.y + bounds.size.height / 2 + node.font_size / 3;
            const text_x = bounds.origin.x + 12; // Left padding
            text_system.renderText(scene, text_content, text_x, text_y, node.font_size, node.text_color) catch {};
        }

        // Children
        for (node.children) |*child| {
            const mutable_child = @as(*ViewNode, @ptrCast(@constCast(child)));
            self.renderNode(mutable_child, scene, text_system);
        }
    }

    // ========================================================================
    // Event Handling
    // ========================================================================

    /// Handle mouse move
    pub fn handleMouseMove(self: *Self, pos: Point(Pixels)) void {
        self.context.mouse_position = pos;

        // Handle dragging
        if (self.context.drag_node) |drag_node| {
            if (drag_node.on_drag) |handler| {
                const delta = Point(Pixels){
                    .x = pos.x - self.context.drag_start.x,
                    .y = pos.y - self.context.drag_start.y,
                };
                handler(&self.context, .{ .position = pos, .delta = delta });
            }
        }

        // Hit test for hover
        const hit_node = self.hitTest(pos);
        
        // Handle hover changes
        if (hit_node != self.context.hovered_node) {
            // Exit old node
            if (self.context.hovered_node) |old| {
                if (old.on_hover) |handler| {
                    handler(&self.context, .{ .position = pos, .entered = false });
                }
            }
            // Enter new node
            if (hit_node) |new| {
                if (new.on_hover) |handler| {
                    handler(&self.context, .{ .position = pos, .entered = true });
                }
            }
            self.context.hovered_node = hit_node;
        }
    }

    /// Handle mouse button press
    pub fn handleMouseDown(self: *Self, pos: Point(Pixels), button: MouseButton) void {
        self.context.mouse_down = true;
        self.context.mouse_position = pos;

        if (self.hitTest(pos)) |node| {
            // Start drag if draggable
            if (node.on_drag != null) {
                self.context.drag_node = node;
                self.context.drag_start = pos;
            }

            // Handle click
            if (node.on_click) |handler| {
                handler(&self.context, .{ .position = pos, .button = button });
            }
        }
    }

    /// Handle mouse button release
    pub fn handleMouseUp(self: *Self, pos: Point(Pixels), _: MouseButton) void {
        self.context.mouse_down = false;
        self.context.mouse_position = pos;
        self.context.drag_node = null;
    }

    /// Hit test - find the topmost node at a position
    fn hitTest(self: *Self, pos: Point(Pixels)) ?*ViewNode {
        var best: ?*ViewNode = null;
        var best_z: u32 = 0;

        for (self.hit_test_list.items) |entry| {
            if (entry.bounds.contains(pos) and entry.z_index >= best_z) {
                best = entry.node;
                best_z = entry.z_index;
            }
        }

        return best;
    }

    /// Check if a redraw is needed
    pub fn needsRedraw(self: *Self) bool {
        const needs = self.context.needs_redraw;
        self.context.needs_redraw = false;
        return needs;
    }

    /// Get current cursor
    pub fn getCursor(self: *Self) Cursor {
        if (self.context.hovered_node) |node| {
            return node.cursor;
        }
        return .default;
    }
};

// ============================================================================
// Builder Functions - Ergonomic API for creating views
// ============================================================================

/// Create a flex column container
pub fn col() ViewNode {
    return .{
        .style = .{
            .flex_direction = .column,
        },
    };
}

/// Create a flex row container
pub fn row() ViewNode {
    return .{
        .style = .{
            .flex_direction = .row,
        },
    };
}

/// Create a styled container
pub fn container() ViewNode {
    return .{};
}

/// Create a text node
pub fn text(content: []const u8) ViewNode {
    return .{
        .text = content,
        .style = .{
            .size = .{
                .width = .auto,
                .height = .auto,
            },
        },
    };
}

// ============================================================================
// ViewNode Builder Methods
// ============================================================================

pub fn withId(node: ViewNode, id: []const u8) ViewNode {
    var n = node;
    n.id = id;
    return n;
}

pub fn withChildren(node: ViewNode, children: []const ViewNode) ViewNode {
    var n = node;
    n.children = children;
    return n;
}

pub fn withPadding(node: ViewNode, p: Pixels) ViewNode {
    var n = node;
    n.style.padding = Edges(Length).all(.{ .px = p });
    return n;
}

pub fn withGap(node: ViewNode, g: Pixels) ViewNode {
    var n = node;
    n.style.gap = .{ .width = .{ .px = g }, .height = .{ .px = g } };
    return n;
}

pub fn withSize(node: ViewNode, w: Pixels, h: Pixels) ViewNode {
    var n = node;
    n.style.size = .{ .width = .{ .px = w }, .height = .{ .px = h } };
    return n;
}

pub fn withWidth(node: ViewNode, w: Pixels) ViewNode {
    var n = node;
    n.style.size.width = .{ .px = w };
    return n;
}

pub fn withHeight(node: ViewNode, h: Pixels) ViewNode {
    var n = node;
    n.style.size.height = .{ .px = h };
    return n;
}

pub fn withFlex(node: ViewNode, grow: f32, shrink: f32) ViewNode {
    var n = node;
    n.style.flex_grow = grow;
    n.style.flex_shrink = shrink;
    return n;
}

pub fn withBackground(node: ViewNode, bg: Hsla) ViewNode {
    var n = node;
    n.background = bg;
    return n;
}

pub fn withBorder(node: ViewNode, width: Pixels, c: Hsla) ViewNode {
    var n = node;
    n.border_width = width;
    n.border_color = c;
    return n;
}

pub fn withCornerRadius(node: ViewNode, r: Pixels) ViewNode {
    var n = node;
    n.corner_radius = r;
    return n;
}

pub fn withShadow(node: ViewNode, blur: Pixels, c: Hsla) ViewNode {
    var n = node;
    n.shadow_blur = blur;
    n.shadow_color = c;
    return n;
}

pub fn withTextColor(node: ViewNode, c: Hsla) ViewNode {
    var n = node;
    n.text_color = c;
    return n;
}

pub fn withFontSize(node: ViewNode, s: Pixels) ViewNode {
    var n = node;
    n.font_size = s;
    return n;
}

pub fn withCursor(node: ViewNode, c: Cursor) ViewNode {
    var n = node;
    n.cursor = c;
    return n;
}

pub fn withOnClick(node: ViewNode, handler: ClickHandler) ViewNode {
    var n = node;
    n.on_click = handler;
    n.cursor = .pointer;
    return n;
}

pub fn withOnHover(node: ViewNode, handler: HoverHandler) ViewNode {
    var n = node;
    n.on_hover = handler;
    return n;
}

pub fn withOnDrag(node: ViewNode, handler: DragHandler) ViewNode {
    var n = node;
    n.on_drag = handler;
    return n;
}

pub fn withUserData(node: ViewNode, data: *anyopaque) ViewNode {
    var n = node;
    n.user_data = data;
    return n;
}

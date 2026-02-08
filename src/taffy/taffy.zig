//! TaffyTree - High-level layout tree API
//!
//! Zig port of taffy/src/tree/taffy_tree.rs

const std = @import("std");
const geo = @import("geometry.zig");
const style_mod = @import("style.zig");
const tree_mod = @import("tree.zig");
const flexbox = @import("flexbox.zig");

const Allocator = std.mem.Allocator;

pub const Point = geo.Point;
pub const Size = geo.Size;
pub const Rect = geo.Rect;
pub const Line = geo.Line;
pub const AvailableSpace = geo.AvailableSpace;
pub const FlexDirection = geo.FlexDirection;
pub const AbsoluteAxis = geo.AbsoluteAxis;

pub const Style = style_mod.Style;
pub const LengthPercentage = style_mod.LengthPercentage;
pub const LengthPercentageAuto = style_mod.LengthPercentageAuto;
pub const Dimension = style_mod.Dimension;
pub const AlignItems = style_mod.AlignItems;
pub const AlignSelf = style_mod.AlignSelf;
pub const AlignContent = style_mod.AlignContent;
pub const JustifyContent = style_mod.JustifyContent;
pub const FlexWrap = style_mod.FlexWrap;
pub const Display = style_mod.Display;
pub const Position = style_mod.Position;

pub const NodeId = tree_mod.NodeId;
pub const INVALID_NODE_ID = tree_mod.INVALID_NODE_ID;
pub const Layout = tree_mod.Layout;
pub const LayoutInput = tree_mod.LayoutInput;
pub const LayoutOutput = tree_mod.LayoutOutput;
pub const RunMode = tree_mod.RunMode;
pub const SizingMode = tree_mod.SizingMode;
pub const Cache = tree_mod.Cache;

// ============================================================================
// Node data
// ============================================================================

const NodeData = struct {
    style: Style,
    layout: Layout,
    cache: Cache,
    children: std.ArrayListUnmanaged(NodeId),
    parent: ?NodeId,

    fn init() NodeData {
        return .{
            .style = Style.DEFAULT,
            .layout = Layout.ZERO,
            .cache = Cache.init(),
            .children = .{ .items = &.{}, .capacity = 0 },
            .parent = null,
        };
    }

    fn deinit(self: *NodeData, allocator: Allocator) void {
        self.children.deinit(allocator);
    }
};

// ============================================================================
// TaffyTree
// ============================================================================

/// A tree of UI nodes with layout computation
pub fn TaffyTree(comptime NodeContext: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        nodes: std.ArrayListUnmanaged(NodeData),
        contexts: std.ArrayListUnmanaged(?NodeContext),
        free_list: std.ArrayListUnmanaged(NodeId),
        use_rounding: bool,

        /// Initialize a new TaffyTree
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .nodes = .{ .items = &.{}, .capacity = 0 },
                .contexts = .{ .items = &.{}, .capacity = 0 },
                .free_list = .{ .items = &.{}, .capacity = 0 },
                .use_rounding = true,
            };
        }

        /// Deinitialize the tree
        pub fn deinit(self: *Self) void {
            for (self.nodes.items) |*node| {
                node.deinit(self.allocator);
            }
            self.nodes.deinit(self.allocator);
            self.contexts.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        /// Create a new leaf node with no children
        pub fn newLeaf(self: *Self, style: Style) !NodeId {
            return self.newLeafWithContext(style, null);
        }

        /// Create a new leaf node with context
        pub fn newLeafWithContext(self: *Self, style: Style, context: ?NodeContext) !NodeId {
            const id = try self.allocNode();
            self.nodes.items[id].style = style;
            self.contexts.items[id] = context;
            return id;
        }

        /// Create a new node with children
        pub fn newWithChildren(self: *Self, node_style: Style, child_ids: []const NodeId) !NodeId {
            const id = try self.newLeaf(node_style);
            for (child_ids) |child| {
                try self.appendChild(id, child);
            }
            return id;
        }

        /// Remove a node from the tree
        pub fn remove(self: *Self, node: NodeId) !void {
            // Remove from parent
            if (self.nodes.items[node].parent) |parent_id| {
                self.removeChildInternal(parent_id, node);
            }

            // Remove all children
            const child_nodes = self.nodes.items[node].children.items;
            for (child_nodes) |child| {
                self.nodes.items[child].parent = null;
            }

            // Clear and add to free list
            self.nodes.items[node].children.clearRetainingCapacity();
            self.contexts.items[node] = null;
            try self.free_list.append(self.allocator, node);
        }

        /// Clear all nodes
        pub fn clear(self: *Self) void {
            for (self.nodes.items) |*node| {
                node.deinit(self.allocator);
            }
            self.nodes.clearRetainingCapacity();
            self.contexts.clearRetainingCapacity();
            self.free_list.clearRetainingCapacity();
        }

        // ====================================================================
        // Tree operations
        // ====================================================================

        /// Add a child to a node
        pub fn appendChild(self: *Self, parent_id: NodeId, child: NodeId) !void {
            // Remove from old parent
            if (self.nodes.items[child].parent) |old_parent| {
                self.removeChildInternal(old_parent, child);
            }

            try self.nodes.items[parent_id].children.append(self.allocator, child);
            self.nodes.items[child].parent = parent_id;
            self.markDirty(parent_id);
        }

        /// Insert a child at a specific index
        pub fn insertChildAtIndex(self: *Self, parent_id: NodeId, index: usize, child: NodeId) !void {
            // Remove from old parent
            if (self.nodes.items[child].parent) |old_parent| {
                self.removeChildInternal(old_parent, child);
            }

            try self.nodes.items[parent_id].children.insert(self.allocator, index, child);
            self.nodes.items[child].parent = parent_id;
            self.markDirty(parent_id);
        }

        /// Remove a child from a parent
        pub fn removeChild(self: *Self, parent_id: NodeId, child: NodeId) void {
            self.removeChildInternal(parent_id, child);
            self.nodes.items[child].parent = null;
            self.markDirty(parent_id);
        }

        /// Remove a child at a specific index
        pub fn removeChildAtIndex(self: *Self, parent_id: NodeId, index: usize) NodeId {
            const child = self.nodes.items[parent_id].children.orderedRemove(index);
            self.nodes.items[child].parent = null;
            self.markDirty(parent_id);
            return child;
        }

        /// Replace a child with another node
        pub fn replaceChildAtIndex(self: *Self, parent_id: NodeId, index: usize, new_child: NodeId) !NodeId {
            const old_child = self.nodes.items[parent_id].children.items[index];
            self.nodes.items[old_child].parent = null;

            // Remove new_child from old parent
            if (self.nodes.items[new_child].parent) |old_parent| {
                self.removeChildInternal(old_parent, new_child);
            }

            self.nodes.items[parent_id].children.items[index] = new_child;
            self.nodes.items[new_child].parent = parent_id;
            self.markDirty(parent_id);
            return old_child;
        }

        /// Get the parent of a node
        pub fn parent(self: *const Self, node: NodeId) ?NodeId {
            return self.nodes.items[node].parent;
        }

        /// Get the children of a node
        pub fn children(self: *const Self, node: NodeId) []const NodeId {
            return self.nodes.items[node].children.items;
        }

        /// Get the number of children
        pub fn childCount(self: *const Self, node: NodeId) usize {
            return self.nodes.items[node].children.items.len;
        }

        /// Get a child by index
        pub fn getChildId(self: *const Self, node: NodeId, index: usize) NodeId {
            return self.nodes.items[node].children.items[index];
        }

        /// Get the total number of nodes
        pub fn totalNodeCount(self: *const Self) usize {
            return self.nodes.items.len - self.free_list.items.len;
        }

        // ====================================================================
        // Style and layout
        // ====================================================================

        /// Get the style of a node
        pub fn getStyle(self: *const Self, node: NodeId) *const Style {
            return &self.nodes.items[node].style;
        }

        /// Set the style of a node
        pub fn setStyle(self: *Self, node: NodeId, style: Style) void {
            self.nodes.items[node].style = style;
            self.markDirty(node);
        }

        /// Get the context of a node
        pub fn getContext(self: *const Self, node: NodeId) ?NodeContext {
            return self.contexts.items[node];
        }

        /// Set the context of a node
        pub fn setContext(self: *Self, node: NodeId, context: ?NodeContext) void {
            self.contexts.items[node] = context;
        }

        /// Get the computed layout of a node
        pub fn getLayout(self: *const Self, node: NodeId) *const Layout {
            return &self.nodes.items[node].layout;
        }

        /// Set the layout of a node (called by layout algorithms)
        pub fn setLayout(self: *Self, node: NodeId, layout: Layout) void {
            self.nodes.items[node].layout = layout;
        }

        // ====================================================================
        // Layout computation
        // ====================================================================

        /// Compute layout for the entire tree
        pub fn computeLayout(self: *Self, root: NodeId, available_space: Size(AvailableSpace)) void {
            const inputs = LayoutInput{
                .run_mode = .perform_layout,
                .sizing_mode = .inherent_size,
                .axis = .both,
                .known_dimensions = .{ .width = null, .height = null },
                .parent_size = .{ .width = null, .height = null },
                .available_space = available_space,
            };

            _ = flexbox.computeFlexboxLayout(self, root, inputs);

            // Set root location to 0,0
            self.nodes.items[root].layout.location = Point(f32).ZERO;

            // Round if enabled
            if (self.use_rounding) {
                self.roundLayout(root, 0, 0);
            }
        }

        /// Compute layout with a specific size
        pub fn computeLayoutWithSize(self: *Self, root: NodeId, width: f32, height: f32) void {
            self.computeLayout(root, Size(AvailableSpace){
                .width = .{ .definite = width },
                .height = .{ .definite = height },
            });
        }

        /// Mark a node as needing relayout
        pub fn markDirty(self: *Self, node: NodeId) void {
            self.nodes.items[node].cache.clear();

            // Propagate up to root
            if (self.nodes.items[node].parent) |p| {
                self.markDirty(p);
            }
        }

        /// Check if any node is dirty
        pub fn isDirty(self: *const Self, node: NodeId) bool {
            return !self.nodes.items[node].cache.final_layout;
        }

        // ====================================================================
        // Debug
        // ====================================================================

        /// Print the tree for debugging
        pub fn printTree(self: *const Self, node: NodeId) void {
            self.printTreeRecursive(node, 0);
        }

        fn printTreeRecursive(self: *const Self, node: NodeId, depth: usize) void {
            const layout = self.getLayout(node);
            const style = self.getStyle(node);

            // Print indentation
            var i: usize = 0;
            while (i < depth) : (i += 1) {
                std.debug.print("  ", .{});
            }

            std.debug.print("Node {}: pos=({d:.1}, {d:.1}) size=({d:.1} x {d:.1}) dir={s}\n", .{
                node,
                layout.location.x,
                layout.location.y,
                layout.size.width,
                layout.size.height,
                @tagName(style.flex_direction),
            });

            for (self.children(node)) |child| {
                self.printTreeRecursive(child, depth + 1);
            }
        }

        // ====================================================================
        // Internal helpers
        // ====================================================================

        fn allocNode(self: *Self) !NodeId {
            if (self.free_list.items.len > 0) {
                const id = self.free_list.items[self.free_list.items.len - 1];
                self.free_list.items.len -= 1;
                self.nodes.items[id] = NodeData.init();
                self.contexts.items[id] = null;
                return id;
            }

            const id: NodeId = @intCast(self.nodes.items.len);
            try self.nodes.append(self.allocator, NodeData.init());
            try self.contexts.append(self.allocator, null);
            return id;
        }

        fn removeChildInternal(self: *Self, parent_id: NodeId, child: NodeId) void {
            const children_list = &self.nodes.items[parent_id].children;
            for (children_list.items, 0..) |c, i| {
                if (c == child) {
                    _ = children_list.orderedRemove(i);
                    break;
                }
            }
        }

        fn roundLayout(self: *Self, node: NodeId, abs_x: f32, abs_y: f32) void {
            const layout = &self.nodes.items[node].layout;

            // Calculate absolute position
            const node_abs_x = abs_x + layout.location.x;
            const node_abs_y = abs_y + layout.location.y;

            // Round location
            layout.location.x = @round(layout.location.x);
            layout.location.y = @round(layout.location.y);

            // Round size
            layout.size.width = @round(node_abs_x + layout.size.width) - @round(node_abs_x);
            layout.size.height = @round(node_abs_y + layout.size.height) - @round(node_abs_y);

            // Recurse to children
            for (self.children(node)) |child| {
                self.roundLayout(child, node_abs_x, node_abs_y);
            }
        }
    };
}

/// Default TaffyTree with no node context
pub const Taffy = TaffyTree(void);

// ============================================================================
// Tests
// ============================================================================

test "TaffyTree basic" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    const root = try tree.newLeaf(Style.DEFAULT);
    try std.testing.expectEqual(@as(usize, 1), tree.totalNodeCount());

    const child1 = try tree.newLeaf(Style{ .flex_grow = 1 });
    const child2 = try tree.newLeaf(Style{ .flex_grow = 1 });

    try tree.appendChild(root, child1);
    try tree.appendChild(root, child2);

    try std.testing.expectEqual(@as(usize, 2), tree.childCount(root));
    try std.testing.expectEqual(@as(usize, 3), tree.totalNodeCount());
}

test "TaffyTree layout" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    // Create a row with two flex children
    const root = try tree.newLeaf(Style{
        .flex_direction = .row,
        .size = .{ .width = .{ .length = 200 }, .height = .{ .length = 100 } },
    });

    const child1 = try tree.newLeaf(Style{ .flex_grow = 1 });
    const child2 = try tree.newLeaf(Style{ .flex_grow = 1 });

    try tree.appendChild(root, child1);
    try tree.appendChild(root, child2);

    tree.computeLayout(root, .{ .width = .max_content, .height = .max_content });

    const layout1 = tree.getLayout(child1);
    const layout2 = tree.getLayout(child2);

    // Both children should be 100px wide (200 / 2)
    try std.testing.expectEqual(@as(f32, 100), layout1.size.width);
    try std.testing.expectEqual(@as(f32, 100), layout2.size.width);

    // Second child should be offset by 100px
    try std.testing.expectEqual(@as(f32, 0), layout1.location.x);
    try std.testing.expectEqual(@as(f32, 100), layout2.location.x);
}

test "TaffyTree flex grow ratio" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    // Row with flex-grow 1:2:1 ratio
    const root = try tree.newLeaf(Style{
        .flex_direction = .row,
        .size = .{ .width = .{ .length = 400 }, .height = .{ .length = 100 } },
    });

    const child1 = try tree.newLeaf(Style{ .flex_grow = 1 });
    const child2 = try tree.newLeaf(Style{ .flex_grow = 2 });
    const child3 = try tree.newLeaf(Style{ .flex_grow = 1 });

    try tree.appendChild(root, child1);
    try tree.appendChild(root, child2);
    try tree.appendChild(root, child3);

    tree.computeLayout(root, .{ .width = .max_content, .height = .max_content });

    // Should be 100:200:100 ratio
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(child1).size.width);
    try std.testing.expectEqual(@as(f32, 200), tree.getLayout(child2).size.width);
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(child3).size.width);
}

test "TaffyTree padding and gap" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    const root = try tree.newLeaf(Style{
        .flex_direction = .row,
        .size = .{ .width = .{ .length = 220 }, .height = .{ .length = 100 } },
        .padding = Rect(LengthPercentage).all(.{ .length = 10 }),
        .gap = .{ .width = .{ .length = 20 }, .height = .{ .length = 0 } },
    });

    const child1 = try tree.newLeaf(Style{ .flex_grow = 1 });
    const child2 = try tree.newLeaf(Style{ .flex_grow = 1 });

    try tree.appendChild(root, child1);
    try tree.appendChild(root, child2);

    tree.computeLayout(root, .{ .width = .max_content, .height = .max_content });

    // Content width = 220 - 20 (padding) = 200
    // Minus gap: 200 - 20 = 180, divided by 2 = 90 each
    try std.testing.expectEqual(@as(f32, 90), tree.getLayout(child1).size.width);
    try std.testing.expectEqual(@as(f32, 90), tree.getLayout(child2).size.width);

    // First child at x=10 (padding), second at x=10+90+20=120
    try std.testing.expectEqual(@as(f32, 10), tree.getLayout(child1).location.x);
    try std.testing.expectEqual(@as(f32, 120), tree.getLayout(child2).location.x);
}

test "TaffyTree justify content" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    const root = try tree.newLeaf(Style{
        .flex_direction = .row,
        .size = .{ .width = .{ .length = 300 }, .height = .{ .length = 100 } },
        .justify_content = .space_between,
    });

    const child1 = try tree.newLeaf(Style{
        .size = .{ .width = .{ .length = 50 }, .height = .{ .length = 50 } },
    });
    const child2 = try tree.newLeaf(Style{
        .size = .{ .width = .{ .length = 50 }, .height = .{ .length = 50 } },
    });
    const child3 = try tree.newLeaf(Style{
        .size = .{ .width = .{ .length = 50 }, .height = .{ .length = 50 } },
    });

    try tree.appendChild(root, child1);
    try tree.appendChild(root, child2);
    try tree.appendChild(root, child3);

    tree.computeLayout(root, .{ .width = .max_content, .height = .max_content });

    // Space between: 300 - 150 = 150 / 2 = 75 gap
    try std.testing.expectEqual(@as(f32, 0), tree.getLayout(child1).location.x);
    try std.testing.expectEqual(@as(f32, 125), tree.getLayout(child2).location.x);
    try std.testing.expectEqual(@as(f32, 250), tree.getLayout(child3).location.x);
}

test "TaffyTree nested layout" {
    var tree = Taffy.init(std.testing.allocator);
    defer tree.deinit();

    // Root: column
    //   Child1: row with two children
    //   Child2: row with two children

    const root = try tree.newLeaf(Style{
        .flex_direction = .column,
        .size = .{ .width = .{ .length = 200 }, .height = .{ .length = 200 } },
    });

    const row1 = try tree.newLeaf(Style{
        .flex_direction = .row,
        .flex_grow = 1,
    });

    const row2 = try tree.newLeaf(Style{
        .flex_direction = .row,
        .flex_grow = 1,
    });

    const a = try tree.newLeaf(Style{ .flex_grow = 1 });
    const b = try tree.newLeaf(Style{ .flex_grow = 1 });
    const c = try tree.newLeaf(Style{ .flex_grow = 1 });
    const d = try tree.newLeaf(Style{ .flex_grow = 1 });

    try tree.appendChild(row1, a);
    try tree.appendChild(row1, b);
    try tree.appendChild(row2, c);
    try tree.appendChild(row2, d);
    try tree.appendChild(root, row1);
    try tree.appendChild(root, row2);

    tree.computeLayout(root, .{ .width = .max_content, .height = .max_content });

    // Each row should be 100px tall
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(row1).size.height);
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(row2).size.height);

    // Each cell should be 100x100
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(a).size.width);
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(a).size.height);

    // Row2 should be at y=100
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(row2).location.y);

    // c should be at x=0 within row2
    try std.testing.expectEqual(@as(f32, 0), tree.getLayout(c).location.x);
    // d should be at x=100 within row2
    try std.testing.expectEqual(@as(f32, 100), tree.getLayout(d).location.x);
}

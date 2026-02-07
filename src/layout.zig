//! Flexbox layout engine for zapui.
//! Computes element positions and sizes based on CSS flexbox rules.

const std = @import("std");
const geometry = @import("geometry.zig");
const style_mod = @import("style.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Edges = geometry.Edges;

const Style = style_mod.Style;
const Length = style_mod.Length;
const Display = style_mod.Display;
const Position = style_mod.Position;
const FlexDirection = style_mod.FlexDirection;
const FlexWrap = style_mod.FlexWrap;
const AlignItems = style_mod.AlignItems;
const AlignSelf = style_mod.AlignSelf;
const JustifyContent = style_mod.JustifyContent;

/// Layout node identifier
pub const LayoutId = u32;

/// Available space for layout computation
pub const AvailableSpace = union(enum) {
    /// A definite pixel size
    definite: Pixels,
    /// Size to fit minimum content
    min_content,
    /// Size to fit maximum content
    max_content,

    pub fn toPixels(self: AvailableSpace) ?Pixels {
        return switch (self) {
            .definite => |v| v,
            else => null,
        };
    }

    pub fn unwrapOr(self: AvailableSpace, default: Pixels) Pixels {
        return switch (self) {
            .definite => |v| v,
            else => default,
        };
    }
};

/// Measure function for leaf nodes (e.g., text)
pub const MeasureFn = *const fn (
    known_size: Size(?Pixels),
    available: Size(AvailableSpace),
    context: ?*anyopaque,
) Size(Pixels);

/// Layout style - subset of Style used for layout computation
pub const LayoutStyle = struct {
    display: Display = .flex,
    position: Position = .relative,
    flex_direction: FlexDirection = .row,
    flex_wrap: FlexWrap = .no_wrap,
    align_items: ?AlignItems = null,
    align_self: ?AlignSelf = null,
    justify_content: ?JustifyContent = null,
    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,
    flex_basis: Length = .auto,
    gap: Size(Length) = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } },
    size: Size(Length) = .{ .width = .auto, .height = .auto },
    min_size: Size(Length) = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } },
    max_size: Size(Length) = .{ .width = .auto, .height = .auto },
    padding: Edges(Length) = Edges(Length){ .top = .{ .px = 0 }, .right = .{ .px = 0 }, .bottom = .{ .px = 0 }, .left = .{ .px = 0 } },
    margin: Edges(Length) = Edges(Length){ .top = .{ .px = 0 }, .right = .{ .px = 0 }, .bottom = .{ .px = 0 }, .left = .{ .px = 0 } },
    border_widths: Edges(Pixels) = Edges(Pixels).zero,
    aspect_ratio: ?f32 = null,
    inset: Edges(?Length) = .{ .top = null, .right = null, .bottom = null, .left = null },

    /// Create from a full Style
    pub fn fromStyle(s: Style) LayoutStyle {
        return .{
            .display = s.display,
            .position = s.position,
            .flex_direction = s.flex_direction,
            .flex_wrap = s.flex_wrap,
            .align_items = s.align_items,
            .align_self = s.align_self,
            .justify_content = s.justify_content,
            .flex_grow = s.flex_grow,
            .flex_shrink = s.flex_shrink,
            .flex_basis = s.flex_basis,
            .gap = s.gap,
            .size = s.size,
            .min_size = s.min_size,
            .max_size = s.max_size,
            .padding = s.padding,
            .margin = s.margin,
            .border_widths = s.border_widths,
            .aspect_ratio = s.aspect_ratio,
            .inset = s.inset,
        };
    }
};

/// Internal layout node
const LayoutNode = struct {
    style: LayoutStyle,
    children: std.ArrayListUnmanaged(LayoutId),
    measure: ?MeasureFn = null,
    measure_context: ?*anyopaque = null,
    // Computed results
    location: Point(Pixels) = Point(Pixels).zero,
    size: Size(Pixels) = Size(Pixels).zero,
    content_size: Size(Pixels) = Size(Pixels).zero,
};

/// Default rem size for length resolution
const DEFAULT_REM_SIZE: Pixels = 16.0;

/// Layout engine - manages layout tree and computes positions
pub const LayoutEngine = struct {
    allocator: Allocator,
    nodes: std.ArrayListUnmanaged(LayoutNode),
    free_list: std.ArrayListUnmanaged(LayoutId),

    pub fn init(allocator: Allocator) LayoutEngine {
        return .{
            .allocator = allocator,
            .nodes = .{ .items = &.{}, .capacity = 0 },
            .free_list = .{ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *LayoutEngine) void {
        for (self.nodes.items) |*node| {
            node.children.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    /// Clear all nodes for a new frame
    pub fn clear(self: *LayoutEngine) void {
        for (self.nodes.items) |*node| {
            node.children.clearRetainingCapacity();
        }
        self.free_list.clearRetainingCapacity();
        // Reset computed values
        for (self.nodes.items) |*node| {
            node.location = Point(Pixels).zero;
            node.size = Size(Pixels).zero;
            node.content_size = Size(Pixels).zero;
        }
    }

    /// Allocate a new node ID
    fn allocNode(self: *LayoutEngine) !LayoutId {
        if (self.free_list.items.len > 0) {
            return self.free_list.pop().?;
        }
        const id: LayoutId = @intCast(self.nodes.items.len);
        try self.nodes.append(self.allocator, .{
            .style = .{},
            .children = .{ .items = &.{}, .capacity = 0 },
        });
        return id;
    }

    /// Create a layout node with children
    pub fn createNode(self: *LayoutEngine, layout_style: LayoutStyle, children: []const LayoutId) !LayoutId {
        const id = try self.allocNode();
        var node = &self.nodes.items[id];
        node.style = layout_style;
        node.measure = null;
        node.measure_context = null;
        node.children.clearRetainingCapacity();
        for (children) |child_id| {
            try node.children.append(self.allocator, child_id);
        }
        return id;
    }

    /// Create a layout node from a full Style
    pub fn createNodeWithStyle(self: *LayoutEngine, s: Style, children: []const LayoutId) !LayoutId {
        return self.createNode(LayoutStyle.fromStyle(s), children);
    }

    /// Create a leaf node with a measure function
    pub fn createLeaf(self: *LayoutEngine, layout_style: LayoutStyle, measure: MeasureFn, context: ?*anyopaque) !LayoutId {
        const id = try self.allocNode();
        var node = &self.nodes.items[id];
        node.style = layout_style;
        node.measure = measure;
        node.measure_context = context;
        node.children.clearRetainingCapacity();
        return id;
    }

    /// Compute layout for the tree rooted at `id`
    pub fn computeLayout(self: *LayoutEngine, id: LayoutId, available: Size(AvailableSpace)) void {
        self.computeNodeLayout(id, available, null);
    }

    /// Get computed bounds for a node (relative to parent)
    pub fn getLayout(self: *const LayoutEngine, id: LayoutId) Bounds(Pixels) {
        const node = &self.nodes.items[id];
        return Bounds(Pixels).init(node.location, node.size);
    }

    /// Get computed size for a node
    pub fn getSize(self: *const LayoutEngine, id: LayoutId) Size(Pixels) {
        return self.nodes.items[id].size;
    }

    /// Get computed location for a node (relative to parent)
    pub fn getLocation(self: *const LayoutEngine, id: LayoutId) Point(Pixels) {
        return self.nodes.items[id].location;
    }

    // ========================================================================
    // Internal layout computation
    // ========================================================================

    fn computeNodeLayout(self: *LayoutEngine, id: LayoutId, available: Size(AvailableSpace), parent_size: ?Size(Pixels)) void {
        var node = &self.nodes.items[id];
        const s = &node.style;

        if (s.display == .none) {
            node.size = Size(Pixels).zero;
            return;
        }

        // Resolve padding, border
        const padding = self.resolveEdges(s.padding, parent_size);
        const border = s.border_widths;
        // TODO: margin handling for absolute positioning
        _ = self.resolveEdges(s.margin, parent_size);

        const padding_border = Edges(Pixels){
            .top = padding.top + border.top,
            .right = padding.right + border.right,
            .bottom = padding.bottom + border.bottom,
            .left = padding.left + border.left,
        };

        // Resolve explicit size
        const parent_width = if (parent_size) |ps| ps.width else available.width.toPixels();
        const parent_height = if (parent_size) |ps| ps.height else available.height.toPixels();

        var width = self.resolveLength(s.size.width, parent_width);
        var height = self.resolveLength(s.size.height, parent_height);

        // Apply aspect ratio
        if (s.aspect_ratio) |ratio| {
            if (width != null and height == null) {
                height = width.? / ratio;
            } else if (height != null and width == null) {
                width = height.? * ratio;
            }
        }

        // Compute content size
        var content_size: Size(Pixels) = undefined;

        if (node.measure) |measure| {
            // Leaf node - use measure function
            const known = Size(?Pixels){
                .width = if (width) |w| w - padding_border.horizontal() else null,
                .height = if (height) |h| h - padding_border.vertical() else null,
            };
            const inner_available = Size(AvailableSpace){
                .width = if (width) |w| .{ .definite = w - padding_border.horizontal() } else available.width,
                .height = if (height) |h| .{ .definite = h - padding_border.vertical() } else available.height,
            };
            content_size = measure(known, inner_available, node.measure_context);
        } else if (node.children.items.len > 0) {
            // Container node - layout children with flexbox
            content_size = self.layoutFlexContainer(id, available, width, height, padding_border);
        } else {
            // Empty node
            content_size = Size(Pixels).zero;
        }

        node.content_size = content_size;

        // Compute final size
        const final_width = width orelse (content_size.width + padding_border.horizontal());
        const final_height = height orelse (content_size.height + padding_border.vertical());

        // Apply min/max constraints
        const min_width = self.resolveLength(s.min_size.width, parent_width) orelse 0;
        const min_height = self.resolveLength(s.min_size.height, parent_height) orelse 0;
        const max_width = self.resolveLength(s.max_size.width, parent_width) orelse std.math.floatMax(f32);
        const max_height = self.resolveLength(s.max_size.height, parent_height) orelse std.math.floatMax(f32);

        node.size = Size(Pixels){
            .width = std.math.clamp(final_width, min_width, max_width),
            .height = std.math.clamp(final_height, min_height, max_height),
        };
    }

    fn layoutFlexContainer(
        self: *LayoutEngine,
        id: LayoutId,
        available: Size(AvailableSpace),
        container_width: ?Pixels,
        container_height: ?Pixels,
        padding_border: Edges(Pixels),
    ) Size(Pixels) {
        const node = &self.nodes.items[id];
        const s = &node.style;
        const children = node.children.items;

        if (children.len == 0) {
            return Size(Pixels).zero;
        }

        const is_row = s.flex_direction.isRow();
        const is_reverse = s.flex_direction.isReverse();

        // Available inner space
        const inner_width = if (container_width) |w| w - padding_border.horizontal() else available.width.unwrapOr(std.math.floatMax(f32));
        const inner_height = if (container_height) |h| h - padding_border.vertical() else available.height.unwrapOr(std.math.floatMax(f32));

        const inner_main = if (is_row) inner_width else inner_height;
        const inner_cross = if (is_row) inner_height else inner_width;

        // Resolve gap
        const gap_width = self.resolveLength(s.gap.width, container_width) orelse 0;
        const gap_height = self.resolveLength(s.gap.height, container_height) orelse 0;
        const main_gap = if (is_row) gap_width else gap_height;
        const cross_gap = if (is_row) gap_height else gap_width;
        _ = cross_gap; // TODO: use for wrap

        // First pass: compute child sizes and collect flex info
        var total_main: Pixels = 0;
        var total_flex_grow: f32 = 0;
        var total_flex_shrink: f32 = 0;
        var max_cross: Pixels = 0;

        // Compute base sizes for all children
        for (children) |child_id| {
            const child = &self.nodes.items[child_id];
            const child_style = &child.style;

            if (child_style.display == .none) continue;

            // Determine child's available space
            const child_available = Size(AvailableSpace){
                .width = if (is_row) .max_content else .{ .definite = inner_width },
                .height = if (is_row) .{ .definite = inner_height } else .max_content,
            };

            self.computeNodeLayout(child_id, child_available, Size(Pixels){ .width = inner_width, .height = inner_height });

            const child_main = if (is_row) child.size.width else child.size.height;
            const child_cross = if (is_row) child.size.height else child.size.width;

            total_main += child_main;
            total_flex_grow += child_style.flex_grow;
            total_flex_shrink += child_style.flex_shrink;
            max_cross = @max(max_cross, child_cross);
        }

        // Add gaps
        const num_gaps = if (children.len > 1) children.len - 1 else 0;
        total_main += main_gap * @as(f32, @floatFromInt(num_gaps));

        // Calculate free space and distribute
        const free_space = inner_main - total_main;

        // Second pass: apply flex grow/shrink and position children
        var main_pos: Pixels = padding_border.left;
        if (!is_row) main_pos = padding_border.top;

        // Apply justify-content for initial offset
        const justify = s.justify_content orelse .flex_start;
        const child_count = children.len;

        if (free_space > 0 and total_flex_grow == 0) {
            // No flex grow, apply justify-content
            switch (justify) {
                .flex_start => {},
                .flex_end => main_pos += free_space,
                .center => main_pos += free_space / 2,
                .space_between => {}, // Handled in gap
                .space_around => main_pos += free_space / @as(f32, @floatFromInt(child_count * 2)),
                .space_evenly => main_pos += free_space / @as(f32, @floatFromInt(child_count + 1)),
            }
        }

        // Calculate gap for space-between/around/evenly
        var effective_gap = main_gap;
        if (free_space > 0 and total_flex_grow == 0 and child_count > 1) {
            switch (justify) {
                .space_between => effective_gap = main_gap + free_space / @as(f32, @floatFromInt(child_count - 1)),
                .space_around => effective_gap = main_gap + free_space / @as(f32, @floatFromInt(child_count)),
                .space_evenly => effective_gap = main_gap + free_space / @as(f32, @floatFromInt(child_count + 1)),
                else => {},
            }
        }

        const align_items = s.align_items orelse .stretch;

        var i: usize = 0;
        const order = if (is_reverse) blk: {
            var reversed: [256]usize = undefined;
            var j: usize = 0;
            while (j < @min(children.len, 256)) : (j += 1) {
                reversed[j] = children.len - 1 - j;
            }
            break :blk reversed[0..@min(children.len, 256)];
        } else blk: {
            var forward: [256]usize = undefined;
            var j: usize = 0;
            while (j < @min(children.len, 256)) : (j += 1) {
                forward[j] = j;
            }
            break :blk forward[0..@min(children.len, 256)];
        };

        for (order) |idx| {
            if (idx >= children.len) break;
            const child_id = children[idx];
            var child = &self.nodes.items[child_id];
            const child_style = &child.style;

            if (child_style.display == .none) continue;

            var child_main = if (is_row) child.size.width else child.size.height;
            var child_cross = if (is_row) child.size.height else child.size.width;

            // Apply flex grow/shrink
            if (free_space > 0 and total_flex_grow > 0 and child_style.flex_grow > 0) {
                child_main += free_space * (child_style.flex_grow / total_flex_grow);
            } else if (free_space < 0 and total_flex_shrink > 0 and child_style.flex_shrink > 0) {
                child_main += free_space * (child_style.flex_shrink / total_flex_shrink);
            }

            // Handle stretch for cross axis
            if (align_items == .stretch and child_style.align_self != .flex_start and
                child_style.align_self != .flex_end and child_style.align_self != .center)
            {
                child_cross = inner_cross;
            }

            // Update child size
            if (is_row) {
                child.size.width = child_main;
                child.size.height = child_cross;
            } else {
                child.size.height = child_main;
                child.size.width = child_cross;
            }

            // Calculate cross position based on alignment
            var cross_pos: Pixels = if (is_row) padding_border.top else padding_border.left;
            const self_align = child_style.align_self orelse (if (s.align_items) |a| switch (a) {
                .flex_start => AlignSelf.flex_start,
                .flex_end => AlignSelf.flex_end,
                .center => AlignSelf.center,
                .stretch => AlignSelf.stretch,
                .baseline => AlignSelf.baseline,
            } else AlignSelf.stretch);

            switch (self_align) {
                .auto, .stretch => {},
                .flex_start => {},
                .flex_end => cross_pos += inner_cross - child_cross,
                .center => cross_pos += (inner_cross - child_cross) / 2,
                .baseline => {}, // TODO: proper baseline alignment
            }

            // Set child location
            if (is_row) {
                child.location = Point(Pixels).init(main_pos, cross_pos);
            } else {
                child.location = Point(Pixels).init(cross_pos, main_pos);
            }

            main_pos += child_main;
            if (i < children.len - 1) {
                main_pos += effective_gap;
            }
            i += 1;
        }

        // Return content size
        const content_main = main_pos - (if (is_row) padding_border.left else padding_border.top);
        if (is_row) {
            return Size(Pixels){ .width = content_main, .height = max_cross };
        } else {
            return Size(Pixels){ .width = max_cross, .height = content_main };
        }
    }

    fn resolveLength(self: *const LayoutEngine, len: Length, parent_size: ?Pixels) ?Pixels {
        _ = self;
        return len.resolve(parent_size, DEFAULT_REM_SIZE);
    }

    fn resolveEdges(self: *const LayoutEngine, edges: Edges(Length), parent_size: ?Size(Pixels)) Edges(Pixels) {
        const parent_width = if (parent_size) |ps| ps.width else null;
        const parent_height = if (parent_size) |ps| ps.height else null;
        return Edges(Pixels){
            .top = self.resolveLength(edges.top, parent_height) orelse 0,
            .right = self.resolveLength(edges.right, parent_width) orelse 0,
            .bottom = self.resolveLength(edges.bottom, parent_height) orelse 0,
            .left = self.resolveLength(edges.left, parent_width) orelse 0,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "basic layout - single node with fixed size" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const node = try engine.createNode(.{
        .size = .{ .width = .{ .px = 100 }, .height = .{ .px = 50 } },
    }, &.{});

    engine.computeLayout(node, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const layout = engine.getLayout(node);
    try std.testing.expectEqual(@as(Pixels, 100), layout.size.width);
    try std.testing.expectEqual(@as(Pixels, 50), layout.size.height);
}

test "flexbox row - basic" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child1 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const child2 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{ child1, child2 });

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c1_layout = engine.getLayout(child1);
    const c2_layout = engine.getLayout(child2);

    try std.testing.expectEqual(@as(Pixels, 0), c1_layout.origin.x);
    try std.testing.expectEqual(@as(Pixels, 50), c2_layout.origin.x);
}

test "flexbox column - basic" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child1 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const child2 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .column,
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{ child1, child2 });

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c1_layout = engine.getLayout(child1);
    const c2_layout = engine.getLayout(child2);

    try std.testing.expectEqual(@as(Pixels, 0), c1_layout.origin.y);
    try std.testing.expectEqual(@as(Pixels, 30), c2_layout.origin.y);
}

test "flexbox - flex grow" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child1 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
        .flex_grow = 1,
    }, &.{});

    const child2 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
        .flex_grow = 1,
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{ child1, child2 });

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c1_layout = engine.getLayout(child1);
    const c2_layout = engine.getLayout(child2);

    // Each should grow to take half of 200 = 100
    try std.testing.expectEqual(@as(Pixels, 100), c1_layout.size.width);
    try std.testing.expectEqual(@as(Pixels, 100), c2_layout.size.width);
}

test "flexbox - justify center" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .justify_content = .center,
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{child});

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c_layout = engine.getLayout(child);

    // Child should be centered: (200 - 50) / 2 = 75
    try std.testing.expectEqual(@as(Pixels, 75), c_layout.origin.x);
}

test "flexbox - align items center" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .align_items = .center,
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{child});

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c_layout = engine.getLayout(child);

    // Child should be vertically centered: (100 - 30) / 2 = 35
    try std.testing.expectEqual(@as(Pixels, 35), c_layout.origin.y);
}

test "flexbox - padding" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .padding = .{ .top = .{ .px = 10 }, .right = .{ .px = 10 }, .bottom = .{ .px = 10 }, .left = .{ .px = 20 } },
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{child});

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c_layout = engine.getLayout(child);

    // Child should start after left padding
    try std.testing.expectEqual(@as(Pixels, 20), c_layout.origin.x);
    try std.testing.expectEqual(@as(Pixels, 10), c_layout.origin.y);
}

test "flexbox - gap" {
    const allocator = std.testing.allocator;
    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    const child1 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const child2 = try engine.createNode(.{
        .size = .{ .width = .{ .px = 50 }, .height = .{ .px = 30 } },
    }, &.{});

    const container = try engine.createNode(.{
        .flex_direction = .row,
        .gap = .{ .width = .{ .px = 10 }, .height = .{ .px = 0 } },
        .size = .{ .width = .{ .px = 200 }, .height = .{ .px = 100 } },
    }, &.{ child1, child2 });

    engine.computeLayout(container, .{ .width = .{ .definite = 800 }, .height = .{ .definite = 600 } });

    const c1_layout = engine.getLayout(child1);
    const c2_layout = engine.getLayout(child2);

    try std.testing.expectEqual(@as(Pixels, 0), c1_layout.origin.x);
    // Second child should be at 50 (first width) + 10 (gap) = 60
    try std.testing.expectEqual(@as(Pixels, 60), c2_layout.origin.x);
}

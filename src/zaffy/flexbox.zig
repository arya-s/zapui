//! Flexbox layout algorithm
//!
//! Zig port of taffy/src/compute/flexbox.rs
//! Implements the CSS Flexbox layout algorithm according to the spec:
//! https://www.w3.org/TR/css-flexbox-1/

const std = @import("std");
const geo = @import("geometry.zig");
const style_mod = @import("style.zig");
const tree_mod = @import("tree.zig");

const Point = geo.Point;
const Size = geo.Size;
const Rect = geo.Rect;
const Line = geo.Line;
const AvailableSpace = geo.AvailableSpace;
const FlexDirection = geo.FlexDirection;
const AbsoluteAxis = geo.AbsoluteAxis;

const Style = style_mod.Style;
const LengthPercentage = style_mod.LengthPercentage;
const LengthPercentageAuto = style_mod.LengthPercentageAuto;
const Dimension = style_mod.Dimension;
const AlignItems = style_mod.AlignItems;
const AlignSelf = style_mod.AlignSelf;
const AlignContent = style_mod.AlignContent;
const JustifyContent = style_mod.JustifyContent;
const FlexWrap = style_mod.FlexWrap;

const NodeId = tree_mod.NodeId;
const Layout = tree_mod.Layout;
const LayoutInput = tree_mod.LayoutInput;
const LayoutOutput = tree_mod.LayoutOutput;
const RunMode = tree_mod.RunMode;
const SizingMode = tree_mod.SizingMode;

// ============================================================================
// Flex Item
// ============================================================================

/// Intermediate results for a single flex item
const FlexItem = struct {
    node: NodeId,
    order: u32,

    // Style properties
    size: Size(?f32),
    min_size: Size(?f32),
    max_size: Size(?f32),
    align_self: AlignSelf,
    flex_shrink: f32,
    flex_grow: f32,
    flex_basis: f32,

    // Spacing
    margin: Rect(f32),
    margin_is_auto: Rect(bool),
    padding: Rect(f32),
    border: Rect(f32),
    padding_border: Rect(f32),

    // Computed values
    inner_flex_basis: f32,
    hypothetical_inner_size: Size(f32),
    hypothetical_outer_size: Size(f32),
    target_size: Size(f32),
    outer_target_size: Size(f32),
    content_flex_fraction: f32,
    resolved_minimum_main_size: f32,

    // State
    violation: f32,
    frozen: bool,

    // Position
    offset_main: f32,
    offset_cross: f32,
    baseline: f32,

    fn paddingBorderSum(self: *const FlexItem, axis: AbsoluteAxis) f32 {
        return switch (axis) {
            .horizontal => self.padding_border.horizontal(),
            .vertical => self.padding_border.vertical(),
        };
    }

    fn marginSum(self: *const FlexItem, axis: AbsoluteAxis) f32 {
        return switch (axis) {
            .horizontal => self.margin.horizontal(),
            .vertical => self.margin.vertical(),
        };
    }
};

/// A line of flex items
const FlexLine = struct {
    items: []FlexItem,
    cross_size: f32,
    offset_cross: f32,
};

// ============================================================================
// Main computation function
// ============================================================================

/// Compute flexbox layout for a node
pub fn computeFlexboxLayout(
    tree: anytype,
    node: NodeId,
    inputs: LayoutInput,
) LayoutOutput {
    const style = tree.getStyle(node);

    // Handle hidden nodes
    if (inputs.run_mode == .perform_hidden_layout or style.display == .none) {
        return computeHiddenLayout(tree, node);
    }

    const dir = style.flex_direction;
    const is_row = dir.isRow();
    const is_wrap_reverse = style.flex_wrap == .wrap_reverse;

    // For percentage resolution, use parent_size if available, otherwise fall back to available_space
    // This handles the root node case where parent_size is null but available_space is definite
    const parent_size_for_resolution = Size(?f32){
        .width = inputs.parent_size.width orelse inputs.available_space.width.intoOption(),
        .height = inputs.parent_size.height orelse inputs.available_space.height.intoOption(),
    };

    // Get container dimensions - resolve own style size first
    const style_size = resolveSize(style.size, parent_size_for_resolution);
    const known_dimensions = Size(?f32){
        .width = inputs.known_dimensions.width orelse style_size.width,
        .height = inputs.known_dimensions.height orelse style_size.height,
    };
    const parent_size = parent_size_for_resolution;
    const available_space = inputs.available_space;

    // Resolve padding and border
    const padding = resolveRect(style.padding, parent_size);
    const border = resolveRect(style.border, parent_size);
    const padding_border = padding.add(border);
    const content_box_inset = padding_border;

    // Determine container size constraints
    const min_size = resolveSize(style.min_size, parent_size);
    const max_size = resolveSize(style.max_size, parent_size);

    // Get available space for content
    const available_content_width = availableSpaceFromKnown(
        known_dimensions.width,
        available_space.width,
    ).maybeSub(content_box_inset.horizontal());

    const available_content_height = availableSpaceFromKnown(
        known_dimensions.height,
        available_space.height,
    ).maybeSub(content_box_inset.vertical());

    const available_content_space = Size(AvailableSpace){
        .width = available_content_width,
        .height = available_content_height,
    };

    // ========================================================================
    // Step 1: Generate flex items
    // ========================================================================

    const child_count = tree.childCount(node);
    if (child_count == 0) {
        // No children - compute container size
        const size = computeContainerSize(
            style,
            known_dimensions,
            parent_size,
            available_space,
            padding_border,
            min_size,
            max_size,
            Size(f32).ZERO,
        );
        // Set the node's own layout
        tree.setLayout(node, Layout{
            .size = size,
            .padding = padding,
            .border = border,
        });
        return LayoutOutput.fromOuterSize(size);
    }

    // Allocate flex items
    var items_buf: [256]FlexItem = undefined;
    const items = items_buf[0..@min(child_count, 256)];

    var absolute_count: usize = 0;
    var flex_item_count: usize = 0;

    // Populate flex items
    var child_idx: usize = 0;
    while (child_idx < child_count) : (child_idx += 1) {
        const child_id = tree.getChildId(node, child_idx);
        const child_style = tree.getStyle(child_id);

        if (child_style.display == .none) {
            continue;
        }

        if (child_style.position == .absolute) {
            absolute_count += 1;
            continue;
        }

        if (flex_item_count >= items.len) {
            break;
        }

        const item = &items[flex_item_count];
        item.* = createFlexItem(
            child_id,
            child_style,
            @intCast(child_idx),
            dir,
            parent_size,
            available_content_space,
        );

        flex_item_count += 1;
    }

    const flex_items = items[0..flex_item_count];

    // ========================================================================
    // Step 2: Determine flex base size and hypothetical main size
    // ========================================================================

    for (flex_items) |*item| {
        // Compute hypothetical main size
        const child_min = item.min_size.main(dir);
        const child_max = item.max_size.main(dir);

        // Determine flex basis - if auto and no size, measure content
        var hypothetical_inner_main = item.flex_basis;

        // If flex_basis is 0 and item has children, compute its intrinsic size
        // This is needed even for items with flex_grow when the container has auto size
        if (hypothetical_inner_main == 0 and item.size.main(dir) == null) {
            const child_style = tree.getStyle(item.node);
            if (child_style.display == .flex and tree.childCount(item.node) > 0) {
                // Compute child's intrinsic size
                // Pass the available main space to allow proper content sizing
                const available_main = available_content_space.main(dir);
                const measure_inputs = LayoutInput{
                    .run_mode = .compute_size,
                    .sizing_mode = .content_size,
                    .axis = .both,
                    .known_dimensions = .{ .width = null, .height = null },
                    .parent_size = parent_size,
                    .available_space = if (dir == .column or dir == .column_reverse)
                        .{ .width = available_content_space.width, .height = available_main }
                    else
                        .{ .width = available_main, .height = available_content_space.height },
                };
                const measured = computeFlexboxLayout(tree, item.node, measure_inputs);
                hypothetical_inner_main = measured.size.main(dir);
            }
        }

        // Apply min/max constraints
        if (child_min) |min_val| {
            hypothetical_inner_main = @max(hypothetical_inner_main, min_val);
        }
        if (child_max) |max_val| {
            hypothetical_inner_main = @min(hypothetical_inner_main, max_val);
        }

        item.hypothetical_inner_size.setMain(dir, hypothetical_inner_main);
        item.hypothetical_outer_size.setMain(dir, hypothetical_inner_main + item.marginSum(dir.mainAxis()) + item.paddingBorderSum(dir.mainAxis()));

        // Cross size - use style size or compute intrinsic if needed
        var cross_size = item.size.cross(dir) orelse 0;
        if (cross_size == 0 and tree.childCount(item.node) > 0) {
            const child_style = tree.getStyle(item.node);
            if (child_style.display == .flex) {
                // When measuring cross size, pass the available cross space from parent
                // This allows percentage widths and justify-center to work correctly
                const available_cross = available_content_space.cross(dir);
                const measure_inputs = LayoutInput{
                    .run_mode = .compute_size,
                    .sizing_mode = .content_size,
                    .axis = .both,
                    .known_dimensions = .{ .width = null, .height = null },
                    .parent_size = parent_size,
                    .available_space = if (dir == .column or dir == .column_reverse)
                        .{ .width = available_cross, .height = .max_content }
                    else
                        .{ .width = .max_content, .height = available_cross },
                };
                const measured = computeFlexboxLayout(tree, item.node, measure_inputs);
                cross_size = measured.size.cross(dir);
            }
        }
        item.hypothetical_inner_size.setCross(dir, cross_size);
        item.hypothetical_outer_size.setCross(dir, cross_size + item.marginSum(dir.crossAxis()) + item.paddingBorderSum(dir.crossAxis()));
    }

    // ========================================================================
    // Step 3: Collect flex items into lines
    // ========================================================================

    var lines_buf: [64]FlexLine = undefined;
    var line_count: usize = 0;

    const container_main_size = available_content_space.main(dir).unwrapOr(std.math.floatMax(f32));

    if (style.flex_wrap == .no_wrap or flex_item_count == 0) {
        // Single line
        if (line_count < lines_buf.len) {
            lines_buf[line_count] = .{
                .items = flex_items,
                .cross_size = 0,
                .offset_cross = 0,
            };
            line_count += 1;
        }
    } else {
        // Multiple lines - collect into lines based on available space
        var line_start: usize = 0;
        var line_main_size: f32 = 0;

        for (flex_items, 0..) |*item, i| {
            const outer_main = item.hypothetical_outer_size.main(dir);

            if (line_main_size + outer_main > container_main_size and i > line_start) {
                // Start new line
                if (line_count < lines_buf.len) {
                    lines_buf[line_count] = .{
                        .items = flex_items[line_start..i],
                        .cross_size = 0,
                        .offset_cross = 0,
                    };
                    line_count += 1;
                }
                line_start = i;
                line_main_size = 0;
            }

            line_main_size += outer_main;
        }

        // Add remaining items to last line
        if (line_start < flex_item_count and line_count < lines_buf.len) {
            lines_buf[line_count] = .{
                .items = flex_items[line_start..],
                .cross_size = 0,
                .offset_cross = 0,
            };
            line_count += 1;
        }
    }

    const lines = lines_buf[0..line_count];

    // ========================================================================
    // Step 4: Resolve flexible lengths (flex grow/shrink)
    // ========================================================================

    // Calculate gap for main axis
    const gap_main_resolved = style.gap.main(dir).resolveOrZero(known_dimensions.main(dir));

    for (lines) |*line| {
        // Calculate total hypothetical main size
        var total_hypothetical_main: f32 = 0;
        var total_flex_grow: f32 = 0;
        var total_flex_shrink: f32 = 0;

        for (line.items) |item| {
            total_hypothetical_main += item.hypothetical_outer_size.main(dir);
            total_flex_grow += item.flex_grow;
            total_flex_shrink += item.flex_shrink;
        }

        // Account for gaps between items
        const num_gaps: f32 = if (line.items.len > 1) @floatFromInt(line.items.len - 1) else 0;
        total_hypothetical_main += gap_main_resolved * num_gaps;

        const free_space = container_main_size - total_hypothetical_main;



        // Resolve flexible lengths
        if (free_space > 0 and total_flex_grow > 0) {
            // Flex grow
            for (line.items) |*item| {
                if (item.flex_grow > 0) {
                    const grow_ratio = item.flex_grow / total_flex_grow;
                    const extra = free_space * grow_ratio;
                    item.target_size.setMain(dir, item.hypothetical_inner_size.main(dir) + extra);
                } else {
                    item.target_size.setMain(dir, item.hypothetical_inner_size.main(dir));
                }
                item.outer_target_size.setMain(dir, item.target_size.main(dir) + item.marginSum(dir.mainAxis()) + item.paddingBorderSum(dir.mainAxis()));
            }
        } else if (free_space < 0 and total_flex_shrink > 0) {
            // Flex shrink
            var total_shrink_scaled: f32 = 0;
            for (line.items) |item| {
                total_shrink_scaled += item.flex_shrink * item.hypothetical_inner_size.main(dir);
            }

            if (total_shrink_scaled > 0) {
                for (line.items) |*item| {
                    const shrink_ratio = (item.flex_shrink * item.hypothetical_inner_size.main(dir)) / total_shrink_scaled;
                    const shrink = (-free_space) * shrink_ratio;
                    const new_main = @max(0, item.hypothetical_inner_size.main(dir) - shrink);
                    item.target_size.setMain(dir, new_main);
                    item.outer_target_size.setMain(dir, new_main + item.marginSum(dir.mainAxis()) + item.paddingBorderSum(dir.mainAxis()));
                }
            }
        } else {
            // No flex
            for (line.items) |*item| {
                item.target_size.setMain(dir, item.hypothetical_inner_size.main(dir));
                item.outer_target_size.setMain(dir, item.hypothetical_outer_size.main(dir));
            }
        }
    }

    // ========================================================================
    // Step 5: Determine cross size of each line
    // ========================================================================

    // For compute_size mode, always compute intrinsic cross size
    // For perform_layout mode, use available cross space if definite
    const inner_container_cross_size = if (inputs.run_mode == .compute_size)
        known_dimensions.cross(dir) // Only use explicit size, not available space
    else
        known_dimensions.cross(dir) orelse available_content_space.cross(dir).intoOption();

    const container_cross_size = inner_container_cross_size orelse blk: {
        var max_cross: f32 = 0;
        for (lines) |line| {
            var line_cross: f32 = 0;
            for (line.items) |item| {
                line_cross = @max(line_cross, item.hypothetical_outer_size.cross(dir));
            }
            max_cross += line_cross;
        }
        break :blk max_cross;
    };

    // Distribute cross size to lines
    if (lines.len > 0) {
        if (inner_container_cross_size != null) {
            // Container has definite cross size - distribute equally
            const cross_per_line = container_cross_size / @as(f32, @floatFromInt(lines.len));
            for (lines) |*line| {
                line.cross_size = cross_per_line;
            }
        } else {
            // Container has auto cross size - each line uses its intrinsic size
            for (lines) |*line| {
                var line_cross: f32 = 0;
                for (line.items) |item| {
                    line_cross = @max(line_cross, item.hypothetical_outer_size.cross(dir));
                }
                line.cross_size = line_cross;
            }
        }
    }

    // ========================================================================
    // Step 6: Determine cross size of flex items
    // ========================================================================

    for (lines) |*line| {
        for (line.items) |*item| {
            const item_align = if (item.align_self == .auto) style.getAlignItems().toAlignSelf() else item.align_self;

            if (item_align == .stretch and item.size.cross(dir) == null) {
                // Stretch to fill line
                const cross = @max(0, line.cross_size - item.marginSum(dir.crossAxis()) - item.paddingBorderSum(dir.crossAxis()));
                item.target_size.setCross(dir, cross);
            } else {
                item.target_size.setCross(dir, item.hypothetical_inner_size.cross(dir));
            }
            item.outer_target_size.setCross(dir, item.target_size.cross(dir) + item.marginSum(dir.crossAxis()) + item.paddingBorderSum(dir.crossAxis()));
        }
    }

    // ========================================================================
    // Step 7: Main-axis alignment (justify-content)
    // ========================================================================

    const justify = style.getJustifyContent();
    const gap_main = style.gap.main(dir).resolveOrZero(inner_container_cross_size);

    for (lines) |*line| {
        var total_main: f32 = 0;
        for (line.items) |item| {
            total_main += item.outer_target_size.main(dir);
        }

        const item_count = line.items.len;
        const num_gaps: f32 = if (item_count > 1) @floatFromInt(item_count - 1) else 0;
        total_main += gap_main * num_gaps;

        const free_space_main = @max(0, container_main_size - total_main);
        const num_auto_margins = countAutoMargins(line.items, dir);

        var offset_main: f32 = 0;
        var gap_between: f32 = gap_main;

        if (num_auto_margins > 0) {
            // Auto margins absorb free space
            gap_between = gap_main;
        } else {
            switch (justify) {
                .flex_start => {},
                .flex_end => offset_main = free_space_main,
                .center => offset_main = free_space_main / 2,
                .space_between => {
                    if (item_count > 1) {
                        gap_between = gap_main + free_space_main / @as(f32, @floatFromInt(item_count - 1));
                    }
                },
                .space_around => {
                    gap_between = gap_main + free_space_main / @as(f32, @floatFromInt(item_count));
                    offset_main = (free_space_main / @as(f32, @floatFromInt(item_count))) / 2;
                },
                .space_evenly => {
                    gap_between = gap_main + free_space_main / @as(f32, @floatFromInt(item_count + 1));
                    offset_main = gap_between - gap_main;
                },
            }
        }

        // Apply positions
        var pos_main = offset_main;
        for (line.items, 0..) |*item, i| {
            item.offset_main = pos_main + item.margin.mainStart(dir);
            pos_main += item.outer_target_size.main(dir);
            if (i < item_count - 1) {
                pos_main += gap_between;
            }
        }
    }

    // ========================================================================
    // Step 8: Cross-axis alignment (align-items/align-self)
    // ========================================================================

    const gap_cross = style.gap.cross(dir).resolveOrZero(inner_container_cross_size);
    var offset_cross: f32 = 0;

    for (lines) |*line| {
        line.offset_cross = offset_cross;

        for (line.items) |*item| {
            const cross_align = if (item.align_self == .auto) style.getAlignItems().toAlignSelf() else item.align_self;

            const item_cross = item.outer_target_size.cross(dir);
            const free_cross = line.cross_size - item_cross;

            item.offset_cross = switch (cross_align) {
                .auto, .stretch, .flex_start => item.margin.crossStart(dir),
                .flex_end => free_cross + item.margin.crossStart(dir),
                .center => (free_cross / 2) + item.margin.crossStart(dir),
                .baseline => item.margin.crossStart(dir), // TODO: proper baseline
            };
        }

        offset_cross += line.cross_size + gap_cross;
    }

    // Handle wrap-reverse
    if (is_wrap_reverse and lines.len > 1) {
        const total_cross = offset_cross - gap_cross;
        for (lines) |*line| {
            line.offset_cross = total_cross - line.offset_cross - line.cross_size;
        }
    }

    // ========================================================================
    // Step 9: Final layout
    // ========================================================================

    // Calculate final container size
    var max_main: f32 = 0;
    var total_cross: f32 = 0;

    for (lines) |line| {
        var line_main: f32 = 0;
        for (line.items) |item| {
            line_main = @max(line_main, item.offset_main + item.target_size.main(dir) + item.paddingBorderSum(dir.mainAxis()) + item.margin.mainEnd(dir));
        }
        max_main = @max(max_main, line_main);
        total_cross += line.cross_size;
    }

    if (lines.len > 1) {
        total_cross += gap_cross * @as(f32, @floatFromInt(lines.len - 1));
    }

    const content_size = if (is_row)
        Size(f32){ .width = max_main, .height = total_cross }
    else
        Size(f32){ .width = total_cross, .height = max_main };

    const container_size = computeContainerSize(
        style,
        known_dimensions,
        parent_size,
        available_space,
        padding_border,
        min_size,
        max_size,
        content_size,
    );

    // Perform child layout if needed
    if (inputs.run_mode == .perform_layout) {
        for (lines) |line| {
            for (line.items) |item| {
                const x = if (is_row)
                    content_box_inset.left + item.offset_main
                else
                    content_box_inset.left + line.offset_cross + item.offset_cross;

                const y = if (is_row)
                    content_box_inset.top + line.offset_cross + item.offset_cross
                else
                    content_box_inset.top + item.offset_main;

                // Recursively compute layout for child
                const child_inputs = LayoutInput{
                    .run_mode = .perform_layout,
                    .sizing_mode = .inherent_size,
                    .axis = .both,
                    .known_dimensions = .{ .width = item.target_size.width, .height = item.target_size.height },
                    .parent_size = .{ .width = container_size.width, .height = container_size.height },
                    .available_space = .{
                        .width = .{ .definite = item.target_size.width },
                        .height = .{ .definite = item.target_size.height },
                    },
                };
                _ = computeFlexboxLayout(tree, item.node, child_inputs);

                // Now set the location (child layout computed its own size but location is determined by parent)
                var child_layout = tree.getLayout(item.node).*;
                child_layout.order = item.order;
                child_layout.location = Point(f32).init(x, y);
                child_layout.padding = item.padding;
                child_layout.border = item.border;
                child_layout.margin = item.margin;

                tree.setLayout(item.node, child_layout);
            }
        }

        // Layout absolute children
        if (absolute_count > 0) {
            layoutAbsoluteChildren(tree, node, container_size, padding_border);
        }
    }

    // Set this node's own layout
    tree.setLayout(node, Layout{
        .size = container_size,
        .padding = padding,
        .border = border,
    });

    return LayoutOutput{
        .size = container_size,
        .content_size = content_size,
    };
}

// ============================================================================
// Helper functions
// ============================================================================

fn createFlexItem(
    node: NodeId,
    style: *const Style,
    order: u32,
    dir: FlexDirection,
    parent_size: Size(?f32),
    available_content_space: Size(AvailableSpace),
) FlexItem {
    // For percentage resolution, prefer available_content_space (the container's content area)
    // Fall back to parent_size for cases where available space is not definite
    const size_for_resolution = Size(?f32){
        .width = available_content_space.width.intoOption() orelse parent_size.width,
        .height = available_content_space.height.intoOption() orelse parent_size.height,
    };
    
    const padding = resolveRect(style.padding, size_for_resolution);
    const border = resolveRect(style.border, size_for_resolution);
    const margin = resolveRectAuto(style.margin, size_for_resolution);
    const padding_border = padding.add(border);

    // Determine flex basis
    // Note: style.size is content-box, so when flex_basis comes from style.size,
    // it's already the inner/content size (no need to subtract padding)
    var flex_basis: f32 = 0;
    var flex_basis_is_content_box = false;
    switch (style.flex_basis) {
        .length => |v| {
            flex_basis = v;
            flex_basis_is_content_box = false; // explicit value includes padding
        },
        .percent => |p| {
            flex_basis = if (size_for_resolution.main(dir)) |ps| ps * p else 0;
            flex_basis_is_content_box = false;
        },
        .auto => {
            flex_basis = style.size.main(dir).resolve(size_for_resolution.main(dir)) orelse 0;
            flex_basis_is_content_box = true; // style.size is content-box
        },
    }

    // Only subtract padding if flex_basis is NOT from content-box style.size
    const inner_flex_basis = if (flex_basis_is_content_box)
        flex_basis // Already content size
    else
        @max(0, flex_basis - padding_border.mainAxisSum(dir));

    return FlexItem{
        .node = node,
        .order = order,
        .size = resolveSize(style.size, size_for_resolution),
        .min_size = resolveSize(style.min_size, size_for_resolution),
        .max_size = resolveSize(style.max_size, size_for_resolution),
        .align_self = style.align_self orelse .auto,
        .flex_shrink = style.flex_shrink,
        .flex_grow = style.flex_grow,
        .flex_basis = flex_basis,
        .margin = margin,
        .margin_is_auto = .{
            .left = style.margin.left == .auto,
            .right = style.margin.right == .auto,
            .top = style.margin.top == .auto,
            .bottom = style.margin.bottom == .auto,
        },
        .padding = padding,
        .border = border,
        .padding_border = padding_border,
        .inner_flex_basis = inner_flex_basis,
        .hypothetical_inner_size = Size(f32).ZERO,
        .hypothetical_outer_size = Size(f32).ZERO,
        .target_size = Size(f32).ZERO,
        .outer_target_size = Size(f32).ZERO,
        .content_flex_fraction = 0,
        .resolved_minimum_main_size = 0,
        .violation = 0,
        .frozen = false,
        .offset_main = 0,
        .offset_cross = 0,
        .baseline = 0,
    };
}

fn computeHiddenLayout(tree: anytype, node: NodeId) LayoutOutput {
    // Recursively hide all children
    const child_count = tree.childCount(node);
    var i: usize = 0;
    while (i < child_count) : (i += 1) {
        const child = tree.getChildId(node, i);
        tree.setLayout(child, Layout.ZERO);
        _ = computeHiddenLayout(tree, child);
    }
    return LayoutOutput.HIDDEN;
}

fn computeContainerSize(
    _: *const Style,
    known_dimensions: Size(?f32),
    _: Size(?f32),
    _: Size(AvailableSpace),
    padding_border: Rect(f32),
    min_size: Size(?f32),
    max_size: Size(?f32),
    content_size: Size(f32),
) Size(f32) {

    var width = known_dimensions.width orelse (content_size.width + padding_border.horizontal());
    var height = known_dimensions.height orelse (content_size.height + padding_border.vertical());

    // Apply min/max
    if (min_size.width) |min_w| width = @max(width, min_w);
    if (min_size.height) |min_h| height = @max(height, min_h);
    if (max_size.width) |max_w| width = @min(width, max_w);
    if (max_size.height) |max_h| height = @min(height, max_h);

    return Size(f32){ .width = width, .height = height };
}

fn layoutAbsoluteChildren(
    tree: anytype,
    node: NodeId,
    container_size: Size(f32),
    padding_border: Rect(f32),
) void {
    const child_count = tree.childCount(node);
    var i: usize = 0;
    while (i < child_count) : (i += 1) {
        const child = tree.getChildId(node, i);
        const child_style = tree.getStyle(child);

        if (child_style.position != .absolute) {
            continue;
        }

        // Simple absolute positioning
        const inset = child_style.inset;
        const x = inset.left.resolve(container_size.width) orelse padding_border.left;
        const y = inset.top.resolve(container_size.height) orelse padding_border.top;

        const child_size = resolveSize(child_style.size, Size(?f32){ .width = container_size.width, .height = container_size.height });
        const w = child_size.width orelse 0;
        const h = child_size.height orelse 0;

        tree.setLayout(child, Layout{
            .location = Point(f32).init(x, y),
            .size = Size(f32).init(w, h),
        });
    }
}

fn resolveRect(rect: Rect(LengthPercentage), parent_size: Size(?f32)) Rect(f32) {
    return Rect(f32){
        .left = rect.left.resolveOrZero(parent_size.width),
        .right = rect.right.resolveOrZero(parent_size.width),
        .top = rect.top.resolveOrZero(parent_size.height),
        .bottom = rect.bottom.resolveOrZero(parent_size.height),
    };
}

fn resolveRectAuto(rect: Rect(LengthPercentageAuto), parent_size: Size(?f32)) Rect(f32) {
    return Rect(f32){
        .left = rect.left.resolveOrZero(parent_size.width),
        .right = rect.right.resolveOrZero(parent_size.width),
        .top = rect.top.resolveOrZero(parent_size.height),
        .bottom = rect.bottom.resolveOrZero(parent_size.height),
    };
}

fn resolveSize(size: Size(Dimension), parent_size: Size(?f32)) Size(?f32) {
    return Size(?f32){
        .width = size.width.resolve(parent_size.width),
        .height = size.height.resolve(parent_size.height),
    };
}

fn availableSpaceFromKnown(known: ?f32, available: AvailableSpace) AvailableSpace {
    if (known) |k| {
        return .{ .definite = k };
    }
    return available;
}

fn countAutoMargins(items: []FlexItem, dir: FlexDirection) usize {
    var count: usize = 0;
    for (items) |item| {
        if (dir.isRow()) {
            if (item.margin_is_auto.left) count += 1;
            if (item.margin_is_auto.right) count += 1;
        } else {
            if (item.margin_is_auto.top) count += 1;
            if (item.margin_is_auto.bottom) count += 1;
        }
    }
    return count;
}

// ============================================================================
// Tests
// ============================================================================

test "flexbox imports" {
    _ = geo;
    _ = style_mod;
    _ = tree_mod;
}

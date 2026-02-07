//! Div element - the fundamental container element for zapui.
//! Provides a fluent builder API for constructing styled containers.

const std = @import("std");
const geometry = @import("../geometry.zig");
const style_mod = @import("../style.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const scene_mod = @import("../scene.zig");
const element_mod = @import("../element.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Edges = geometry.Edges;
const Style = style_mod.Style;
const Length = style_mod.Length;
const Background = style_mod.Background;
const FlexDirection = style_mod.FlexDirection;
const AlignItems = style_mod.AlignItems;
const JustifyContent = style_mod.JustifyContent;
const Hsla = color_mod.Hsla;
const LayoutId = layout_mod.LayoutId;
const LayoutStyle = layout_mod.LayoutStyle;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;

/// Div element - a styled container
pub const Div = struct {
    const Self = @This();

    allocator: Allocator,
    style: Style = .{},
    children_list: std.ArrayListUnmanaged(AnyElement) = .{ .items = &.{}, .capacity = 0 },
    child_layout_ids: std.ArrayListUnmanaged(LayoutId) = .{ .items = &.{}, .capacity = 0 },

    /// Create a new Div
    pub fn init(allocator: Allocator) *Div {
        const d = allocator.create(Div) catch @panic("OOM");
        d.* = .{ .allocator = allocator };
        return d;
    }

    /// Clean up resources
    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.children_list.items) |*c| {
            c.deinit(allocator);
        }
        self.children_list.deinit(allocator);
        self.child_layout_ids.deinit(allocator);
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API - Display & Flex
    // ========================================================================

    pub fn flex(self: *Self) *Self {
        self.style.display = .flex;
        return self;
    }

    pub fn flexRow(self: *Self) *Self {
        self.style.flex_direction = .row;
        return self;
    }

    pub fn flexCol(self: *Self) *Self {
        self.style.flex_direction = .column;
        return self;
    }

    pub fn flexRowReverse(self: *Self) *Self {
        self.style.flex_direction = .row_reverse;
        return self;
    }

    pub fn flexColReverse(self: *Self) *Self {
        self.style.flex_direction = .column_reverse;
        return self;
    }

    pub fn flexGrow(self: *Self, value: f32) *Self {
        self.style.flex_grow = value;
        return self;
    }

    pub fn flexShrink(self: *Self, value: f32) *Self {
        self.style.flex_shrink = value;
        return self;
    }

    pub fn flexBasis(self: *Self, value: Length) *Self {
        self.style.flex_basis = value;
        return self;
    }

    pub fn grow(self: *Self) *Self {
        return self.flexGrow(1);
    }

    pub fn shrink(self: *Self) *Self {
        return self.flexShrink(1);
    }

    // ========================================================================
    // Alignment
    // ========================================================================

    pub fn justifyStart(self: *Self) *Self {
        self.style.justify_content = .flex_start;
        return self;
    }

    pub fn justifyEnd(self: *Self) *Self {
        self.style.justify_content = .flex_end;
        return self;
    }

    pub fn justifyCenter(self: *Self) *Self {
        self.style.justify_content = .center;
        return self;
    }

    pub fn justifyBetween(self: *Self) *Self {
        self.style.justify_content = .space_between;
        return self;
    }

    pub fn justifyAround(self: *Self) *Self {
        self.style.justify_content = .space_around;
        return self;
    }

    pub fn justifyEvenly(self: *Self) *Self {
        self.style.justify_content = .space_evenly;
        return self;
    }

    pub fn itemsStart(self: *Self) *Self {
        self.style.align_items = .flex_start;
        return self;
    }

    pub fn itemsEnd(self: *Self) *Self {
        self.style.align_items = .flex_end;
        return self;
    }

    pub fn itemsCenter(self: *Self) *Self {
        self.style.align_items = .center;
        return self;
    }

    pub fn itemsStretch(self: *Self) *Self {
        self.style.align_items = .stretch;
        return self;
    }

    // ========================================================================
    // Sizing
    // ========================================================================

    pub fn w(self: *Self, value: Length) *Self {
        self.style.size.width = value;
        return self;
    }

    pub fn h(self: *Self, value: Length) *Self {
        self.style.size.height = value;
        return self;
    }

    pub fn size(self: *Self, width: Length, height: Length) *Self {
        self.style.size.width = width;
        self.style.size.height = height;
        return self;
    }

    pub fn wFull(self: *Self) *Self {
        self.style.size.width = .{ .percent = 100.0 };
        return self;
    }

    pub fn hFull(self: *Self) *Self {
        self.style.size.height = .{ .percent = 100.0 };
        return self;
    }

    pub fn minW(self: *Self, value: Length) *Self {
        self.style.min_size.width = value;
        return self;
    }

    pub fn minH(self: *Self, value: Length) *Self {
        self.style.min_size.height = value;
        return self;
    }

    pub fn maxW(self: *Self, value: Length) *Self {
        self.style.max_size.width = value;
        return self;
    }

    pub fn maxH(self: *Self, value: Length) *Self {
        self.style.max_size.height = value;
        return self;
    }

    // ========================================================================
    // Spacing
    // ========================================================================

    pub fn p(self: *Self, value: Length) *Self {
        self.style.padding = Edges(Length).all(value);
        return self;
    }

    pub fn px(self: *Self, value: Length) *Self {
        self.style.padding.left = value;
        self.style.padding.right = value;
        return self;
    }

    pub fn py(self: *Self, value: Length) *Self {
        self.style.padding.top = value;
        self.style.padding.bottom = value;
        return self;
    }

    pub fn pt(self: *Self, value: Length) *Self {
        self.style.padding.top = value;
        return self;
    }

    pub fn pr(self: *Self, value: Length) *Self {
        self.style.padding.right = value;
        return self;
    }

    pub fn pb(self: *Self, value: Length) *Self {
        self.style.padding.bottom = value;
        return self;
    }

    pub fn pl(self: *Self, value: Length) *Self {
        self.style.padding.left = value;
        return self;
    }

    pub fn m(self: *Self, value: Length) *Self {
        self.style.margin = Edges(Length).all(value);
        return self;
    }

    pub fn mx(self: *Self, value: Length) *Self {
        self.style.margin.left = value;
        self.style.margin.right = value;
        return self;
    }

    pub fn my(self: *Self, value: Length) *Self {
        self.style.margin.top = value;
        self.style.margin.bottom = value;
        return self;
    }

    pub fn gap(self: *Self, value: Length) *Self {
        self.style.gap.width = value;
        self.style.gap.height = value;
        return self;
    }

    pub fn gapX(self: *Self, value: Length) *Self {
        self.style.gap.width = value;
        return self;
    }

    pub fn gapY(self: *Self, value: Length) *Self {
        self.style.gap.height = value;
        return self;
    }

    // ========================================================================
    // Tailwind-style spacing shortcuts (in rems)
    // ========================================================================

    pub fn p1(self: *Self) *Self { return self.p(.{ .rems = 0.25 }); }
    pub fn p2(self: *Self) *Self { return self.p(.{ .rems = 0.5 }); }
    pub fn p3(self: *Self) *Self { return self.p(.{ .rems = 0.75 }); }
    pub fn p4(self: *Self) *Self { return self.p(.{ .rems = 1.0 }); }
    pub fn p5(self: *Self) *Self { return self.p(.{ .rems = 1.25 }); }
    pub fn p6(self: *Self) *Self { return self.p(.{ .rems = 1.5 }); }
    pub fn p8(self: *Self) *Self { return self.p(.{ .rems = 2.0 }); }

    pub fn gap1(self: *Self) *Self { return self.gap(.{ .rems = 0.25 }); }
    pub fn gap2(self: *Self) *Self { return self.gap(.{ .rems = 0.5 }); }
    pub fn gap3(self: *Self) *Self { return self.gap(.{ .rems = 0.75 }); }
    pub fn gap4(self: *Self) *Self { return self.gap(.{ .rems = 1.0 }); }

    // ========================================================================
    // Background & Colors
    // ========================================================================

    pub fn bg(self: *Self, color: Hsla) *Self {
        self.style.background = .{ .solid = color };
        return self;
    }

    pub fn bgNone(self: *Self) *Self {
        self.style.background = null;
        return self;
    }

    // ========================================================================
    // Border
    // ========================================================================

    pub fn border(self: *Self, width: Pixels) *Self {
        self.style.border_widths = Edges(Pixels).all(width);
        return self;
    }

    pub fn border1(self: *Self) *Self {
        return self.border(1);
    }

    pub fn border2(self: *Self) *Self {
        return self.border(2);
    }

    pub fn borderColor(self: *Self, color: Hsla) *Self {
        self.style.border_color = color;
        return self;
    }

    pub fn borderT(self: *Self, width: Pixels) *Self {
        self.style.border_widths.top = width;
        return self;
    }

    pub fn borderR(self: *Self, width: Pixels) *Self {
        self.style.border_widths.right = width;
        return self;
    }

    pub fn borderB(self: *Self, width: Pixels) *Self {
        self.style.border_widths.bottom = width;
        return self;
    }

    pub fn borderL(self: *Self, width: Pixels) *Self {
        self.style.border_widths.left = width;
        return self;
    }

    // ========================================================================
    // Border Radius
    // ========================================================================

    pub fn rounded(self: *Self, radius: Pixels) *Self {
        self.style.corner_radii = Corners(Pixels).all(radius);
        return self;
    }

    pub fn roundedSm(self: *Self) *Self { return self.rounded(2); }
    pub fn roundedMd(self: *Self) *Self { return self.rounded(6); }
    pub fn roundedLg(self: *Self) *Self { return self.rounded(8); }
    pub fn roundedXl(self: *Self) *Self { return self.rounded(12); }
    pub fn rounded2xl(self: *Self) *Self { return self.rounded(16); }
    pub fn roundedFull(self: *Self) *Self { return self.rounded(9999); }

    pub fn roundedT(self: *Self, radius: Pixels) *Self {
        self.style.corner_radii.top_left = radius;
        self.style.corner_radii.top_right = radius;
        return self;
    }

    pub fn roundedB(self: *Self, radius: Pixels) *Self {
        self.style.corner_radii.bottom_left = radius;
        self.style.corner_radii.bottom_right = radius;
        return self;
    }

    // ========================================================================
    // Shadow
    // ========================================================================

    pub fn shadow(self: *Self, blur: Pixels, clr: Hsla) *Self {
        self.style.box_shadow = .{
            .blur_radius = blur,
            .color = clr,
        };
        return self;
    }

    pub fn shadowSm(self: *Self) *Self {
        return self.shadow(4, color_mod.black().withAlpha(0.1));
    }

    pub fn shadowMd(self: *Self) *Self {
        return self.shadow(10, color_mod.black().withAlpha(0.15));
    }

    pub fn shadowLg(self: *Self) *Self {
        return self.shadow(20, color_mod.black().withAlpha(0.2));
    }

    pub fn shadowXl(self: *Self) *Self {
        return self.shadow(30, color_mod.black().withAlpha(0.25));
    }

    // ========================================================================
    // Children
    // ========================================================================

    pub fn child(self: *Self, elem: AnyElement) *Self {
        self.children_list.append(self.allocator, elem) catch @panic("OOM");
        return self;
    }

    pub fn children(self: *Self, elems: []const AnyElement) *Self {
        for (elems) |elem| {
            self.children_list.append(self.allocator, elem) catch @panic("OOM");
        }
        return self;
    }

    // ========================================================================
    // Build
    // ========================================================================

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Div, self);
    }

    // ========================================================================
    // Element interface implementation
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        // Request layout for children first
        self.child_layout_ids.clearRetainingCapacity();
        for (self.children_list.items) |*child_elem| {
            const child_id = child_elem.requestLayout(ctx);
            self.child_layout_ids.append(self.allocator, child_id) catch @panic("OOM");
        }

        // Create layout node for this div
        const layout_style = LayoutStyle.fromStyle(self.style);
        return ctx.layout_engine.createNode(layout_style, self.child_layout_ids.items) catch @panic("Layout error");
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        // Prepaint children with their computed bounds
        for (self.children_list.items, 0..) |*child_elem, i| {
            if (i < self.child_layout_ids.items.len) {
                const child_id = self.child_layout_ids.items[i];
                const child_layout = ctx.layout_engine.getLayout(child_id);
                const child_bounds = Bounds(Pixels).init(
                    .{ .x = bounds.origin.x + child_layout.origin.x, .y = bounds.origin.y + child_layout.origin.y },
                    child_layout.size,
                );
                child_elem.prepaint(child_bounds, ctx);
            }
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const s = &self.style;

        // Paint shadow first (if any)
        if (s.box_shadow) |box_shadow| {
            ctx.scene.insertShadow(.{
                .bounds = bounds,
                .corner_radii = s.corner_radii,
                .blur_radius = box_shadow.blur_radius,
                .color = box_shadow.color,
            }) catch {};
        }

        // Paint background quad
        const has_background = s.background != null;
        const has_border = s.border_widths.top > 0 or s.border_widths.right > 0 or
            s.border_widths.bottom > 0 or s.border_widths.left > 0;

        if (has_background or has_border) {
            ctx.scene.insertQuad(.{
                .bounds = bounds,
                .background = s.background,
                .corner_radii = s.corner_radii,
                .border_widths = s.border_widths,
                .border_color = s.border_color,
            }) catch {};
        }

        // Paint children
        for (self.children_list.items, 0..) |*child_elem, i| {
            if (i < self.child_layout_ids.items.len) {
                const child_id = self.child_layout_ids.items[i];
                const child_layout = ctx.layout_engine.getLayout(child_id);
                const child_bounds = Bounds(Pixels).init(
                    .{ .x = bounds.origin.x + child_layout.origin.x, .y = bounds.origin.y + child_layout.origin.y },
                    child_layout.size,
                );
                child_elem.paint(child_bounds, ctx);
            }
        }
    }
};

/// Helper function to create a div
pub fn div(allocator: Allocator) *Div {
    return Div.init(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "Div fluent builder" {
    const allocator = std.testing.allocator;

    const d = div(allocator)
        .flex()
        .flexCol()
        .justifyCenter()
        .itemsCenter()
        .p4()
        .gap2()
        .bg(color_mod.rgb(0x4299e1))
        .roundedLg()
        .shadowMd();

    defer d.deinit(allocator);

    try std.testing.expectEqual(style_mod.Display.flex, d.style.display);
    try std.testing.expectEqual(FlexDirection.column, d.style.flex_direction);
    try std.testing.expectEqual(JustifyContent.center, d.style.justify_content.?);
    try std.testing.expectEqual(AlignItems.center, d.style.align_items.?);
    try std.testing.expectEqual(@as(Pixels, 8), d.style.corner_radii.top_left);
}

test "Div with children" {
    const allocator = std.testing.allocator;

    const child1 = div(allocator).w(.{ .px = 50 }).h(.{ .px = 50 }).bg(color_mod.rgb(0xff0000));
    const child2 = div(allocator).w(.{ .px = 50 }).h(.{ .px = 50 }).bg(color_mod.rgb(0x00ff00));

    const parent = div(allocator)
        .flex()
        .flexRow()
        .gap4()
        .child(child1.build())
        .child(child2.build());

    defer parent.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), parent.children_list.items.len);
}

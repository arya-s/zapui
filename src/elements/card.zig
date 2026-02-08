//! Card element for zapui.
//! A styled container with optional header, shadow, and rounded corners.

const std = @import("std");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const element_mod = @import("../element.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Edges = geometry.Edges;
const Hsla = color_mod.Hsla;
const Length = @import("../style.zig").Length;
const LayoutId = layout_mod.LayoutId;
const LayoutStyle = layout_mod.LayoutStyle;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;

/// Card element
pub const Card = struct {
    const Self = @This();

    allocator: Allocator,
    children_list: std.ArrayListUnmanaged(AnyElement) = .{ .items = &.{}, .capacity = 0 },
    child_layout_ids: std.ArrayListUnmanaged(LayoutId) = .{ .items = &.{}, .capacity = 0 },

    // Styling
    background: Hsla = color_mod.rgb(0x2d3748),
    border_color: ?Hsla = null,
    border_width: Pixels = 0,
    corner_radius: Pixels = 12,
    shadow_blur: Pixels = 15,
    shadow_color: Hsla = color_mod.black().withAlpha(0.2),
    padding_val: Pixels = 16,
    gap_val: Pixels = 12,

    // Size
    width: ?Pixels = null,
    height: ?Pixels = null,

    pub fn init(allocator: Allocator) *Card {
        const c = allocator.create(Card) catch @panic("OOM");
        c.* = .{ .allocator = allocator };
        return c;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.children_list.items) |*ch| {
            ch.deinit(allocator);
        }
        self.children_list.deinit(allocator);
        self.child_layout_ids.deinit(allocator);
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn bg(self: *Self, c: Hsla) *Self {
        self.background = c;
        return self;
    }

    pub fn border(self: *Self, width: Pixels, c: Hsla) *Self {
        self.border_width = width;
        self.border_color = c;
        return self;
    }

    pub fn rounded(self: *Self, r: Pixels) *Self {
        self.corner_radius = r;
        return self;
    }

    pub fn shadow(self: *Self, blur: Pixels, c: Hsla) *Self {
        self.shadow_blur = blur;
        self.shadow_color = c;
        return self;
    }

    pub fn noShadow(self: *Self) *Self {
        self.shadow_blur = 0;
        return self;
    }

    pub fn padding(self: *Self, p: Pixels) *Self {
        self.padding_val = p;
        return self;
    }

    pub fn gap(self: *Self, g: Pixels) *Self {
        self.gap_val = g;
        return self;
    }

    pub fn w(self: *Self, width: Pixels) *Self {
        self.width = width;
        return self;
    }

    pub fn h(self: *Self, height: Pixels) *Self {
        self.height = height;
        return self;
    }

    pub fn child(self: *Self, elem: AnyElement) *Self {
        self.children_list.append(self.allocator, elem) catch @panic("OOM");
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Card, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        self.child_layout_ids.clearRetainingCapacity();
        for (self.children_list.items) |*child_elem| {
            const child_id = child_elem.requestLayout(ctx);
            self.child_layout_ids.append(self.allocator, child_id) catch @panic("OOM");
        }

        return ctx.layout_engine.createNode(.{
            .flex_direction = .column,
            .padding = Edges(Length).all(.{ .px = self.padding_val }),
            .gap = .{ .width = .{ .px = self.gap_val }, .height = .{ .px = self.gap_val } },
            .size = .{
                .width = if (self.width) |wval| .{ .px = wval } else .auto,
                .height = if (self.height) |hval| .{ .px = hval } else .auto,
            },
        }, self.child_layout_ids.items) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
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
        // Shadow
        if (self.shadow_blur > 0) {
            ctx.scene.insertShadow(.{
                .bounds = bounds,
                .corner_radii = Corners(Pixels).all(self.corner_radius),
                .blur_radius = self.shadow_blur,
                .color = self.shadow_color,
            }) catch {};
        }

        // Background
        ctx.scene.insertQuad(.{
            .bounds = bounds,
            .background = .{ .solid = self.background },
            .corner_radii = Corners(Pixels).all(self.corner_radius),
            .border_widths = if (self.border_width > 0) Edges(Pixels).all(self.border_width) else Edges(Pixels).zero,
            .border_color = self.border_color,
        }) catch {};

        // Children
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

/// Helper function
pub fn card(allocator: Allocator) *Card {
    return Card.init(allocator);
}

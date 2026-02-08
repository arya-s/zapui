//! Divider element for zapui.
//! A horizontal or vertical separator line.

const std = @import("std");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const element_mod = @import("../element.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Hsla = color_mod.Hsla;
const LayoutId = layout_mod.LayoutId;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;

/// Divider orientation
pub const Orientation = enum {
    horizontal,
    vertical,
};

/// Divider element
pub const Divider = struct {
    const Self = @This();

    allocator: Allocator,
    orientation: Orientation = .horizontal,
    thickness: Pixels = 1,
    color: Hsla = color_mod.rgb(0x4a5568),
    margin_val: Pixels = 0,

    pub fn init(allocator: Allocator) *Divider {
        const d = allocator.create(Divider) catch @panic("OOM");
        d.* = .{ .allocator = allocator };
        return d;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn horizontal(self: *Self) *Self {
        self.orientation = .horizontal;
        return self;
    }

    pub fn vertical(self: *Self) *Self {
        self.orientation = .vertical;
        return self;
    }

    pub fn setThickness(self: *Self, t: Pixels) *Self {
        self.thickness = t;
        return self;
    }

    pub fn setColor(self: *Self, c: Hsla) *Self {
        self.color = c;
        return self;
    }

    pub fn margin(self: *Self, m: Pixels) *Self {
        self.margin_val = m;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Divider, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const size = switch (self.orientation) {
            .horizontal => .{
                .width = .{ .percent = 100 },
                .height = .{ .px = self.thickness + self.margin_val * 2 },
            },
            .vertical => .{
                .width = .{ .px = self.thickness + self.margin_val * 2 },
                .height = .{ .percent = 100 },
            },
        };

        return ctx.layout_engine.createNode(.{
            .size = size,
        }, &.{}) catch 0;
    }

    pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const line_bounds = switch (self.orientation) {
            .horizontal => Bounds(Pixels).fromXYWH(
                bounds.origin.x,
                bounds.origin.y + self.margin_val,
                bounds.size.width,
                self.thickness,
            ),
            .vertical => Bounds(Pixels).fromXYWH(
                bounds.origin.x + self.margin_val,
                bounds.origin.y,
                self.thickness,
                bounds.size.height,
            ),
        };

        ctx.scene.insertQuad(.{
            .bounds = line_bounds,
            .background = .{ .solid = self.color },
        }) catch {};
    }
};

/// Helper functions
pub fn divider(allocator: Allocator) *Divider {
    return Divider.init(allocator);
}

pub fn horizontalDivider(allocator: Allocator) *Divider {
    return divider(allocator).horizontal();
}

pub fn verticalDivider(allocator: Allocator) *Divider {
    return divider(allocator).vertical();
}

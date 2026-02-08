//! Progress bar element for zapui.
//! A visual indicator of progress or loading state.

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

/// Progress variant
pub const ProgressVariant = enum {
    default,
    success,
    warning,
    danger,

    pub fn color(self: ProgressVariant) Hsla {
        return switch (self) {
            .default => color_mod.rgb(0x4299e1),
            .success => color_mod.rgb(0x48bb78),
            .warning => color_mod.rgb(0xed8936),
            .danger => color_mod.rgb(0xf56565),
        };
    }
};

/// Progress bar element
pub const Progress = struct {
    const Self = @This();

    allocator: Allocator,
    value: f32 = 0,
    max: f32 = 100,
    variant: ProgressVariant = .default,
    indeterminate: bool = false,

    // Styling
    width: Pixels = 200,
    height: Pixels = 8,
    track_color: Hsla = color_mod.rgb(0x2d3748),
    bar_color: ?Hsla = null,
    show_label: bool = false,
    striped: bool = false,

    pub fn init(allocator: Allocator) *Progress {
        const p = allocator.create(Progress) catch @panic("OOM");
        p.* = .{ .allocator = allocator };
        return p;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setValue(self: *Self, v: f32) *Self {
        self.value = std.math.clamp(v, 0, self.max);
        return self;
    }

    pub fn setMax(self: *Self, m: f32) *Self {
        self.max = m;
        return self;
    }

    pub fn default(self: *Self) *Self {
        self.variant = .default;
        return self;
    }

    pub fn success(self: *Self) *Self {
        self.variant = .success;
        return self;
    }

    pub fn warning(self: *Self) *Self {
        self.variant = .warning;
        return self;
    }

    pub fn danger(self: *Self) *Self {
        self.variant = .danger;
        return self;
    }

    pub fn setColor(self: *Self, c: Hsla) *Self {
        self.bar_color = c;
        return self;
    }

    pub fn setWidth(self: *Self, w: Pixels) *Self {
        self.width = w;
        return self;
    }

    pub fn setHeight(self: *Self, h: Pixels) *Self {
        self.height = h;
        return self;
    }

    pub fn setIndeterminate(self: *Self, i: bool) *Self {
        self.indeterminate = i;
        return self;
    }

    pub fn setShowLabel(self: *Self, s: bool) *Self {
        self.show_label = s;
        return self;
    }

    pub fn setStriped(self: *Self, s: bool) *Self {
        self.striped = s;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Progress, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const total_height = if (self.show_label) self.height + 20 else self.height;

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = self.width },
                .height = .{ .px = total_height },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const bar_y = if (self.show_label) bounds.origin.y + 20 else bounds.origin.y;

        // Track
        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bar_y, bounds.size.width, self.height),
            .background = .{ .solid = self.track_color },
            .corner_radii = Corners(Pixels).all(self.height / 2),
        }) catch {};

        // Progress bar
        const bar_color = self.bar_color orelse self.variant.color();
        const pct = self.value / self.max;
        const bar_width = pct * bounds.size.width;

        if (bar_width > 0) {
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bar_y, bar_width, self.height),
                .background = .{ .solid = bar_color },
                .corner_radii = Corners(Pixels).all(self.height / 2),
            }) catch {};
        }

        // Label
        if (self.show_label) {
            const percent = @as(u32, @intFromFloat(pct * 100));
            _ = percent;

            // Placeholder for percentage text
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bounds.origin.y, 30, 14),
                .background = .{ .solid = color_mod.rgb(0xe2e8f0).withAlpha(0.4) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};
        }
    }
};

/// Helper function
pub fn progress(allocator: Allocator) *Progress {
    return Progress.init(allocator);
}

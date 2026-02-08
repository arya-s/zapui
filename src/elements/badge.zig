//! Badge element for zapui.
//! A small label/tag for status or categorization.

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
const LayoutId = layout_mod.LayoutId;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;

/// Badge variant
pub const BadgeVariant = enum {
    default,
    primary,
    success,
    warning,
    danger,
    info,

    pub fn backgroundColor(self: BadgeVariant) Hsla {
        return switch (self) {
            .default => color_mod.rgb(0x4a5568),
            .primary => color_mod.rgb(0x4299e1),
            .success => color_mod.rgb(0x48bb78),
            .warning => color_mod.rgb(0xed8936),
            .danger => color_mod.rgb(0xf56565),
            .info => color_mod.rgb(0x667eea),
        };
    }

    pub fn textColor(self: BadgeVariant) Hsla {
        return switch (self) {
            .warning => color_mod.rgb(0x1a202c),
            else => color_mod.rgb(0xffffff),
        };
    }
};

/// Badge element
pub const Badge = struct {
    const Self = @This();

    allocator: Allocator,
    text: []const u8,
    variant: BadgeVariant = .default,
    outlined: bool = false,
    rounded: bool = false,

    pub fn init(allocator: Allocator, text: []const u8) *Badge {
        const b = allocator.create(Badge) catch @panic("OOM");
        b.* = .{
            .allocator = allocator,
            .text = text,
        };
        return b;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn default(self: *Self) *Self {
        self.variant = .default;
        return self;
    }

    pub fn primary(self: *Self) *Self {
        self.variant = .primary;
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

    pub fn info(self: *Self) *Self {
        self.variant = .info;
        return self;
    }

    pub fn setOutlined(self: *Self, o: bool) *Self {
        self.outlined = o;
        return self;
    }

    pub fn pill(self: *Self) *Self {
        self.rounded = true;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Badge, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const text_width = @as(Pixels, @floatFromInt(self.text.len)) * 7;
        const padding_x: Pixels = if (self.rounded) 12 else 8;
        const height: Pixels = 22;

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = text_width + padding_x * 2 },
                .height = .{ .px = height },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const bg_color = self.variant.backgroundColor();
        const text_color = self.variant.textColor();
        const radius: Pixels = if (self.rounded) bounds.size.height / 2 else 4;

        if (self.outlined) {
            ctx.scene.insertQuad(.{
                .bounds = bounds,
                .background = null,
                .corner_radii = Corners(Pixels).all(radius),
                .border_widths = Edges(Pixels).all(1),
                .border_color = bg_color,
            }) catch {};
        } else {
            ctx.scene.insertQuad(.{
                .bounds = bounds,
                .background = .{ .solid = bg_color },
                .corner_radii = Corners(Pixels).all(radius),
            }) catch {};
        }

        // Text placeholder
        const actual_text_color = if (self.outlined) bg_color else text_color;
        const text_width = @as(Pixels, @floatFromInt(self.text.len)) * 7;
        const text_x = bounds.origin.x + (bounds.size.width - text_width) / 2;
        const text_y = bounds.origin.y + (bounds.size.height - 10) / 2;

        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(text_x, text_y, text_width, 10),
            .background = .{ .solid = actual_text_color.withAlpha(0.4) },
            .corner_radii = Corners(Pixels).all(2),
        }) catch {};
    }
};

/// Helper function
pub fn badge(allocator: Allocator, text: []const u8) *Badge {
    return Badge.init(allocator, text);
}

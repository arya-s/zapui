//! Avatar element for zapui.
//! A circular or rounded avatar display.

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

/// Avatar size
pub const AvatarSize = enum {
    xs,
    sm,
    md,
    lg,
    xl,

    pub fn pixels(self: AvatarSize) Pixels {
        return switch (self) {
            .xs => 24,
            .sm => 32,
            .md => 40,
            .lg => 48,
            .xl => 64,
        };
    }

    pub fn fontSize(self: AvatarSize) Pixels {
        return switch (self) {
            .xs => 10,
            .sm => 12,
            .md => 14,
            .lg => 18,
            .xl => 24,
        };
    }
};

/// Status indicator
pub const AvatarStatus = enum {
    none,
    online,
    offline,
    busy,
    away,

    pub fn color(self: AvatarStatus) ?Hsla {
        return switch (self) {
            .none => null,
            .online => color_mod.rgb(0x48bb78),
            .offline => color_mod.rgb(0x718096),
            .busy => color_mod.rgb(0xf56565),
            .away => color_mod.rgb(0xed8936),
        };
    }
};

/// Avatar element
pub const Avatar = struct {
    const Self = @This();

    allocator: Allocator,
    initials: ?[]const u8 = null,
    image_url: ?[]const u8 = null, // Placeholder for future image support
    avatar_size: AvatarSize = .md,
    status: AvatarStatus = .none,
    rounded: bool = true, // true = circle, false = rounded square

    // Styling
    background: Hsla = color_mod.rgb(0x4299e1),
    text_color: Hsla = color_mod.rgb(0xffffff),
    border_color: ?Hsla = null,
    border_width: Pixels = 0,

    pub fn init(allocator: Allocator) *Avatar {
        const a = allocator.create(Avatar) catch @panic("OOM");
        a.* = .{ .allocator = allocator };
        return a;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setInitials(self: *Self, i: []const u8) *Self {
        self.initials = i;
        return self;
    }

    pub fn xs(self: *Self) *Self {
        self.avatar_size = .xs;
        return self;
    }

    pub fn sm(self: *Self) *Self {
        self.avatar_size = .sm;
        return self;
    }

    pub fn md(self: *Self) *Self {
        self.avatar_size = .md;
        return self;
    }

    pub fn lg(self: *Self) *Self {
        self.avatar_size = .lg;
        return self;
    }

    pub fn xl(self: *Self) *Self {
        self.avatar_size = .xl;
        return self;
    }

    pub fn setStatus(self: *Self, s: AvatarStatus) *Self {
        self.status = s;
        return self;
    }

    pub fn online(self: *Self) *Self {
        return self.setStatus(.online);
    }

    pub fn offline(self: *Self) *Self {
        return self.setStatus(.offline);
    }

    pub fn busy(self: *Self) *Self {
        return self.setStatus(.busy);
    }

    pub fn away(self: *Self) *Self {
        return self.setStatus(.away);
    }

    pub fn circle(self: *Self) *Self {
        self.rounded = true;
        return self;
    }

    pub fn square(self: *Self) *Self {
        self.rounded = false;
        return self;
    }

    pub fn bg(self: *Self, c: Hsla) *Self {
        self.background = c;
        return self;
    }

    pub fn border(self: *Self, width: Pixels, c: Hsla) *Self {
        self.border_width = width;
        self.border_color = c;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Avatar, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const size = self.avatar_size.pixels();

        return ctx.layout_engine.createNode(.{
            .size = .{ .width = .{ .px = size }, .height = .{ .px = size } },
        }, &.{}) catch 0;
    }

    pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const size = self.avatar_size.pixels();
        const radius = if (self.rounded) size / 2 else 8;

        // Avatar background
        ctx.scene.insertQuad(.{
            .bounds = bounds,
            .background = .{ .solid = self.background },
            .corner_radii = Corners(Pixels).all(radius),
            .border_widths = if (self.border_width > 0) Edges(Pixels).all(self.border_width) else Edges(Pixels).zero,
            .border_color = self.border_color,
        }) catch {};

        // Initials
        if (self.initials) |initials| {
            const font_size = self.avatar_size.fontSize();
            const text_width = @as(Pixels, @floatFromInt(initials.len)) * font_size * 0.7;
            const text_x = bounds.origin.x + (size - text_width) / 2;
            const text_y = bounds.origin.y + (size - font_size) / 2;

            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(text_x, text_y, text_width, font_size),
                .background = .{ .solid = self.text_color.withAlpha(0.8) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};
        }

        // Status indicator
        if (self.status.color()) |status_color| {
            const status_size: Pixels = switch (self.avatar_size) {
                .xs, .sm => 8,
                .md => 10,
                .lg, .xl => 12,
            };
            const status_x = bounds.origin.x + size - status_size;
            const status_y = bounds.origin.y + size - status_size;

            // Status border (white ring)
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(status_x - 2, status_y - 2, status_size + 4, status_size + 4),
                .background = .{ .solid = color_mod.rgb(0x1a202c) },
                .corner_radii = Corners(Pixels).all((status_size + 4) / 2),
            }) catch {};

            // Status dot
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(status_x, status_y, status_size, status_size),
                .background = .{ .solid = status_color },
                .corner_radii = Corners(Pixels).all(status_size / 2),
            }) catch {};
        }
    }
};

/// Helper function
pub fn avatar(allocator: Allocator) *Avatar {
    return Avatar.init(allocator);
}

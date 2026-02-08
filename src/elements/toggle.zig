//! Toggle (Switch) element for zapui.
//! A toggle switch for boolean values.

const std = @import("std");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const element_mod = @import("../element.zig");
const input_mod = @import("../input.zig");
const app_mod = @import("../app.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Hsla = color_mod.Hsla;
const LayoutId = layout_mod.LayoutId;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;
const HitboxId = input_mod.HitboxId;
const App = app_mod.App;

/// Toggle size
pub const ToggleSize = enum {
    sm,
    md,
    lg,

    pub fn width(self: ToggleSize) Pixels {
        return switch (self) {
            .sm => 36,
            .md => 44,
            .lg => 52,
        };
    }

    pub fn height(self: ToggleSize) Pixels {
        return switch (self) {
            .sm => 20,
            .md => 24,
            .lg => 28,
        };
    }

    pub fn thumbSize(self: ToggleSize) Pixels {
        return switch (self) {
            .sm => 16,
            .md => 20,
            .lg => 24,
        };
    }
};

/// Change handler
pub const ChangeHandler = *const fn (*App, bool) void;

/// Toggle element
pub const Toggle = struct {
    const Self = @This();

    allocator: Allocator,
    checked: bool = false,
    disabled: bool = false,
    toggle_size: ToggleSize = .md,
    label: ?[]const u8 = null,

    // Styling
    active_color: Hsla = color_mod.rgb(0x4299e1),
    inactive_color: Hsla = color_mod.rgb(0x4a5568),
    thumb_color: Hsla = color_mod.rgb(0xffffff),

    // Event handler
    on_change: ?ChangeHandler = null,

    // Runtime state
    hitbox_id: ?HitboxId = null,
    is_hovered: bool = false,

    pub fn init(allocator: Allocator) *Toggle {
        const t = allocator.create(Toggle) catch @panic("OOM");
        t.* = .{ .allocator = allocator };
        return t;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setChecked(self: *Self, c: bool) *Self {
        self.checked = c;
        return self;
    }

    pub fn setDisabled(self: *Self, d: bool) *Self {
        self.disabled = d;
        return self;
    }

    pub fn small(self: *Self) *Self {
        self.toggle_size = .sm;
        return self;
    }

    pub fn medium(self: *Self) *Self {
        self.toggle_size = .md;
        return self;
    }

    pub fn large(self: *Self) *Self {
        self.toggle_size = .lg;
        return self;
    }

    pub fn setLabel(self: *Self, l: []const u8) *Self {
        self.label = l;
        return self;
    }

    pub fn setActiveColor(self: *Self, c: Hsla) *Self {
        self.active_color = c;
        return self;
    }

    pub fn onChange(self: *Self, handler: ChangeHandler) *Self {
        self.on_change = handler;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Toggle, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const label_width: Pixels = if (self.label) |l| @as(Pixels, @floatFromInt(l.len)) * 8 + 12 else 0;

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = self.toggle_size.width() + label_width },
                .height = .{ .px = self.toggle_size.height() },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        if (!self.disabled) {
            self.hitbox_id = ctx.registerHitbox(bounds, .pointer);
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const w = self.toggle_size.width();
        const h = self.toggle_size.height();
        const thumb = self.toggle_size.thumbSize();
        const padding: Pixels = 2;

        // Track
        const track_color = if (self.disabled)
            color_mod.rgb(0x2d3748)
        else if (self.checked)
            self.active_color
        else if (self.is_hovered)
            color_mod.rgb(0x718096)
        else
            self.inactive_color;

        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bounds.origin.y, w, h),
            .background = .{ .solid = track_color },
            .corner_radii = Corners(Pixels).all(h / 2),
        }) catch {};

        // Thumb
        const thumb_x = if (self.checked)
            bounds.origin.x + w - thumb - padding
        else
            bounds.origin.x + padding;
        const thumb_y = bounds.origin.y + padding;

        const actual_thumb_color = if (self.disabled)
            color_mod.rgb(0x718096)
        else
            self.thumb_color;

        // Thumb shadow
        ctx.scene.insertShadow(.{
            .bounds = Bounds(Pixels).fromXYWH(thumb_x, thumb_y, thumb, thumb),
            .corner_radii = Corners(Pixels).all(thumb / 2),
            .blur_radius = 3,
            .color = color_mod.black().withAlpha(0.15),
        }) catch {};

        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(thumb_x, thumb_y, thumb, thumb),
            .background = .{ .solid = actual_thumb_color },
            .corner_radii = Corners(Pixels).all(thumb / 2),
        }) catch {};

        // Label
        if (self.label) |_| {
            const label_x = bounds.origin.x + w + 12;
            const label_y = bounds.origin.y + (h - 12) / 2;
            const label_color = if (self.disabled) color_mod.rgb(0x718096) else color_mod.rgb(0xe2e8f0);

            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(label_x, label_y, 60, 12),
                .background = .{ .solid = label_color.withAlpha(0.4) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};
        }
    }
};

/// Helper function
pub fn toggle(allocator: Allocator) *Toggle {
    return Toggle.init(allocator);
}

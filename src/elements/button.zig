//! Button element for zapui.
//! A clickable button with various styles and states.

const std = @import("std");
const geometry = @import("../geometry.zig");
const style_mod = @import("../style.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const element_mod = @import("../element.zig");
const input_mod = @import("../input.zig");
const app_mod = @import("../app.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Corners = geometry.Corners;
const Edges = geometry.Edges;
const Hsla = color_mod.Hsla;
const Length = style_mod.Length;
const LayoutId = layout_mod.LayoutId;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;
const HitboxId = input_mod.HitboxId;
const App = app_mod.App;

/// Button variant/style
pub const ButtonVariant = enum {
    primary,
    secondary,
    outline,
    ghost,
    danger,
};

/// Button size
pub const ButtonSize = enum {
    sm,
    md,
    lg,

    pub fn height(self: ButtonSize) Pixels {
        return switch (self) {
            .sm => 32,
            .md => 40,
            .lg => 48,
        };
    }

    pub fn paddingX(self: ButtonSize) Pixels {
        return switch (self) {
            .sm => 12,
            .md => 16,
            .lg => 24,
        };
    }

    pub fn fontSize(self: ButtonSize) Pixels {
        return switch (self) {
            .sm => 13,
            .md => 14,
            .lg => 16,
        };
    }
};

/// Click handler type
pub const ClickHandler = *const fn (*App) void;

/// Button element
pub const Button = struct {
    const Self = @This();

    allocator: Allocator,
    label: []const u8,
    variant: ButtonVariant = .primary,
    btn_size: ButtonSize = .md,
    disabled: bool = false,
    full_width: bool = false,
    icon_left: ?[]const u8 = null,
    icon_right: ?[]const u8 = null,

    // Event handlers
    on_click: ?ClickHandler = null,

    // Runtime state
    hitbox_id: ?HitboxId = null,
    is_hovered: bool = false,
    is_pressed: bool = false,

    pub fn init(allocator: Allocator, label: []const u8) *Button {
        const b = allocator.create(Button) catch @panic("OOM");
        b.* = .{
            .allocator = allocator,
            .label = label,
        };
        return b;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn primary(self: *Self) *Self {
        self.variant = .primary;
        return self;
    }

    pub fn secondary(self: *Self) *Self {
        self.variant = .secondary;
        return self;
    }

    pub fn outline(self: *Self) *Self {
        self.variant = .outline;
        return self;
    }

    pub fn ghost(self: *Self) *Self {
        self.variant = .ghost;
        return self;
    }

    pub fn danger(self: *Self) *Self {
        self.variant = .danger;
        return self;
    }

    pub fn small(self: *Self) *Self {
        self.btn_size = .sm;
        return self;
    }

    pub fn medium(self: *Self) *Self {
        self.btn_size = .md;
        return self;
    }

    pub fn large(self: *Self) *Self {
        self.btn_size = .lg;
        return self;
    }

    pub fn setDisabled(self: *Self, d: bool) *Self {
        self.disabled = d;
        return self;
    }

    pub fn fullWidth(self: *Self) *Self {
        self.full_width = true;
        return self;
    }

    pub fn onClick(self: *Self, handler: ClickHandler) *Self {
        self.on_click = handler;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Button, self);
    }

    // ========================================================================
    // Styling helpers
    // ========================================================================

    fn getBackgroundColor(self: *const Self) Hsla {
        if (self.disabled) {
            return color_mod.rgb(0x4a5568);
        }

        const base = switch (self.variant) {
            .primary => color_mod.rgb(0x4299e1),
            .secondary => color_mod.rgb(0x718096),
            .outline => color_mod.transparent(),
            .ghost => color_mod.transparent(),
            .danger => color_mod.rgb(0xf56565),
        };

        if (self.is_pressed) {
            return base.adjustLightness(-0.1);
        } else if (self.is_hovered) {
            return base.adjustLightness(0.05);
        }
        return base;
    }

    fn getBorderColor(self: *const Self) ?Hsla {
        if (self.variant == .outline) {
            if (self.disabled) {
                return color_mod.rgb(0x4a5568);
            }
            return color_mod.rgb(0x4299e1);
        }
        return null;
    }

    fn getTextColor(self: *const Self) Hsla {
        if (self.disabled) {
            return color_mod.rgb(0xa0aec0);
        }

        return switch (self.variant) {
            .primary, .danger => color_mod.rgb(0xffffff),
            .secondary => color_mod.rgb(0xffffff),
            .outline, .ghost => color_mod.rgb(0x4299e1),
        };
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const h = self.btn_size.height();
        const px = self.btn_size.paddingX();
        const text_width = @as(Pixels, @floatFromInt(self.label.len)) * self.btn_size.fontSize() * 0.6;

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = if (self.full_width) .{ .percent = 100 } else .{ .px = text_width + px * 2 },
                .height = .{ .px = h },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        self.hitbox_id = ctx.registerHitbox(bounds, .pointer);
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const bg = self.getBackgroundColor();
        const border = self.getBorderColor();
        const radius: Pixels = 6;

        // Draw button background
        ctx.scene.insertQuad(.{
            .bounds = bounds,
            .background = if (bg.a > 0) .{ .solid = bg } else null,
            .corner_radii = Corners(Pixels).all(radius),
            .border_widths = if (border != null) Edges(Pixels).all(1) else Edges(Pixels).zero,
            .border_color = border,
        }) catch {};

        // Text would be rendered here with text system
        // For now, render a text placeholder
        const text_color = self.getTextColor();
        const font_size = self.btn_size.fontSize();
        const text_width = @as(Pixels, @floatFromInt(self.label.len)) * font_size * 0.6;
        const text_x = bounds.origin.x + (bounds.size.width - text_width) / 2;
        const text_y = bounds.origin.y + (bounds.size.height - font_size) / 2;

        // Placeholder for text - in real implementation would use text system
        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(text_x, text_y + font_size * 0.2, text_width, font_size * 0.7),
            .background = .{ .solid = text_color.withAlpha(0.3) },
            .corner_radii = Corners(Pixels).all(2),
        }) catch {};
    }
};

/// Helper function to create a button
pub fn button(allocator: Allocator, label: []const u8) *Button {
    return Button.init(allocator, label);
}

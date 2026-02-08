//! Input element for zapui.
//! A text input field.

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
const Edges = geometry.Edges;
const Hsla = color_mod.Hsla;
const LayoutId = layout_mod.LayoutId;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;
const HitboxId = input_mod.HitboxId;
const App = app_mod.App;

/// Input size
pub const InputSize = enum {
    sm,
    md,
    lg,

    pub fn height(self: InputSize) Pixels {
        return switch (self) {
            .sm => 32,
            .md => 40,
            .lg => 48,
        };
    }

    pub fn fontSize(self: InputSize) Pixels {
        return switch (self) {
            .sm => 13,
            .md => 14,
            .lg => 16,
        };
    }
};

/// Input element
pub const Input = struct {
    const Self = @This();

    allocator: Allocator,
    placeholder: ?[]const u8 = null,
    value: []const u8 = "",
    input_size: InputSize = .md,
    disabled: bool = false,
    readonly: bool = false,
    error_state: bool = false,
    width: ?Pixels = null,

    // Styling
    background: Hsla = color_mod.rgb(0x1a202c),
    border_color: Hsla = color_mod.rgb(0x4a5568),
    focus_color: Hsla = color_mod.rgb(0x4299e1),
    error_color: Hsla = color_mod.rgb(0xf56565),
    text_color: Hsla = color_mod.rgb(0xe2e8f0),
    placeholder_color: Hsla = color_mod.rgb(0x718096),

    // Runtime state
    hitbox_id: ?HitboxId = null,
    is_focused: bool = false,
    is_hovered: bool = false,

    pub fn init(allocator: Allocator) *Input {
        const i = allocator.create(Input) catch @panic("OOM");
        i.* = .{ .allocator = allocator };
        return i;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setPlaceholder(self: *Self, p: []const u8) *Self {
        self.placeholder = p;
        return self;
    }

    pub fn setValue(self: *Self, v: []const u8) *Self {
        self.value = v;
        return self;
    }

    pub fn small(self: *Self) *Self {
        self.input_size = .sm;
        return self;
    }

    pub fn medium(self: *Self) *Self {
        self.input_size = .md;
        return self;
    }

    pub fn large(self: *Self) *Self {
        self.input_size = .lg;
        return self;
    }

    pub fn setDisabled(self: *Self, d: bool) *Self {
        self.disabled = d;
        return self;
    }

    pub fn setReadonly(self: *Self, r: bool) *Self {
        self.readonly = r;
        return self;
    }

    pub fn setError(self: *Self, e: bool) *Self {
        self.error_state = e;
        return self;
    }

    pub fn setWidth(self: *Self, w: Pixels) *Self {
        self.width = w;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Input, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = if (self.width) |w| .{ .px = w } else .{ .px = 200 },
                .height = .{ .px = self.input_size.height() },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        if (!self.disabled) {
            self.hitbox_id = ctx.registerHitbox(bounds, .text);
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const border = if (self.error_state)
            self.error_color
        else if (self.is_focused)
            self.focus_color
        else if (self.is_hovered and !self.disabled)
            color_mod.rgb(0x718096)
        else
            self.border_color;

        const bg = if (self.disabled)
            color_mod.rgb(0x2d3748)
        else
            self.background;

        // Input box
        ctx.scene.insertQuad(.{
            .bounds = bounds,
            .background = .{ .solid = bg },
            .corner_radii = Corners(Pixels).all(6),
            .border_widths = Edges(Pixels).all(1),
            .border_color = border,
        }) catch {};

        // Focus ring
        if (self.is_focused) {
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(
                    bounds.origin.x - 2,
                    bounds.origin.y - 2,
                    bounds.size.width + 4,
                    bounds.size.height + 4,
                ),
                .background = null,
                .corner_radii = Corners(Pixels).all(8),
                .border_widths = Edges(Pixels).all(2),
                .border_color = self.focus_color.withAlpha(0.3),
            }) catch {};
        }

        // Text or placeholder
        const padding: Pixels = 12;
        const font_size = self.input_size.fontSize();
        const text_y = bounds.origin.y + (bounds.size.height - font_size) / 2;

        const display_text = if (self.value.len > 0) self.value else self.placeholder;
        const is_placeholder = self.value.len == 0;

        if (display_text) |text| {
            const text_color = if (is_placeholder)
                self.placeholder_color
            else if (self.disabled)
                color_mod.rgb(0x718096)
            else
                self.text_color;

            const text_width = @min(
                @as(Pixels, @floatFromInt(text.len)) * font_size * 0.6,
                bounds.size.width - padding * 2,
            );

            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x + padding, text_y, text_width, font_size),
                .background = .{ .solid = text_color.withAlpha(0.4) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};
        }

        // Cursor (when focused)
        if (self.is_focused and !self.readonly) {
            const cursor_x = bounds.origin.x + padding + @as(Pixels, @floatFromInt(self.value.len)) * self.input_size.fontSize() * 0.6;
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(cursor_x, text_y, 2, font_size),
                .background = .{ .solid = self.text_color },
            }) catch {};
        }
    }
};

/// Helper function
pub fn input(allocator: Allocator) *Input {
    return Input.init(allocator);
}

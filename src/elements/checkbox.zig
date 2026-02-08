//! Checkbox element for zapui.
//! A toggleable checkbox with label.

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

/// Change handler type
pub const ChangeHandler = *const fn (*App, bool) void;

/// Checkbox element
pub const Checkbox = struct {
    const Self = @This();

    allocator: Allocator,
    label: ?[]const u8 = null,
    checked: bool = false,
    disabled: bool = false,
    indeterminate: bool = false,

    // Styling
    size: Pixels = 20,
    color: Hsla = color_mod.rgb(0x4299e1),

    // Event handlers
    on_change: ?ChangeHandler = null,

    // Runtime state
    hitbox_id: ?HitboxId = null,
    is_hovered: bool = false,

    pub fn init(allocator: Allocator) *Checkbox {
        const c = allocator.create(Checkbox) catch @panic("OOM");
        c.* = .{ .allocator = allocator };
        return c;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setLabel(self: *Self, l: []const u8) *Self {
        self.label = l;
        return self;
    }

    pub fn setChecked(self: *Self, c: bool) *Self {
        self.checked = c;
        return self;
    }

    pub fn setDisabled(self: *Self, d: bool) *Self {
        self.disabled = d;
        return self;
    }

    pub fn setIndeterminate(self: *Self, i: bool) *Self {
        self.indeterminate = i;
        return self;
    }

    pub fn setSize(self: *Self, s: Pixels) *Self {
        self.size = s;
        return self;
    }

    pub fn setColor(self: *Self, c: Hsla) *Self {
        self.color = c;
        return self;
    }

    pub fn onChange(self: *Self, handler: ChangeHandler) *Self {
        self.on_change = handler;
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Checkbox, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        const label_width: Pixels = if (self.label) |l| @as(Pixels, @floatFromInt(l.len)) * 8 else 0;
        const gap: Pixels = if (self.label != null) 8 else 0;

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = self.size + gap + label_width },
                .height = .{ .px = self.size },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        if (!self.disabled) {
            self.hitbox_id = ctx.registerHitbox(bounds, .pointer);
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const box_size = self.size;
        const box_x = bounds.origin.x;
        const box_y = bounds.origin.y;

        // Checkbox box
        const bg_color = if (self.checked or self.indeterminate)
            (if (self.disabled) color_mod.rgb(0x4a5568) else self.color)
        else if (self.is_hovered and !self.disabled)
            color_mod.rgb(0x2d3748)
        else
            color_mod.rgb(0x1a202c);

        const border_color = if (self.disabled)
            color_mod.rgb(0x4a5568)
        else if (self.checked or self.indeterminate)
            self.color
        else if (self.is_hovered)
            color_mod.rgb(0x4299e1)
        else
            color_mod.rgb(0x4a5568);

        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(box_x, box_y, box_size, box_size),
            .background = .{ .solid = bg_color },
            .corner_radii = Corners(Pixels).all(4),
            .border_widths = Edges(Pixels).all(2),
            .border_color = border_color,
        }) catch {};

        // Checkmark or indeterminate dash
        if (self.checked) {
            // Draw checkmark (simplified as two lines)
            const mark_color = color_mod.rgb(0xffffff);
            const cx = box_x + box_size / 2;
            const cy = box_y + box_size / 2;

            // Left part of check
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(cx - 5, cy, 6, 2),
                .background = .{ .solid = mark_color },
                .corner_radii = Corners(Pixels).all(1),
            }) catch {};

            // Right part of check
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(cx - 1, cy - 4, 2, 8),
                .background = .{ .solid = mark_color },
                .corner_radii = Corners(Pixels).all(1),
            }) catch {};
        } else if (self.indeterminate) {
            // Draw dash
            const dash_color = color_mod.rgb(0xffffff);
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(box_x + 4, box_y + box_size / 2 - 1, box_size - 8, 2),
                .background = .{ .solid = dash_color },
                .corner_radii = Corners(Pixels).all(1),
            }) catch {};
        }

        // Label (placeholder)
        if (self.label) |_| {
            const label_x = box_x + box_size + 8;
            const label_color = if (self.disabled) color_mod.rgb(0x718096) else color_mod.rgb(0xe2e8f0);

            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(label_x, box_y + 4, 60, 12),
                .background = .{ .solid = label_color.withAlpha(0.3) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};
        }
    }
};

/// Helper function
pub fn checkbox(allocator: Allocator) *Checkbox {
    return Checkbox.init(allocator);
}

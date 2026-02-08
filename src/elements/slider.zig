//! Slider element for zapui.
//! A range slider for selecting numeric values.

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

/// Change handler type
pub const ChangeHandler = *const fn (*App, f32) void;

/// Slider element
pub const Slider = struct {
    const Self = @This();

    allocator: Allocator,
    value: f32 = 0.5,
    min: f32 = 0,
    max: f32 = 1,
    step: ?f32 = null,
    disabled: bool = false,

    // Styling
    width: Pixels = 200,
    track_height: Pixels = 6,
    thumb_size: Pixels = 18,
    color: Hsla = color_mod.rgb(0x4299e1),
    track_color: Hsla = color_mod.rgb(0x4a5568),

    // Event handlers
    on_change: ?ChangeHandler = null,

    // Runtime state
    hitbox_id: ?HitboxId = null,
    is_hovered: bool = false,
    is_dragging: bool = false,

    pub fn init(allocator: Allocator) *Slider {
        const s = allocator.create(Slider) catch @panic("OOM");
        s.* = .{ .allocator = allocator };
        return s;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn setValue(self: *Self, v: f32) *Self {
        self.value = std.math.clamp(v, self.min, self.max);
        return self;
    }

    pub fn setMin(self: *Self, m: f32) *Self {
        self.min = m;
        return self;
    }

    pub fn setMax(self: *Self, m: f32) *Self {
        self.max = m;
        return self;
    }

    pub fn setStep(self: *Self, s: f32) *Self {
        self.step = s;
        return self;
    }

    pub fn setDisabled(self: *Self, d: bool) *Self {
        self.disabled = d;
        return self;
    }

    pub fn setWidth(self: *Self, w: Pixels) *Self {
        self.width = w;
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
        return intoAnyElement(Slider, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = self.width },
                .height = .{ .px = self.thumb_size },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        if (!self.disabled) {
            self.hitbox_id = ctx.registerHitbox(bounds, .pointer);
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const track_y = bounds.origin.y + (bounds.size.height - self.track_height) / 2;
        const progress = (self.value - self.min) / (self.max - self.min);
        const thumb_x = bounds.origin.x + progress * (bounds.size.width - self.thumb_size);

        // Track background
        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, track_y, bounds.size.width, self.track_height),
            .background = .{ .solid = self.track_color },
            .corner_radii = Corners(Pixels).all(self.track_height / 2),
        }) catch {};

        // Track fill (progress)
        const fill_color = if (self.disabled) color_mod.rgb(0x4a5568) else self.color;
        const fill_width = progress * bounds.size.width;
        if (fill_width > 0) {
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, track_y, fill_width, self.track_height),
                .background = .{ .solid = fill_color },
                .corner_radii = Corners(Pixels).all(self.track_height / 2),
            }) catch {};
        }

        // Thumb
        const thumb_color = if (self.disabled)
            color_mod.rgb(0x718096)
        else if (self.is_dragging)
            self.color.adjustLightness(-0.1)
        else if (self.is_hovered)
            self.color.adjustLightness(0.1)
        else
            color_mod.rgb(0xffffff);

        // Thumb shadow
        ctx.scene.insertShadow(.{
            .bounds = Bounds(Pixels).fromXYWH(thumb_x, bounds.origin.y, self.thumb_size, self.thumb_size),
            .corner_radii = Corners(Pixels).all(self.thumb_size / 2),
            .blur_radius = 4,
            .color = color_mod.black().withAlpha(0.2),
        }) catch {};

        ctx.scene.insertQuad(.{
            .bounds = Bounds(Pixels).fromXYWH(thumb_x, bounds.origin.y, self.thumb_size, self.thumb_size),
            .background = .{ .solid = thumb_color },
            .corner_radii = Corners(Pixels).all(self.thumb_size / 2),
        }) catch {};
    }
};

/// Helper function
pub fn slider(allocator: Allocator) *Slider {
    return Slider.init(allocator);
}

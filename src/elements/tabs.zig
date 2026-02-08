//! Tabs element for zapui.
//! A tabbed interface for switching between views.

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

/// Tab variant style
pub const TabVariant = enum {
    underline,
    pills,
    boxed,
};

/// Tab change handler
pub const TabChangeHandler = *const fn (*App, usize) void;

/// Single tab definition
pub const TabItem = struct {
    label: []const u8,
    disabled: bool = false,
};

/// Tabs element
pub const Tabs = struct {
    const Self = @This();

    allocator: Allocator,
    tabs: std.ArrayListUnmanaged(TabItem) = .{ .items = &.{}, .capacity = 0 },
    selected: usize = 0,
    variant: TabVariant = .underline,

    // Styling
    active_color: Hsla = color_mod.rgb(0x4299e1),
    inactive_color: Hsla = color_mod.rgb(0xa0aec0),
    background: ?Hsla = null,

    // Event handler
    on_change: ?TabChangeHandler = null,

    // Runtime state
    tab_hitboxes: std.ArrayListUnmanaged(HitboxId) = .{ .items = &.{}, .capacity = 0 },
    hovered_tab: ?usize = null,

    // Content
    content_list: std.ArrayListUnmanaged(AnyElement) = .{ .items = &.{}, .capacity = 0 },
    content_layout_ids: std.ArrayListUnmanaged(LayoutId) = .{ .items = &.{}, .capacity = 0 },

    pub fn init(allocator: Allocator) *Tabs {
        const t = allocator.create(Tabs) catch @panic("OOM");
        t.* = .{ .allocator = allocator };
        return t;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.tabs.deinit(allocator);
        self.tab_hitboxes.deinit(allocator);
        for (self.content_list.items) |*c| {
            c.deinit(allocator);
        }
        self.content_list.deinit(allocator);
        self.content_layout_ids.deinit(allocator);
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn addTab(self: *Self, label: []const u8) *Self {
        self.tabs.append(self.allocator, .{ .label = label }) catch @panic("OOM");
        return self;
    }

    pub fn addDisabledTab(self: *Self, label: []const u8) *Self {
        self.tabs.append(self.allocator, .{ .label = label, .disabled = true }) catch @panic("OOM");
        return self;
    }

    pub fn setSelected(self: *Self, idx: usize) *Self {
        self.selected = idx;
        return self;
    }

    pub fn underline(self: *Self) *Self {
        self.variant = .underline;
        return self;
    }

    pub fn pills(self: *Self) *Self {
        self.variant = .pills;
        return self;
    }

    pub fn boxed(self: *Self) *Self {
        self.variant = .boxed;
        return self;
    }

    pub fn setActiveColor(self: *Self, c: Hsla) *Self {
        self.active_color = c;
        return self;
    }

    pub fn setInactiveColor(self: *Self, c: Hsla) *Self {
        self.inactive_color = c;
        return self;
    }

    pub fn bg(self: *Self, c: Hsla) *Self {
        self.background = c;
        return self;
    }

    pub fn onChange(self: *Self, handler: TabChangeHandler) *Self {
        self.on_change = handler;
        return self;
    }

    pub fn content(self: *Self, elem: AnyElement) *Self {
        self.content_list.append(self.allocator, elem) catch @panic("OOM");
        return self;
    }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Tabs, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        // Request layout for content
        self.content_layout_ids.clearRetainingCapacity();
        for (self.content_list.items) |*content_elem| {
            const content_id = content_elem.requestLayout(ctx);
            self.content_layout_ids.append(self.allocator, content_id) catch @panic("OOM");
        }

        // Calculate tabs width
        var total_width: Pixels = 0;
        for (self.tabs.items) |tab| {
            total_width += @as(Pixels, @floatFromInt(tab.label.len)) * 8 + 32;
        }

        return ctx.layout_engine.createNode(.{
            .flex_direction = .column,
            .size = .{ .width = .{ .percent = 100 }, .height = .auto },
        }, &.{}) catch 0;
    }

    pub fn prepaint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        // Register hitboxes for tabs
        self.tab_hitboxes.clearRetainingCapacity();

        var x = bounds.origin.x;
        const tab_height: Pixels = 40;

        for (self.tabs.items, 0..) |tab, i| {
            const tab_width = @as(Pixels, @floatFromInt(tab.label.len)) * 8 + 32;
            const tab_bounds = Bounds(Pixels).fromXYWH(x, bounds.origin.y, tab_width, tab_height);

            if (!tab.disabled) {
                if (ctx.registerHitbox(tab_bounds, .pointer)) |hid| {
                    self.tab_hitboxes.append(self.allocator, hid) catch {};
                }
            }

            _ = i;
            x += tab_width;
        }

        // Prepaint selected content
        if (self.selected < self.content_list.items.len) {
            const content_y = bounds.origin.y + 40 + 8;
            const content_bounds = Bounds(Pixels).fromXYWH(
                bounds.origin.x,
                content_y,
                bounds.size.width,
                bounds.size.height - 48,
            );
            self.content_list.items[self.selected].prepaint(content_bounds, ctx);
        }
    }

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        const tab_height: Pixels = 40;
        var x = bounds.origin.x;

        // Background for boxed variant
        if (self.variant == .boxed and self.background != null) {
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bounds.origin.y, bounds.size.width, tab_height),
                .background = .{ .solid = self.background.? },
                .corner_radii = .{ .top_left = 8, .top_right = 8, .bottom_left = 0, .bottom_right = 0 },
            }) catch {};
        }

        // Draw tabs
        for (self.tabs.items, 0..) |tab, i| {
            const tab_width = @as(Pixels, @floatFromInt(tab.label.len)) * 8 + 32;
            const is_selected = i == self.selected;
            const is_hovered = self.hovered_tab == i;
            const is_disabled = tab.disabled;

            const tab_bounds = Bounds(Pixels).fromXYWH(x, bounds.origin.y, tab_width, tab_height);

            // Tab background/styling based on variant
            switch (self.variant) {
                .underline => {
                    // Just underline for selected
                    if (is_selected) {
                        ctx.scene.insertQuad(.{
                            .bounds = Bounds(Pixels).fromXYWH(x, bounds.origin.y + tab_height - 2, tab_width, 2),
                            .background = .{ .solid = self.active_color },
                        }) catch {};
                    }
                },
                .pills => {
                    if (is_selected) {
                        ctx.scene.insertQuad(.{
                            .bounds = Bounds(Pixels).fromXYWH(x + 4, bounds.origin.y + 4, tab_width - 8, tab_height - 8),
                            .background = .{ .solid = self.active_color },
                            .corner_radii = Corners(Pixels).all(6),
                        }) catch {};
                    } else if (is_hovered and !is_disabled) {
                        ctx.scene.insertQuad(.{
                            .bounds = Bounds(Pixels).fromXYWH(x + 4, bounds.origin.y + 4, tab_width - 8, tab_height - 8),
                            .background = .{ .solid = color_mod.rgb(0x2d3748) },
                            .corner_radii = Corners(Pixels).all(6),
                        }) catch {};
                    }
                },
                .boxed => {
                    if (is_selected) {
                        ctx.scene.insertQuad(.{
                            .bounds = tab_bounds,
                            .background = .{ .solid = color_mod.rgb(0x1a202c) },
                            .corner_radii = .{ .top_left = 8, .top_right = 8, .bottom_left = 0, .bottom_right = 0 },
                            .border_widths = .{ .top = 1, .left = 1, .right = 1, .bottom = 0 },
                            .border_color = color_mod.rgb(0x4a5568),
                        }) catch {};
                    }
                },
            }

            // Tab label placeholder
            const text_color = if (is_disabled)
                color_mod.rgb(0x4a5568)
            else if (is_selected)
                (if (self.variant == .pills) color_mod.rgb(0xffffff) else self.active_color)
            else if (is_hovered)
                self.active_color.adjustLightness(0.1)
            else
                self.inactive_color;

            const text_width = @as(Pixels, @floatFromInt(tab.label.len)) * 8;
            const text_x = x + (tab_width - text_width) / 2;
            const text_y = bounds.origin.y + (tab_height - 12) / 2;

            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(text_x, text_y, text_width, 12),
                .background = .{ .solid = text_color.withAlpha(0.5) },
                .corner_radii = Corners(Pixels).all(2),
            }) catch {};

            x += tab_width;
        }

        // Underline for underline variant (full width)
        if (self.variant == .underline) {
            ctx.scene.insertQuad(.{
                .bounds = Bounds(Pixels).fromXYWH(bounds.origin.x, bounds.origin.y + tab_height - 1, bounds.size.width, 1),
                .background = .{ .solid = color_mod.rgb(0x4a5568) },
            }) catch {};
        }

        // Paint selected content
        if (self.selected < self.content_list.items.len) {
            const content_y = bounds.origin.y + tab_height + 8;
            const content_bounds = Bounds(Pixels).fromXYWH(
                bounds.origin.x,
                content_y,
                bounds.size.width,
                bounds.size.height - tab_height - 8,
            );
            self.content_list.items[self.selected].paint(content_bounds, ctx);
        }
    }
};

/// Helper function
pub fn tabs(allocator: Allocator) *Tabs {
    return Tabs.init(allocator);
}

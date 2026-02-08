//! Text element for zapui.
//! Renders styled text using the text system.

const std = @import("std");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const layout_mod = @import("../layout.zig");
const element_mod = @import("../element.zig");
const text_system_mod = @import("../text_system.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Bounds = geometry.Bounds;
const Hsla = color_mod.Hsla;
const LayoutId = layout_mod.LayoutId;
const LayoutStyle = layout_mod.LayoutStyle;
const AvailableSpace = layout_mod.AvailableSpace;
const RenderContext = element_mod.RenderContext;
const AnyElement = element_mod.AnyElement;
const intoAnyElement = element_mod.intoAnyElement;
const TextSystem = text_system_mod.TextSystem;
const FontId = text_system_mod.FontId;

/// Text alignment
pub const TextAlign = enum {
    left,
    center,
    right,
};

/// Text element
pub const Text = struct {
    const Self = @This();

    allocator: Allocator,
    content: []const u8,
    font_id: ?FontId = null,
    font_size: Pixels = 16,
    text_color: Hsla = color_mod.rgb(0xffffff),
    text_align: TextAlign = .left,
    line_height: ?f32 = null,

    // Cached measurements
    measured_width: Pixels = 0,
    measured_height: Pixels = 0,

    pub fn init(allocator: Allocator, content: []const u8) *Text {
        const t = allocator.create(Text) catch @panic("OOM");
        t.* = .{
            .allocator = allocator,
            .content = content,
        };
        return t;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.destroy(self);
    }

    // ========================================================================
    // Fluent builder API
    // ========================================================================

    pub fn font(self: *Self, id: FontId) *Self {
        self.font_id = id;
        return self;
    }

    pub fn size(self: *Self, s: Pixels) *Self {
        self.font_size = s;
        return self;
    }

    pub fn textColor(self: *Self, c: Hsla) *Self {
        self.text_color = c;
        return self;
    }

    pub fn alignment(self: *Self, a: TextAlign) *Self {
        self.text_align = a;
        return self;
    }

    pub fn lineHeight(self: *Self, lh: f32) *Self {
        self.line_height = lh;
        return self;
    }

    // Size shortcuts
    pub fn xs(self: *Self) *Self { return self.size(12); }
    pub fn sm(self: *Self) *Self { return self.size(14); }
    pub fn base(self: *Self) *Self { return self.size(16); }
    pub fn lg(self: *Self) *Self { return self.size(18); }
    pub fn xl(self: *Self) *Self { return self.size(20); }
    pub fn xl2(self: *Self) *Self { return self.size(24); }
    pub fn xl3(self: *Self) *Self { return self.size(30); }
    pub fn xl4(self: *Self) *Self { return self.size(36); }

    pub fn build(self: *Self) AnyElement {
        return intoAnyElement(Text, self);
    }

    // ========================================================================
    // Element interface
    // ========================================================================

    pub fn requestLayout(self: *Self, ctx: *RenderContext) LayoutId {
        // Measure text if we have a text system
        // For now, estimate based on font size
        self.measured_width = @as(Pixels, @floatFromInt(self.content.len)) * self.font_size * 0.6;
        self.measured_height = self.font_size * (self.line_height orelse 1.4);

        return ctx.layout_engine.createNode(.{
            .size = .{
                .width = .{ .px = self.measured_width },
                .height = .{ .px = self.measured_height },
            },
        }, &.{}) catch 0;
    }

    pub fn prepaint(_: *Self, _: Bounds(Pixels), _: *RenderContext) void {}

    pub fn paint(self: *Self, bounds: Bounds(Pixels), ctx: *RenderContext) void {
        // Get text system from context if available
        // For now, render as placeholder or use scene directly
        const x = switch (self.text_align) {
            .left => bounds.origin.x,
            .center => bounds.origin.x + (bounds.size.width - self.measured_width) / 2,
            .right => bounds.origin.x + bounds.size.width - self.measured_width,
        };
        const y = bounds.origin.y + self.font_size;

        // We need access to a text system - for now just render a placeholder
        // In production, this would call text_system.shapeText and render glyphs
        _ = x;
        _ = y;
        _ = ctx;
    }
};

/// Helper function to create a text element
pub fn text(allocator: Allocator, content: []const u8) *Text {
    return Text.init(allocator, content);
}

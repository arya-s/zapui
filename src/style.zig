//! Style definitions for zapui elements.
//! CSS-like styling with flexbox layout properties.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");

const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Edges = geometry.Edges;
const Corners = geometry.Corners;
const Hsla = color.Hsla;

// ============================================================================
// Layout enums
// ============================================================================

/// Display type (flex or none)
pub const Display = enum {
    flex,
    block,
    none,
};

/// Position type
pub const Position = enum {
    relative,
    absolute,
};

/// Overflow behavior
pub const Overflow = enum {
    visible,
    hidden,
    scroll,
};

/// Flex direction
pub const FlexDirection = enum {
    row,
    row_reverse,
    column,
    column_reverse,

    pub fn isRow(self: FlexDirection) bool {
        return self == .row or self == .row_reverse;
    }

    pub fn isColumn(self: FlexDirection) bool {
        return self == .column or self == .column_reverse;
    }

    pub fn isReverse(self: FlexDirection) bool {
        return self == .row_reverse or self == .column_reverse;
    }
};

/// Flex wrap
pub const FlexWrap = enum {
    no_wrap,
    wrap,
    wrap_reverse,
};

/// Align items (cross axis)
pub const AlignItems = enum {
    flex_start,
    flex_end,
    center,
    stretch,
    baseline,
};

/// Align self (overrides AlignItems for a single child)
pub const AlignSelf = enum {
    auto,
    flex_start,
    flex_end,
    center,
    stretch,
    baseline,
};

/// Align content (for wrapped flex containers)
pub const AlignContent = enum {
    flex_start,
    flex_end,
    center,
    stretch,
    space_between,
    space_around,
    space_evenly,
};

/// Justify content (main axis)
pub const JustifyContent = enum {
    flex_start,
    flex_end,
    center,
    space_between,
    space_around,
    space_evenly,
};

// ============================================================================
// Length type
// ============================================================================

/// A length value that can be pixels, rems, percent, or auto.
pub const Length = union(enum) {
    px: Pixels,
    rems: f32,
    percent: f32,
    auto,

    pub const zero = Length{ .px = 0 };

    /// Resolve to pixels given parent size and rem base
    pub fn resolve(self: Length, parent_size: ?Pixels, rem_size: Pixels) ?Pixels {
        return switch (self) {
            .px => |v| v,
            .rems => |v| v * rem_size,
            .percent => |v| if (parent_size) |ps| ps * v / 100.0 else null,
            .auto => null,
        };
    }

    /// Check if this is auto
    pub fn isAuto(self: Length) bool {
        return self == .auto;
    }
};

/// Helper to create a pixel length
pub fn px(value: f32) Length {
    return .{ .px = value };
}

/// Helper to create a rem length
pub fn rems(value: f32) Length {
    return .{ .rems = value };
}

/// Helper to create a percent length
pub fn percent(value: f32) Length {
    return .{ .percent = value };
}

/// Auto length
pub const auto = Length.auto;

// ============================================================================
// Background
// ============================================================================

/// Background fill type
pub const Background = union(enum) {
    solid: Hsla,
    // Future: gradient, image
};

// ============================================================================
// Shadow
// ============================================================================

/// Box shadow definition
pub const BoxShadow = struct {
    color: Hsla = color.black().withAlpha(0.25),
    blur_radius: Pixels = 0,
    spread_radius: Pixels = 0,
    offset: Point(Pixels) = Point(Pixels).zero,
};

// ============================================================================
// Style struct
// ============================================================================

/// Complete style definition for an element.
pub const Style = struct {
    // Display & positioning
    display: Display = .flex,
    position: Position = .relative,
    overflow: Point(Overflow) = .{ .x = .visible, .y = .visible },

    // Position offsets (for absolute positioning)
    inset: Edges(?Length) = .{ .top = null, .right = null, .bottom = null, .left = null },

    // Flexbox container properties
    flex_direction: FlexDirection = .row,
    flex_wrap: FlexWrap = .no_wrap,
    align_items: ?AlignItems = null,
    align_content: ?AlignContent = null,
    justify_content: ?JustifyContent = null,
    gap: Size(Length) = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } },

    // Flexbox item properties
    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,
    flex_basis: Length = .auto,
    align_self: ?AlignSelf = null,
    order: i32 = 0,

    // Sizing
    size: Size(Length) = .{ .width = .auto, .height = .auto },
    min_size: Size(Length) = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } },
    max_size: Size(Length) = .{ .width = .auto, .height = .auto },
    aspect_ratio: ?f32 = null,

    // Spacing
    padding: Edges(Length) = Edges(Length){ .top = .{ .px = 0 }, .right = .{ .px = 0 }, .bottom = .{ .px = 0 }, .left = .{ .px = 0 } },
    margin: Edges(Length) = Edges(Length){ .top = .{ .px = 0 }, .right = .{ .px = 0 }, .bottom = .{ .px = 0 }, .left = .{ .px = 0 } },

    // Border
    border_widths: Edges(Pixels) = Edges(Pixels).zero,
    border_color: ?Hsla = null,

    // Corner radius
    corner_radii: Corners(Pixels) = Corners(Pixels).zero,

    // Background
    background: ?Background = null,

    // Shadow
    box_shadow: ?BoxShadow = null,

    // Text styling (inherited)
    text_color: ?Hsla = null,
    font_size: ?Pixels = null,
    font_weight: ?FontWeight = null,
    line_height: ?f32 = null,

    // Effects
    opacity: f32 = 1.0,
    z_index: ?i32 = null,
    visibility: Visibility = .visible,

    // Cursor (for interactivity hints)
    cursor: ?Cursor = null,

    /// Create a default style
    pub fn init() Style {
        return .{};
    }

    /// Check if the element should render
    pub fn isVisible(self: Style) bool {
        return self.display != .none and self.visibility == .visible and self.opacity > 0;
    }

    /// Check if the element has any visual content (background, border, shadow)
    pub fn hasVisualContent(self: Style) bool {
        return self.background != null or
            (self.border_color != null and !self.border_widths.eql(Edges(Pixels).zero)) or
            self.box_shadow != null;
    }

    /// Get the effective align-items (with default based on flex direction)
    pub fn effectiveAlignItems(self: Style) AlignItems {
        return self.align_items orelse .stretch;
    }

    /// Get the effective justify-content (with default)
    pub fn effectiveJustifyContent(self: Style) JustifyContent {
        return self.justify_content orelse .flex_start;
    }
};

// ============================================================================
// Additional style types
// ============================================================================

pub const FontWeight = enum {
    thin, // 100
    extra_light, // 200
    light, // 300
    normal, // 400
    medium, // 500
    semi_bold, // 600
    bold, // 700
    extra_bold, // 800
    black, // 900

    pub fn toNumeric(self: FontWeight) u16 {
        return switch (self) {
            .thin => 100,
            .extra_light => 200,
            .light => 300,
            .normal => 400,
            .medium => 500,
            .semi_bold => 600,
            .bold => 700,
            .extra_bold => 800,
            .black => 900,
        };
    }
};

pub const Visibility = enum {
    visible,
    hidden,
};

pub const Cursor = enum {
    default,
    pointer,
    text,
    move,
    not_allowed,
    crosshair,
    grab,
    grabbing,
    resize_ew,
    resize_ns,
    resize_nwse,
    resize_nesw,
};

// ============================================================================
// Style presets (common patterns)
// ============================================================================

/// Common spacing values (like Tailwind's spacing scale)
pub const Spacing = struct {
    pub const _0: Length = .{ .px = 0 };
    pub const _0_5: Length = .{ .px = 2 };
    pub const _1: Length = .{ .px = 4 };
    pub const _1_5: Length = .{ .px = 6 };
    pub const _2: Length = .{ .px = 8 };
    pub const _2_5: Length = .{ .px = 10 };
    pub const _3: Length = .{ .px = 12 };
    pub const _3_5: Length = .{ .px = 14 };
    pub const _4: Length = .{ .px = 16 };
    pub const _5: Length = .{ .px = 20 };
    pub const _6: Length = .{ .px = 24 };
    pub const _7: Length = .{ .px = 28 };
    pub const _8: Length = .{ .px = 32 };
    pub const _9: Length = .{ .px = 36 };
    pub const _10: Length = .{ .px = 40 };
    pub const _11: Length = .{ .px = 44 };
    pub const _12: Length = .{ .px = 48 };
    pub const _14: Length = .{ .px = 56 };
    pub const _16: Length = .{ .px = 64 };
    pub const _20: Length = .{ .px = 80 };
    pub const _24: Length = .{ .px = 96 };
    pub const _28: Length = .{ .px = 112 };
    pub const _32: Length = .{ .px = 128 };
    pub const _36: Length = .{ .px = 144 };
    pub const _40: Length = .{ .px = 160 };
    pub const _44: Length = .{ .px = 176 };
    pub const _48: Length = .{ .px = 192 };
    pub const _52: Length = .{ .px = 208 };
    pub const _56: Length = .{ .px = 224 };
    pub const _60: Length = .{ .px = 240 };
    pub const _64: Length = .{ .px = 256 };
    pub const _72: Length = .{ .px = 288 };
    pub const _80: Length = .{ .px = 320 };
    pub const _96: Length = .{ .px = 384 };
};

/// Common border radius values
pub const Radius = struct {
    pub const none: Pixels = 0;
    pub const sm: Pixels = 2;
    pub const default: Pixels = 4;
    pub const md: Pixels = 6;
    pub const lg: Pixels = 8;
    pub const xl: Pixels = 12;
    pub const xl2: Pixels = 16;
    pub const xl3: Pixels = 24;
    pub const full: Pixels = 9999;
};

/// Common font sizes
pub const FontSize = struct {
    pub const xs: Pixels = 12;
    pub const sm: Pixels = 14;
    pub const base: Pixels = 16;
    pub const lg: Pixels = 18;
    pub const xl: Pixels = 20;
    pub const xl2: Pixels = 24;
    pub const xl3: Pixels = 30;
    pub const xl4: Pixels = 36;
    pub const xl5: Pixels = 48;
    pub const xl6: Pixels = 60;
    pub const xl7: Pixels = 72;
    pub const xl8: Pixels = 96;
    pub const xl9: Pixels = 128;
};

// ============================================================================
// Tests
// ============================================================================

test "Length resolve" {
    try std.testing.expectEqual(@as(?Pixels, 100), (Length{ .px = 100 }).resolve(null, 16));
    try std.testing.expectEqual(@as(?Pixels, 32), (Length{ .rems = 2 }).resolve(null, 16));
    try std.testing.expectEqual(@as(?Pixels, 50), (Length{ .percent = 50 }).resolve(100, 16));
    try std.testing.expectEqual(@as(?Pixels, null), (Length{ .auto = {} }).resolve(null, 16));
    try std.testing.expectEqual(@as(?Pixels, null), (Length{ .percent = 50 }).resolve(null, 16));
}

test "Style defaults" {
    const s = Style.init();
    try std.testing.expectEqual(Display.flex, s.display);
    try std.testing.expectEqual(Position.relative, s.position);
    try std.testing.expectEqual(FlexDirection.row, s.flex_direction);
    try std.testing.expectEqual(@as(f32, 0), s.flex_grow);
    try std.testing.expectEqual(@as(f32, 1), s.flex_shrink);
    try std.testing.expect(s.flex_basis.isAuto());
}

test "FlexDirection helpers" {
    try std.testing.expect(FlexDirection.row.isRow());
    try std.testing.expect(FlexDirection.row_reverse.isRow());
    try std.testing.expect(!FlexDirection.column.isRow());

    try std.testing.expect(FlexDirection.column.isColumn());
    try std.testing.expect(FlexDirection.column_reverse.isColumn());
    try std.testing.expect(!FlexDirection.row.isColumn());

    try std.testing.expect(FlexDirection.row_reverse.isReverse());
    try std.testing.expect(FlexDirection.column_reverse.isReverse());
    try std.testing.expect(!FlexDirection.row.isReverse());
}

test "Style visibility checks" {
    var s = Style.init();
    try std.testing.expect(s.isVisible());

    s.display = .none;
    try std.testing.expect(!s.isVisible());

    s.display = .flex;
    s.visibility = .hidden;
    try std.testing.expect(!s.isVisible());

    s.visibility = .visible;
    s.opacity = 0;
    try std.testing.expect(!s.isVisible());
}

test "Style has visual content" {
    var s = Style.init();
    try std.testing.expect(!s.hasVisualContent());

    s.background = .{ .solid = color.red() };
    try std.testing.expect(s.hasVisualContent());

    s = Style.init();
    s.border_color = color.black();
    s.border_widths = Edges(Pixels).all(1);
    try std.testing.expect(s.hasVisualContent());
}

test "Spacing presets" {
    try std.testing.expectEqual(@as(Pixels, 0), Spacing._0.px);
    try std.testing.expectEqual(@as(Pixels, 16), Spacing._4.px);
    try std.testing.expectEqual(@as(Pixels, 32), Spacing._8.px);
}

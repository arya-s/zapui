//! Style types for Taffy layout
//!
//! Zig port of taffy/src/style/*.rs

const std = @import("std");
const geo = @import("geometry.zig");

const Size = geo.Size;
const Rect = geo.Rect;
const Point = geo.Point;
const Line = geo.Line;
const AvailableSpace = geo.AvailableSpace;

pub const FlexDirection = geo.FlexDirection;
pub const AbsoluteAxis = geo.AbsoluteAxis;

// ============================================================================
// Dimension types
// ============================================================================

/// A unit of length
pub const LengthPercentage = union(enum) {
    /// A fixed length in pixels
    length: f32,
    /// A percentage of the parent's size
    percent: f32,

    pub const ZERO: LengthPercentage = .{ .length = 0 };

    pub fn resolve(self: LengthPercentage, parent_size: ?f32) ?f32 {
        return switch (self) {
            .length => |v| v,
            .percent => |p| if (parent_size) |ps| ps * p else null,
        };
    }

    pub fn resolveOrZero(self: LengthPercentage, parent_size: ?f32) f32 {
        return self.resolve(parent_size) orelse 0;
    }
};

/// A unit of length that can be auto
pub const LengthPercentageAuto = union(enum) {
    /// A fixed length in pixels
    length: f32,
    /// A percentage of the parent's size
    percent: f32,
    /// Automatically determined
    auto,

    pub const ZERO: LengthPercentageAuto = .{ .length = 0 };
    pub const AUTO: LengthPercentageAuto = .auto;

    pub fn resolve(self: LengthPercentageAuto, parent_size: ?f32) ?f32 {
        return switch (self) {
            .length => |v| v,
            .percent => |p| if (parent_size) |ps| ps * p else null,
            .auto => null,
        };
    }

    pub fn resolveOrZero(self: LengthPercentageAuto, parent_size: ?f32) f32 {
        return self.resolve(parent_size) orelse 0;
    }

    pub fn isAuto(self: LengthPercentageAuto) bool {
        return self == .auto;
    }

    pub fn intoLengthPercentage(self: LengthPercentageAuto) ?LengthPercentage {
        return switch (self) {
            .length => |v| .{ .length = v },
            .percent => |p| .{ .percent = p },
            .auto => null,
        };
    }
};

/// A dimension that can be auto, a length, a percentage, or content-based
pub const Dimension = union(enum) {
    /// A fixed length in pixels
    length: f32,
    /// A percentage of the parent's size
    percent: f32,
    /// Automatically determined
    auto,

    pub const ZERO: Dimension = .{ .length = 0 };
    pub const AUTO: Dimension = .auto;

    pub fn resolve(self: Dimension, parent_size: ?f32) ?f32 {
        return switch (self) {
            .length => |v| v,
            .percent => |p| if (parent_size) |ps| ps * p else null,
            .auto => null,
        };
    }

    pub fn isAuto(self: Dimension) bool {
        return self == .auto;
    }

    pub fn intoLengthPercentage(self: Dimension) ?LengthPercentage {
        return switch (self) {
            .length => |v| .{ .length = v },
            .percent => |p| .{ .percent = p },
            .auto => null,
        };
    }
};

// ============================================================================
// Alignment
// ============================================================================

/// How items are aligned on the cross axis
pub const AlignItems = enum {
    flex_start,
    flex_end,
    center,
    baseline,
    stretch,

    pub fn toAlignSelf(self: AlignItems) AlignSelf {
        return switch (self) {
            .flex_start => .flex_start,
            .flex_end => .flex_end,
            .center => .center,
            .baseline => .baseline,
            .stretch => .stretch,
        };
    }
};

/// How a single item is aligned on the cross axis
pub const AlignSelf = enum {
    auto,
    flex_start,
    flex_end,
    center,
    baseline,
    stretch,
};

/// How content is aligned on the cross axis when there is extra space
pub const AlignContent = enum {
    flex_start,
    flex_end,
    center,
    stretch,
    space_between,
    space_around,
    space_evenly,
};

/// How items are aligned on the main axis
pub const JustifyContent = enum {
    flex_start,
    flex_end,
    center,
    space_between,
    space_around,
    space_evenly,
};

/// How items are aligned (for both main and cross axis)
pub const JustifyItems = enum {
    flex_start,
    flex_end,
    center,
    baseline,
    stretch,
};

// ============================================================================
// Other style properties
// ============================================================================

/// How to display an element
pub const Display = enum {
    flex,
    block,
    grid,
    none,
};

/// How to position an element
pub const Position = enum {
    relative,
    absolute,
};

/// How to wrap flex items
pub const FlexWrap = enum {
    no_wrap,
    wrap,
    wrap_reverse,

    pub fn isWrap(self: FlexWrap) bool {
        return self != .no_wrap;
    }

    pub fn isReverse(self: FlexWrap) bool {
        return self == .wrap_reverse;
    }
};

/// How to handle overflow
pub const Overflow = enum {
    visible,
    hidden,
    scroll,

    pub fn isScrollContainer(self: Overflow) bool {
        return self == .scroll;
    }
};

/// How to size a box
pub const BoxSizing = enum {
    border_box,
    content_box,
};

// ============================================================================
// Style struct
// ============================================================================

/// The complete style for a node
pub const Style = struct {
    /// How to display the node
    display: Display = .flex,
    /// How to position the node
    position: Position = .relative,
    /// Overflow behavior
    overflow: Point(Overflow) = .{ .x = .visible, .y = .visible },
    /// Scrollbar width
    scrollbar_width: f32 = 0,

    // Flexbox container properties
    /// Flex direction
    flex_direction: FlexDirection = .row,
    /// Flex wrap
    flex_wrap: FlexWrap = .no_wrap,
    /// Align items on cross axis
    align_items: ?AlignItems = null,
    /// Align content (multiple lines)
    align_content: ?AlignContent = null,
    /// Justify content on main axis
    justify_content: ?JustifyContent = null,
    /// Justify items
    justify_items: ?JustifyItems = null,
    /// Gap between items
    gap: Size(LengthPercentage) = .{ .width = LengthPercentage.ZERO, .height = LengthPercentage.ZERO },

    // Flexbox item properties
    /// Align self
    align_self: ?AlignSelf = null,
    /// Justify self
    justify_self: ?AlignSelf = null,
    /// Flex grow
    flex_grow: f32 = 0.0,
    /// Flex shrink
    flex_shrink: f32 = 1.0,
    /// Flex basis
    flex_basis: Dimension = .auto,

    // Size properties
    /// Width
    size: Size(Dimension) = .{ .width = .auto, .height = .auto },
    /// Minimum size
    min_size: Size(Dimension) = .{ .width = .auto, .height = .auto },
    /// Maximum size
    max_size: Size(Dimension) = .{ .width = .auto, .height = .auto },
    /// Aspect ratio
    aspect_ratio: ?f32 = null,

    // Spacing properties
    /// Margin
    margin: Rect(LengthPercentageAuto) = Rect(LengthPercentageAuto).all(LengthPercentageAuto.ZERO),
    /// Padding
    padding: Rect(LengthPercentage) = Rect(LengthPercentage).all(LengthPercentage.ZERO),
    /// Border
    border: Rect(LengthPercentage) = Rect(LengthPercentage).all(LengthPercentage.ZERO),

    // Inset (for positioned elements)
    /// Inset
    inset: Rect(LengthPercentageAuto) = Rect(LengthPercentageAuto).all(LengthPercentageAuto.AUTO),

    // Box sizing
    /// Box sizing model
    box_sizing: BoxSizing = .border_box,

    /// Default style
    pub const DEFAULT: Style = .{};

    // ========================================================================
    // Helper methods
    // ========================================================================

    /// Returns true if the node is absolutely positioned
    pub fn isAbsolutelyPositioned(self: *const Style) bool {
        return self.position == .absolute;
    }

    /// Get the aspect ratio
    pub fn getAspectRatio(self: *const Style) ?f32 {
        return self.aspect_ratio;
    }

    /// Get the box sizing mode
    pub fn getBoxSizing(self: *const Style) BoxSizing {
        return self.box_sizing;
    }

    /// Returns true if the node should be hidden (display: none)
    pub fn isDisplayNone(self: *const Style) bool {
        return self.display == .none;
    }

    /// Get the align items value, defaulting to stretch
    pub fn getAlignItems(self: *const Style) AlignItems {
        return self.align_items orelse .stretch;
    }

    /// Get the align self value, defaulting to the parent's align_items
    pub fn getAlignSelf(self: *const Style, parent_align_items: AlignItems) AlignSelf {
        const align_self = self.align_self orelse .auto;
        if (align_self == .auto) {
            return parent_align_items.toAlignSelf();
        }
        return align_self;
    }

    /// Get the justify content value, defaulting to flex_start
    pub fn getJustifyContent(self: *const Style) JustifyContent {
        return self.justify_content orelse .flex_start;
    }

    /// Get the align content value, defaulting to stretch
    pub fn getAlignContent(self: *const Style) AlignContent {
        return self.align_content orelse .stretch;
    }

    /// Is this a flex container that wraps
    pub fn isWrap(self: *const Style) bool {
        return self.flex_wrap.isWrap();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Style defaults" {
    const style = Style.DEFAULT;
    try std.testing.expectEqual(Display.flex, style.display);
    try std.testing.expectEqual(FlexDirection.row, style.flex_direction);
    try std.testing.expectEqual(@as(f32, 0.0), style.flex_grow);
    try std.testing.expectEqual(@as(f32, 1.0), style.flex_shrink);
}

test "LengthPercentage resolve" {
    const length = LengthPercentage{ .length = 100 };
    try std.testing.expectEqual(@as(?f32, 100), length.resolve(null));
    try std.testing.expectEqual(@as(?f32, 100), length.resolve(200));

    const percent = LengthPercentage{ .percent = 0.5 };
    try std.testing.expectEqual(@as(?f32, null), percent.resolve(null));
    try std.testing.expectEqual(@as(?f32, 100), percent.resolve(200));
}

test "Dimension auto" {
    const dim = Dimension.AUTO;
    try std.testing.expect(dim.isAuto());
    try std.testing.expectEqual(@as(?f32, null), dim.resolve(100));
}

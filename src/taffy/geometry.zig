//! Geometric primitives for Taffy layout
//!
//! Zig port of taffy/src/geometry.rs

const std = @import("std");

/// A 2D point
pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub const ZERO: Self = .{ .x = 0, .y = 0 };

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn mapFn(self: Self, comptime R: type, comptime f: fn (T) R) Point(R) {
            return .{ .x = f(self.x), .y = f(self.y) };
        }

        pub fn get(self: Self, axis: AbsoluteAxis) T {
            return switch (axis) {
                .horizontal => self.x,
                .vertical => self.y,
            };
        }

        pub fn set(self: *Self, axis: AbsoluteAxis, value: T) void {
            switch (axis) {
                .horizontal => self.x = value,
                .vertical => self.y = value,
            }
        }
    };
}

/// A 2D size
pub fn Size(comptime T: type) type {
    return struct {
        const Self = @This();

        width: T,
        height: T,

        pub const ZERO: Self = .{ .width = 0, .height = 0 };

        pub fn init(width: T, height: T) Self {
            return .{ .width = width, .height = height };
        }

        pub fn zero() Self {
            return .{ .width = 0, .height = 0 };
        }

        pub fn mapFn(self: Self, comptime R: type, comptime f: fn (T) R) Size(R) {
            return .{ .width = f(self.width), .height = f(self.height) };
        }

        pub fn get(self: Self, axis: AbsoluteAxis) T {
            return switch (axis) {
                .horizontal => self.width,
                .vertical => self.height,
            };
        }

        pub fn set(self: *Self, axis: AbsoluteAxis, value: T) void {
            switch (axis) {
                .horizontal => self.width = value,
                .vertical => self.height = value,
            }
        }

        pub fn setMain(self: *Self, dir: FlexDirection, value: T) void {
            self.set(dir.mainAxis(), value);
        }

        pub fn setCross(self: *Self, dir: FlexDirection, value: T) void {
            self.set(dir.crossAxis(), value);
        }

        pub fn main(self: Self, dir: FlexDirection) T {
            return self.get(dir.mainAxis());
        }

        pub fn cross(self: Self, dir: FlexDirection) T {
            return self.get(dir.crossAxis());
        }
    };
}

/// A rectangle defined by left/right/top/bottom edges
pub fn Rect(comptime T: type) type {
    return struct {
        const Self = @This();

        left: T,
        right: T,
        top: T,
        bottom: T,

        pub const ZERO: Self = .{ .left = 0, .right = 0, .top = 0, .bottom = 0 };

        pub fn init(left: T, right: T, top: T, bottom: T) Self {
            return .{ .left = left, .right = right, .top = top, .bottom = bottom };
        }

        pub fn all(value: T) Self {
            return .{ .left = value, .right = value, .top = value, .bottom = value };
        }

        pub fn horizontal(self: Self) T {
            return self.left + self.right;
        }

        pub fn vertical(self: Self) T {
            return self.top + self.bottom;
        }

        pub fn sum(self: Self) Size(T) {
            return .{ .width = self.horizontal(), .height = self.vertical() };
        }

        pub fn mainAxisSum(self: Self, dir: FlexDirection) T {
            return switch (dir.mainAxis()) {
                .horizontal => self.horizontal(),
                .vertical => self.vertical(),
            };
        }

        pub fn crossAxisSum(self: Self, dir: FlexDirection) T {
            return switch (dir.crossAxis()) {
                .horizontal => self.horizontal(),
                .vertical => self.vertical(),
            };
        }

        pub fn mainStart(self: Self, dir: FlexDirection) T {
            return switch (dir) {
                .row => self.left,
                .row_reverse => self.right,
                .column => self.top,
                .column_reverse => self.bottom,
            };
        }

        pub fn mainEnd(self: Self, dir: FlexDirection) T {
            return switch (dir) {
                .row => self.right,
                .row_reverse => self.left,
                .column => self.bottom,
                .column_reverse => self.top,
            };
        }

        pub fn crossStart(self: Self, dir: FlexDirection) T {
            return switch (dir) {
                .row, .row_reverse => self.top,
                .column, .column_reverse => self.left,
            };
        }

        pub fn crossEnd(self: Self, dir: FlexDirection) T {
            return switch (dir) {
                .row, .row_reverse => self.bottom,
                .column, .column_reverse => self.right,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .left = self.left + other.left,
                .right = self.right + other.right,
                .top = self.top + other.top,
                .bottom = self.bottom + other.bottom,
            };
        }
    };
}

/// A line defined by start and end points
pub fn Line(comptime T: type) type {
    return struct {
        const Self = @This();

        start: T,
        end: T,

        pub const FALSE: Line(bool) = .{ .start = false, .end = false };

        pub fn init(start: T, end: T) Self {
            return .{ .start = start, .end = end };
        }

        pub fn sum(self: Self) T {
            return self.start + self.end;
        }
    };
}

/// The simple absolute horizontal and vertical axis
pub const AbsoluteAxis = enum {
    horizontal,
    vertical,

    pub fn other(self: AbsoluteAxis) AbsoluteAxis {
        return switch (self) {
            .horizontal => .vertical,
            .vertical => .horizontal,
        };
    }
};

/// Flex direction
pub const FlexDirection = enum {
    row,
    column,
    row_reverse,
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

    pub fn mainAxis(self: FlexDirection) AbsoluteAxis {
        return switch (self) {
            .row, .row_reverse => .horizontal,
            .column, .column_reverse => .vertical,
        };
    }

    pub fn crossAxis(self: FlexDirection) AbsoluteAxis {
        return self.mainAxis().other();
    }
};

/// Available space for layout
pub const AvailableSpace = union(enum) {
    /// A definite amount of space
    definite: f32,
    /// The amount of space available is the min content size
    min_content,
    /// The amount of space available is the max content size
    max_content,

    pub fn isDefinite(self: AvailableSpace) bool {
        return self == .definite;
    }

    pub fn intoOption(self: AvailableSpace) ?f32 {
        return switch (self) {
            .definite => |v| v,
            else => null,
        };
    }

    pub fn unwrapOr(self: AvailableSpace, default: f32) f32 {
        return switch (self) {
            .definite => |v| v,
            else => default,
        };
    }

    pub fn unwrapOrElse(self: AvailableSpace, comptime f: fn () f32) f32 {
        return switch (self) {
            .definite => |v| v,
            else => f(),
        };
    }

    pub fn maybeMax(self: AvailableSpace, value: f32) AvailableSpace {
        return switch (self) {
            .definite => |v| .{ .definite = @max(v, value) },
            else => self,
        };
    }

    pub fn maybeMin(self: AvailableSpace, value: f32) AvailableSpace {
        return switch (self) {
            .definite => |v| .{ .definite = @min(v, value) },
            else => self,
        };
    }

    pub fn maybeSub(self: AvailableSpace, value: f32) AvailableSpace {
        return switch (self) {
            .definite => |v| .{ .definite = v - value },
            else => self,
        };
    }

    pub fn maybeAdd(self: AvailableSpace, value: f32) AvailableSpace {
        return switch (self) {
            .definite => |v| .{ .definite = v + value },
            else => self,
        };
    }

    pub fn computeFreeSpace(self: AvailableSpace, used: f32) f32 {
        return switch (self) {
            .definite => |v| v - used,
            .max_content => std.math.floatMax(f32),
            .min_content => 0.0,
        };
    }

    pub fn mapDefiniteValue(self: AvailableSpace, comptime f: fn (f32) f32) AvailableSpace {
        return switch (self) {
            .definite => |v| .{ .definite = f(v) },
            else => self,
        };
    }
};

// Tests
test "Point basic" {
    const p = Point(f32).init(10, 20);
    try std.testing.expectEqual(@as(f32, 10), p.x);
    try std.testing.expectEqual(@as(f32, 20), p.y);
}

test "Size basic" {
    const s = Size(f32).init(100, 200);
    try std.testing.expectEqual(@as(f32, 100), s.width);
    try std.testing.expectEqual(@as(f32, 200), s.height);
}

test "Rect horizontal/vertical" {
    const r = Rect(f32).init(10, 20, 30, 40);
    try std.testing.expectEqual(@as(f32, 30), r.horizontal());
    try std.testing.expectEqual(@as(f32, 70), r.vertical());
}

test "FlexDirection axes" {
    try std.testing.expectEqual(AbsoluteAxis.horizontal, FlexDirection.row.mainAxis());
    try std.testing.expectEqual(AbsoluteAxis.vertical, FlexDirection.row.crossAxis());
    try std.testing.expectEqual(AbsoluteAxis.vertical, FlexDirection.column.mainAxis());
    try std.testing.expectEqual(AbsoluteAxis.horizontal, FlexDirection.column.crossAxis());
}

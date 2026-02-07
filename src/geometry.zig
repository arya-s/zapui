//! Geometry primitives for zapui.
//! Generic types for points, sizes, bounds, edges, and corners.

const std = @import("std");

/// Pixel unit type
pub const Pixels = f32;

/// Scaled pixel unit type (for HiDPI)
pub const ScaledPixels = f32;

/// Rem unit type (relative to root font size)
pub const Rems = f32;

/// Helper to create a Pixels value
pub fn px(value: f32) Pixels {
    return value;
}

/// Helper to create a Rems value
pub fn rems(value: f32) Rems {
    return value;
}

/// A 2D point with x and y coordinates.
pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub const zero = Self{ .x = 0, .y = 0 };

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{ .x = self.x * factor, .y = self.y * factor };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }

        /// Convert to a different point type (useful for Pixels -> ScaledPixels)
        pub fn map(self: Self, comptime U: type, transform: fn (T) U) Point(U) {
            return .{ .x = transform(self.x), .y = transform(self.y) };
        }
    };
}

/// A 2D size with width and height.
pub fn Size(comptime T: type) type {
    return struct {
        const Self = @This();

        width: T,
        height: T,

        pub const zero = Self{ .width = 0, .height = 0 };

        pub fn init(width: T, height: T) Self {
            return .{ .width = width, .height = height };
        }

        pub fn square(side: T) Self {
            return .{ .width = side, .height = side };
        }

        pub fn area(self: Self) T {
            return self.width * self.height;
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{ .width = self.width * factor, .height = self.height * factor };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.width == other.width and self.height == other.height;
        }

        /// Convert to a different size type
        pub fn map(self: Self, comptime U: type, transform: fn (T) U) Size(U) {
            return .{ .width = transform(self.width), .height = transform(self.height) };
        }

        /// Convert to a Point (width -> x, height -> y)
        pub fn toPoint(self: Self) Point(T) {
            return .{ .x = self.width, .y = self.height };
        }
    };
}

/// A 2D bounding box with origin and size.
pub fn Bounds(comptime T: type) type {
    return struct {
        const Self = @This();

        origin: Point(T),
        size: Size(T),

        pub const zero = Self{ .origin = Point(T).zero, .size = Size(T).zero };

        pub fn init(origin: Point(T), size: Size(T)) Self {
            return .{ .origin = origin, .size = size };
        }

        pub fn fromXYWH(x_pos: T, y_pos: T, w: T, h: T) Self {
            return .{
                .origin = .{ .x = x_pos, .y = y_pos },
                .size = .{ .width = w, .height = h },
            };
        }

        pub fn fromCorners(top_left: Point(T), bottom_right: Point(T)) Self {
            return .{
                .origin = top_left,
                .size = .{
                    .width = bottom_right.x - top_left.x,
                    .height = bottom_right.y - top_left.y,
                },
            };
        }

        pub fn x(self: Self) T {
            return self.origin.x;
        }

        pub fn y(self: Self) T {
            return self.origin.y;
        }

        pub fn width(self: Self) T {
            return self.size.width;
        }

        pub fn height(self: Self) T {
            return self.size.height;
        }

        pub fn left(self: Self) T {
            return self.origin.x;
        }

        pub fn right(self: Self) T {
            return self.origin.x + self.size.width;
        }

        pub fn top(self: Self) T {
            return self.origin.y;
        }

        pub fn bottom(self: Self) T {
            return self.origin.y + self.size.height;
        }

        pub fn center(self: Self) Point(T) {
            return .{
                .x = self.origin.x + self.size.width / 2,
                .y = self.origin.y + self.size.height / 2,
            };
        }

        pub fn topLeft(self: Self) Point(T) {
            return self.origin;
        }

        pub fn topRight(self: Self) Point(T) {
            return .{ .x = self.right(), .y = self.top() };
        }

        pub fn bottomLeft(self: Self) Point(T) {
            return .{ .x = self.left(), .y = self.bottom() };
        }

        pub fn bottomRight(self: Self) Point(T) {
            return .{ .x = self.right(), .y = self.bottom() };
        }

        /// Check if a point is inside this bounds
        pub fn contains(self: Self, point: Point(T)) bool {
            return point.x >= self.left() and point.x < self.right() and
                point.y >= self.top() and point.y < self.bottom();
        }

        /// Check if two bounds intersect
        pub fn intersects(self: Self, other: Self) bool {
            return self.left() < other.right() and self.right() > other.left() and
                self.top() < other.bottom() and self.bottom() > other.top();
        }

        /// Compute the intersection of two bounds
        pub fn intersection(self: Self, other: Self) ?Self {
            const max_left = @max(self.left(), other.left());
            const min_right = @min(self.right(), other.right());
            const max_top = @max(self.top(), other.top());
            const min_bottom = @min(self.bottom(), other.bottom());

            if (max_left >= min_right or max_top >= min_bottom) {
                return null;
            }

            return Self.fromCorners(
                .{ .x = max_left, .y = max_top },
                .{ .x = min_right, .y = min_bottom },
            );
        }

        /// Compute the union (bounding box) of two bounds
        pub fn unionWith(self: Self, other: Self) Self {
            const min_left = @min(self.left(), other.left());
            const max_right = @max(self.right(), other.right());
            const min_top = @min(self.top(), other.top());
            const max_bottom = @max(self.bottom(), other.bottom());

            return Self.fromCorners(
                .{ .x = min_left, .y = min_top },
                .{ .x = max_right, .y = max_bottom },
            );
        }

        /// Offset the bounds by a point
        pub fn offset(self: Self, delta: Point(T)) Self {
            return .{ .origin = self.origin.add(delta), .size = self.size };
        }

        /// Inset the bounds by edges
        pub fn inset(self: Self, edges: Edges(T)) Self {
            return .{
                .origin = .{
                    .x = self.origin.x + edges.left,
                    .y = self.origin.y + edges.top,
                },
                .size = .{
                    .width = self.size.width - edges.left - edges.right,
                    .height = self.size.height - edges.top - edges.bottom,
                },
            };
        }

        /// Expand the bounds by edges
        pub fn expand(self: Self, edges: Edges(T)) Self {
            return .{
                .origin = .{
                    .x = self.origin.x - edges.left,
                    .y = self.origin.y - edges.top,
                },
                .size = .{
                    .width = self.size.width + edges.left + edges.right,
                    .height = self.size.height + edges.top + edges.bottom,
                },
            };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.origin.eql(other.origin) and self.size.eql(other.size);
        }

        /// Convert to a different bounds type
        pub fn map(self: Self, comptime U: type, transform: fn (T) U) Bounds(U) {
            return .{
                .origin = self.origin.map(U, transform),
                .size = self.size.map(U, transform),
            };
        }
    };
}

/// Edge values for top, right, bottom, left (like CSS padding/margin).
pub fn Edges(comptime T: type) type {
    return struct {
        const Self = @This();

        top: T,
        right: T,
        bottom: T,
        left: T,

        pub const zero = Self{ .top = 0, .right = 0, .bottom = 0, .left = 0 };

        pub fn all(value: T) Self {
            return .{ .top = value, .right = value, .bottom = value, .left = value };
        }

        pub fn symmetric(vert: T, horiz: T) Self {
            return .{ .top = vert, .right = horiz, .bottom = vert, .left = horiz };
        }

        pub fn axes(top_bottom: T, left_right: T) Self {
            return .{ .top = top_bottom, .right = left_right, .bottom = top_bottom, .left = left_right };
        }

        pub fn horizontal(self: Self) T {
            return self.left + self.right;
        }

        pub fn vertical(self: Self) T {
            return self.top + self.bottom;
        }

        pub fn toSize(self: Self) Size(T) {
            return .{ .width = self.horizontal(), .height = self.vertical() };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .top = self.top + other.top,
                .right = self.right + other.right,
                .bottom = self.bottom + other.bottom,
                .left = self.left + other.left,
            };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{
                .top = self.top * factor,
                .right = self.right * factor,
                .bottom = self.bottom * factor,
                .left = self.left * factor,
            };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.top == other.top and self.right == other.right and
                self.bottom == other.bottom and self.left == other.left;
        }

        /// Convert to a different edges type
        pub fn map(self: Self, comptime U: type, transform: fn (T) U) Edges(U) {
            return .{
                .top = transform(self.top),
                .right = transform(self.right),
                .bottom = transform(self.bottom),
                .left = transform(self.left),
            };
        }
    };
}

/// Corner values for top_left, top_right, bottom_right, bottom_left (like CSS border-radius).
pub fn Corners(comptime T: type) type {
    return struct {
        const Self = @This();

        top_left: T,
        top_right: T,
        bottom_right: T,
        bottom_left: T,

        pub const zero = Self{ .top_left = 0, .top_right = 0, .bottom_right = 0, .bottom_left = 0 };

        pub fn all(value: T) Self {
            return .{ .top_left = value, .top_right = value, .bottom_right = value, .bottom_left = value };
        }

        pub fn top(value: T) Self {
            return .{ .top_left = value, .top_right = value, .bottom_right = 0, .bottom_left = 0 };
        }

        pub fn bottom(value: T) Self {
            return .{ .top_left = 0, .top_right = 0, .bottom_right = value, .bottom_left = value };
        }

        pub fn leftSide(value: T) Self {
            return .{ .top_left = value, .top_right = 0, .bottom_right = 0, .bottom_left = value };
        }

        pub fn rightSide(value: T) Self {
            return .{ .top_left = 0, .top_right = value, .bottom_right = value, .bottom_left = 0 };
        }

        pub fn scale(self: Self, factor: T) Self {
            return .{
                .top_left = self.top_left * factor,
                .top_right = self.top_right * factor,
                .bottom_right = self.bottom_right * factor,
                .bottom_left = self.bottom_left * factor,
            };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.top_left == other.top_left and self.top_right == other.top_right and
                self.bottom_right == other.bottom_right and self.bottom_left == other.bottom_left;
        }

        /// Convert to a different corners type
        pub fn map(self: Self, comptime U: type, transform: fn (T) U) Corners(U) {
            return .{
                .top_left = transform(self.top_left),
                .top_right = transform(self.top_right),
                .bottom_right = transform(self.bottom_right),
                .bottom_left = transform(self.bottom_left),
            };
        }

        /// Get maximum corner radius
        pub fn max(self: Self) T {
            return @max(@max(self.top_left, self.top_right), @max(self.bottom_right, self.bottom_left));
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "Point operations" {
    const p1 = Point(f32).init(10, 20);
    const p2 = Point(f32).init(5, 10);

    try std.testing.expectEqual(Point(f32).init(15, 30), p1.add(p2));
    try std.testing.expectEqual(Point(f32).init(5, 10), p1.sub(p2));
    try std.testing.expectEqual(Point(f32).init(20, 40), p1.scale(2));
    try std.testing.expect(p1.eql(Point(f32).init(10, 20)));
}

test "Size operations" {
    const s1 = Size(f32).init(100, 200);

    try std.testing.expectEqual(@as(f32, 20000), s1.area());
    try std.testing.expectEqual(Size(f32).init(200, 400), s1.scale(2));
    try std.testing.expectEqual(Size(f32).square(50), Size(f32).init(50, 50));
}

test "Bounds operations" {
    const b1 = Bounds(f32).fromXYWH(10, 20, 100, 50);

    try std.testing.expectEqual(@as(f32, 10), b1.left());
    try std.testing.expectEqual(@as(f32, 110), b1.right());
    try std.testing.expectEqual(@as(f32, 20), b1.top());
    try std.testing.expectEqual(@as(f32, 70), b1.bottom());
    try std.testing.expectEqual(Point(f32).init(60, 45), b1.center());

    // Contains
    try std.testing.expect(b1.contains(Point(f32).init(50, 40)));
    try std.testing.expect(!b1.contains(Point(f32).init(5, 40)));

    // Intersection
    const b2 = Bounds(f32).fromXYWH(50, 40, 100, 50);
    const inter = b1.intersection(b2).?;
    try std.testing.expectEqual(@as(f32, 50), inter.left());
    try std.testing.expectEqual(@as(f32, 110), inter.right());
    try std.testing.expectEqual(@as(f32, 40), inter.top());
    try std.testing.expectEqual(@as(f32, 70), inter.bottom());

    // No intersection
    const b3 = Bounds(f32).fromXYWH(200, 200, 50, 50);
    try std.testing.expect(b1.intersection(b3) == null);

    // Union
    const uni = b1.unionWith(b2);
    try std.testing.expectEqual(@as(f32, 10), uni.left());
    try std.testing.expectEqual(@as(f32, 150), uni.right());
    try std.testing.expectEqual(@as(f32, 20), uni.top());
    try std.testing.expectEqual(@as(f32, 90), uni.bottom());
}

test "Bounds inset and expand" {
    const b = Bounds(f32).fromXYWH(10, 10, 100, 100);
    const edges = Edges(f32).all(5);

    const inset = b.inset(edges);
    try std.testing.expectEqual(@as(f32, 15), inset.left());
    try std.testing.expectEqual(@as(f32, 105), inset.right());
    try std.testing.expectEqual(@as(f32, 90), inset.width());

    const expanded = b.expand(edges);
    try std.testing.expectEqual(@as(f32, 5), expanded.left());
    try std.testing.expectEqual(@as(f32, 115), expanded.right());
    try std.testing.expectEqual(@as(f32, 110), expanded.width());
}

test "Edges operations" {
    const e1 = Edges(f32).all(10);
    try std.testing.expectEqual(@as(f32, 20), e1.horizontal());
    try std.testing.expectEqual(@as(f32, 20), e1.vertical());

    const e2 = Edges(f32).symmetric(5, 10);
    try std.testing.expectEqual(@as(f32, 5), e2.top);
    try std.testing.expectEqual(@as(f32, 10), e2.right);
    try std.testing.expectEqual(@as(f32, 5), e2.bottom);
    try std.testing.expectEqual(@as(f32, 10), e2.left);
}

test "Corners operations" {
    const c1 = Corners(f32).all(8);
    try std.testing.expectEqual(@as(f32, 8), c1.top_left);
    try std.testing.expectEqual(@as(f32, 8), c1.max());

    const c2 = Corners(f32).top(10);
    try std.testing.expectEqual(@as(f32, 10), c2.top_left);
    try std.testing.expectEqual(@as(f32, 10), c2.top_right);
    try std.testing.expectEqual(@as(f32, 0), c2.bottom_left);
}

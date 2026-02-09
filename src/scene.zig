//! Scene graph for zapui.
//! Collects rendering primitives (quads, shadows, sprites) for batched rendering.

const std = @import("std");
const geometry = @import("geometry.zig");
const color = @import("color.zig");
const style = @import("style.zig");

const Allocator = std.mem.Allocator;
const ScaledPixels = geometry.ScaledPixels;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Size = geometry.Size;
const Bounds = geometry.Bounds;
const Edges = geometry.Edges;
const Corners = geometry.Corners;
const Hsla = color.Hsla;
const Background = style.Background;

/// Draw order for z-sorting primitives
pub const DrawOrder = u32;

/// Border style for quads
pub const BorderStyle = enum {
    solid,
    dashed,
};

/// A quad primitive - the primary building block for UI rendering.
/// Supports backgrounds, borders, and rounded corners.
pub const Quad = struct {
    order: DrawOrder = 0,
    bounds: Bounds(ScaledPixels),
    background: ?Background = null,
    border_color: ?Hsla = null,
    border_widths: Edges(ScaledPixels) = Edges(ScaledPixels).zero,
    border_style: BorderStyle = .solid,
    corner_radii: Corners(ScaledPixels) = Corners(ScaledPixels).zero,
    content_mask: ?Bounds(ScaledPixels) = null,
};

/// A shadow primitive - renders a box shadow with blur.
pub const Shadow = struct {
    order: DrawOrder = 0,
    bounds: Bounds(ScaledPixels),
    corner_radii: Corners(ScaledPixels) = Corners(ScaledPixels).zero,
    blur_radius: ScaledPixels = 0,
    spread_radius: ScaledPixels = 0,
    color: Hsla = color.black().withAlpha(0.25),
    content_mask: ?Bounds(ScaledPixels) = null,
};

/// A monochrome sprite - used for text glyphs (single channel alpha mask).
pub const MonochromeSprite = struct {
    order: DrawOrder = 0,
    bounds: Bounds(ScaledPixels),
    tile_bounds: Bounds(f32), // UV coordinates in atlas
    color: Hsla = color.white(),
    content_mask: ?Bounds(ScaledPixels) = null,
};

/// A polychrome sprite - used for images (full RGBA).
pub const PolychromeSprite = struct {
    order: DrawOrder = 0,
    bounds: Bounds(ScaledPixels),
    tile_bounds: Bounds(f32), // UV coordinates in atlas
    content_mask: ?Bounds(ScaledPixels) = null,
};

/// Primitive type enumeration for batching
pub const PrimitiveKind = enum {
    quad,
    shadow,
    mono_sprite,
    poly_sprite,
};

/// A batch of primitives of the same type, ready for rendering
pub const PrimitiveBatch = union(PrimitiveKind) {
    quad: []const Quad,
    shadow: []const Shadow,
    mono_sprite: []const MonochromeSprite,
    poly_sprite: []const PolychromeSprite,
};

/// Scene collects all primitives for a frame and prepares them for rendering.
pub const Scene = struct {
    allocator: Allocator,
    quads: std.ArrayListUnmanaged(Quad),
    shadows: std.ArrayListUnmanaged(Shadow),
    mono_sprites: std.ArrayListUnmanaged(MonochromeSprite),
    poly_sprites: std.ArrayListUnmanaged(PolychromeSprite),
    next_order: DrawOrder = 0,

    pub fn init(allocator: Allocator) Scene {
        return .{
            .allocator = allocator,
            .quads = .{ .items = &.{}, .capacity = 0 },
            .shadows = .{ .items = &.{}, .capacity = 0 },
            .mono_sprites = .{ .items = &.{}, .capacity = 0 },
            .poly_sprites = .{ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *Scene) void {
        self.quads.deinit(self.allocator);
        self.shadows.deinit(self.allocator);
        self.mono_sprites.deinit(self.allocator);
        self.poly_sprites.deinit(self.allocator);
    }

    /// Clear all primitives for a new frame
    pub fn clear(self: *Scene) void {
        self.quads.clearRetainingCapacity();
        self.shadows.clearRetainingCapacity();
        self.mono_sprites.clearRetainingCapacity();
        self.poly_sprites.clearRetainingCapacity();
        self.next_order = 0;
    }

    /// Get the next draw order value (auto-incrementing)
    pub fn nextDrawOrder(self: *Scene) DrawOrder {
        const order = self.next_order;
        self.next_order += 1;
        return order;
    }

    /// Insert a quad into the scene
    pub fn insertQuad(self: *Scene, quad: Quad) !void {
        var q = quad;
        if (q.order == 0) {
            q.order = self.nextDrawOrder();
        }
        try self.quads.append(self.allocator, q);
    }

    /// Insert a shadow into the scene
    pub fn insertShadow(self: *Scene, shadow: Shadow) !void {
        var s = shadow;
        if (s.order == 0) {
            s.order = self.nextDrawOrder();
        }
        try self.shadows.append(self.allocator, s);
    }

    /// Insert a monochrome sprite (glyph) into the scene
    pub fn insertMonoSprite(self: *Scene, sprite: MonochromeSprite) !void {
        var s = sprite;
        if (s.order == 0) {
            s.order = self.nextDrawOrder();
        }
        try self.mono_sprites.append(self.allocator, s);
    }

    /// Insert a polychrome sprite (image) into the scene
    pub fn insertPolySprite(self: *Scene, sprite: PolychromeSprite) !void {
        var s = sprite;
        if (s.order == 0) {
            s.order = self.nextDrawOrder();
        }
        try self.poly_sprites.append(self.allocator, s);
    }

    /// Sort all primitives by draw order for correct rendering
    pub fn finish(self: *Scene) void {
        std.mem.sort(Quad, self.quads.items, {}, struct {
            fn lessThan(_: void, a: Quad, b: Quad) bool {
                return a.order < b.order;
            }
        }.lessThan);
        std.mem.sort(Shadow, self.shadows.items, {}, struct {
            fn lessThan(_: void, a: Shadow, b: Shadow) bool {
                return a.order < b.order;
            }
        }.lessThan);
        std.mem.sort(MonochromeSprite, self.mono_sprites.items, {}, struct {
            fn lessThan(_: void, a: MonochromeSprite, b: MonochromeSprite) bool {
                return a.order < b.order;
            }
        }.lessThan);
        std.mem.sort(PolychromeSprite, self.poly_sprites.items, {}, struct {
            fn lessThan(_: void, a: PolychromeSprite, b: PolychromeSprite) bool {
                return a.order < b.order;
            }
        }.lessThan);
    }

    /// Get quad slice for rendering
    pub fn getQuads(self: *const Scene) []const Quad {
        return self.quads.items;
    }

    /// Get shadow slice for rendering
    pub fn getShadows(self: *const Scene) []const Shadow {
        return self.shadows.items;
    }

    /// Get monochrome sprite slice for rendering
    pub fn getMonoSprites(self: *const Scene) []const MonochromeSprite {
        return self.mono_sprites.items;
    }

    /// Get polychrome sprite slice for rendering
    pub fn getPolySprites(self: *const Scene) []const PolychromeSprite {
        return self.poly_sprites.items;
    }

    /// Check if scene is empty
    pub fn isEmpty(self: *const Scene) bool {
        return self.quads.items.len == 0 and
            self.shadows.items.len == 0 and
            self.mono_sprites.items.len == 0 and
            self.poly_sprites.items.len == 0;
    }

    /// Get total primitive count
    pub fn primitiveCount(self: *const Scene) usize {
        return self.quads.items.len +
            self.shadows.items.len +
            self.mono_sprites.items.len +
            self.poly_sprites.items.len;
    }
};

// ============================================================================
// Helper functions to create primitives from styles
// ============================================================================

/// Create a quad from bounds and style
pub fn quadFromStyle(
    bounds: Bounds(ScaledPixels),
    s: style.Style,
    content_mask: ?Bounds(ScaledPixels),
) Quad {
    return .{
        .bounds = bounds,
        .background = s.background,
        .border_color = s.border_color,
        .border_widths = s.border_widths.map(ScaledPixels, struct {
            fn convert(v: Pixels) ScaledPixels {
                return v;
            }
        }.convert),
        .corner_radii = s.corner_radii.map(ScaledPixels, struct {
            fn convert(v: Pixels) ScaledPixels {
                return v;
            }
        }.convert),
        .content_mask = content_mask,
    };
}

/// Create a shadow from bounds and box shadow style
pub fn shadowFromStyle(
    bounds: Bounds(ScaledPixels),
    shadow: style.BoxShadow,
    corner_radii: Corners(Pixels),
    content_mask: ?Bounds(ScaledPixels),
) Shadow {
    // Expand bounds by blur radius for shadow rendering
    const expanded = bounds.expand(Edges(ScaledPixels).all(shadow.blur_radius + shadow.spread_radius));
    const offset_bounds = expanded.offset(Point(ScaledPixels).init(shadow.offset.x, shadow.offset.y));

    return .{
        .bounds = offset_bounds,
        .corner_radii = corner_radii.map(ScaledPixels, struct {
            fn convert(v: Pixels) ScaledPixels {
                return v;
            }
        }.convert),
        .blur_radius = shadow.blur_radius,
        .color = shadow.color,
        .content_mask = content_mask,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "Scene basic operations" {
    const allocator = std.testing.allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();

    try std.testing.expect(scene.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), scene.primitiveCount());

    // Insert a quad
    try scene.insertQuad(.{
        .bounds = Bounds(ScaledPixels).fromXYWH(10, 20, 100, 50),
        .background = .{ .solid = color.red() },
    });

    try std.testing.expect(!scene.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), scene.primitiveCount());
    try std.testing.expectEqual(@as(usize, 1), scene.getQuads().len);

    // Insert a shadow
    try scene.insertShadow(.{
        .bounds = Bounds(ScaledPixels).fromXYWH(10, 20, 100, 50),
        .blur_radius = 10,
        .color = color.black().withAlpha(0.3),
    });

    try std.testing.expectEqual(@as(usize, 2), scene.primitiveCount());

    // Clear
    scene.clear();
    try std.testing.expect(scene.isEmpty());
}

test "Scene draw order" {
    const allocator = std.testing.allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // Insert quads - they should get auto-incrementing order (starting at 0)
    try scene.insertQuad(.{ .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });
    try scene.insertQuad(.{ .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });
    try scene.insertQuad(.{ .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });

    const quads = scene.getQuads();
    // Note: order 0 is reserved as "unset", so auto-assigned orders start at 1
    try std.testing.expectEqual(@as(DrawOrder, 0), quads[0].order);
    try std.testing.expectEqual(@as(DrawOrder, 1), quads[1].order);
    try std.testing.expectEqual(@as(DrawOrder, 2), quads[2].order);
}

test "Scene sorting" {
    const allocator = std.testing.allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();

    // Insert quads with explicit out-of-order draw orders
    try scene.insertQuad(.{ .order = 3, .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });
    try scene.insertQuad(.{ .order = 1, .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });
    try scene.insertQuad(.{ .order = 2, .bounds = Bounds(ScaledPixels).fromXYWH(0, 0, 10, 10) });

    scene.finish();

    const quads = scene.getQuads();
    try std.testing.expectEqual(@as(DrawOrder, 1), quads[0].order);
    try std.testing.expectEqual(@as(DrawOrder, 2), quads[1].order);
    try std.testing.expectEqual(@as(DrawOrder, 3), quads[2].order);
}

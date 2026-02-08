//! Tree structures and layout result types for Taffy
//!
//! Zig port of taffy/src/tree/*.rs

const std = @import("std");
const geo = @import("geometry.zig");
const style_mod = @import("style.zig");

const Point = geo.Point;
const Size = geo.Size;
const Rect = geo.Rect;
const Line = geo.Line;
const AvailableSpace = geo.AvailableSpace;

const Style = style_mod.Style;

// ============================================================================
// Node ID
// ============================================================================

/// A node identifier
pub const NodeId = u32;

/// Invalid node ID
pub const INVALID_NODE_ID: NodeId = std.math.maxInt(NodeId);

// ============================================================================
// Layout result
// ============================================================================

/// The final result of a layout algorithm for a single node
pub const Layout = struct {
    /// The relative ordering of the node (for z-ordering)
    order: u32 = 0,
    /// The top-left corner of the node
    location: Point(f32) = Point(f32).ZERO,
    /// The size of the node
    size: Size(f32) = Size(f32).ZERO,
    /// The size of the content inside the node (may be larger for scrollable content)
    content_size: Size(f32) = Size(f32).ZERO,
    /// The size of scrollbars
    scrollbar_size: Size(f32) = Size(f32).ZERO,
    /// The border size
    border: Rect(f32) = Rect(f32).ZERO,
    /// The padding size
    padding: Rect(f32) = Rect(f32).ZERO,
    /// The margin size
    margin: Rect(f32) = Rect(f32).ZERO,

    pub const ZERO: Layout = .{};

    /// Create a new layout with just location and size
    pub fn init(location: Point(f32), size: Size(f32)) Layout {
        return .{
            .location = location,
            .size = size,
        };
    }
};

// ============================================================================
// Run mode
// ============================================================================

/// Whether we are performing a full layout, or we merely need to size the node
pub const RunMode = enum {
    /// A full layout for this node and all children should be computed
    perform_layout,
    /// The layout algorithm should be executed such that an accurate container size can be determined
    compute_size,
    /// This node should have a null layout set as it has been hidden
    perform_hidden_layout,
};

/// Whether styles should be taken into account when computing size
pub const SizingMode = enum {
    /// Only content contributions should be taken into account
    content_size,
    /// Inherent size styles should be taken into account in addition to content contributions
    inherent_size,
};

/// Which axis we are computing
pub const RequestedAxis = enum {
    horizontal,
    vertical,
    both,
};

// ============================================================================
// Layout input/output
// ============================================================================

/// Input to the layout algorithm
pub const LayoutInput = struct {
    /// Whether to compute size or perform full layout
    run_mode: RunMode = .perform_layout,
    /// Whether to use style sizes
    sizing_mode: SizingMode = .inherent_size,
    /// Which axis to compute
    axis: RequestedAxis = .both,
    /// Known dimensions (if any)
    known_dimensions: Size(?f32) = .{ .width = null, .height = null },
    /// Parent size (for percentage resolution)
    parent_size: Size(?f32) = .{ .width = null, .height = null },
    /// Available space
    available_space: Size(AvailableSpace) = .{ .width = .max_content, .height = .max_content },
    /// Whether vertical margins can collapse (for block layout)
    vertical_margins_are_collapsible: Line(bool) = Line(bool).FALSE,

    pub const HIDDEN: LayoutInput = .{
        .run_mode = .perform_hidden_layout,
    };
};

/// Output from the layout algorithm
pub const LayoutOutput = struct {
    /// The computed size
    size: Size(f32) = Size(f32).ZERO,
    /// The content size
    content_size: Size(f32) = Size(f32).ZERO,
    /// First baseline in each dimension
    first_baselines: Point(?f32) = .{ .x = null, .y = null },
    /// Top margin for collapse
    top_margin: f32 = 0,
    /// Bottom margin for collapse
    bottom_margin: f32 = 0,
    /// Whether margins can collapse through this node
    margins_can_collapse_through: bool = false,

    pub const HIDDEN: LayoutOutput = .{};

    pub fn fromOuterSize(size: Size(f32)) LayoutOutput {
        return .{ .size = size };
    }

    pub fn fromSizes(size: Size(f32), content_size: Size(f32)) LayoutOutput {
        return .{ .size = size, .content_size = content_size };
    }
};

// ============================================================================
// Cache
// ============================================================================

/// Size and baseline cache entry
pub const CacheEntry = struct {
    known_dimensions: Size(?f32),
    available_space: Size(AvailableSpace),
    cached_size: Size(f32),
    first_baselines: Point(?f32),
};

/// Layout cache for a node
pub const Cache = struct {
    const CACHE_SIZE = 7;

    entries: [CACHE_SIZE]?CacheEntry = [_]?CacheEntry{null} ** CACHE_SIZE,
    final_layout: bool = false,

    pub fn init() Cache {
        return .{};
    }

    pub fn clear(self: *Cache) void {
        for (&self.entries) |*entry| {
            entry.* = null;
        }
        self.final_layout = false;
    }

    pub fn get(
        self: *const Cache,
        known_dimensions: Size(?f32),
        available_space: Size(AvailableSpace),
    ) ?CacheEntry {
        for (self.entries) |entry_opt| {
            if (entry_opt) |entry| {
                if (cacheMatch(entry.known_dimensions, entry.available_space, known_dimensions, available_space)) {
                    return entry;
                }
            }
        }
        return null;
    }

    pub fn store(
        self: *Cache,
        known_dimensions: Size(?f32),
        available_space: Size(AvailableSpace),
        cached_size: Size(f32),
        first_baselines: Point(?f32),
    ) void {
        // Find empty slot or oldest entry
        var slot: usize = 0;
        for (self.entries, 0..) |entry, i| {
            if (entry == null) {
                slot = i;
                break;
            }
        }

        self.entries[slot] = .{
            .known_dimensions = known_dimensions,
            .available_space = available_space,
            .cached_size = cached_size,
            .first_baselines = first_baselines,
        };
    }
};

fn cacheMatch(
    cached_known: Size(?f32),
    cached_available: Size(AvailableSpace),
    new_known: Size(?f32),
    new_available: Size(AvailableSpace),
) bool {
    // Check width
    if (!dimMatch(cached_known.width, cached_available.width, new_known.width, new_available.width)) {
        return false;
    }

    // Check height
    if (!dimMatch(cached_known.height, cached_available.height, new_known.height, new_available.height)) {
        return false;
    }

    return true;
}

fn dimMatch(
    cached_known: ?f32,
    cached_available: AvailableSpace,
    new_known: ?f32,
    new_available: AvailableSpace,
) bool {
    // If new has known dimension, cached must match exactly
    if (new_known) |nk| {
        if (cached_known) |ck| {
            return @abs(ck - nk) < 0.01;
        }
        return false;
    }

    // Compare available space
    return switch (new_available) {
        .definite => |nv| switch (cached_available) {
            .definite => |cv| @abs(cv - nv) < 0.01,
            else => false,
        },
        .min_content => cached_available == .min_content,
        .max_content => cached_available == .max_content,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "Layout init" {
    const layout = Layout.init(
        Point(f32).init(10, 20),
        Size(f32).init(100, 200),
    );
    try std.testing.expectEqual(@as(f32, 10), layout.location.x);
    try std.testing.expectEqual(@as(f32, 20), layout.location.y);
    try std.testing.expectEqual(@as(f32, 100), layout.size.width);
    try std.testing.expectEqual(@as(f32, 200), layout.size.height);
}

test "Cache basic" {
    var cache = Cache.init();

    const known = Size(?f32){ .width = 100, .height = null };
    const available = Size(AvailableSpace){ .width = .max_content, .height = .max_content };
    const cached_size = Size(f32).init(100, 50);

    cache.store(known, available, cached_size, .{ .x = null, .y = null });

    const result = cache.get(known, available);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(f32, 100), result.?.cached_size.width);
}

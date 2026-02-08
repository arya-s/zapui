//! Taffy - A flexible UI layout library
//!
//! Zig port of https://github.com/DioxusLabs/taffy
//!
//! Taffy is a high-performance, pure-Zig library for computing CSS-style layouts.
//! It currently supports Flexbox layout with plans for CSS Grid in the future.
//!
//! ## Quick Start
//!
//! ```zig
//! const taffy = @import("taffy.zig");
//!
//! var tree = taffy.Taffy.init(allocator);
//! defer tree.deinit();
//!
//! // Create nodes
//! const root = try tree.newLeaf(.{
//!     .flex_direction = .row,
//!     .size = .{ .width = .{ .length = 200 }, .height = .{ .length = 100 } },
//! });
//!
//! const child1 = try tree.newLeaf(.{ .flex_grow = 1 });
//! const child2 = try tree.newLeaf(.{ .flex_grow = 1 });
//!
//! try tree.appendChild(root, child1);
//! try tree.appendChild(root, child2);
//!
//! // Compute layout
//! tree.computeLayoutWithSize(root, 200, 100);
//!
//! // Get results
//! const layout1 = tree.getLayout(child1);
//! // layout1.location.x == 0
//! // layout1.size.width == 100
//! ```

// Re-export the main TaffyTree type
pub const TaffyTree = @import("taffy/taffy.zig").TaffyTree;
pub const Taffy = @import("taffy/taffy.zig").Taffy;

// Re-export geometry types
pub const Point = @import("taffy/geometry.zig").Point;
pub const Size = @import("taffy/geometry.zig").Size;
pub const Rect = @import("taffy/geometry.zig").Rect;
pub const Line = @import("taffy/geometry.zig").Line;
pub const AbsoluteAxis = @import("taffy/geometry.zig").AbsoluteAxis;
pub const FlexDirection = @import("taffy/geometry.zig").FlexDirection;
pub const AvailableSpace = @import("taffy/geometry.zig").AvailableSpace;

// Re-export style types
pub const Style = @import("taffy/style.zig").Style;
pub const LengthPercentage = @import("taffy/style.zig").LengthPercentage;
pub const LengthPercentageAuto = @import("taffy/style.zig").LengthPercentageAuto;
pub const Dimension = @import("taffy/style.zig").Dimension;
pub const Display = @import("taffy/style.zig").Display;
pub const Position = @import("taffy/style.zig").Position;
pub const FlexWrap = @import("taffy/style.zig").FlexWrap;
pub const AlignItems = @import("taffy/style.zig").AlignItems;
pub const AlignSelf = @import("taffy/style.zig").AlignSelf;
pub const AlignContent = @import("taffy/style.zig").AlignContent;
pub const JustifyContent = @import("taffy/style.zig").JustifyContent;
pub const JustifyItems = @import("taffy/style.zig").JustifyItems;
pub const Overflow = @import("taffy/style.zig").Overflow;
pub const BoxSizing = @import("taffy/style.zig").BoxSizing;

// Re-export tree types
pub const NodeId = @import("taffy/tree.zig").NodeId;
pub const INVALID_NODE_ID = @import("taffy/tree.zig").INVALID_NODE_ID;
pub const Layout = @import("taffy/tree.zig").Layout;
pub const LayoutInput = @import("taffy/tree.zig").LayoutInput;
pub const LayoutOutput = @import("taffy/tree.zig").LayoutOutput;
pub const RunMode = @import("taffy/tree.zig").RunMode;
pub const SizingMode = @import("taffy/tree.zig").SizingMode;
pub const Cache = @import("taffy/tree.zig").Cache;

// Sub-modules for advanced use
pub const geometry = @import("taffy/geometry.zig");
pub const style = @import("taffy/style.zig");
pub const tree = @import("taffy/tree.zig");
pub const flexbox = @import("taffy/flexbox.zig");

// Style helpers
pub fn length(value: f32) Dimension {
    return .{ .length = value };
}

pub fn percent(value: f32) Dimension {
    return .{ .percent = value };
}

pub fn auto() Dimension {
    return .auto;
}

pub fn px(value: f32) LengthPercentage {
    return .{ .length = value };
}

pub fn pct(value: f32) LengthPercentage {
    return .{ .percent = value };
}

// Tests
test {
    _ = @import("taffy/geometry.zig");
    _ = @import("taffy/style.zig");
    _ = @import("taffy/tree.zig");
    _ = @import("taffy/flexbox.zig");
    _ = @import("taffy/taffy.zig");
}

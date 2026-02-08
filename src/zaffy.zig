//! Zaffy - A flexible UI layout library
//!
//! Zig port of https://github.com/DioxusLabs/taffy
//!
//! Zaffy is a high-performance, pure-Zig library for computing CSS-style layouts.
//! It currently supports Flexbox layout with plans for CSS Grid in the future.
//!
//! ## Quick Start
//!
//! ```zig
//! const zaffy = @import("zaffy.zig");
//!
//! var tree = zaffy.Zaffy.init(allocator);
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

// Re-export the main ZaffyTree type
pub const ZaffyTree = @import("zaffy/zaffy.zig").ZaffyTree;
pub const Zaffy = @import("zaffy/zaffy.zig").Zaffy;

// Re-export geometry types
pub const Point = @import("zaffy/geometry.zig").Point;
pub const Size = @import("zaffy/geometry.zig").Size;
pub const Rect = @import("zaffy/geometry.zig").Rect;
pub const Line = @import("zaffy/geometry.zig").Line;
pub const AbsoluteAxis = @import("zaffy/geometry.zig").AbsoluteAxis;
pub const FlexDirection = @import("zaffy/geometry.zig").FlexDirection;
pub const AvailableSpace = @import("zaffy/geometry.zig").AvailableSpace;

// Re-export style types
pub const Style = @import("zaffy/style.zig").Style;
pub const LengthPercentage = @import("zaffy/style.zig").LengthPercentage;
pub const LengthPercentageAuto = @import("zaffy/style.zig").LengthPercentageAuto;
pub const Dimension = @import("zaffy/style.zig").Dimension;
pub const Display = @import("zaffy/style.zig").Display;
pub const Position = @import("zaffy/style.zig").Position;
pub const FlexWrap = @import("zaffy/style.zig").FlexWrap;
pub const AlignItems = @import("zaffy/style.zig").AlignItems;
pub const AlignSelf = @import("zaffy/style.zig").AlignSelf;
pub const AlignContent = @import("zaffy/style.zig").AlignContent;
pub const JustifyContent = @import("zaffy/style.zig").JustifyContent;
pub const JustifyItems = @import("zaffy/style.zig").JustifyItems;
pub const Overflow = @import("zaffy/style.zig").Overflow;
pub const BoxSizing = @import("zaffy/style.zig").BoxSizing;

// Re-export tree types
pub const NodeId = @import("zaffy/tree.zig").NodeId;
pub const INVALID_NODE_ID = @import("zaffy/tree.zig").INVALID_NODE_ID;
pub const Layout = @import("zaffy/tree.zig").Layout;
pub const LayoutInput = @import("zaffy/tree.zig").LayoutInput;
pub const LayoutOutput = @import("zaffy/tree.zig").LayoutOutput;
pub const RunMode = @import("zaffy/tree.zig").RunMode;
pub const SizingMode = @import("zaffy/tree.zig").SizingMode;
pub const Cache = @import("zaffy/tree.zig").Cache;

// Sub-modules for advanced use
pub const geometry = @import("zaffy/geometry.zig");
pub const style = @import("zaffy/style.zig");
pub const tree = @import("zaffy/tree.zig");
pub const flexbox = @import("zaffy/flexbox.zig");

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
    _ = @import("zaffy/geometry.zig");
    _ = @import("zaffy/style.zig");
    _ = @import("zaffy/tree.zig");
    _ = @import("zaffy/flexbox.zig");
    _ = @import("zaffy/zaffy.zig");
}

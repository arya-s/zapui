//! zapui - A GPU-accelerated UI framework for Zig
//!
//! zapui is an embeddable UI library inspired by GPUI. Users provide their own
//! OpenGL 3.3 context and forward input events; zapui handles layout, styling,
//! and rendering.

const std = @import("std");

// ============================================================================
// Core modules
// ============================================================================

pub const geometry = @import("geometry.zig");
pub const color = @import("color.zig");
pub const style = @import("style.zig");

// ============================================================================
// Re-exports for convenience
// ============================================================================

// Geometry types
pub const Point = geometry.Point;
pub const Size = geometry.Size;
pub const Bounds = geometry.Bounds;
pub const Edges = geometry.Edges;
pub const Corners = geometry.Corners;
pub const Pixels = geometry.Pixels;
pub const ScaledPixels = geometry.ScaledPixels;
pub const Rems = geometry.Rems;

// Color types
pub const Hsla = color.Hsla;
pub const Rgba = color.Rgba;

// Color constructors
pub const rgb = color.rgb;
pub const rgba = color.rgba;
pub const hsla = color.hsla;
pub const hsl = color.hsl;

// Named colors
pub const transparent = color.transparent;
pub const black = color.black;
pub const white = color.white;
pub const red = color.red;
pub const green = color.green;
pub const blue = color.blue;
pub const yellow = color.yellow;
pub const cyan = color.cyan;
pub const magenta = color.magenta;
pub const gray = color.gray;

// Style types
pub const Style = style.Style;
pub const Display = style.Display;
pub const Position = style.Position;
pub const Overflow = style.Overflow;
pub const FlexDirection = style.FlexDirection;
pub const FlexWrap = style.FlexWrap;
pub const AlignItems = style.AlignItems;
pub const AlignSelf = style.AlignSelf;
pub const AlignContent = style.AlignContent;
pub const JustifyContent = style.JustifyContent;
pub const Length = style.Length;
pub const Background = style.Background;
pub const BoxShadow = style.BoxShadow;
pub const FontWeight = style.FontWeight;
pub const Visibility = style.Visibility;
pub const Cursor = style.Cursor;

// Length constructors
pub const px = style.px;
pub const rems = style.rems;
pub const percent = style.percent;
pub const auto = style.auto;

// Style presets
pub const Spacing = style.Spacing;
pub const Radius = style.Radius;
pub const FontSize = style.FontSize;

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all module tests
    std.testing.refAllDeclsRecursive(@This());
}

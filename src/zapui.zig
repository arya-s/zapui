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
pub const scene = @import("scene.zig");
pub const layout = @import("layout.zig");
pub const entity = @import("entity.zig");
pub const app = @import("app.zig");
pub const element = @import("element.zig");
pub const elements = struct {
    pub const div = @import("elements/div.zig");
};

// Renderer modules
pub const renderer = struct {
    pub const gl = @import("renderer/gl.zig");
    pub const shaders = @import("renderer/shaders.zig");
    pub const atlas = @import("renderer/atlas.zig");
    pub const gl_renderer = @import("renderer/gl_renderer.zig");
};

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

// Scene types
pub const Scene = scene.Scene;
pub const Quad = scene.Quad;
pub const Shadow = scene.Shadow;
pub const DrawOrder = scene.DrawOrder;

// Layout types
pub const LayoutEngine = layout.LayoutEngine;
pub const LayoutId = layout.LayoutId;
pub const LayoutStyle = layout.LayoutStyle;
pub const AvailableSpace = layout.AvailableSpace;

// Entity types
pub const EntityId = entity.EntityId;
pub const Entity = entity.Entity;
pub const AnyEntity = entity.AnyEntity;
pub const EntityStore = entity.EntityStore;

// App types
pub const App = app.App;
pub const Context = app.Context;
pub const Subscription = app.Subscription;

// Element types
pub const AnyElement = element.AnyElement;
pub const RenderContext = element.RenderContext;
pub const intoAnyElement = element.intoAnyElement;

// Div element
pub const Div = elements.div.Div;
pub const div = elements.div.div;

// Renderer types
pub const GlRenderer = renderer.gl_renderer.GlRenderer;
pub const Atlas = renderer.atlas.Atlas;

/// Load OpenGL function pointers (call after creating GL context)
pub fn loadGl(getProcAddress: *const fn ([*:0]const u8) ?*anyopaque) !void {
    try renderer.gl.loadGlFunctions(getProcAddress);
}

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all module tests
    std.testing.refAllDeclsRecursive(geometry);
    std.testing.refAllDeclsRecursive(color);
    std.testing.refAllDeclsRecursive(style);
    std.testing.refAllDeclsRecursive(scene);
    std.testing.refAllDeclsRecursive(layout);
    std.testing.refAllDeclsRecursive(entity);
    std.testing.refAllDeclsRecursive(app);
    std.testing.refAllDeclsRecursive(element);
    std.testing.refAllDeclsRecursive(elements.div);
    // Note: renderer tests require OpenGL context, skip in unit tests
}

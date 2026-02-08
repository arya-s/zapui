//! zapui - A GPU-accelerated UI framework for Zig
//!
//! zapui is an embeddable UI library inspired by GPUI. Users provide their own
//! OpenGL 3.3 context and forward input events; zapui handles layout, styling,
//! and rendering.

const std = @import("std");

// Font backend modules (FreeType + HarfBuzz)
pub const freetype = @import("freetype");
pub const harfbuzz = @import("harfbuzz");

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
pub const input = @import("input.zig");
pub const ui = @import("ui.zig");
pub const text_system = @import("text_system.zig");
pub const elements = @import("elements.zig");
pub const view = @import("view.zig");
pub const zaffy = @import("zaffy.zig");
pub const window = @import("window.zig");

// Platform modules
pub const platform = @import("platform/platform.zig");

// Renderer modules
pub const renderer = struct {
    pub const gl = @import("renderer/gl.zig");
    pub const shaders = @import("renderer/shaders.zig");
    pub const atlas = @import("renderer/atlas.zig");
    pub const gl_renderer = @import("renderer/gl_renderer.zig");
    pub const d3d11_renderer = @import("renderer/d3d11_renderer.zig");
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

// Elements
pub const Div = elements.Div;
pub const Text = elements.Text;
pub const Button = elements.Button;
pub const Checkbox = elements.Checkbox;
pub const Slider = elements.Slider;
pub const Badge = elements.Badge;
pub const Card = elements.Card;
pub const Divider = elements.Divider;
pub const Tabs = elements.Tabs;
pub const Input = elements.Input;
pub const Toggle = elements.Toggle;
pub const Progress = elements.Progress;
pub const Avatar = elements.Avatar;

// Input types
pub const InputEvent = input.InputEvent;
pub const MouseButton = input.MouseButton;
pub const MouseDownEvent = input.MouseDownEvent;
pub const MouseUpEvent = input.MouseUpEvent;
pub const MouseMoveEvent = input.MouseMoveEvent;
pub const ScrollWheelEvent = input.ScrollWheelEvent;
pub const KeyDownEvent = input.KeyDownEvent;
pub const KeyUpEvent = input.KeyUpEvent;
pub const Key = input.Key;
pub const Modifiers = input.Modifiers;
// Cursor is exported from style module
pub const HitTestEngine = input.HitTestEngine;
pub const HitboxId = input.HitboxId;

// UI orchestration
pub const Ui = ui.Ui;
pub const InitOptions = ui.InitOptions;

// View system
pub const ViewTree = view.ViewTree;
pub const ViewNode = view.ViewNode;
pub const ViewContext = view.ViewContext;
pub const ClickEvent = view.ClickEvent;
pub const HoverEvent = view.HoverEvent;
pub const DragEvent = view.DragEvent;

// View builders
pub const col = view.col;
pub const row = view.row;
pub const container = view.container;
pub const text = view.text;
pub const withId = view.withId;
pub const withChildren = view.withChildren;
pub const withPadding = view.withPadding;
pub const withGap = view.withGap;
pub const withSize = view.withSize;
pub const withWidth = view.withWidth;
pub const withHeight = view.withHeight;
pub const withFlex = view.withFlex;
pub const withBackground = view.withBackground;
pub const withBorder = view.withBorder;
pub const withCornerRadius = view.withCornerRadius;
pub const withShadow = view.withShadow;
pub const withTextColor = view.withTextColor;
pub const withFontSize = view.withFontSize;
pub const withCursor = view.withCursor;
pub const withOnClick = view.withOnClick;
pub const withOnHover = view.withOnHover;
pub const withOnDrag = view.withOnDrag;
pub const withUserData = view.withUserData;

// Text system
pub const TextSystem = text_system.TextSystem;
pub const FontId = text_system.FontId;
pub const ShapedRun = text_system.ShapedRun;
pub const ShapedGlyph = text_system.ShapedGlyph;
pub const FontMetrics = text_system.FontMetrics;

// Renderer types
pub const GlRenderer = renderer.gl_renderer.GlRenderer;
pub const Atlas = renderer.atlas.Atlas;
pub const GlAtlas = renderer.atlas.GlAtlas;
pub const AtlasFormat = renderer.atlas.Format;
pub const AtlasRegion = renderer.atlas.Region;

/// Load OpenGL function pointers (call after creating GL context)
/// Use this with zglfw.getProcAddress or similar loaders
pub fn loadGl(getProcAddress: renderer.gl.GlProcLoader) !void {
    try renderer.gl.loadGlFunctions(getProcAddress);
}

/// Load OpenGL function pointers using legacy loader (for cImport-based code)
pub fn loadGlLegacy(getProcAddress: renderer.gl.LegacyGlProcLoader) !void {
    try renderer.gl.loadGlFunctionsLegacy(getProcAddress);
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
    std.testing.refAllDeclsRecursive(input);
    std.testing.refAllDeclsRecursive(ui);
    std.testing.refAllDeclsRecursive(text_system);
    std.testing.refAllDeclsRecursive(elements.div);
    // Note: renderer tests require OpenGL context, skip in unit tests
}

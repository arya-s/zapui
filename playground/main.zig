//! zapui playground - Development sandbox for testing the library

const std = @import("std");
const zapui = @import("zapui");

pub fn main() !void {
    std.debug.print("=== zapui Playground ===\n\n", .{});

    // Test geometry
    std.debug.print("-- Geometry --\n", .{});
    const point = zapui.Point(f32).init(100, 200);
    std.debug.print("Point: ({d}, {d})\n", .{ point.x, point.y });

    const size = zapui.Size(f32).init(800, 600);
    std.debug.print("Size: {d}x{d}, area: {d}\n", .{ size.width, size.height, size.area() });

    const bounds = zapui.Bounds(f32).fromXYWH(10, 20, 100, 50);
    std.debug.print("Bounds: origin=({d},{d}), size={d}x{d}\n", .{
        bounds.origin.x,
        bounds.origin.y,
        bounds.size.width,
        bounds.size.height,
    });
    std.debug.print("  center: ({d}, {d})\n", .{ bounds.center().x, bounds.center().y });
    std.debug.print("  contains (50, 40): {}\n", .{bounds.contains(zapui.Point(f32).init(50, 40))});

    const edges = zapui.Edges(f32).all(8);
    std.debug.print("Edges (all 8): top={d}, right={d}, bottom={d}, left={d}\n", .{
        edges.top,
        edges.right,
        edges.bottom,
        edges.left,
    });

    const corners = zapui.Corners(f32).all(4);
    std.debug.print("Corners (all 4): TL={d}, TR={d}, BR={d}, BL={d}\n", .{
        corners.top_left,
        corners.top_right,
        corners.bottom_right,
        corners.bottom_left,
    });

    // Test colors
    std.debug.print("\n-- Colors --\n", .{});
    const c1 = zapui.rgb(0xFF5500);
    std.debug.print("rgb(0xFF5500) -> HSLA: h={d:.3}, s={d:.3}, l={d:.3}, a={d:.3}\n", .{ c1.h, c1.s, c1.l, c1.a });

    const rgba_color = c1.toRgba();
    std.debug.print("  -> RGBA: r={d:.3}, g={d:.3}, b={d:.3}, a={d:.3}\n", .{
        rgba_color.r,
        rgba_color.g,
        rgba_color.b,
        rgba_color.a,
    });

    const red_color = zapui.red();
    std.debug.print("red() -> HSLA: h={d:.3}, s={d:.3}, l={d:.3}\n", .{ red_color.h, red_color.s, red_color.l });

    const lighter = red_color.lighten(0.2);
    std.debug.print("red().lighten(0.2) -> l={d:.3}\n", .{lighter.l});

    // Test style
    std.debug.print("\n-- Style --\n", .{});
    var style = zapui.Style.init();
    style.display = .flex;
    style.flex_direction = .column;
    style.justify_content = .center;
    style.align_items = .center;
    style.padding = .{
        .top = zapui.px(16),
        .right = zapui.px(16),
        .bottom = zapui.px(16),
        .left = zapui.px(16),
    };
    style.background = .{ .solid = zapui.rgb(0x1a1a2e) };
    style.corner_radii = zapui.Corners(zapui.Pixels).all(zapui.Radius.lg);
    style.border_widths = zapui.Edges(zapui.Pixels).all(1);
    style.border_color = zapui.rgb(0x4a4a6a);

    std.debug.print("Style created:\n", .{});
    std.debug.print("  display: {}\n", .{style.display});
    std.debug.print("  flex_direction: {}\n", .{style.flex_direction});
    std.debug.print("  justify_content: {?}\n", .{style.justify_content});
    std.debug.print("  align_items: {?}\n", .{style.align_items});
    std.debug.print("  isVisible: {}\n", .{style.isVisible()});
    std.debug.print("  hasVisualContent: {}\n", .{style.hasVisualContent()});

    // Test length resolution
    std.debug.print("\n-- Length Resolution --\n", .{});
    const rem_base: zapui.Pixels = 16;
    const parent_size: zapui.Pixels = 200;

    const len_px = zapui.px(100);
    const len_rems = zapui.rems(2);
    const len_pct = zapui.percent(50);
    const len_auto = zapui.auto;

    std.debug.print("px(100) resolves to: {?d}\n", .{len_px.resolve(parent_size, rem_base)});
    std.debug.print("rems(2) resolves to: {?d} (rem_base=16)\n", .{len_rems.resolve(parent_size, rem_base)});
    std.debug.print("percent(50) resolves to: {?d} (parent=200)\n", .{len_pct.resolve(parent_size, rem_base)});
    std.debug.print("auto resolves to: {?}\n", .{zapui.Length.resolve(len_auto, parent_size, rem_base)});

    // Test spacing presets
    std.debug.print("\n-- Spacing Presets --\n", .{});
    std.debug.print("Spacing._4 = {d}px\n", .{zapui.Spacing._4.px});
    std.debug.print("Spacing._8 = {d}px\n", .{zapui.Spacing._8.px});
    std.debug.print("Radius.lg = {d}px\n", .{zapui.Radius.lg});
    std.debug.print("FontSize.xl = {d}px\n", .{zapui.FontSize.xl});

    std.debug.print("\n=== Phase 1 Complete! ===\n", .{});
}

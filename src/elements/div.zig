//! Div - Declarative UI element with Taffy layout
//!
//! API designed to match GPUI's div() API exactly.
//! Uses zapui's unified Style struct for layout and visual properties.

const std = @import("std");
const zaffy = @import("../zaffy.zig");
const scene_mod = @import("../scene.zig");
const text_system_mod = @import("../text_system.zig");
const geometry = @import("../geometry.zig");
const color_mod = @import("../color.zig");
const style_mod = @import("../style.zig");

const Scene = scene_mod.Scene;
const TextSystem = text_system_mod.TextSystem;
const Bounds = geometry.Bounds;
const Point = geometry.Point;
const Pixels = geometry.Pixels;
const Corners = geometry.Corners;
const Edges = geometry.Edges;
const Hsla = color_mod.Hsla;
const Style = style_mod.Style;
const Length = style_mod.Length;
const Allocator = std.mem.Allocator;

// ============================================================================
// GPUI-compatible unit wrapper
// ============================================================================

/// Pixel value wrapper (matches GPUI's px())
pub const Px = struct {
    value: Pixels,
};

/// Create a pixel value (matches GPUI's px() function)
pub fn px(value: anytype) Px {
    return .{ .value = @floatCast(switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @as(f64, @floatFromInt(value)),
        .float, .comptime_float => @as(f64, value),
        else => @compileError("px() requires a number"),
    }) };
}

/// Rems value wrapper (matches GPUI's rems())
pub const Rems = struct {
    value: f32,
};

/// Create a rems value
pub fn rems(value: anytype) Rems {
    return .{ .value = @floatCast(switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @as(f64, @floatFromInt(value)),
        .float, .comptime_float => @as(f64, value),
        else => @compileError("rems() requires a number"),
    }) };
}

/// Relative/fraction value wrapper (matches GPUI's relative())
pub const Relative = struct {
    value: f32,
};

/// Create a relative/fractional value (matches GPUI's relative() function)
/// Usage: .w(relative(1.0 / 6.0)) for 1/6th width
pub fn relative(value: anytype) Relative {
    return .{ .value = @floatCast(switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @as(f64, @floatFromInt(value)),
        .float, .comptime_float => @as(f64, value),
        else => @compileError("relative() requires a number"),
    }) };
}

// ============================================================================
// Div Element
// ============================================================================

pub const Div = struct {
    style: Style = .{},
    text_content_val: ?[]const u8 = null,
    text_size_val: Pixels = 14,
    text_color_val: Hsla = color_mod.rgb(0xe2e8f0),
    hitbox_id: ?usize = null,
    children_list: std.ArrayListUnmanaged(*Div) = .{},
    node_id: ?zaffy.NodeId = null,
    
    // Hover styles (applied when hovered)
    hover_bg_val: ?Hsla = null,
    hover_border_color_val: ?Hsla = null,
    hover_text_color_val: ?Hsla = null,

    const Self = @This();

    // ========================================================================
    // Display
    // ========================================================================

    pub fn flex(self: *Self) *Self { self.style.display = .flex; return self; }
    pub fn block(self: *Self) *Self { self.style.display = .block; return self; }
    pub fn hidden(self: *Self) *Self { self.style.display = .none; return self; }

    // ========================================================================
    // Flex Direction
    // ========================================================================

    pub fn flex_col(self: *Self) *Self { self.style.flex_direction = .column; return self; }
    pub fn flex_col_reverse(self: *Self) *Self { self.style.flex_direction = .column_reverse; return self; }
    pub fn flex_row(self: *Self) *Self { self.style.flex_direction = .row; return self; }
    pub fn flex_row_reverse(self: *Self) *Self { self.style.flex_direction = .row_reverse; return self; }

    // ========================================================================
    // Flex Properties
    // ========================================================================

    pub fn flex_1(self: *Self) *Self { 
        self.style.flex_grow = 1.0;
        self.style.flex_shrink = 1.0;
        self.style.flex_basis = .{ .percent = 0 };
        return self; 
    }
    pub fn flex_grow(self: *Self, val: f32) *Self { self.style.flex_grow = val; return self; }
    pub fn flex_shrink(self: *Self, val: f32) *Self { self.style.flex_shrink = val; return self; }
    pub fn flex_none(self: *Self) *Self { 
        self.style.flex_grow = 0;
        self.style.flex_shrink = 0;
        return self; 
    }
    pub fn flex_wrap(self: *Self) *Self { self.style.flex_wrap = .wrap; return self; }
    pub fn flex_nowrap(self: *Self) *Self { self.style.flex_wrap = .no_wrap; return self; }

    // ========================================================================
    // Size
    // ========================================================================
    
    pub fn w(self: *Self, width: anytype) *Self { 
        const T = @TypeOf(width);
        if (T == Px) {
            self.style.size.width = .{ .px = width.value }; 
        } else if (T == Relative) {
            self.style.size.width = .{ .percent = width.value * 100 };
        } else {
            @compileError("w() requires Px or Relative");
        }
        return self; 
    }
    pub fn h(self: *Self, height: anytype) *Self { 
        const T = @TypeOf(height);
        if (T == Px) {
            self.style.size.height = .{ .px = height.value }; 
        } else if (T == Relative) {
            self.style.size.height = .{ .percent = height.value * 100 };
        } else {
            @compileError("h() requires Px or Relative");
        }
        return self; 
    }
    pub fn size_full(self: *Self) *Self { 
        self.style.size.width = .{ .percent = 100 }; 
        self.style.size.height = .{ .percent = 100 }; 
        return self; 
    }
    pub fn w_full(self: *Self) *Self { self.style.size.width = .{ .percent = 100 }; return self; }
    pub fn h_full(self: *Self) *Self { self.style.size.height = .{ .percent = 100 }; return self; }
    pub fn w_auto(self: *Self) *Self { self.style.size.width = .auto; return self; }
    pub fn h_auto(self: *Self) *Self { self.style.size.height = .auto; return self; }
    
    /// Set width as a fraction (e.g., 1.0/6.0 for 1/6 of parent) - matches GPUI's relative()
    pub fn w_frac(self: *Self, fraction: f32) *Self { self.style.size.width = .{ .percent = fraction * 100 }; return self; }
    /// Set height as a fraction
    pub fn h_frac(self: *Self, fraction: f32) *Self { self.style.size.height = .{ .percent = fraction * 100 }; return self; }
    
    pub fn min_w(self: *Self, width: Px) *Self { self.style.min_size.width = .{ .px = width.value }; return self; }
    pub fn min_h(self: *Self, height: Px) *Self { self.style.min_size.height = .{ .px = height.value }; return self; }
    pub fn max_w(self: *Self, width: Px) *Self { self.style.max_size.width = .{ .px = width.value }; return self; }
    pub fn max_h(self: *Self, height: Px) *Self { self.style.max_size.height = .{ .px = height.value }; return self; }
    
    /// Set both width and height (matches GPUI's .size())
    pub fn size(self: *Self, val: Px) *Self { 
        self.style.size.width = .{ .px = val.value }; 
        self.style.size.height = .{ .px = val.value }; 
        return self; 
    }
    
    /// Size presets (matches GPUI's size_N where N * 4 = pixels)
    pub fn size_1(self: *Self) *Self { return self.size(.{ .value = 4 }); }
    pub fn size_2(self: *Self) *Self { return self.size(.{ .value = 8 }); }
    pub fn size_3(self: *Self) *Self { return self.size(.{ .value = 12 }); }
    pub fn size_4(self: *Self) *Self { return self.size(.{ .value = 16 }); }
    pub fn size_5(self: *Self) *Self { return self.size(.{ .value = 20 }); }
    pub fn size_6(self: *Self) *Self { return self.size(.{ .value = 24 }); }
    pub fn size_8(self: *Self) *Self { return self.size(.{ .value = 32 }); }
    pub fn size_10(self: *Self) *Self { return self.size(.{ .value = 40 }); }
    pub fn size_12(self: *Self) *Self { return self.size(.{ .value = 48 }); }
    pub fn size_16(self: *Self) *Self { return self.size(.{ .value = 64 }); }
    pub fn size_20(self: *Self) *Self { return self.size(.{ .value = 80 }); }
    pub fn size_24(self: *Self) *Self { return self.size(.{ .value = 96 }); }

    // ========================================================================
    // Padding
    // ========================================================================

    pub fn p(self: *Self, val: Px) *Self { 
        self.style.padding = Edges(Length).all(.{ .px = val.value }); 
        return self; 
    }
    pub fn padding(self: *Self, val: Px) *Self { return self.p(val); }
    pub fn px(self: *Self, val: Px) *Self {
        self.style.padding.left = .{ .px = val.value }; 
        self.style.padding.right = .{ .px = val.value }; 
        return self; 
    }
    pub fn py(self: *Self, val: Px) *Self { 
        self.style.padding.top = .{ .px = val.value }; 
        self.style.padding.bottom = .{ .px = val.value }; 
        return self; 
    }
    pub fn pt(self: *Self, val: Px) *Self { self.style.padding.top = .{ .px = val.value }; return self; }
    pub fn pr(self: *Self, val: Px) *Self { self.style.padding.right = .{ .px = val.value }; return self; }
    pub fn pb(self: *Self, val: Px) *Self { self.style.padding.bottom = .{ .px = val.value }; return self; }
    pub fn pl(self: *Self, val: Px) *Self { self.style.padding.left = .{ .px = val.value }; return self; }
    
    // Padding presets (N * 4 = pixels, matching Tailwind/GPUI)
    pub fn p_1(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 4 }); return self; }
    pub fn p_2(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 8 }); return self; }
    pub fn p_3(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 12 }); return self; }
    pub fn p_4(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 16 }); return self; }
    pub fn p_6(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 24 }); return self; }
    pub fn p_8(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 32 }); return self; }
    pub fn p_12(self: *Self) *Self { self.style.padding = Edges(Length).all(.{ .px = 48 }); return self; }
    
    pub fn py_1(self: *Self) *Self { self.style.padding.top = .{ .px = 4 }; self.style.padding.bottom = .{ .px = 4 }; return self; }
    pub fn py_2(self: *Self) *Self { self.style.padding.top = .{ .px = 8 }; self.style.padding.bottom = .{ .px = 8 }; return self; }
    pub fn py_3(self: *Self) *Self { self.style.padding.top = .{ .px = 12 }; self.style.padding.bottom = .{ .px = 12 }; return self; }
    pub fn py_4(self: *Self) *Self { self.style.padding.top = .{ .px = 16 }; self.style.padding.bottom = .{ .px = 16 }; return self; }
    pub fn py_6(self: *Self) *Self { self.style.padding.top = .{ .px = 24 }; self.style.padding.bottom = .{ .px = 24 }; return self; }
    pub fn py_8(self: *Self) *Self { self.style.padding.top = .{ .px = 32 }; self.style.padding.bottom = .{ .px = 32 }; return self; }
    pub fn py_12(self: *Self) *Self { self.style.padding.top = .{ .px = 48 }; self.style.padding.bottom = .{ .px = 48 }; return self; }
    
    pub fn px_1(self: *Self) *Self { self.style.padding.left = .{ .px = 4 }; self.style.padding.right = .{ .px = 4 }; return self; }
    pub fn px_2(self: *Self) *Self { self.style.padding.left = .{ .px = 8 }; self.style.padding.right = .{ .px = 8 }; return self; }
    pub fn px_3(self: *Self) *Self { self.style.padding.left = .{ .px = 12 }; self.style.padding.right = .{ .px = 12 }; return self; }
    pub fn px_4(self: *Self) *Self { self.style.padding.left = .{ .px = 16 }; self.style.padding.right = .{ .px = 16 }; return self; }

    // ========================================================================
    // Margin
    // ========================================================================

    pub fn m(self: *Self, val: Px) *Self { 
        self.style.margin = Edges(Length).all(.{ .px = val.value }); 
        return self; 
    }
    pub fn margin(self: *Self, val: Px) *Self { return self.m(val); }
    pub fn mx(self: *Self, val: Px) *Self { 
        self.style.margin.left = .{ .px = val.value }; 
        self.style.margin.right = .{ .px = val.value }; 
        return self; 
    }
    pub fn my(self: *Self, val: Px) *Self { 
        self.style.margin.top = .{ .px = val.value }; 
        self.style.margin.bottom = .{ .px = val.value }; 
        return self; 
    }
    pub fn mt(self: *Self, val: Px) *Self { self.style.margin.top = .{ .px = val.value }; return self; }
    pub fn mr(self: *Self, val: Px) *Self { self.style.margin.right = .{ .px = val.value }; return self; }
    pub fn mb(self: *Self, val: Px) *Self { self.style.margin.bottom = .{ .px = val.value }; return self; }
    pub fn ml(self: *Self, val: Px) *Self { self.style.margin.left = .{ .px = val.value }; return self; }
    pub fn m_auto(self: *Self) *Self { self.style.margin = Edges(Length).all(.auto); return self; }
    pub fn mx_auto(self: *Self) *Self { self.style.margin.left = .auto; self.style.margin.right = .auto; return self; }

    // ========================================================================
    // Gap
    // ========================================================================

    pub fn gap(self: *Self, val: Px) *Self { 
        self.style.gap.width = .{ .px = val.value }; 
        self.style.gap.height = .{ .px = val.value }; 
        return self; 
    }
    pub fn gap_x(self: *Self, val: Px) *Self { self.style.gap.width = .{ .px = val.value }; return self; }
    pub fn gap_y(self: *Self, val: Px) *Self { self.style.gap.height = .{ .px = val.value }; return self; }
    
    // Gap presets (matches GPUI's gap_N)
    pub fn gap_0(self: *Self) *Self { return self.gap(.{ .value = 0 }); }
    pub fn gap_1(self: *Self) *Self { return self.gap(.{ .value = 4 }); }
    pub fn gap_2(self: *Self) *Self { return self.gap(.{ .value = 8 }); }
    pub fn gap_3(self: *Self) *Self { return self.gap(.{ .value = 12 }); }
    pub fn gap_4(self: *Self) *Self { return self.gap(.{ .value = 16 }); }
    pub fn gap_5(self: *Self) *Self { return self.gap(.{ .value = 20 }); }
    pub fn gap_6(self: *Self) *Self { return self.gap(.{ .value = 24 }); }
    pub fn gap_8(self: *Self) *Self { return self.gap(.{ .value = 32 }); }

    // ========================================================================
    // Alignment
    // ========================================================================

    pub fn justify_start(self: *Self) *Self { self.style.justify_content = .flex_start; return self; }
    pub fn justify_center(self: *Self) *Self { self.style.justify_content = .center; return self; }
    pub fn justify_end(self: *Self) *Self { self.style.justify_content = .flex_end; return self; }
    pub fn justify_between(self: *Self) *Self { self.style.justify_content = .space_between; return self; }
    pub fn justify_around(self: *Self) *Self { self.style.justify_content = .space_around; return self; }
    pub fn justify_evenly(self: *Self) *Self { self.style.justify_content = .space_evenly; return self; }

    pub fn items_start(self: *Self) *Self { self.style.align_items = .flex_start; return self; }
    pub fn items_center(self: *Self) *Self { self.style.align_items = .center; return self; }
    pub fn items_end(self: *Self) *Self { self.style.align_items = .flex_end; return self; }
    pub fn items_stretch(self: *Self) *Self { self.style.align_items = .stretch; return self; }
    pub fn items_baseline(self: *Self) *Self { self.style.align_items = .baseline; return self; }

    pub fn self_start(self: *Self) *Self { self.style.align_self = .flex_start; return self; }
    pub fn self_center(self: *Self) *Self { self.style.align_self = .center; return self; }
    pub fn self_end(self: *Self) *Self { self.style.align_self = .flex_end; return self; }
    pub fn self_stretch(self: *Self) *Self { self.style.align_self = .stretch; return self; }

    // ========================================================================
    // Background
    // ========================================================================

    pub fn bg(self: *Self, color: Hsla) *Self { self.style.background = .{ .solid = color }; return self; }

    // ========================================================================
    // Shadow
    // ========================================================================
    
    pub fn shadow(self: *Self, shadow_def: style_mod.BoxShadow) *Self { 
        self.style.box_shadow = shadow_def; 
        return self; 
    }
    
    /// 2X Small shadow (matches GPUI's shadow_2xs)
    pub fn shadow_2xs(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.05),
            .blur_radius = 1,
            .spread_radius = 0,
            .offset = .{ .x = 0, .y = 1 },
        }; 
        return self; 
    }
    
    /// Extra small shadow (matches GPUI's shadow_xs)
    pub fn shadow_xs(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.05),
            .blur_radius = 2,
            .spread_radius = 0,
            .offset = .{ .x = 0, .y = 1 },
        }; 
        return self; 
    }
    
    /// Small shadow (matches Tailwind's shadow-sm)
    pub fn shadow_sm(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.05),
            .blur_radius = 2,
            .spread_radius = 0,
            .offset = .{ .x = 0, .y = 1 },
        }; 
        return self; 
    }
    
    /// Default shadow (matches Tailwind's shadow)
    pub fn shadow_default(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.1),
            .blur_radius = 6,
            .spread_radius = 0,
            .offset = .{ .x = 0, .y = 2 },
        }; 
        return self; 
    }
    
    /// Medium shadow (matches Tailwind's shadow-md)
    pub fn shadow_md(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.1),
            .blur_radius = 10,
            .spread_radius = -2,
            .offset = .{ .x = 0, .y = 4 },
        }; 
        return self; 
    }
    
    /// Large shadow (matches Tailwind's shadow-lg / GPUI's shadow_lg)
    pub fn shadow_lg(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.15),
            .blur_radius = 20,
            .spread_radius = -4,
            .offset = .{ .x = 0, .y = 8 },
        }; 
        return self; 
    }
    
    /// Extra large shadow (matches Tailwind's shadow-xl)
    pub fn shadow_xl(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.2),
            .blur_radius = 30,
            .spread_radius = -6,
            .offset = .{ .x = 0, .y = 12 },
        }; 
        return self; 
    }
    
    /// 2XL shadow (matches Tailwind's shadow-2xl)
    pub fn shadow_2xl(self: *Self) *Self { 
        self.style.box_shadow = .{
            .color = color_mod.black().withAlpha(0.25),
            .blur_radius = 50,
            .spread_radius = -12,
            .offset = .{ .x = 0, .y = 25 },
        }; 
        return self; 
    }
    
    /// No shadow
    pub fn shadow_none(self: *Self) *Self { 
        self.style.box_shadow = null; 
        return self; 
    }

    // ========================================================================
    // Border
    // ========================================================================

    pub fn border_0(self: *Self) *Self { self.style.border_widths = Edges(Pixels).all(0); return self; }
    pub fn border_1(self: *Self) *Self { self.style.border_widths = Edges(Pixels).all(1); return self; }
    pub fn border_2(self: *Self) *Self { self.style.border_widths = Edges(Pixels).all(2); return self; }
    pub fn border_3(self: *Self) *Self { self.style.border_widths = Edges(Pixels).all(3); return self; }
    pub fn border_4(self: *Self) *Self { self.style.border_widths = Edges(Pixels).all(4); return self; }
    pub fn border(self: *Self, width: Px) *Self { self.style.border_widths = Edges(Pixels).all(width.value); return self; }
    pub fn border_t(self: *Self, width: Px) *Self { self.style.border_widths.top = width.value; return self; }
    pub fn border_r(self: *Self, width: Px) *Self { self.style.border_widths.right = width.value; return self; }
    pub fn border_b(self: *Self, width: Px) *Self { self.style.border_widths.bottom = width.value; return self; }
    pub fn border_l(self: *Self, width: Px) *Self { self.style.border_widths.left = width.value; return self; }
    pub fn border_t_1(self: *Self) *Self { self.style.border_widths.top = 1; return self; }
    pub fn border_r_1(self: *Self) *Self { self.style.border_widths.right = 1; return self; }
    pub fn border_b_1(self: *Self) *Self { self.style.border_widths.bottom = 1; return self; }
    pub fn border_l_1(self: *Self) *Self { self.style.border_widths.left = 1; return self; }
    pub fn border_color(self: *Self, color: Hsla) *Self { self.style.border_color = color; return self; }
    
    /// Set border style to dashed (matches GPUI's border_dashed())
    pub fn border_dashed(self: *Self) *Self { self.style.border_style = .dashed; return self; }
    
    /// Set border style to solid (default)
    pub fn border_solid(self: *Self) *Self { self.style.border_style = .solid; return self; }

    pub fn rounded(self: *Self, radius: Px) *Self { self.style.corner_radii = Corners(Pixels).all(radius.value); return self; }
    pub fn rounded_sm(self: *Self) *Self { self.style.corner_radii = Corners(Pixels).all(2); return self; }
    pub fn rounded_md(self: *Self) *Self { self.style.corner_radii = Corners(Pixels).all(6); return self; }
    pub fn rounded_lg(self: *Self) *Self { self.style.corner_radii = Corners(Pixels).all(8); return self; }
    pub fn rounded_xl(self: *Self) *Self { self.style.corner_radii = Corners(Pixels).all(12); return self; }
    pub fn rounded_full(self: *Self) *Self { self.style.corner_radii = Corners(Pixels).all(9999); return self; }
    pub fn rounded_t(self: *Self, radius: Px) *Self { 
        self.style.corner_radii.top_left = radius.value;
        self.style.corner_radii.top_right = radius.value;
        return self; 
    }
    pub fn rounded_b(self: *Self, radius: Px) *Self { 
        self.style.corner_radii.bottom_left = radius.value;
        self.style.corner_radii.bottom_right = radius.value;
        return self; 
    }

    // ========================================================================
    // Position
    // ========================================================================

    pub fn relative(self: *Self) *Self { self.style.position = .relative; return self; }
    pub fn absolute(self: *Self) *Self { self.style.position = .absolute; return self; }
    pub fn inset_0(self: *Self) *Self {
        self.style.inset.top = .{ .px = 0 };
        self.style.inset.right = .{ .px = 0 };
        self.style.inset.bottom = .{ .px = 0 };
        self.style.inset.left = .{ .px = 0 };
        return self;
    }
    pub fn top(self: *Self, val: Px) *Self { self.style.inset.top = .{ .px = val.value }; return self; }
    pub fn right(self: *Self, val: Px) *Self { self.style.inset.right = .{ .px = val.value }; return self; }
    pub fn bottom(self: *Self, val: Px) *Self { self.style.inset.bottom = .{ .px = val.value }; return self; }
    pub fn left(self: *Self, val: Px) *Self { self.style.inset.left = .{ .px = val.value }; return self; }

    // ========================================================================
    // Overflow
    // ========================================================================

    pub fn overflow_hidden(self: *Self) *Self { 
        self.style.overflow.x = .hidden;
        self.style.overflow.y = .hidden;
        return self; 
    }
    pub fn overflow_visible(self: *Self) *Self { 
        self.style.overflow.x = .visible;
        self.style.overflow.y = .visible;
        return self; 
    }
    pub fn overflow_scroll(self: *Self) *Self { 
        self.style.overflow.x = .scroll;
        self.style.overflow.y = .scroll;
        return self; 
    }
    pub fn overflow_x_hidden(self: *Self) *Self { self.style.overflow.x = .hidden; return self; }
    pub fn overflow_y_hidden(self: *Self) *Self { self.style.overflow.y = .hidden; return self; }
    pub fn overflow_x_scroll(self: *Self) *Self { self.style.overflow.x = .scroll; return self; }
    pub fn overflow_y_scroll(self: *Self) *Self { self.style.overflow.y = .scroll; return self; }

    // ========================================================================
    // Text
    // ========================================================================

    pub fn text_color(self: *Self, color: Hsla) *Self { self.text_color_val = color; return self; }
    pub fn text_size(self: *Self, sz: Px) *Self { self.text_size_val = sz.value; return self; }
    pub fn text_xs(self: *Self) *Self { self.text_size_val = 12; return self; }
    pub fn text_sm(self: *Self) *Self { self.text_size_val = 14; return self; }
    pub fn text_base(self: *Self) *Self { self.text_size_val = 16; return self; }
    pub fn text_lg(self: *Self) *Self { self.text_size_val = 18; return self; }
    pub fn text_xl(self: *Self) *Self { self.text_size_val = 20; return self; }
    pub fn text_2xl(self: *Self) *Self { self.text_size_val = 24; return self; }
    pub fn text_3xl(self: *Self) *Self { self.text_size_val = 30; return self; }

    // ========================================================================
    // Hover
    // ========================================================================
    
    pub fn hover_bg(self: *Self, color: Hsla) *Self { self.hover_bg_val = color; return self; }
    pub fn hover_border_color(self: *Self, color: Hsla) *Self { self.hover_border_color_val = color; return self; }
    pub fn hover_text_color(self: *Self, color: Hsla) *Self { self.hover_text_color_val = color; return self; }

    // ========================================================================
    // ID & Hitbox
    // ========================================================================

    /// Set element ID for hit testing (matches GPUI's .id())
    pub fn id(self: *Self, hitbox: usize) *Self { self.hitbox_id = hitbox; return self; }

    // ========================================================================
    // Conditional
    // ========================================================================

    pub fn when(self: *Self, condition: bool, apply: *const fn (*Self) *Self) *Self {
        if (condition) {
            return apply(self);
        }
        return self;
    }

    // ========================================================================
    // Children
    // ========================================================================

    /// Add a child - accepts either a *Div or a string (like GPUI's .child())
    pub fn child(self: *Self, c: anytype) *Self {
        const T = @TypeOf(c);
        const allocator = g_allocator orelse std.heap.page_allocator;
        
        if (T == *Div) {
            // Inherit text styles recursively
            inheritTextStylesRecursive(c, self.text_color_val, self.text_size_val);
            self.children_list.append(allocator, c) catch {};
        } else if (T == []const u8 or T == *const [c.len:0]u8) {
            // String child - wrap in a text div (like GPUI's .child("text"))
            self.text_content_val = c;
        } else {
            @compileError("child() requires *Div or string literal");
        }
        return self;
    }

    /// Add multiple children at once (like GPUI's .children(vec![...]))
    pub fn children(self: *Self, kids: []const *Div) *Self {
        const allocator = g_allocator orelse std.heap.page_allocator;
        for (kids) |c| {
            // Inherit text styles recursively
            inheritTextStylesRecursive(c, self.text_color_val, self.text_size_val);
            self.children_list.append(allocator, c) catch {};
        }
        return self;
    }
    
    fn inheritTextStylesRecursive(d: *Div, parent_color: Hsla, parent_size: f32) void {
        const default_text_color = color_mod.rgb(0xe2e8f0);
        // Inherit color if using default
        if (d.text_color_val.h == default_text_color.h and 
            d.text_color_val.s == default_text_color.s and 
            d.text_color_val.l == default_text_color.l) {
            d.text_color_val = parent_color;
        }
        // Inherit size if using default (14)
        if (d.text_size_val == 14) {
            d.text_size_val = parent_size;
        }
        // Recurse to children
        for (d.children_list.items) |c| {
            inheritTextStylesRecursive(c, d.text_color_val, d.text_size_val);
        }
    }

    /// Add text as a child (like GPUI's .child("text"))
    pub fn child_text(self: *Self, text: []const u8) *Self {
        self.text_content_val = text;
        return self;
    }

    // ========================================================================
    // Layout & Rendering
    // ========================================================================

    pub fn build(self: *Self, tree: *zaffy.Zaffy, rem_size: Pixels) !void {
        try self.buildWithTextSystem(tree, rem_size, null);
    }

    pub fn buildWithTextSystem(self: *Self, tree: *zaffy.Zaffy, rem_size: Pixels, text_system: ?*TextSystem) !void {
        for (self.children_list.items) |c| {
            try c.buildWithTextSystem(tree, rem_size, text_system);
        }
        
        const allocator = g_allocator orelse std.heap.page_allocator;
        var child_ids = std.ArrayListUnmanaged(zaffy.NodeId){};
        try child_ids.ensureTotalCapacity(allocator, self.children_list.items.len);
        defer child_ids.deinit(allocator);
        
        for (self.children_list.items) |c| {
            if (c.node_id) |nid| {
                try child_ids.append(allocator, nid);
            }
        }
        
        var ts = self.style.toZaffy(rem_size);
        
        // If this div has text content and no explicit size, measure the text
        // to give it an intrinsic size (like GPUI does)
        if (self.text_content_val) |text| {
            if (text_system) |tsys| {
                const font_id: text_system_mod.FontId = 0;
                const text_width = tsys.measureText(text, font_id, self.text_size_val);
                const metrics = tsys.getFontMetrics(font_id, self.text_size_val);
                const text_height = metrics.ascent - metrics.descent;
                
                // Only set size if not already explicitly set
                if (ts.size.width == .auto) {
                    ts.size.width = .{ .length = text_width };
                }
                if (ts.size.height == .auto) {
                    ts.size.height = .{ .length = text_height };
                }
            }
        }
        
        self.node_id = if (child_ids.items.len == 0)
            try tree.newLeaf(ts)
        else
            try tree.newWithChildren(ts, child_ids.items);
    }

    /// Paint the div and its children to a scene
    pub fn paint(
        self: *const Self,
        scene: *Scene,
        text_system: *TextSystem,
        parent_x: Pixels,
        parent_y: Pixels,
        tree: *const zaffy.Zaffy,
        hitbox_fn: ?*const fn (usize, Bounds(Pixels)) void,
        is_hovered_fn: ?*const fn (usize) bool,
    ) void {
        const nid = self.node_id orelse return;
        const layout = tree.getLayout(nid);
        const x = parent_x + layout.location.x;
        const y = parent_y + layout.location.y;
        const width = layout.size.width;
        const height = layout.size.height;
        
        // Check if hovered (for hover styles)
        var is_hovered = false;
        if (self.hitbox_id) |hid| {
            // Register hitbox
            if (hitbox_fn) |hfn| {
                hfn(hid, .{ .origin = .{ .x = x, .y = y }, .size = .{ .width = width, .height = height } });
            }
            // Check hover state
            if (is_hovered_fn) |ifn| {
                is_hovered = ifn(hid);
            }
        }
        
        // Apply hover styles if hovered
        var effective_style = self.style;
        var effective_text_color = self.text_color_val;
        if (is_hovered) {
            if (self.hover_bg_val) |hbg| {
                effective_style.background = .{ .solid = hbg };
            }
            if (self.hover_border_color_val) |hbc| {
                effective_style.border_color = hbc;
            }
            if (self.hover_text_color_val) |htc| {
                effective_text_color = htc;
            }
        }
        
        // Render shadow first (behind the quad)
        if (effective_style.box_shadow) |box_shadow| {
            scene.insertShadow(.{
                .bounds = .{ 
                    .origin = .{ .x = x + box_shadow.offset.x, .y = y + box_shadow.offset.y }, 
                    .size = .{ .width = width, .height = height } 
                },
                .corner_radii = effective_style.corner_radii,
                .color = box_shadow.color,
                .blur_radius = box_shadow.blur_radius,
                .spread_radius = box_shadow.spread_radius,
            }) catch {};
        }
        
        // Render the quad (background + border)
        const bs: scene_mod.BorderStyle = @enumFromInt(@intFromEnum(effective_style.border_style));
        if (effective_style.background) |bg_color| {
            scene.insertQuad(.{
                .bounds = .{ .origin = .{ .x = x, .y = y }, .size = .{ .width = width, .height = height } },
                .background = bg_color,
                .border_color = effective_style.border_color,
                .border_widths = effective_style.border_widths,
                .border_style = bs,
                .corner_radii = effective_style.corner_radii,
            }) catch {};
        } else if (effective_style.border_color) |_| {
            // Has border but no background
            scene.insertQuad(.{
                .bounds = .{ .origin = .{ .x = x, .y = y }, .size = .{ .width = width, .height = height } },
                .background = null,
                .border_color = effective_style.border_color,
                .border_widths = effective_style.border_widths,
                .border_style = bs,
                .corner_radii = effective_style.corner_radii,
            }) catch {};
        }
        
        // Render text if any
        if (self.text_content_val) |t| {
            // Center text in the div
            const font_id: text_system_mod.FontId = 0;
            const text_width = text_system.measureText(t, font_id, self.text_size_val);
            const metrics = text_system.getFontMetrics(font_id, self.text_size_val);
            const text_height = metrics.ascent - metrics.descent;
            const tx = x + (width - text_width) / 2;
            const ty = y + (height - text_height) / 2 + metrics.ascent;
            
            text_system.renderText(scene, t, tx, ty, self.text_size_val, effective_text_color) catch {};
        }

        for (self.children_list.items) |c| {
            c.paint(scene, text_system, x, y, tree, hitbox_fn, is_hovered_fn);
        }
    }

    /// Paint without rendering text to scene (for D3D11 where text is rendered separately)
    pub fn paintQuadsOnly(
        self: *const Self,
        scene: *Scene,
        parent_x: Pixels,
        parent_y: Pixels,
        tree: *const zaffy.Zaffy,
    ) void {
        const nid = self.node_id orelse return;
        const layout = tree.getLayout(nid);
        const x = parent_x + layout.location.x;
        const y = parent_y + layout.location.y;
        const width = layout.size.width;
        const height = layout.size.height;
        
        // Render shadow
        if (self.style.box_shadow) |box_shadow| {
            // Clamp corner radii to half the minimum dimension (for circles)
            const max_radius = @min(width, height) / 2.0;
            const clamped_radii = geometry.Corners(geometry.Pixels){
                .top_left = @min(self.style.corner_radii.top_left, max_radius),
                .top_right = @min(self.style.corner_radii.top_right, max_radius),
                .bottom_right = @min(self.style.corner_radii.bottom_right, max_radius),
                .bottom_left = @min(self.style.corner_radii.bottom_left, max_radius),
            };
            scene.insertShadow(.{
                .bounds = .{ 
                    .origin = .{ .x = x + box_shadow.offset.x, .y = y + box_shadow.offset.y }, 
                    .size = .{ .width = width, .height = height } 
                },
                .corner_radii = clamped_radii,
                .color = box_shadow.color,
                .blur_radius = box_shadow.blur_radius,
                .spread_radius = box_shadow.spread_radius,
            }) catch {};
        }
        
        // Render the quad (background + border)
        const bs2: scene_mod.BorderStyle = @enumFromInt(@intFromEnum(self.style.border_style));
        if (self.style.background) |bg_color| {
            scene.insertQuad(.{
                .bounds = .{ .origin = .{ .x = x, .y = y }, .size = .{ .width = width, .height = height } },
                .background = bg_color,
                .border_color = self.style.border_color,
                .border_widths = self.style.border_widths,
                .border_style = bs2,
                .corner_radii = self.style.corner_radii,
            }) catch {};
        } else if (self.style.border_color) |_| {
            scene.insertQuad(.{
                .bounds = .{ .origin = .{ .x = x, .y = y }, .size = .{ .width = width, .height = height } },
                .background = null,
                .border_color = self.style.border_color,
                .border_widths = self.style.border_widths,
                .border_style = bs2,
                .corner_radii = self.style.corner_radii,
            }) catch {};
        }

        // Recurse (skip text)
        for (self.children_list.items) |c| {
            c.paintQuadsOnly(scene, x, y, tree);
        }
    }
};

// ============================================================================
// Global allocator for div()
// ============================================================================

var g_allocator: ?Allocator = null;

/// Initialize the div system with an allocator
pub fn initAllocator(allocator: Allocator) void {
    g_allocator = allocator;
}

/// Reset is now a no-op since we use proper allocation
/// Call this at frame boundaries if you want to track frame-based allocation
pub fn reset() void {
    // No-op - divs are allocated dynamically
}

/// Create a new div (matches GPUI's div() function)
pub fn div() *Div {
    const allocator = g_allocator orelse std.heap.page_allocator;
    const d = allocator.create(Div) catch @panic("Failed to allocate Div");
    d.* = .{};
    return d;
}

/// Create a vertical flex container (matches GPUI's v_flex())
pub fn v_flex() *Div {
    return div().flex().flex_col();
}

/// Create a horizontal flex container (matches GPUI's h_flex())
pub fn h_flex() *Div {
    return div().flex().flex_row();
}

/// Text draw callback for D3D11 rendering
pub const TextDrawFn = *const fn (
    text: []const u8,
    x: Pixels,
    y: Pixels,
    size: Pixels,
    color_r: f32,
    color_g: f32,
    color_b: f32,
    color_a: f32,
    ctx: ?*anyopaque,
) void;

/// Walk div tree and call callback for each text element
pub fn drawTextWithCallback(
    d: *const Div,
    tree: *const zaffy.Zaffy,
    parent_x: Pixels,
    parent_y: Pixels,
    callback: TextDrawFn,
    ctx: ?*anyopaque,
) void {
    const nid = d.node_id orelse return;
    const layout = tree.getLayout(nid);
    const x = parent_x + layout.location.x;
    const y = parent_y + layout.location.y;

    if (d.text_content_val) |text| {
        // Calculate centered position (simplified - assumes centered layout)
        // The callback can do its own measurement for precise centering
        const tc = d.text_color_val.toRgba();
        callback(text, x, y, d.text_size_val, tc.r, tc.g, tc.b, tc.a, ctx);
    }

    for (d.children_list.items) |child| {
        drawTextWithCallback(child, tree, x, y, callback, ctx);
    }
}

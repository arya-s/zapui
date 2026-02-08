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

// ============================================================================
// Div Element
// ============================================================================

pub const MAX_CHILDREN = 8;

pub const Div = struct {
    style: Style = .{},
    text_content_val: ?[]const u8 = null,
    text_size_val: Pixels = 14,
    text_color_val: Hsla = color_mod.rgb(0xe2e8f0),
    hitbox_id: ?usize = null,
    children: [MAX_CHILDREN]?*Div = [_]?*Div{null} ** MAX_CHILDREN,
    child_count: usize = 0,
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

    pub fn flex_grow(self: *Self) *Self { self.style.flex_grow = 1; return self; }
    pub fn flex_shrink(self: *Self) *Self { self.style.flex_shrink = 1; return self; }
    pub fn flex_shrink_0(self: *Self) *Self { self.style.flex_shrink = 0; return self; }
    pub fn flex_1(self: *Self) *Self { 
        self.style.flex_grow = 1; 
        self.style.flex_shrink = 1; 
        self.style.flex_basis = .{ .px = 0 }; 
        return self; 
    }
    pub fn flex_auto(self: *Self) *Self {
        self.style.flex_grow = 1;
        self.style.flex_shrink = 1;
        self.style.flex_basis = .auto;
        return self;
    }
    pub fn flex_none(self: *Self) *Self {
        self.style.flex_grow = 0;
        self.style.flex_shrink = 0;
        return self;
    }
    pub fn flex_wrap(self: *Self) *Self { self.style.flex_wrap = .wrap; return self; }
    pub fn flex_wrap_reverse(self: *Self) *Self { self.style.flex_wrap = .wrap_reverse; return self; }
    pub fn flex_nowrap(self: *Self) *Self { self.style.flex_wrap = .no_wrap; return self; }

    // ========================================================================
    // Size
    // ========================================================================

    pub fn w(self: *Self, width: Px) *Self { self.style.size.width = .{ .px = width.value }; return self; }
    pub fn h(self: *Self, height: Px) *Self { self.style.size.height = .{ .px = height.value }; return self; }
    pub fn size_full(self: *Self) *Self { 
        self.style.size.width = .{ .percent = 100 }; 
        self.style.size.height = .{ .percent = 100 }; 
        return self; 
    }
    pub fn w_full(self: *Self) *Self { self.style.size.width = .{ .percent = 100 }; return self; }
    pub fn h_full(self: *Self) *Self { self.style.size.height = .{ .percent = 100 }; return self; }
    pub fn w_auto(self: *Self) *Self { self.style.size.width = .auto; return self; }
    pub fn h_auto(self: *Self) *Self { self.style.size.height = .auto; return self; }
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
    pub fn size_1(self: *Self) *Self { self.style.size.width = .{ .px = 4 }; self.style.size.height = .{ .px = 4 }; return self; }
    pub fn size_2(self: *Self) *Self { self.style.size.width = .{ .px = 8 }; self.style.size.height = .{ .px = 8 }; return self; }
    pub fn size_3(self: *Self) *Self { self.style.size.width = .{ .px = 12 }; self.style.size.height = .{ .px = 12 }; return self; }
    pub fn size_4(self: *Self) *Self { self.style.size.width = .{ .px = 16 }; self.style.size.height = .{ .px = 16 }; return self; }
    pub fn size_5(self: *Self) *Self { self.style.size.width = .{ .px = 20 }; self.style.size.height = .{ .px = 20 }; return self; }
    pub fn size_6(self: *Self) *Self { self.style.size.width = .{ .px = 24 }; self.style.size.height = .{ .px = 24 }; return self; }
    pub fn size_7(self: *Self) *Self { self.style.size.width = .{ .px = 28 }; self.style.size.height = .{ .px = 28 }; return self; }
    pub fn size_8(self: *Self) *Self { self.style.size.width = .{ .px = 32 }; self.style.size.height = .{ .px = 32 }; return self; }
    pub fn size_9(self: *Self) *Self { self.style.size.width = .{ .px = 36 }; self.style.size.height = .{ .px = 36 }; return self; }
    pub fn size_10(self: *Self) *Self { self.style.size.width = .{ .px = 40 }; self.style.size.height = .{ .px = 40 }; return self; }
    pub fn size_12(self: *Self) *Self { self.style.size.width = .{ .px = 48 }; self.style.size.height = .{ .px = 48 }; return self; }
    pub fn size_16(self: *Self) *Self { self.style.size.width = .{ .px = 64 }; self.style.size.height = .{ .px = 64 }; return self; }

    // ========================================================================
    // Gap
    // ========================================================================

    pub fn gap(self: *Self, val: Px) *Self { 
        self.style.gap = .{ .width = .{ .px = val.value }, .height = .{ .px = val.value } }; 
        return self; 
    }
    pub fn gap_x(self: *Self, val: Px) *Self { self.style.gap.width = .{ .px = val.value }; return self; }
    pub fn gap_y(self: *Self, val: Px) *Self { self.style.gap.height = .{ .px = val.value }; return self; }
    
    /// Gap presets (matches GPUI's gap_N where N * 4 = pixels)
    pub fn gap_0(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 0 }, .height = .{ .px = 0 } }; return self; }
    pub fn gap_1(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 4 }, .height = .{ .px = 4 } }; return self; }
    pub fn gap_2(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 8 }, .height = .{ .px = 8 } }; return self; }
    pub fn gap_3(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 12 }, .height = .{ .px = 12 } }; return self; }
    pub fn gap_4(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 16 }, .height = .{ .px = 16 } }; return self; }
    pub fn gap_5(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 20 }, .height = .{ .px = 20 } }; return self; }
    pub fn gap_6(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 24 }, .height = .{ .px = 24 } }; return self; }
    pub fn gap_8(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 32 }, .height = .{ .px = 32 } }; return self; }
    pub fn gap_10(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 40 }, .height = .{ .px = 40 } }; return self; }
    pub fn gap_12(self: *Self) *Self { self.style.gap = .{ .width = .{ .px = 48 }, .height = .{ .px = 48 } }; return self; }

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
    // Alignment
    // ========================================================================

    pub fn justify_start(self: *Self) *Self { self.style.justify_content = .flex_start; return self; }
    pub fn justify_end(self: *Self) *Self { self.style.justify_content = .flex_end; return self; }
    pub fn justify_center(self: *Self) *Self { self.style.justify_content = .center; return self; }
    pub fn justify_between(self: *Self) *Self { self.style.justify_content = .space_between; return self; }
    pub fn justify_around(self: *Self) *Self { self.style.justify_content = .space_around; return self; }
    pub fn justify_evenly(self: *Self) *Self { self.style.justify_content = .space_evenly; return self; }

    pub fn items_start(self: *Self) *Self { self.style.align_items = .flex_start; return self; }
    pub fn items_end(self: *Self) *Self { self.style.align_items = .flex_end; return self; }
    pub fn items_center(self: *Self) *Self { self.style.align_items = .center; return self; }
    pub fn items_stretch(self: *Self) *Self { self.style.align_items = .stretch; return self; }
    pub fn items_baseline(self: *Self) *Self { self.style.align_items = .baseline; return self; }

    pub fn self_start(self: *Self) *Self { self.style.align_self = .flex_start; return self; }
    pub fn self_end(self: *Self) *Self { self.style.align_self = .flex_end; return self; }
    pub fn self_center(self: *Self) *Self { self.style.align_self = .center; return self; }
    pub fn self_stretch(self: *Self) *Self { self.style.align_self = .stretch; return self; }

    pub fn content_start(self: *Self) *Self { self.style.align_content = .flex_start; return self; }
    pub fn content_end(self: *Self) *Self { self.style.align_content = .flex_end; return self; }
    pub fn content_center(self: *Self) *Self { self.style.align_content = .center; return self; }
    pub fn content_stretch(self: *Self) *Self { self.style.align_content = .stretch; return self; }
    pub fn content_between(self: *Self) *Self { self.style.align_content = .space_between; return self; }
    pub fn content_around(self: *Self) *Self { self.style.align_content = .space_around; return self; }

    // ========================================================================
    // Position
    // ========================================================================

    pub fn relative(self: *Self) *Self { self.style.position = .relative; return self; }
    pub fn absolute(self: *Self) *Self { self.style.position = .absolute; return self; }
    pub fn top(self: *Self, val: Px) *Self { self.style.inset.top = .{ .px = val.value }; return self; }
    pub fn right(self: *Self, val: Px) *Self { self.style.inset.right = .{ .px = val.value }; return self; }
    pub fn bottom(self: *Self, val: Px) *Self { self.style.inset.bottom = .{ .px = val.value }; return self; }
    pub fn left(self: *Self, val: Px) *Self { self.style.inset.left = .{ .px = val.value }; return self; }

    // ========================================================================
    // Background
    // ========================================================================

    pub fn bg(self: *Self, color: Hsla) *Self { self.style.background = .{ .solid = color }; return self; }

    // ========================================================================
    // Shadow
    // ========================================================================

    /// Custom shadow
    pub fn shadow(self: *Self, shadow_def: style_mod.BoxShadow) *Self { 
        self.style.box_shadow = shadow_def; 
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
    pub fn border_color(self: *Self, color: Hsla) *Self { self.style.border_color = color; return self; }

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
    pub fn overflow_x_hidden(self: *Self) *Self { self.style.overflow.x = .hidden; return self; }
    pub fn overflow_y_hidden(self: *Self) *Self { self.style.overflow.y = .hidden; return self; }

    // ========================================================================
    // Interaction
    // ========================================================================

    pub fn id(self: *Self, hitbox_id: usize) *Self { self.hitbox_id = hitbox_id; return self; }

    // ========================================================================
    // Conditionals
    // ========================================================================

    /// Conditionally apply a transformation (like GPUI's .when())
    /// Usage: div().when(condition, struct { fn f(d: *Div) *Div { return d.bg(color); } }.f)
    pub fn when(self: *Self, condition: bool, apply: *const fn (*Self) *Self) *Self {
        if (condition) {
            return apply(self);
        }
        return self;
    }

    // ========================================================================
    // Hover Styles
    // ========================================================================

    /// Set background color on hover
    pub fn hover_bg(self: *Self, color: Hsla) *Self { 
        self.hover_bg_val = color; 
        return self; 
    }
    
    /// Set border color on hover
    pub fn hover_border_color(self: *Self, color: Hsla) *Self { 
        self.hover_border_color_val = color; 
        return self; 
    }
    
    /// Set text color on hover
    pub fn hover_text_color(self: *Self, color: Hsla) *Self { 
        self.hover_text_color_val = color; 
        return self; 
    }

    // ========================================================================
    // Children
    // ========================================================================

    /// Add a div as a child
    pub fn child(self: *Self, c: *Div) *Self {
        // Inherit text styles from parent if child uses defaults
        const default_text_color = color_mod.rgb(0xe2e8f0);
        if (c.text_color_val.h == default_text_color.h and 
            c.text_color_val.s == default_text_color.s and 
            c.text_color_val.l == default_text_color.l) {
            c.text_color_val = self.text_color_val;
        }
        if (c.text_size_val == 14) {
            c.text_size_val = self.text_size_val;
        }
        
        if (self.child_count < MAX_CHILDREN) {
            self.children[self.child_count] = c;
            self.child_count += 1;
        }
        return self;
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
        for (self.children[0..self.child_count]) |maybe_child| {
            if (maybe_child) |c| try c.buildWithTextSystem(tree, rem_size, text_system);
        }
        
        var child_ids: [MAX_CHILDREN]zaffy.NodeId = undefined;
        var count: usize = 0;
        for (self.children[0..self.child_count]) |maybe_child| {
            if (maybe_child) |c| {
                if (c.node_id) |nid| {
                    child_ids[count] = nid;
                    count += 1;
                }
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
        
        self.node_id = if (count == 0)
            try tree.newLeaf(ts)
        else
            try tree.newWithChildren(ts, child_ids[0..count]);
    }

    pub fn paint(
        self: *const Self,
        scene: *Scene,
        text_system: *TextSystem,
        parent_x: Pixels,
        parent_y: Pixels,
        tree: *const zaffy.Zaffy,
        hitbox_fn: ?*const fn (Bounds(Pixels), usize) void,
        is_hovered_fn: ?*const fn (usize) bool,
    ) void {
        const nid = self.node_id orelse return;
        const layout = tree.getLayout(nid);
        
        const x = parent_x + layout.location.x;
        const y = parent_y + layout.location.y;
        const lw = layout.size.width;
        const lh = layout.size.height;
        const bounds = Bounds(Pixels).fromXYWH(x, y, lw, lh);

        if (self.hitbox_id) |hid| {
            if (hitbox_fn) |f| f(bounds, hid);
        }

        // Check if this element is hovered
        const hovered = if (self.hitbox_id) |hid| 
            if (is_hovered_fn) |f| f(hid) else false
        else false;

        // Apply hover styles if hovered
        var effective_style = self.style;
        var effective_text_color = self.text_color_val;
        
        if (hovered) {
            if (self.hover_bg_val) |hover_bg_color| {
                effective_style.background = .{ .solid = hover_bg_color };
            }
            if (self.hover_border_color_val) |hover_bc| {
                effective_style.border_color = hover_bc;
            }
            if (self.hover_text_color_val) |hover_tc| {
                effective_text_color = hover_tc;
            }
        }

        // Render shadow first (behind the quad)
        if (effective_style.box_shadow) |box_shadow| {
            scene.insertShadow(.{
                .bounds = bounds,
                .color = box_shadow.color,
                .blur_radius = box_shadow.blur_radius,
                .corner_radii = self.style.corner_radii,
            }) catch {};
        }

        if (effective_style.background != null or effective_style.border_color != null) {
            scene.insertQuad(.{
                .bounds = bounds,
                .background = effective_style.background,
                .border_color = effective_style.border_color,
                .border_widths = self.style.border_widths,
                .corner_radii = self.style.corner_radii,
            }) catch {};
        }

        if (self.text_content_val) |t| {
            // Use actual text measurement instead of approximations
            const font_id: text_system_mod.FontId = 0;
            const tw = text_system.measureText(t, font_id, self.text_size_val);
            const metrics = text_system.getFontMetrics(font_id, self.text_size_val);
            
            const padding_l = self.style.padding.left.resolve(null, 16) orelse 0;
            const padding_r = self.style.padding.right.resolve(null, 16) orelse 0;
            const padding_t = self.style.padding.top.resolve(null, 16) orelse 0;
            const padding_b = self.style.padding.bottom.resolve(null, 16) orelse 0;
            const inner_w = lw - padding_l - padding_r;
            const inner_h = lh - padding_t - padding_b;
            
            const tx = x + padding_l + switch (self.style.justify_content orelse .flex_start) {
                .center, .space_between, .space_around, .space_evenly => (inner_w - tw) / 2,
                .flex_end => inner_w - tw,
                else => 0,
            };
            
            // Use actual font metrics for baseline positioning
            // Text height = ascent - descent (descent is negative)
            // For vertical centering: baseline = (inner_h + ascent + descent) / 2
            const ty = y + padding_t + switch (self.style.align_items orelse .stretch) {
                .center => (inner_h + metrics.ascent + metrics.descent) / 2,
                .flex_end => inner_h + metrics.descent,
                .flex_start => metrics.ascent,
                else => (inner_h + metrics.ascent + metrics.descent) / 2,
            };
            
            text_system.renderText(scene, t, tx, ty, self.text_size_val, effective_text_color) catch {};
        }

        for (self.children[0..self.child_count]) |maybe_child| {
            if (maybe_child) |c| {
                c.paint(scene, text_system, x, y, tree, hitbox_fn, is_hovered_fn);
            }
        }
    }
};

// ============================================================================
// Element Storage
// ============================================================================

const MAX_ELEMENTS = 512;
var g_elements: [MAX_ELEMENTS]Div = undefined;
var g_element_count: usize = 0;

/// Reset element storage (call at start of each frame)
pub fn reset() void {
    g_element_count = 0;
}

/// Create a new div (matches GPUI's div() function)
pub fn div() *Div {
    if (g_element_count < MAX_ELEMENTS) {
        g_elements[g_element_count] = .{};
        const ptr = &g_elements[g_element_count];
        g_element_count += 1;
        return ptr;
    }
    return &g_elements[MAX_ELEMENTS - 1];
}

/// Create a vertical flex container (matches GPUI's v_flex())
pub fn v_flex() *Div {
    return div().flex().flex_col();
}

/// Create a horizontal flex container (matches GPUI's h_flex())
pub fn h_flex() *Div {
    return div().flex().flex_row();
}

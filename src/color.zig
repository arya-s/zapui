//! Color types and utilities for zapui.
//! Provides HSLA and RGBA color representations with conversion utilities.

const std = @import("std");

/// HSLA color representation (hue, saturation, lightness, alpha).
/// All values are in the range [0, 1], except hue which is [0, 1] representing [0°, 360°].
pub const Hsla = struct {
    h: f32, // Hue: 0-1 (maps to 0-360 degrees)
    s: f32, // Saturation: 0-1
    l: f32, // Lightness: 0-1
    a: f32, // Alpha: 0-1

    pub const transparent = Hsla{ .h = 0, .s = 0, .l = 0, .a = 0 };
    pub const black = Hsla{ .h = 0, .s = 0, .l = 0, .a = 1 };
    pub const white = Hsla{ .h = 0, .s = 0, .l = 1, .a = 1 };

    /// Convert to RGBA
    pub fn toRgba(self: Hsla) Rgba {
        if (self.s == 0) {
            // Achromatic (gray)
            return .{ .r = self.l, .g = self.l, .b = self.l, .a = self.a };
        }

        const q = if (self.l < 0.5)
            self.l * (1 + self.s)
        else
            self.l + self.s - self.l * self.s;
        const p = 2 * self.l - q;

        return .{
            .r = hueToRgb(p, q, self.h + 1.0 / 3.0),
            .g = hueToRgb(p, q, self.h),
            .b = hueToRgb(p, q, self.h - 1.0 / 3.0),
            .a = self.a,
        };
    }

    /// Blend with another color
    pub fn blend(self: Hsla, other: Hsla, t: f32) Hsla {
        return .{
            .h = lerp(self.h, other.h, t),
            .s = lerp(self.s, other.s, t),
            .l = lerp(self.l, other.l, t),
            .a = lerp(self.a, other.a, t),
        };
    }

    /// Lighten by a factor (0-1)
    pub fn lighten(self: Hsla, amount: f32) Hsla {
        return .{
            .h = self.h,
            .s = self.s,
            .l = @min(1.0, self.l + amount),
            .a = self.a,
        };
    }

    /// Darken by a factor (0-1)
    pub fn darken(self: Hsla, amount: f32) Hsla {
        return .{
            .h = self.h,
            .s = self.s,
            .l = @max(0.0, self.l - amount),
            .a = self.a,
        };
    }

    /// Adjust opacity
    pub fn withAlpha(self: Hsla, alpha: f32) Hsla {
        return .{ .h = self.h, .s = self.s, .l = self.l, .a = alpha };
    }

    /// Fade (multiply alpha)
    pub fn fade(self: Hsla, factor: f32) Hsla {
        return .{ .h = self.h, .s = self.s, .l = self.l, .a = self.a * factor };
    }
};

/// RGBA color representation.
/// All values are in the range [0, 1].
pub const Rgba = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub const transparent = Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const black = Rgba{ .r = 0, .g = 0, .b = 0, .a = 1 };
    pub const white = Rgba{ .r = 1, .g = 1, .b = 1, .a = 1 };

    /// Convert to HSLA
    pub fn toHsla(self: Rgba) Hsla {
        const max_c = @max(@max(self.r, self.g), self.b);
        const min_c = @min(@min(self.r, self.g), self.b);
        const delta = max_c - min_c;
        const l = (max_c + min_c) / 2;

        if (delta == 0) {
            return .{ .h = 0, .s = 0, .l = l, .a = self.a };
        }

        const s = if (l < 0.5)
            delta / (max_c + min_c)
        else
            delta / (2 - max_c - min_c);

        var h: f32 = 0;
        if (max_c == self.r) {
            h = (self.g - self.b) / delta + (if (self.g < self.b) @as(f32, 6) else @as(f32, 0));
        } else if (max_c == self.g) {
            h = (self.b - self.r) / delta + 2;
        } else {
            h = (self.r - self.g) / delta + 4;
        }
        h /= 6;

        return .{ .h = h, .s = s, .l = l, .a = self.a };
    }

    /// Convert to u8 array [r, g, b, a] (0-255 range)
    pub fn toU8Array(self: Rgba) [4]u8 {
        return .{
            @intFromFloat(@round(self.r * 255)),
            @intFromFloat(@round(self.g * 255)),
            @intFromFloat(@round(self.b * 255)),
            @intFromFloat(@round(self.a * 255)),
        };
    }

    /// Create from u8 values (0-255 range)
    pub fn fromU8(r: u8, g: u8, b: u8, a: u8) Rgba {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
            .a = @as(f32, @floatFromInt(a)) / 255.0,
        };
    }

    /// Blend with another color using alpha compositing
    pub fn blend(self: Rgba, other: Rgba, t: f32) Rgba {
        return .{
            .r = lerp(self.r, other.r, t),
            .g = lerp(self.g, other.g, t),
            .b = lerp(self.b, other.b, t),
            .a = lerp(self.a, other.a, t),
        };
    }

    /// Premultiply alpha
    pub fn premultiply(self: Rgba) Rgba {
        return .{
            .r = self.r * self.a,
            .g = self.g * self.a,
            .b = self.b * self.a,
            .a = self.a,
        };
    }
};

// ============================================================================
// Color constructors
// ============================================================================

/// Create an HSLA color from hue (0-1), saturation (0-1), lightness (0-1), alpha (0-1)
pub fn hsla(h: f32, s: f32, l: f32, a: f32) Hsla {
    return .{ .h = h, .s = s, .l = l, .a = a };
}

/// Create an opaque HSLA color from hue (0-1), saturation (0-1), lightness (0-1)
pub fn hsl(h: f32, s: f32, l: f32) Hsla {
    return .{ .h = h, .s = s, .l = l, .a = 1.0 };
}

/// Create an HSLA color from a hex RGB value (e.g., 0xFF5500)
pub fn rgb(hex: u24) Hsla {
    const r: f32 = @floatFromInt((hex >> 16) & 0xFF);
    const g: f32 = @floatFromInt((hex >> 8) & 0xFF);
    const b: f32 = @floatFromInt(hex & 0xFF);
    return (Rgba{ .r = r / 255.0, .g = g / 255.0, .b = b / 255.0, .a = 1.0 }).toHsla();
}

/// Create an HSLA color from a hex RGBA value (e.g., 0xFF550080)
pub fn rgba(hex: u32) Hsla {
    const r: f32 = @floatFromInt((hex >> 24) & 0xFF);
    const g: f32 = @floatFromInt((hex >> 16) & 0xFF);
    const b: f32 = @floatFromInt((hex >> 8) & 0xFF);
    const a: f32 = @floatFromInt(hex & 0xFF);
    return (Rgba{ .r = r / 255.0, .g = g / 255.0, .b = b / 255.0, .a = a / 255.0 }).toHsla();
}

// ============================================================================
// Named colors
// ============================================================================

pub fn transparent() Hsla {
    return Hsla.transparent;
}

pub fn black() Hsla {
    return Hsla.black;
}

pub fn white() Hsla {
    return Hsla.white;
}

pub fn red() Hsla {
    return rgb(0xFF0000);
}

pub fn green() Hsla {
    return rgb(0x00FF00);
}

pub fn blue() Hsla {
    return rgb(0x0000FF);
}

pub fn yellow() Hsla {
    return rgb(0xFFFF00);
}

pub fn cyan() Hsla {
    return rgb(0x00FFFF);
}

pub fn magenta() Hsla {
    return rgb(0xFF00FF);
}

pub fn gray() Hsla {
    return rgb(0x808080);
}

// ============================================================================
// Helper functions
// ============================================================================

fn hueToRgb(p: f32, q: f32, t_in: f32) f32 {
    var t = t_in;
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1.0 / 6.0) return p + (q - p) * 6 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6;
    return p;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// ============================================================================
// Tests
// ============================================================================

test "rgb hex to Hsla" {
    // Pure red
    const c_red = rgb(0xFF0000);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c_red.h, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c_red.s, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), c_red.l, 0.001);

    // Pure green
    const c_green = rgb(0x00FF00);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), c_green.h, 0.001);

    // Pure blue
    const c_blue = rgb(0x0000FF);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), c_blue.h, 0.001);

    // White
    const c_white = rgb(0xFFFFFF);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c_white.s, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), c_white.l, 0.001);

    // Black
    const c_black = rgb(0x000000);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c_black.l, 0.001);
}

test "Hsla to Rgba roundtrip" {
    const original = hsla(0.5, 0.6, 0.4, 0.8);
    const as_rgba = original.toRgba();
    const back = as_rgba.toHsla();

    try std.testing.expectApproxEqAbs(original.h, back.h, 0.001);
    try std.testing.expectApproxEqAbs(original.s, back.s, 0.001);
    try std.testing.expectApproxEqAbs(original.l, back.l, 0.001);
    try std.testing.expectApproxEqAbs(original.a, back.a, 0.001);
}

test "Rgba toU8Array" {
    const c = Rgba{ .r = 1.0, .g = 0.5, .b = 0.0, .a = 0.8 };
    const arr = c.toU8Array();

    try std.testing.expectEqual(@as(u8, 255), arr[0]);
    try std.testing.expectEqual(@as(u8, 128), arr[1]);
    try std.testing.expectEqual(@as(u8, 0), arr[2]);
    try std.testing.expectEqual(@as(u8, 204), arr[3]);
}

test "color manipulation" {
    const c = rgb(0x808080); // Gray

    const lighter = c.lighten(0.2);
    try std.testing.expect(lighter.l > c.l);

    const darker = c.darken(0.2);
    try std.testing.expect(darker.l < c.l);

    const faded = c.fade(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), faded.a, 0.001);
}

test "blend colors" {
    const c1 = Hsla{ .h = 0.0, .s = 1.0, .l = 0.5, .a = 1.0 }; // Red
    const c2 = Hsla{ .h = 0.5, .s = 1.0, .l = 0.5, .a = 1.0 }; // Cyan

    const blended = c1.blend(c2, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), blended.h, 0.001);
}

//! Abstract Text Atlas Interface
//!
//! Provides a renderer-agnostic interface for glyph atlas management.
//! Renderers implement this interface to receive glyph data.

const std = @import("std");
const geometry = @import("geometry.zig");

const Bounds = geometry.Bounds;

/// A tile in the atlas (UV coordinates)
pub const AtlasTile = struct {
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,

    pub fn toBounds(self: AtlasTile) Bounds(f32) {
        return Bounds(f32).fromXYWH(self.u0, self.v0, self.u1 - self.u0, self.v1 - self.v0);
    }
};

/// Abstract atlas interface - implemented by renderers
pub const TextAtlas = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Upload glyph bitmap data and return UV coordinates
        /// Returns null if atlas is full
        uploadGlyph: *const fn (
            ptr: *anyopaque,
            width: u32,
            height: u32,
            data: []const u8,
            is_color: bool,
        ) ?AtlasTile,

        /// Get the atlas texture size
        getSize: *const fn (ptr: *anyopaque) u32,
    };

    pub fn uploadGlyph(self: TextAtlas, width: u32, height: u32, data: []const u8, is_color: bool) ?AtlasTile {
        return self.vtable.uploadGlyph(self.ptr, width, height, data, is_color);
    }

    pub fn getSize(self: TextAtlas) u32 {
        return self.vtable.getSize(self.ptr);
    }
};

/// Simple CPU-side atlas for glyph packing
/// Used by renderers to track where glyphs are placed
pub const GlyphPacker = struct {
    size: u32,
    next_x: u32,
    next_y: u32,
    row_height: u32,

    pub fn init(size: u32) GlyphPacker {
        return .{
            .size = size,
            .next_x = 1,
            .next_y = 1,
            .row_height = 0,
        };
    }

    /// Allocate space for a glyph, returns UV coordinates
    pub fn allocate(self: *GlyphPacker, width: u32, height: u32) ?AtlasTile {
        if (width == 0 or height == 0) {
            return AtlasTile{ .u0 = 0, .v0 = 0, .u1 = 0, .v1 = 0 };
        }

        // Check if we need to wrap to next row
        if (self.next_x + width + 1 > self.size) {
            self.next_x = 1;
            self.next_y += self.row_height + 1;
            self.row_height = 0;
        }

        // Check if we've run out of vertical space
        if (self.next_y + height + 1 > self.size) {
            return null; // Atlas full
        }

        const x = self.next_x;
        const y = self.next_y;

        // Update tracking
        self.next_x += width + 1;
        if (height > self.row_height) {
            self.row_height = height;
        }

        // Return UV coordinates
        const size_f: f32 = @floatFromInt(self.size);
        return AtlasTile{
            .u0 = @as(f32, @floatFromInt(x)) / size_f,
            .v0 = @as(f32, @floatFromInt(y)) / size_f,
            .u1 = @as(f32, @floatFromInt(x + width)) / size_f,
            .v1 = @as(f32, @floatFromInt(y + height)) / size_f,
        };
    }

    /// Reset for a new frame/atlas
    pub fn reset(self: *GlyphPacker) void {
        self.next_x = 1;
        self.next_y = 1;
        self.row_height = 0;
    }
};

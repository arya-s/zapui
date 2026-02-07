//! Texture atlas for zapui.
//! Uses a simple shelf-packing algorithm for glyph and image allocation.

const std = @import("std");
const gl = @import("gl.zig");
const geometry = @import("../geometry.zig");

const Allocator = std.mem.Allocator;
const Size = geometry.Size;
const Bounds = geometry.Bounds;

/// A tile allocated in the atlas
pub const AtlasTile = struct {
    /// UV bounds in normalized coordinates (0-1)
    uv_bounds: Bounds(f32),
    /// Pixel bounds in the atlas
    pixel_bounds: Bounds(u32),
};

/// A shelf in the shelf-packing algorithm
const Shelf = struct {
    y: u32,
    height: u32,
    next_x: u32,
};

/// Texture atlas using shelf-packing
pub const Atlas = struct {
    texture: gl.GLuint,
    width: u32,
    height: u32,
    shelves: std.ArrayListUnmanaged(Shelf),
    allocator: Allocator,
    is_mono: bool, // true for single-channel (glyphs), false for RGBA

    pub fn init(allocator: Allocator, width: u32, height: u32, mono: bool) !Atlas {
        var texture: gl.GLuint = 0;
        gl.glGenTextures(1, @ptrCast(&texture));
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture);

        // Set texture parameters
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);

        // Allocate texture storage
        if (mono) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
            gl.glTexImage2D(
                gl.GL_TEXTURE_2D,
                0,
                gl.GL_R8,
                @intCast(width),
                @intCast(height),
                0,
                gl.GL_RED,
                gl.GL_UNSIGNED_BYTE,
                null,
            );
        } else {
            gl.glTexImage2D(
                gl.GL_TEXTURE_2D,
                0,
                gl.GL_RGBA8,
                @intCast(width),
                @intCast(height),
                0,
                gl.GL_RGBA,
                gl.GL_UNSIGNED_BYTE,
                null,
            );
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);

        return .{
            .texture = texture,
            .width = width,
            .height = height,
            .shelves = .{ .items = &.{}, .capacity = 0 },
            .allocator = allocator,
            .is_mono = mono,
        };
    }

    pub fn deinit(self: *Atlas) void {
        if (self.texture != 0) {
            gl.glDeleteTextures(1, @ptrCast(&self.texture));
            self.texture = 0;
        }
        self.shelves.deinit(self.allocator);
    }

    /// Allocate a tile in the atlas
    pub fn allocate(self: *Atlas, size: Size(u32)) !?AtlasTile {
        if (size.width == 0 or size.height == 0) {
            return null;
        }

        // Add padding to prevent bleeding
        const padded_width = size.width + 2;
        const padded_height = size.height + 2;

        // Try to find a shelf that fits
        for (self.shelves.items) |*shelf| {
            if (shelf.height >= padded_height and shelf.next_x + padded_width <= self.width) {
                const tile = AtlasTile{
                    .pixel_bounds = Bounds(u32).fromXYWH(
                        shelf.next_x + 1,
                        shelf.y + 1,
                        size.width,
                        size.height,
                    ),
                    .uv_bounds = Bounds(f32).fromXYWH(
                        @as(f32, @floatFromInt(shelf.next_x + 1)) / @as(f32, @floatFromInt(self.width)),
                        @as(f32, @floatFromInt(shelf.y + 1)) / @as(f32, @floatFromInt(self.height)),
                        @as(f32, @floatFromInt(size.width)) / @as(f32, @floatFromInt(self.width)),
                        @as(f32, @floatFromInt(size.height)) / @as(f32, @floatFromInt(self.height)),
                    ),
                };
                shelf.next_x += padded_width;
                return tile;
            }
        }

        // Create a new shelf
        const shelf_y: u32 = if (self.shelves.items.len == 0)
            0
        else blk: {
            const last = self.shelves.items[self.shelves.items.len - 1];
            break :blk last.y + last.height;
        };

        if (shelf_y + padded_height > self.height) {
            // Atlas is full
            return null;
        }

        try self.shelves.append(self.allocator, .{
            .y = shelf_y,
            .height = padded_height,
            .next_x = padded_width,
        });

        return AtlasTile{
            .pixel_bounds = Bounds(u32).fromXYWH(1, shelf_y + 1, size.width, size.height),
            .uv_bounds = Bounds(f32).fromXYWH(
                1.0 / @as(f32, @floatFromInt(self.width)),
                @as(f32, @floatFromInt(shelf_y + 1)) / @as(f32, @floatFromInt(self.height)),
                @as(f32, @floatFromInt(size.width)) / @as(f32, @floatFromInt(self.width)),
                @as(f32, @floatFromInt(size.height)) / @as(f32, @floatFromInt(self.height)),
            ),
        };
    }

    /// Upload pixel data to a tile
    pub fn upload(self: *Atlas, tile: AtlasTile, data: []const u8) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture);

        const x: gl.GLint = @intCast(tile.pixel_bounds.origin.x);
        const y: gl.GLint = @intCast(tile.pixel_bounds.origin.y);
        const w: gl.GLsizei = @intCast(tile.pixel_bounds.size.width);
        const h: gl.GLsizei = @intCast(tile.pixel_bounds.size.height);

        if (self.is_mono) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
            gl.glTexSubImage2D(
                gl.GL_TEXTURE_2D,
                0,
                x,
                y,
                w,
                h,
                gl.GL_RED,
                gl.GL_UNSIGNED_BYTE,
                data.ptr,
            );
        } else {
            gl.glTexSubImage2D(
                gl.GL_TEXTURE_2D,
                0,
                x,
                y,
                w,
                h,
                gl.GL_RGBA,
                gl.GL_UNSIGNED_BYTE,
                data.ptr,
            );
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
    }

    /// Bind the atlas texture
    pub fn bind(self: *const Atlas, unit: u32) void {
        gl.glActiveTexture(gl.GL_TEXTURE0 + unit);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture);
    }

    /// Clear the atlas (reset allocations, keep texture)
    pub fn clear(self: *Atlas) void {
        self.shelves.clearRetainingCapacity();
    }
};

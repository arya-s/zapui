//! Texture atlas for zapui.
//!
//! Uses a skyline bin-packing algorithm for efficient glyph and image allocation.
//! Based on Jukka Jylänki's "A Thousand Ways to Pack the Bin" paper.
//!
//! The Atlas is CPU-side only. Use GlAtlas for GPU texture management with
//! lazy synchronization via the `modified` counter.

const std = @import("std");
const gl = @import("gl.zig");
const geometry = @import("../geometry.zig");

const Allocator = std.mem.Allocator;
const Size = geometry.Size;
const Bounds = geometry.Bounds;

/// Pixel format for the atlas
pub const Format = enum {
    /// 1 byte per pixel (grayscale text glyphs)
    grayscale,
    /// 4 bytes per pixel (color images, emoji)
    bgra,

    pub fn depth(self: Format) u32 {
        return switch (self) {
            .grayscale => 1,
            .bgra => 4,
        };
    }
};

/// A region allocated in the atlas
pub const Region = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,

    /// Convert to UV bounds (normalized 0-1 coordinates)
    pub fn toUvBounds(self: Region, atlas_size: u32) Bounds(f32) {
        const size_f: f32 = @floatFromInt(atlas_size);
        return Bounds(f32).fromXYWH(
            @as(f32, @floatFromInt(self.x)) / size_f,
            @as(f32, @floatFromInt(self.y)) / size_f,
            @as(f32, @floatFromInt(self.width)) / size_f,
            @as(f32, @floatFromInt(self.height)) / size_f,
        );
    }
};

/// A tile allocated in the atlas (legacy compatibility)
pub const AtlasTile = struct {
    /// UV bounds in normalized coordinates (0-1)
    uv_bounds: Bounds(f32),
    /// Pixel bounds in the atlas
    pixel_bounds: Bounds(u32),
};

/// A node tracks a horizontal span of available space at a given y.
/// Think of it as a "shelf" in the skyline packing algorithm.
const Node = struct {
    x: u32,
    y: u32,
    width: u32,
};

/// CPU-side texture atlas with skyline bin-packing.
///
/// Glyphs are packed into a CPU-side pixel buffer. The renderer syncs
/// the buffer to a GPU texture when the `modified` counter changes.
/// A 1px border is reserved around the atlas edges to prevent sampling artifacts.
pub const Atlas = struct {
    /// CPU-side pixel buffer (row-major, tightly packed per format depth)
    data: []u8,
    /// Width = height (always square)
    size: u32,
    /// Available horizontal spans (skyline nodes)
    nodes: std.ArrayListUnmanaged(Node),
    /// Pixel format
    format: Format,
    /// Bumped on every pixel write. Renderer compares this to know when
    /// to re-upload to the GPU.
    modified: std.atomic.Value(usize),
    /// Allocator used for internal allocations
    allocator: Allocator,

    pub fn init(allocator: Allocator, size: u32, format: Format) !Atlas {
        const depth = format.depth();
        const data = try allocator.alloc(u8, @as(usize, size) * size * depth);
        @memset(data, 0);

        // Start with a single node spanning the usable area (1px border on each side)
        var nodes = std.ArrayListUnmanaged(Node){};
        try nodes.append(allocator, .{ .x = 1, .y = 1, .width = size - 2 });

        return .{
            .data = data,
            .size = size,
            .nodes = nodes,
            .format = format,
            .modified = std.atomic.Value(usize).init(1), // Start at 1 so first sync happens
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Atlas) void {
        self.allocator.free(self.data);
        self.nodes.deinit(self.allocator);
        self.* = undefined;
    }

    /// Reserve a rectangle of the given size in the atlas.
    /// Returns the region (top-left x, y, width, height) where pixels should be written.
    /// Returns `error.AtlasFull` if the glyph doesn't fit.
    pub fn reserve(self: *Atlas, width: u32, height: u32) !Region {
        // Add 1px padding around each glyph to prevent GL_LINEAR from
        // sampling neighboring glyphs in the atlas.
        const padded_width = width + 1;
        const padded_height = height + 1;

        // Find best position using best-height-then-best-width heuristic
        var best_idx: ?usize = null;
        var best_height: u32 = std.math.maxInt(u32);
        var best_width: u32 = std.math.maxInt(u32);
        var best_y: u32 = 0;

        for (self.nodes.items, 0..) |_, idx| {
            if (self.fit(idx, padded_width, padded_height)) |y| {
                // Height heuristic: minimize the resulting top edge (y + height)
                const result_height = y + padded_height;
                if (result_height < best_height or
                    (result_height == best_height and self.nodes.items[idx].width < best_width))
                {
                    best_height = result_height;
                    best_width = self.nodes.items[idx].width;
                    best_y = y;
                    best_idx = idx;
                }
            }
        }

        const idx = best_idx orelse return error.AtlasFull;
        const x = self.nodes.items[idx].x;

        // Insert a new node for the padded rectangle (padding is below/right)
        const new_node = Node{ .x = x, .y = best_y + padded_height, .width = padded_width };
        try self.nodes.insert(self.allocator, idx, new_node);

        // Shrink or remove overlapping nodes to the right
        while (idx + 1 < self.nodes.items.len) {
            const prev = self.nodes.items[idx];
            var node = &self.nodes.items[idx + 1];

            const prev_end = prev.x + prev.width;
            if (node.x < prev_end) {
                const shrink = prev_end - node.x;
                if (node.width <= shrink) {
                    // Completely covered — remove it
                    _ = self.nodes.orderedRemove(idx + 1);
                    continue;
                } else {
                    // Partially covered — shrink it
                    node.x += shrink;
                    node.width -= shrink;
                    break;
                }
            } else {
                break;
            }
        }

        // Merge adjacent nodes with the same y
        self.merge();

        return .{ .x = x, .y = best_y, .width = width, .height = height };
    }

    /// Allocate a tile in the atlas (legacy API compatibility)
    pub fn allocate(self: *Atlas, size_arg: Size(u32)) !?AtlasTile {
        if (size_arg.width == 0 or size_arg.height == 0) {
            return null;
        }

        const region = self.reserve(size_arg.width, size_arg.height) catch return null;

        return AtlasTile{
            .pixel_bounds = Bounds(u32).fromXYWH(region.x, region.y, region.width, region.height),
            .uv_bounds = region.toUvBounds(self.size),
        };
    }

    /// Copy pixel data into the atlas at the given region.
    /// `src` must contain exactly `region.width * region.height * format.depth()` bytes.
    /// Bumps the `modified` counter atomically.
    pub fn set(self: *Atlas, region: Region, src: []const u8) void {
        const depth = self.format.depth();
        const expected_len = region.width * region.height * depth;
        std.debug.assert(src.len == expected_len);

        const atlas_stride = self.size * depth;
        for (0..region.height) |row| {
            const dst_offset = (region.y + @as(u32, @intCast(row))) * atlas_stride + region.x * depth;
            const src_offset = @as(u32, @intCast(row)) * region.width * depth;
            const row_bytes = region.width * depth;
            @memcpy(
                self.data[dst_offset..][0..row_bytes],
                src[src_offset..][0..row_bytes],
            );
        }

        _ = self.modified.fetchAdd(1, .release);
    }

    /// Upload pixel data to a tile (legacy API compatibility)
    pub fn upload(self: *Atlas, tile: AtlasTile, data_bytes: []const u8) void {
        self.set(.{
            .x = tile.pixel_bounds.origin.x,
            .y = tile.pixel_bounds.origin.y,
            .width = tile.pixel_bounds.size.width,
            .height = tile.pixel_bounds.size.height,
        }, data_bytes);
    }

    /// Grow the atlas to a larger size. Existing pixel data is preserved
    /// (copied to top-left of the new buffer). Nodes are extended to cover
    /// the new space.
    pub fn grow(self: *Atlas, new_size: u32) !void {
        std.debug.assert(new_size > self.size);

        const depth = self.format.depth();
        const new_data = try self.allocator.alloc(u8, @as(usize, new_size) * new_size * depth);
        @memset(new_data, 0);

        // Copy existing rows into the new buffer
        const old_stride = self.size * depth;
        const new_stride = new_size * depth;
        for (0..self.size) |row| {
            const old_offset = row * old_stride;
            const new_offset = row * new_stride;
            @memcpy(new_data[new_offset..][0..old_stride], self.data[old_offset..][0..old_stride]);
        }

        self.allocator.free(self.data);
        self.data = new_data;

        // Add a node for the new space to the right of the old area
        const old_size = self.size;
        self.size = new_size;

        try self.nodes.append(self.allocator, .{
            .x = old_size - 1,
            .y = 1,
            .width = new_size - old_size,
        });

        self.merge();

        _ = self.modified.fetchAdd(1, .release);
    }

    /// Clear the atlas (reset allocations, keep buffer)
    pub fn clear(self: *Atlas) void {
        self.nodes.clearRetainingCapacity();
        self.nodes.append(self.allocator, .{ .x = 1, .y = 1, .width = self.size - 2 }) catch {};
        @memset(self.data, 0);
        _ = self.modified.fetchAdd(1, .release);
    }

    /// Get the current modification counter
    pub fn getModified(self: *const Atlas) usize {
        return self.modified.load(.acquire);
    }

    // ========================================================================
    // Internal helpers
    // ========================================================================

    /// Check if a rectangle of (width, height) fits starting at node `idx`.
    /// Returns the maximum y coordinate across all spanned nodes, or null if
    /// the rectangle extends beyond the atlas boundary.
    fn fit(self: *const Atlas, idx: usize, width: u32, height: u32) ?u32 {
        const nodes = self.nodes.items;
        const x = nodes[idx].x;

        // Check right boundary (1px border)
        if (x + width > self.size - 1) return null;

        var remaining_width = width;
        var max_y: u32 = 0;
        var i = idx;

        while (remaining_width > 0) {
            if (i >= nodes.len) return null;

            const node = nodes[i];
            max_y = @max(max_y, node.y);

            // Check bottom boundary (1px border)
            if (max_y + height > self.size - 1) return null;

            if (node.width >= remaining_width) {
                remaining_width = 0;
            } else {
                remaining_width -= node.width;
            }
            i += 1;
        }

        return max_y;
    }

    /// Merge adjacent nodes with the same y coordinate
    fn merge(self: *Atlas) void {
        var i: usize = 0;
        while (i + 1 < self.nodes.items.len) {
            const a = &self.nodes.items[i];
            const b = self.nodes.items[i + 1];
            if (a.y == b.y) {
                a.width += b.width;
                _ = self.nodes.orderedRemove(i + 1);
            } else {
                i += 1;
            }
        }
    }
};

/// GPU-backed texture atlas with lazy synchronization.
///
/// Wraps a CPU-side Atlas and manages an OpenGL texture that is
/// automatically re-uploaded when the atlas data changes.
pub const GlAtlas = struct {
    /// CPU-side atlas data
    atlas: Atlas,
    /// OpenGL texture handle
    texture: gl.GLuint,
    /// Last synced modification counter
    last_synced: usize,

    pub fn init(allocator: Allocator, size: u32, format: Format) !GlAtlas {
        var cpu_atlas = try Atlas.init(allocator, size, format);
        errdefer cpu_atlas.deinit();

        var texture: gl.GLuint = 0;
        gl.glGenTextures(1, @ptrCast(&texture));
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture);

        // Set texture parameters
        // Use NEAREST filtering for crisp text rendering
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);

        // Allocate texture storage
        if (format == .grayscale) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
            gl.glTexImage2D(
                gl.GL_TEXTURE_2D,
                0,
                gl.GL_R8,
                @intCast(size),
                @intCast(size),
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
                @intCast(size),
                @intCast(size),
                0,
                gl.GL_RGBA,
                gl.GL_UNSIGNED_BYTE,
                null,
            );
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);

        return .{
            .atlas = cpu_atlas,
            .texture = texture,
            .last_synced = 0, // Force initial sync
        };
    }

    pub fn deinit(self: *GlAtlas) void {
        if (self.texture != 0) {
            gl.glDeleteTextures(1, @ptrCast(&self.texture));
            self.texture = 0;
        }
        self.atlas.deinit();
    }

    /// Sync the CPU atlas to the GPU texture if modified.
    /// Call this before rendering.
    pub fn sync(self: *GlAtlas) void {
        const current = self.atlas.getModified();
        if (current == self.last_synced) return;

        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture);

        if (self.atlas.format == .grayscale) {
            gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);
            gl.glTexSubImage2D(
                gl.GL_TEXTURE_2D,
                0,
                0,
                0,
                @intCast(self.atlas.size),
                @intCast(self.atlas.size),
                gl.GL_RED,
                gl.GL_UNSIGNED_BYTE,
                self.atlas.data.ptr,
            );
        } else {
            gl.glTexSubImage2D(
                gl.GL_TEXTURE_2D,
                0,
                0,
                0,
                @intCast(self.atlas.size),
                @intCast(self.atlas.size),
                gl.GL_RGBA,
                gl.GL_UNSIGNED_BYTE,
                self.atlas.data.ptr,
            );
        }

        gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
        self.last_synced = current;
    }

    /// Bind the atlas texture to a texture unit
    pub fn bind(self: *GlAtlas, unit: u32) void {
        self.sync(); // Ensure texture is up-to-date
        gl.glActiveTexture(gl.GL_TEXTURE0 + unit);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture);
    }

    /// Reserve a region in the atlas
    pub fn reserve(self: *GlAtlas, width: u32, height: u32) !Region {
        return self.atlas.reserve(width, height);
    }

    /// Allocate a tile (legacy API)
    pub fn allocate(self: *GlAtlas, size_arg: Size(u32)) !?AtlasTile {
        return self.atlas.allocate(size_arg);
    }

    /// Set pixel data in a region
    pub fn set(self: *GlAtlas, region: Region, src: []const u8) void {
        self.atlas.set(region, src);
    }

    /// Upload pixel data to a tile (legacy API)
    pub fn upload(self: *GlAtlas, tile: AtlasTile, data_bytes: []const u8) void {
        self.atlas.upload(tile, data_bytes);
    }

    /// Get the atlas size
    pub fn getSize(self: *const GlAtlas) u32 {
        return self.atlas.size;
    }

    /// Get the format
    pub fn getFormat(self: *const GlAtlas) Format {
        return self.atlas.format;
    }

    /// Clear the atlas
    pub fn clear(self: *GlAtlas) void {
        self.atlas.clear();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Atlas reserve and set" {
    const allocator = std.testing.allocator;
    var atlas = try Atlas.init(allocator, 64, .grayscale);
    defer atlas.deinit();

    // Reserve a region
    const region = try atlas.reserve(10, 10);
    try std.testing.expect(region.x >= 1);
    try std.testing.expect(region.y >= 1);
    try std.testing.expectEqual(@as(u32, 10), region.width);
    try std.testing.expectEqual(@as(u32, 10), region.height);

    // Set some data
    var data: [100]u8 = undefined;
    @memset(&data, 255);
    atlas.set(region, &data);

    // Check modified counter increased
    try std.testing.expect(atlas.getModified() >= 2);
}

test "Atlas skyline packing" {
    const allocator = std.testing.allocator;
    var atlas = try Atlas.init(allocator, 64, .grayscale);
    defer atlas.deinit();

    // Allocate several regions
    const r1 = try atlas.reserve(10, 10);
    const r2 = try atlas.reserve(10, 10);
    const r3 = try atlas.reserve(10, 10);

    // They should all fit without error
    try std.testing.expect(r1.x != r2.x or r1.y != r2.y);
    try std.testing.expect(r2.x != r3.x or r2.y != r3.y);
}

test "Atlas full" {
    const allocator = std.testing.allocator;
    var atlas = try Atlas.init(allocator, 16, .grayscale);
    defer atlas.deinit();

    // Try to allocate something too large (usable area is 14x14 with borders)
    const result = atlas.reserve(20, 20);
    try std.testing.expectError(error.AtlasFull, result);
}

test "Atlas legacy API compatibility" {
    const allocator = std.testing.allocator;
    var atlas = try Atlas.init(allocator, 64, .grayscale);
    defer atlas.deinit();

    // Use legacy allocate API
    const tile = try atlas.allocate(.{ .width = 8, .height = 8 });
    try std.testing.expect(tile != null);

    if (tile) |t| {
        try std.testing.expect(t.uv_bounds.size.width > 0);
        try std.testing.expect(t.uv_bounds.size.height > 0);

        // Upload using legacy API
        var data: [64]u8 = undefined;
        @memset(&data, 128);
        atlas.upload(t, &data);
    }
}

//! OpenGL 3.3 renderer for zapui.
//! Renders scene primitives using instanced rendering.

const std = @import("std");
const gl = @import("gl.zig");
const shaders = @import("shaders.zig");
const atlas_mod = @import("atlas.zig");
const scene_mod = @import("../scene.zig");
const geometry = @import("../geometry.zig");
const color = @import("../color.zig");
const style = @import("../style.zig");

const Allocator = std.mem.Allocator;
const Size = geometry.Size;
const Scene = scene_mod.Scene;
const Quad = scene_mod.Quad;
const Shadow = scene_mod.Shadow;
const ShaderProgram = shaders.ShaderProgram;
const Atlas = atlas_mod.Atlas;
const Hsla = color.Hsla;

/// Instance data for quad rendering
const QuadInstance = extern struct {
    // a_bounds: vec4
    bounds_x: f32,
    bounds_y: f32,
    bounds_w: f32,
    bounds_h: f32,
    // a_background_color: vec4
    bg_r: f32,
    bg_g: f32,
    bg_b: f32,
    bg_a: f32,
    // a_border_color: vec4
    border_r: f32,
    border_g: f32,
    border_b: f32,
    border_a: f32,
    // a_border_widths: vec4
    border_top: f32,
    border_right: f32,
    border_bottom: f32,
    border_left: f32,
    // a_corner_radii: vec4
    radius_tl: f32,
    radius_tr: f32,
    radius_br: f32,
    radius_bl: f32,
    // a_content_mask: vec4
    mask_x: f32,
    mask_y: f32,
    mask_w: f32,
    mask_h: f32,
};

/// Instance data for shadow rendering
const ShadowInstance = extern struct {
    // a_bounds: vec4
    bounds_x: f32,
    bounds_y: f32,
    bounds_w: f32,
    bounds_h: f32,
    // a_corner_radii: vec4
    radius_tl: f32,
    radius_tr: f32,
    radius_br: f32,
    radius_bl: f32,
    // a_blur_radius: float
    blur_radius: f32,
    // padding for alignment
    _pad0: f32 = 0,
    _pad1: f32 = 0,
    _pad2: f32 = 0,
    // a_color: vec4
    color_r: f32,
    color_g: f32,
    color_b: f32,
    color_a: f32,
    // a_content_mask: vec4
    mask_x: f32,
    mask_y: f32,
    mask_w: f32,
    mask_h: f32,
};

/// Unit quad vertices (two triangles)
const unit_quad_vertices = [_]f32{
    0, 0,
    1, 0,
    0, 1,
    1, 0,
    1, 1,
    0, 1,
};

/// OpenGL 3.3 renderer
pub const GlRenderer = struct {
    allocator: Allocator,
    quad_program: ShaderProgram,
    shadow_program: ShaderProgram,
    sprite_program: ShaderProgram,
    quad_vao: gl.GLuint,
    quad_vertex_vbo: gl.GLuint,
    quad_instance_vbo: gl.GLuint,
    shadow_vao: gl.GLuint,
    shadow_instance_vbo: gl.GLuint,
    sprite_vao: gl.GLuint,
    sprite_instance_vbo: gl.GLuint,
    glyph_atlas: Atlas,
    image_atlas: Atlas,
    viewport_size: Size(f32),
    scale_factor: f32,
    max_instances: usize,
    quad_instances: std.ArrayListUnmanaged(QuadInstance),
    shadow_instances: std.ArrayListUnmanaged(ShadowInstance),

    pub fn init(allocator: Allocator) !GlRenderer {
        // Create shader programs
        var quad_program = try shaders.createQuadProgram(allocator);
        errdefer quad_program.deinit();

        var shadow_program = try shaders.createShadowProgram(allocator);
        errdefer shadow_program.deinit();

        var sprite_program = try shaders.createSpriteProgram(allocator);
        errdefer sprite_program.deinit();

        // Create VAO and VBOs for quads
        var quad_vao: gl.GLuint = 0;
        var quad_vertex_vbo: gl.GLuint = 0;
        var quad_instance_vbo: gl.GLuint = 0;

        gl.glGenVertexArrays(1, @ptrCast(&quad_vao));
        gl.glGenBuffers(1, @ptrCast(&quad_vertex_vbo));
        gl.glGenBuffers(1, @ptrCast(&quad_instance_vbo));

        gl.glBindVertexArray(quad_vao);

        // Upload unit quad vertices
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, quad_vertex_vbo);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(unit_quad_vertices)),
            &unit_quad_vertices,
            gl.GL_STATIC_DRAW,
        );

        // Vertex position attribute (location 0)
        gl.glEnableVertexAttribArray(0);
        gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 2 * @sizeOf(f32), null);

        // Setup instance buffer
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, quad_instance_vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, 1024 * @sizeOf(QuadInstance), null, gl.GL_DYNAMIC_DRAW);

        // Instance attributes (locations 1-6)
        const stride: gl.GLsizei = @sizeOf(QuadInstance);
        var offset: usize = 0;

        // a_bounds (location 1)
        gl.glEnableVertexAttribArray(1);
        gl.glVertexAttribPointer(1, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(1, 1);
        offset += 4 * @sizeOf(f32);

        // a_background_color (location 2)
        gl.glEnableVertexAttribArray(2);
        gl.glVertexAttribPointer(2, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(2, 1);
        offset += 4 * @sizeOf(f32);

        // a_border_color (location 3)
        gl.glEnableVertexAttribArray(3);
        gl.glVertexAttribPointer(3, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(3, 1);
        offset += 4 * @sizeOf(f32);

        // a_border_widths (location 4)
        gl.glEnableVertexAttribArray(4);
        gl.glVertexAttribPointer(4, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(4, 1);
        offset += 4 * @sizeOf(f32);

        // a_corner_radii (location 5)
        gl.glEnableVertexAttribArray(5);
        gl.glVertexAttribPointer(5, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(5, 1);
        offset += 4 * @sizeOf(f32);

        // a_content_mask (location 6)
        gl.glEnableVertexAttribArray(6);
        gl.glVertexAttribPointer(6, 4, gl.GL_FLOAT, gl.GL_FALSE, stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(6, 1);

        gl.glBindVertexArray(0);

        // Create VAO for shadows (similar setup)
        var shadow_vao: gl.GLuint = 0;
        var shadow_instance_vbo: gl.GLuint = 0;

        gl.glGenVertexArrays(1, @ptrCast(&shadow_vao));
        gl.glGenBuffers(1, @ptrCast(&shadow_instance_vbo));

        gl.glBindVertexArray(shadow_vao);

        // Reuse unit quad vertices
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, quad_vertex_vbo);
        gl.glEnableVertexAttribArray(0);
        gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 2 * @sizeOf(f32), null);

        // Shadow instance buffer
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, shadow_instance_vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, 256 * @sizeOf(ShadowInstance), null, gl.GL_DYNAMIC_DRAW);

        const shadow_stride: gl.GLsizei = @sizeOf(ShadowInstance);
        offset = 0;

        // a_bounds (location 1)
        gl.glEnableVertexAttribArray(1);
        gl.glVertexAttribPointer(1, 4, gl.GL_FLOAT, gl.GL_FALSE, shadow_stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(1, 1);
        offset += 4 * @sizeOf(f32);

        // a_corner_radii (location 2)
        gl.glEnableVertexAttribArray(2);
        gl.glVertexAttribPointer(2, 4, gl.GL_FLOAT, gl.GL_FALSE, shadow_stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(2, 1);
        offset += 4 * @sizeOf(f32);

        // a_blur_radius (location 3) - needs vec4 for attribute, we'll use x component
        gl.glEnableVertexAttribArray(3);
        gl.glVertexAttribPointer(3, 1, gl.GL_FLOAT, gl.GL_FALSE, shadow_stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(3, 1);
        offset += 4 * @sizeOf(f32); // Skip padding too

        // a_color (location 4)
        gl.glEnableVertexAttribArray(4);
        gl.glVertexAttribPointer(4, 4, gl.GL_FLOAT, gl.GL_FALSE, shadow_stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(4, 1);
        offset += 4 * @sizeOf(f32);

        // a_content_mask (location 5)
        gl.glEnableVertexAttribArray(5);
        gl.glVertexAttribPointer(5, 4, gl.GL_FLOAT, gl.GL_FALSE, shadow_stride, @ptrFromInt(offset));
        gl.glVertexAttribDivisor(5, 1);

        gl.glBindVertexArray(0);

        // Create sprite VAO (placeholder for now)
        var sprite_vao: gl.GLuint = 0;
        var sprite_instance_vbo: gl.GLuint = 0;
        gl.glGenVertexArrays(1, @ptrCast(&sprite_vao));
        gl.glGenBuffers(1, @ptrCast(&sprite_instance_vbo));

        // Create atlases
        var glyph_atlas = try Atlas.init(allocator, 1024, 1024, true);
        errdefer glyph_atlas.deinit();

        var image_atlas = try Atlas.init(allocator, 2048, 2048, false);
        errdefer image_atlas.deinit();

        return .{
            .allocator = allocator,
            .quad_program = quad_program,
            .shadow_program = shadow_program,
            .sprite_program = sprite_program,
            .quad_vao = quad_vao,
            .quad_vertex_vbo = quad_vertex_vbo,
            .quad_instance_vbo = quad_instance_vbo,
            .shadow_vao = shadow_vao,
            .shadow_instance_vbo = shadow_instance_vbo,
            .sprite_vao = sprite_vao,
            .sprite_instance_vbo = sprite_instance_vbo,
            .glyph_atlas = glyph_atlas,
            .image_atlas = image_atlas,
            .viewport_size = .{ .width = 800, .height = 600 },
            .scale_factor = 1.0,
            .max_instances = 1024,
            .quad_instances = .{ .items = &.{}, .capacity = 0 },
            .shadow_instances = .{ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *GlRenderer) void {
        self.quad_program.deinit();
        self.shadow_program.deinit();
        self.sprite_program.deinit();

        if (self.quad_instances.capacity > 0) {
            self.quad_instances.deinit(self.allocator);
        }
        if (self.shadow_instances.capacity > 0) {
            self.shadow_instances.deinit(self.allocator);
        }

        var vaos = [_]gl.GLuint{ self.quad_vao, self.shadow_vao, self.sprite_vao };
        gl.glDeleteVertexArrays(3, @ptrCast(&vaos));

        var vbos = [_]gl.GLuint{
            self.quad_vertex_vbo,
            self.quad_instance_vbo,
            self.shadow_instance_vbo,
            self.sprite_instance_vbo,
        };
        gl.glDeleteBuffers(4, @ptrCast(&vbos));

        self.glyph_atlas.deinit();
        self.image_atlas.deinit();
    }

    /// Set the viewport size
    pub fn setViewport(self: *GlRenderer, width: f32, height: f32, scale: f32) void {
        self.viewport_size = .{ .width = width, .height = height };
        self.scale_factor = scale;
        gl.glViewport(0, 0, @intFromFloat(width * scale), @intFromFloat(height * scale));
    }

    /// Clear the screen
    pub fn clear(self: *GlRenderer, c: Hsla) void {
        _ = self;
        const rgba = c.toRgba();
        gl.glClearColor(rgba.r, rgba.g, rgba.b, rgba.a);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    }

    /// Render a scene
    pub fn drawScene(self: *GlRenderer, scene: *const Scene) !void {
        // Setup render state
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        gl.glDisable(gl.GL_DEPTH_TEST);

        // Draw shadows first (they go behind quads)
        try self.drawShadows(scene.getShadows());

        // Draw quads
        try self.drawQuads(scene.getQuads());

        // TODO: Draw sprites
    }

    fn drawQuads(self: *GlRenderer, quads: []const Quad) !void {
        if (quads.len == 0) return;

        // Build instance data
        self.quad_instances.clearRetainingCapacity();
        for (quads) |quad| {
            const bg_rgba = if (quad.background) |bg| switch (bg) {
                .solid => |c| c.toRgba(),
            } else color.Rgba.transparent;

            const border_rgba = if (quad.border_color) |c| c.toRgba() else color.Rgba.transparent;

            const mask = quad.content_mask orelse geometry.Bounds(f32).zero;

            try self.quad_instances.append(self.allocator, .{
                .bounds_x = quad.bounds.origin.x,
                .bounds_y = quad.bounds.origin.y,
                .bounds_w = quad.bounds.size.width,
                .bounds_h = quad.bounds.size.height,
                .bg_r = bg_rgba.r,
                .bg_g = bg_rgba.g,
                .bg_b = bg_rgba.b,
                .bg_a = bg_rgba.a,
                .border_r = border_rgba.r,
                .border_g = border_rgba.g,
                .border_b = border_rgba.b,
                .border_a = border_rgba.a,
                .border_top = quad.border_widths.top,
                .border_right = quad.border_widths.right,
                .border_bottom = quad.border_widths.bottom,
                .border_left = quad.border_widths.left,
                .radius_tl = quad.corner_radii.top_left,
                .radius_tr = quad.corner_radii.top_right,
                .radius_br = quad.corner_radii.bottom_right,
                .radius_bl = quad.corner_radii.bottom_left,
                .mask_x = mask.origin.x,
                .mask_y = mask.origin.y,
                .mask_w = mask.size.width,
                .mask_h = mask.size.height,
            });
        }

        // Upload instance data
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.quad_instance_vbo);
        const data_size: gl.GLsizeiptr = @intCast(self.quad_instances.items.len * @sizeOf(QuadInstance));
        if (self.quad_instances.items.len > 0) {
            gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, data_size, self.quad_instances.items.ptr);
        }

        // Draw
        self.quad_program.use();
        self.quad_program.setViewport(self.viewport_size.width, self.viewport_size.height);
        gl.glBindVertexArray(self.quad_vao);
        gl.glDrawArraysInstanced(gl.GL_TRIANGLES, 0, 6, @intCast(self.quad_instances.items.len));
        gl.glBindVertexArray(0);
    }

    fn drawShadows(self: *GlRenderer, shadows: []const Shadow) !void {
        if (shadows.len == 0) return;

        // Build instance data
        self.shadow_instances.clearRetainingCapacity();
        for (shadows) |shadow| {
            const rgba = shadow.color.toRgba();
            const mask = shadow.content_mask orelse geometry.Bounds(f32).zero;

            try self.shadow_instances.append(self.allocator, .{
                .bounds_x = shadow.bounds.origin.x,
                .bounds_y = shadow.bounds.origin.y,
                .bounds_w = shadow.bounds.size.width,
                .bounds_h = shadow.bounds.size.height,
                .radius_tl = shadow.corner_radii.top_left,
                .radius_tr = shadow.corner_radii.top_right,
                .radius_br = shadow.corner_radii.bottom_right,
                .radius_bl = shadow.corner_radii.bottom_left,
                .blur_radius = shadow.blur_radius,
                .color_r = rgba.r,
                .color_g = rgba.g,
                .color_b = rgba.b,
                .color_a = rgba.a,
                .mask_x = mask.origin.x,
                .mask_y = mask.origin.y,
                .mask_w = mask.size.width,
                .mask_h = mask.size.height,
            });
        }

        // Upload instance data
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.shadow_instance_vbo);
        const data_size: gl.GLsizeiptr = @intCast(self.shadow_instances.items.len * @sizeOf(ShadowInstance));
        if (self.shadow_instances.items.len > 0) {
            gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, data_size, self.shadow_instances.items.ptr);
        }

        // Draw
        self.shadow_program.use();
        self.shadow_program.setViewport(self.viewport_size.width, self.viewport_size.height);
        gl.glBindVertexArray(self.shadow_vao);
        gl.glDrawArraysInstanced(gl.GL_TRIANGLES, 0, 6, @intCast(self.shadow_instances.items.len));
        gl.glBindVertexArray(0);
    }
};

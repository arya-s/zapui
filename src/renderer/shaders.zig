//! Shader compilation and management for zapui renderer.

const std = @import("std");
const gl = @import("gl.zig");

const Allocator = std.mem.Allocator;

/// Embedded shader sources
pub const quad_vert = @embedFile("../shaders/quad.vert.glsl");
pub const quad_frag = @embedFile("../shaders/quad.frag.glsl");
pub const shadow_vert = @embedFile("../shaders/shadow.vert.glsl");
pub const shadow_frag = @embedFile("../shaders/shadow.frag.glsl");
pub const sprite_vert = @embedFile("../shaders/sprite.vert.glsl");
pub const sprite_frag = @embedFile("../shaders/sprite.frag.glsl");

/// Compiled shader program
pub const ShaderProgram = struct {
    program: gl.GLuint,
    viewport_loc: gl.GLint = -1,
    texture_loc: gl.GLint = -1,
    mono_loc: gl.GLint = -1,

    pub fn deinit(self: *ShaderProgram) void {
        if (self.program != 0) {
            gl.glDeleteProgram(self.program);
            self.program = 0;
        }
    }

    pub fn use(self: *const ShaderProgram) void {
        gl.glUseProgram(self.program);
    }

    pub fn setViewport(self: *const ShaderProgram, width: f32, height: f32) void {
        if (self.viewport_loc >= 0) {
            gl.glUniform2f(self.viewport_loc, width, height);
        }
    }

    pub fn setTexture(self: *const ShaderProgram, unit: gl.GLint) void {
        if (self.texture_loc >= 0) {
            gl.glUniform1i(self.texture_loc, unit);
        }
    }

    pub fn setMono(self: *const ShaderProgram, mono: bool) void {
        if (self.mono_loc >= 0) {
            gl.glUniform1i(self.mono_loc, if (mono) 1 else 0);
        }
    }

    pub fn setUniformInt(self: *const ShaderProgram, name: [*:0]const u8, value: gl.GLint) void {
        const loc = gl.glGetUniformLocation(self.program, name);
        if (loc >= 0) {
            gl.glUniform1i(loc, value);
        }
    }
};

/// Compile a shader from source
fn compileShader(shader_type: gl.GLenum, source: []const u8, allocator: Allocator) !gl.GLuint {
    const shader = gl.glCreateShader(shader_type);
    if (shader == 0) {
        return error.ShaderCreationFailed;
    }
    errdefer gl.glDeleteShader(shader);

    // Set source
    const source_ptr: [*]const gl.GLchar = source.ptr;
    const source_len: gl.GLint = @intCast(source.len);
    gl.glShaderSource(shader, 1, @ptrCast(&source_ptr), @ptrCast(&source_len));

    // Compile
    gl.glCompileShader(shader);

    // Check for errors
    var success: gl.GLint = 0;
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var log_len: gl.GLint = 0;
        gl.glGetShaderiv(shader, gl.GL_INFO_LOG_LENGTH, &log_len);
        if (log_len > 0) {
            const log = try allocator.alloc(u8, @intCast(log_len));
            defer allocator.free(log);
            gl.glGetShaderInfoLog(shader, log_len, null, log.ptr);
            std.log.err("Shader compilation failed: {s}", .{log});
        }
        return error.ShaderCompilationFailed;
    }

    return shader;
}

/// Link a shader program
fn linkProgram(vert_shader: gl.GLuint, frag_shader: gl.GLuint, allocator: Allocator) !gl.GLuint {
    const program = gl.glCreateProgram();
    if (program == 0) {
        return error.ProgramCreationFailed;
    }
    errdefer gl.glDeleteProgram(program);

    gl.glAttachShader(program, vert_shader);
    gl.glAttachShader(program, frag_shader);
    gl.glLinkProgram(program);

    // Check for errors
    var success: gl.GLint = 0;
    gl.glGetProgramiv(program, gl.GL_LINK_STATUS, &success);
    if (success == 0) {
        var log_len: gl.GLint = 0;
        gl.glGetProgramiv(program, gl.GL_INFO_LOG_LENGTH, &log_len);
        if (log_len > 0) {
            const log = try allocator.alloc(u8, @intCast(log_len));
            defer allocator.free(log);
            gl.glGetProgramInfoLog(program, log_len, null, log.ptr);
            std.log.err("Program linking failed: {s}", .{log});
        }
        return error.ProgramLinkingFailed;
    }

    return program;
}

/// Create a shader program from vertex and fragment source
pub fn createProgram(vert_source: []const u8, frag_source: []const u8, allocator: Allocator) !ShaderProgram {
    const vert = try compileShader(gl.GL_VERTEX_SHADER, vert_source, allocator);
    defer gl.glDeleteShader(vert);

    const frag = try compileShader(gl.GL_FRAGMENT_SHADER, frag_source, allocator);
    defer gl.glDeleteShader(frag);

    const program = try linkProgram(vert, frag, allocator);

    return .{
        .program = program,
        .viewport_loc = gl.glGetUniformLocation(program, "u_viewport_size"),
        .texture_loc = gl.glGetUniformLocation(program, "u_texture"),
        .mono_loc = gl.glGetUniformLocation(program, "u_mono"),
    };
}

/// Create the quad shader program
pub fn createQuadProgram(allocator: Allocator) !ShaderProgram {
    return createProgram(quad_vert, quad_frag, allocator);
}

/// Create the shadow shader program
pub fn createShadowProgram(allocator: Allocator) !ShaderProgram {
    return createProgram(shadow_vert, shadow_frag, allocator);
}

/// Create the sprite shader program
pub fn createSpriteProgram(allocator: Allocator) !ShaderProgram {
    return createProgram(sprite_vert, sprite_frag, allocator);
}

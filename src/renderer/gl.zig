//! OpenGL 3.3 bindings for zapui.
//! All functions are loaded dynamically at runtime.

const std = @import("std");

// Types
pub const GLuint = c_uint;
pub const GLint = c_int;
pub const GLenum = c_uint;
pub const GLsizei = c_int;
pub const GLfloat = f32;
pub const GLboolean = u8;
pub const GLchar = u8;
pub const GLsizeiptr = isize;
pub const GLintptr = isize;
pub const GLubyte = u8;
pub const GLbitfield = c_uint;

// Constants
pub const GL_TRUE: GLboolean = 1;
pub const GL_FALSE: GLboolean = 0;

// Primitive types
pub const GL_TRIANGLES: GLenum = 0x0004;
pub const GL_TRIANGLE_STRIP: GLenum = 0x0005;

// Data types
pub const GL_FLOAT: GLenum = 0x1406;
pub const GL_UNSIGNED_INT: GLenum = 0x1405;
pub const GL_UNSIGNED_BYTE: GLenum = 0x1401;

// Buffer targets
pub const GL_ARRAY_BUFFER: GLenum = 0x8892;
pub const GL_ELEMENT_ARRAY_BUFFER: GLenum = 0x8893;

// Buffer usage
pub const GL_STATIC_DRAW: GLenum = 0x88E4;
pub const GL_DYNAMIC_DRAW: GLenum = 0x88E8;
pub const GL_STREAM_DRAW: GLenum = 0x88E0;

// Shader types
pub const GL_VERTEX_SHADER: GLenum = 0x8B31;
pub const GL_FRAGMENT_SHADER: GLenum = 0x8B30;

// Shader/program status
pub const GL_COMPILE_STATUS: GLenum = 0x8B81;
pub const GL_LINK_STATUS: GLenum = 0x8B82;
pub const GL_INFO_LOG_LENGTH: GLenum = 0x8B84;

// Textures
pub const GL_TEXTURE_2D: GLenum = 0x0DE1;
pub const GL_TEXTURE0: GLenum = 0x84C0;
pub const GL_TEXTURE_MIN_FILTER: GLenum = 0x2801;
pub const GL_TEXTURE_MAG_FILTER: GLenum = 0x2800;
pub const GL_TEXTURE_WRAP_S: GLenum = 0x2802;
pub const GL_TEXTURE_WRAP_T: GLenum = 0x2803;
pub const GL_LINEAR: GLint = 0x2601;
pub const GL_NEAREST: GLint = 0x2600;
pub const GL_CLAMP_TO_EDGE: GLint = 0x812F;

// Pixel formats
pub const GL_RGBA: GLenum = 0x1908;
pub const GL_RGB: GLenum = 0x1907;
pub const GL_RED: GLenum = 0x1903;
pub const GL_R8: GLenum = 0x8229;
pub const GL_RGBA8: GLenum = 0x8058;

// Blending
pub const GL_BLEND: GLenum = 0x0BE2;
pub const GL_SRC_ALPHA: GLenum = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA: GLenum = 0x0303;
pub const GL_ONE: GLenum = 1;

// Other
pub const GL_DEPTH_TEST: GLenum = 0x0B71;
pub const GL_SCISSOR_TEST: GLenum = 0x0C11;
pub const GL_COLOR_BUFFER_BIT: GLbitfield = 0x4000;
pub const GL_DEPTH_BUFFER_BIT: GLbitfield = 0x0100;
pub const GL_NO_ERROR: GLenum = 0;
pub const GL_UNPACK_ALIGNMENT: GLenum = 0x0CF5;

// Function pointer types and storage
pub var glGenVertexArrays: *const fn (GLsizei, [*]GLuint) callconv(.c) void = undefined;
pub var glDeleteVertexArrays: *const fn (GLsizei, [*]const GLuint) callconv(.c) void = undefined;
pub var glBindVertexArray: *const fn (GLuint) callconv(.c) void = undefined;
pub var glGenBuffers: *const fn (GLsizei, [*]GLuint) callconv(.c) void = undefined;
pub var glDeleteBuffers: *const fn (GLsizei, [*]const GLuint) callconv(.c) void = undefined;
pub var glBindBuffer: *const fn (GLenum, GLuint) callconv(.c) void = undefined;
pub var glBufferData: *const fn (GLenum, GLsizeiptr, ?*const anyopaque, GLenum) callconv(.c) void = undefined;
pub var glBufferSubData: *const fn (GLenum, GLintptr, GLsizeiptr, ?*const anyopaque) callconv(.c) void = undefined;
pub var glVertexAttribPointer: *const fn (GLuint, GLint, GLenum, GLboolean, GLsizei, ?*const anyopaque) callconv(.c) void = undefined;
pub var glVertexAttribDivisor: *const fn (GLuint, GLuint) callconv(.c) void = undefined;
pub var glEnableVertexAttribArray: *const fn (GLuint) callconv(.c) void = undefined;
pub var glDisableVertexAttribArray: *const fn (GLuint) callconv(.c) void = undefined;
pub var glCreateShader: *const fn (GLenum) callconv(.c) GLuint = undefined;
pub var glDeleteShader: *const fn (GLuint) callconv(.c) void = undefined;
pub var glShaderSource: *const fn (GLuint, GLsizei, [*]const [*]const GLchar, ?[*]const GLint) callconv(.c) void = undefined;
pub var glCompileShader: *const fn (GLuint) callconv(.c) void = undefined;
pub var glGetShaderiv: *const fn (GLuint, GLenum, *GLint) callconv(.c) void = undefined;
pub var glGetShaderInfoLog: *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void = undefined;
pub var glCreateProgram: *const fn () callconv(.c) GLuint = undefined;
pub var glDeleteProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var glAttachShader: *const fn (GLuint, GLuint) callconv(.c) void = undefined;
pub var glLinkProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var glGetProgramiv: *const fn (GLuint, GLenum, *GLint) callconv(.c) void = undefined;
pub var glGetProgramInfoLog: *const fn (GLuint, GLsizei, ?*GLsizei, [*]GLchar) callconv(.c) void = undefined;
pub var glUseProgram: *const fn (GLuint) callconv(.c) void = undefined;
pub var glGetUniformLocation: *const fn (GLuint, [*:0]const GLchar) callconv(.c) GLint = undefined;
pub var glUniform1i: *const fn (GLint, GLint) callconv(.c) void = undefined;
pub var glUniform1f: *const fn (GLint, GLfloat) callconv(.c) void = undefined;
pub var glUniform2f: *const fn (GLint, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var glUniform3f: *const fn (GLint, GLfloat, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var glUniform4f: *const fn (GLint, GLfloat, GLfloat, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var glDrawArraysInstanced: *const fn (GLenum, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var glActiveTexture: *const fn (GLenum) callconv(.c) void = undefined;
pub var glGenerateMipmap: *const fn (GLenum) callconv(.c) void = undefined;

// GL 1.x/2.x functions (also loaded dynamically for consistency)
pub var glEnable: *const fn (GLenum) callconv(.c) void = undefined;
pub var glDisable: *const fn (GLenum) callconv(.c) void = undefined;
pub var glBlendFunc: *const fn (GLenum, GLenum) callconv(.c) void = undefined;
pub var glClear: *const fn (GLbitfield) callconv(.c) void = undefined;
pub var glClearColor: *const fn (GLfloat, GLfloat, GLfloat, GLfloat) callconv(.c) void = undefined;
pub var glViewport: *const fn (GLint, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var glScissor: *const fn (GLint, GLint, GLsizei, GLsizei) callconv(.c) void = undefined;
pub var glGenTextures: *const fn (GLsizei, [*]GLuint) callconv(.c) void = undefined;
pub var glDeleteTextures: *const fn (GLsizei, [*]const GLuint) callconv(.c) void = undefined;
pub var glBindTexture: *const fn (GLenum, GLuint) callconv(.c) void = undefined;
pub var glTexImage2D: *const fn (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, ?*const anyopaque) callconv(.c) void = undefined;
pub var glTexSubImage2D: *const fn (GLenum, GLint, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, ?*const anyopaque) callconv(.c) void = undefined;
pub var glTexParameteri: *const fn (GLenum, GLenum, GLint) callconv(.c) void = undefined;
pub var glPixelStorei: *const fn (GLenum, GLint) callconv(.c) void = undefined;
pub var glGetError: *const fn () callconv(.c) GLenum = undefined;
pub var glGetString: *const fn (GLenum) callconv(.c) ?[*:0]const GLubyte = undefined;
pub var glGetIntegerv: *const fn (GLenum, [*]GLint) callconv(.c) void = undefined;

/// Load a single GL function by name
fn loadFunction(comptime name: [:0]const u8, getProcAddress: *const fn ([*:0]const u8) ?*anyopaque) !void {
    const ptr = getProcAddress(name) orelse return error.GlFunctionNotFound;
    @field(@This(), name) = @ptrCast(ptr);
}

/// Load OpenGL 3.3 function pointers
/// This should be called after creating an OpenGL context
pub fn loadGlFunctions(getProcAddress: *const fn ([*:0]const u8) ?*anyopaque) !void {
    // GL 3.0+ functions
    try loadFunction("glGenVertexArrays", getProcAddress);
    try loadFunction("glDeleteVertexArrays", getProcAddress);
    try loadFunction("glBindVertexArray", getProcAddress);
    try loadFunction("glGenBuffers", getProcAddress);
    try loadFunction("glDeleteBuffers", getProcAddress);
    try loadFunction("glBindBuffer", getProcAddress);
    try loadFunction("glBufferData", getProcAddress);
    try loadFunction("glBufferSubData", getProcAddress);
    try loadFunction("glVertexAttribPointer", getProcAddress);
    try loadFunction("glVertexAttribDivisor", getProcAddress);
    try loadFunction("glEnableVertexAttribArray", getProcAddress);
    try loadFunction("glDisableVertexAttribArray", getProcAddress);
    try loadFunction("glCreateShader", getProcAddress);
    try loadFunction("glDeleteShader", getProcAddress);
    try loadFunction("glShaderSource", getProcAddress);
    try loadFunction("glCompileShader", getProcAddress);
    try loadFunction("glGetShaderiv", getProcAddress);
    try loadFunction("glGetShaderInfoLog", getProcAddress);
    try loadFunction("glCreateProgram", getProcAddress);
    try loadFunction("glDeleteProgram", getProcAddress);
    try loadFunction("glAttachShader", getProcAddress);
    try loadFunction("glLinkProgram", getProcAddress);
    try loadFunction("glGetProgramiv", getProcAddress);
    try loadFunction("glGetProgramInfoLog", getProcAddress);
    try loadFunction("glUseProgram", getProcAddress);
    try loadFunction("glGetUniformLocation", getProcAddress);
    try loadFunction("glUniform1i", getProcAddress);
    try loadFunction("glUniform1f", getProcAddress);
    try loadFunction("glUniform2f", getProcAddress);
    try loadFunction("glUniform3f", getProcAddress);
    try loadFunction("glUniform4f", getProcAddress);
    try loadFunction("glDrawArraysInstanced", getProcAddress);
    try loadFunction("glActiveTexture", getProcAddress);
    try loadFunction("glGenerateMipmap", getProcAddress);

    // GL 1.x/2.x functions
    try loadFunction("glEnable", getProcAddress);
    try loadFunction("glDisable", getProcAddress);
    try loadFunction("glBlendFunc", getProcAddress);
    try loadFunction("glClear", getProcAddress);
    try loadFunction("glClearColor", getProcAddress);
    try loadFunction("glViewport", getProcAddress);
    try loadFunction("glScissor", getProcAddress);
    try loadFunction("glGenTextures", getProcAddress);
    try loadFunction("glDeleteTextures", getProcAddress);
    try loadFunction("glBindTexture", getProcAddress);
    try loadFunction("glTexImage2D", getProcAddress);
    try loadFunction("glTexSubImage2D", getProcAddress);
    try loadFunction("glTexParameteri", getProcAddress);
    try loadFunction("glPixelStorei", getProcAddress);
    try loadFunction("glGetError", getProcAddress);
    try loadFunction("glGetString", getProcAddress);
    try loadFunction("glGetIntegerv", getProcAddress);
}

/// Check for OpenGL errors
pub fn checkError() ?GLenum {
    const err = glGetError();
    if (err != GL_NO_ERROR) {
        return err;
    }
    return null;
}

/// Get OpenGL error string
pub fn errorString(err: GLenum) []const u8 {
    return switch (err) {
        0x0500 => "GL_INVALID_ENUM",
        0x0501 => "GL_INVALID_VALUE",
        0x0502 => "GL_INVALID_OPERATION",
        0x0503 => "GL_STACK_OVERFLOW",
        0x0504 => "GL_STACK_UNDERFLOW",
        0x0505 => "GL_OUT_OF_MEMORY",
        0x0506 => "GL_INVALID_FRAMEBUFFER_OPERATION",
        else => "Unknown error",
    };
}

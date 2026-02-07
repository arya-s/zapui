//! zapui playground - Development sandbox for testing the library

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    std.debug.print("=== zapui Playground (Phase 2: OpenGL Renderer) ===\n\n", .{});

    // Initialize GLFW
    if (c.glfwInit() == 0) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return error.GlfwInitFailed;
    }
    defer c.glfwTerminate();

    // Request OpenGL 3.3 Core
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GLFW_TRUE);

    // Create window
    const window = c.glfwCreateWindow(800, 600, "zapui playground", null, null) orelse {
        std.debug.print("Failed to create GLFW window\n", .{});
        return error.WindowCreationFailed;
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1); // VSync

    // Load OpenGL functions
    const glGetProcAddress = struct {
        fn getProcAddress(name: [*:0]const u8) ?*anyopaque {
            const ptr = c.glfwGetProcAddress(name);
            return @ptrCast(@constCast(ptr));
        }
    }.getProcAddress;
    try zapui.loadGl(glGetProcAddress);
    std.debug.print("OpenGL loaded successfully\n", .{});

    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create renderer
    var renderer = try zapui.GlRenderer.init(allocator);
    defer renderer.deinit();
    std.debug.print("Renderer initialized\n", .{});

    // Create scene
    var scene = zapui.Scene.init(allocator);
    defer scene.deinit();

    // Main loop
    var frame_count: u64 = 0;
    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);

        renderer.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);

        // Clear scene
        scene.clear();

        // Build scene with some test quads
        const time: f32 = @floatCast(c.glfwGetTime());

        // Background quad
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(50, 50, 300, 200),
            .background = .{ .solid = zapui.rgb(0x2d3748) },
            .corner_radii = zapui.Corners(f32).all(12),
        });

        // Animated quad
        const x_offset = @sin(time * 2) * 50;
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(100 + x_offset, 100, 150, 100),
            .background = .{ .solid = zapui.rgb(0x4299e1) },
            .corner_radii = zapui.Corners(f32).all(8),
            .border_widths = zapui.Edges(f32).all(2),
            .border_color = zapui.rgb(0x2b6cb0),
        });

        // Red quad with shadow
        try scene.insertShadow(.{
            .bounds = zapui.Bounds(f32).fromXYWH(400, 100, 200, 150),
            .corner_radii = zapui.Corners(f32).all(16),
            .blur_radius = 20,
            .color = zapui.black().withAlpha(0.4),
        });

        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(400, 100, 200, 150),
            .background = .{ .solid = zapui.rgb(0xf56565) },
            .corner_radii = zapui.Corners(f32).all(16),
        });

        // Green quad
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(450, 300, 180, 120),
            .background = .{ .solid = zapui.rgb(0x48bb78) },
            .corner_radii = .{
                .top_left = 0,
                .top_right = 30,
                .bottom_right = 0,
                .bottom_left = 30,
            },
            .border_widths = zapui.Edges(f32).all(3),
            .border_color = zapui.rgb(0x276749),
        });

        // Purple quad with different corner radii
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(100, 350, 250, 180),
            .background = .{ .solid = zapui.rgb(0x9f7aea) },
            .corner_radii = .{
                .top_left = 40,
                .top_right = 10,
                .bottom_right = 40,
                .bottom_left = 10,
            },
        });

        // Orange outlined quad (no fill)
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(650, 400, 120, 120),
            .border_widths = zapui.Edges(f32).all(4),
            .border_color = zapui.rgb(0xed8936),
            .corner_radii = zapui.Corners(f32).all(60), // Circle-ish
        });

        scene.finish();

        // Render
        renderer.clear(zapui.rgb(0x1a202c));
        try renderer.drawScene(&scene);

        c.glfwSwapBuffers(window);
        frame_count += 1;

        if (frame_count % 300 == 0) {
            std.debug.print("Frame {}, {} primitives\n", .{ frame_count, scene.primitiveCount() });
        }
    }

    std.debug.print("\n=== Playground finished ({} frames) ===\n", .{frame_count});
}

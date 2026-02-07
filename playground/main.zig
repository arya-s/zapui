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

        // Build a flexbox layout
        var layout_engine = zapui.LayoutEngine.init(allocator);
        defer layout_engine.deinit();

        // Create child nodes
        const child1 = try layout_engine.createNode(.{
            .size = .{ .width = .{ .px = 100 }, .height = .{ .px = 80 } },
            .flex_grow = 1,
        }, &.{});

        const child2 = try layout_engine.createNode(.{
            .size = .{ .width = .{ .px = 100 }, .height = .{ .px = 80 } },
            .flex_grow = 2,
        }, &.{});

        const child3 = try layout_engine.createNode(.{
            .size = .{ .width = .{ .px = 100 }, .height = .{ .px = 80 } },
            .flex_grow = 1,
        }, &.{});

        // Create container
        const container = try layout_engine.createNode(.{
            .flex_direction = .row,
            .justify_content = .space_between,
            .align_items = .center,
            .gap = .{ .width = .{ .px = 20 }, .height = .{ .px = 0 } },
            .padding = .{ .top = .{ .px = 20 }, .right = .{ .px = 20 }, .bottom = .{ .px = 20 }, .left = .{ .px = 20 } },
            .size = .{ .width = .{ .px = 600 }, .height = .{ .px = 200 } },
        }, &.{ child1, child2, child3 });

        // Compute layout
        layout_engine.computeLayout(container, .{
            .width = .{ .definite = @floatFromInt(width) },
            .height = .{ .definite = @floatFromInt(height) },
        });

        // Get layout results and render quads
        const container_layout = layout_engine.getLayout(container);
        const c1_layout = layout_engine.getLayout(child1);
        const c2_layout = layout_engine.getLayout(child2);
        const c3_layout = layout_engine.getLayout(child3);

        // Offset for centering the demo
        const offset_x: f32 = 50;
        const offset_y: f32 = 50;

        // Container background
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                container_layout.origin.x + offset_x,
                container_layout.origin.y + offset_y,
                container_layout.size.width,
                container_layout.size.height,
            ),
            .background = .{ .solid = zapui.rgb(0x2d3748) },
            .corner_radii = zapui.Corners(f32).all(12),
        });

        // Child 1 (blue)
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                c1_layout.origin.x + offset_x,
                c1_layout.origin.y + offset_y,
                c1_layout.size.width,
                c1_layout.size.height,
            ),
            .background = .{ .solid = zapui.rgb(0x4299e1) },
            .corner_radii = zapui.Corners(f32).all(8),
        });

        // Child 2 (green) - should be bigger due to flex_grow = 2
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                c2_layout.origin.x + offset_x,
                c2_layout.origin.y + offset_y,
                c2_layout.size.width,
                c2_layout.size.height,
            ),
            .background = .{ .solid = zapui.rgb(0x48bb78) },
            .corner_radii = zapui.Corners(f32).all(8),
        });

        // Child 3 (purple)
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                c3_layout.origin.x + offset_x,
                c3_layout.origin.y + offset_y,
                c3_layout.size.width,
                c3_layout.size.height,
            ),
            .background = .{ .solid = zapui.rgb(0x9f7aea) },
            .corner_radii = zapui.Corners(f32).all(8),
        });

        // Second demo: Column layout with shadow
        const col_child1 = try layout_engine.createNode(.{
            .size = .{ .width = .auto, .height = .{ .px = 50 } },
        }, &.{});

        const col_child2 = try layout_engine.createNode(.{
            .size = .{ .width = .auto, .height = .{ .px = 50 } },
        }, &.{});

        const col_child3 = try layout_engine.createNode(.{
            .size = .{ .width = .auto, .height = .{ .px = 50 } },
        }, &.{});

        const col_container = try layout_engine.createNode(.{
            .flex_direction = .column,
            .align_items = .stretch,
            .gap = .{ .width = .{ .px = 0 }, .height = .{ .px = 10 } },
            .padding = .{ .top = .{ .px = 15 }, .right = .{ .px = 15 }, .bottom = .{ .px = 15 }, .left = .{ .px = 15 } },
            .size = .{ .width = .{ .px = 200 }, .height = .auto },
        }, &.{ col_child1, col_child2, col_child3 });

        layout_engine.computeLayout(col_container, .{
            .width = .{ .definite = @floatFromInt(width) },
            .height = .{ .definite = @floatFromInt(height) },
        });

        const col_offset_x: f32 = 50;
        const col_offset_y: f32 = 300;

        const col_cont_layout = layout_engine.getLayout(col_container);

        // Shadow for column container
        try scene.insertShadow(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                col_cont_layout.origin.x + col_offset_x,
                col_cont_layout.origin.y + col_offset_y,
                col_cont_layout.size.width,
                col_cont_layout.size.height,
            ),
            .corner_radii = zapui.Corners(f32).all(16),
            .blur_radius = 15,
            .color = zapui.black().withAlpha(0.3),
        });

        // Column container
        try scene.insertQuad(.{
            .bounds = zapui.Bounds(f32).fromXYWH(
                col_cont_layout.origin.x + col_offset_x,
                col_cont_layout.origin.y + col_offset_y,
                col_cont_layout.size.width,
                col_cont_layout.size.height,
            ),
            .background = .{ .solid = zapui.rgb(0xf7fafc) },
            .corner_radii = zapui.Corners(f32).all(16),
        });

        // Column children
        const colors = [_]u24{ 0xfc8181, 0xf6ad55, 0x68d391 };
        const col_children = [_]zapui.LayoutId{ col_child1, col_child2, col_child3 };

        for (col_children, 0..) |child, i| {
            const child_layout = layout_engine.getLayout(child);
            try scene.insertQuad(.{
                .bounds = zapui.Bounds(f32).fromXYWH(
                    child_layout.origin.x + col_offset_x,
                    child_layout.origin.y + col_offset_y,
                    child_layout.size.width,
                    child_layout.size.height,
                ),
                .background = .{ .solid = zapui.rgb(colors[i]) },
                .corner_radii = zapui.Corners(f32).all(8),
            });
        }

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

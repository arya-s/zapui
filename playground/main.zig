//! zapui playground - Development sandbox for testing the library

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    std.debug.print("=== zapui Playground (Phase 6: Element System) ===\n\n", .{});

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

    // Create scene and layout engine
    var scene = zapui.Scene.init(allocator);
    defer scene.deinit();

    var layout_engine = zapui.LayoutEngine.init(allocator);
    defer layout_engine.deinit();

    var app = zapui.App.init(allocator);
    defer app.deinit();

    // Main loop
    var frame_count: u64 = 0;
    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);

        renderer.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);

        // Clear scene and layout for new frame
        scene.clear();
        layout_engine.clear();

        // Create render context
        var ctx = zapui.RenderContext{
            .allocator = allocator,
            .layout_engine = &layout_engine,
            .scene = &scene,
            .app = &app,
        };

        // Build UI using Div elements
        const child1 = zapui.div(allocator)
            .w(.{ .px = 100 })
            .h(.{ .px = 80 })
            .flexGrow(1)
            .bg(zapui.rgb(0x4299e1))
            .roundedLg();

        const child2 = zapui.div(allocator)
            .w(.{ .px = 100 })
            .h(.{ .px = 80 })
            .flexGrow(2)
            .bg(zapui.rgb(0x48bb78))
            .roundedLg();

        const child3 = zapui.div(allocator)
            .w(.{ .px = 100 })
            .h(.{ .px = 80 })
            .flexGrow(1)
            .bg(zapui.rgb(0x9f7aea))
            .roundedLg();

        const row_container = zapui.div(allocator)
            .flexRow()
            .justifyBetween()
            .itemsCenter()
            .gap(.{ .px = 20 })
            .p(.{ .px = 20 })
            .w(.{ .px = 600 })
            .h(.{ .px = 140 })
            .bg(zapui.rgb(0x2d3748))
            .roundedXl()
            .shadowLg()
            .child(child1.build())
            .child(child2.build())
            .child(child3.build());
        defer row_container.deinit(allocator);

        // Second demo: Column layout
        const col1 = zapui.div(allocator)
            .hFull()
            .h(.{ .px = 50 })
            .bg(zapui.rgb(0xfc8181))
            .roundedMd();

        const col2 = zapui.div(allocator)
            .hFull()
            .h(.{ .px = 50 })
            .bg(zapui.rgb(0xf6ad55))
            .roundedMd();

        const col3 = zapui.div(allocator)
            .hFull()
            .h(.{ .px = 50 })
            .bg(zapui.rgb(0x68d391))
            .roundedMd();

        const col_container = zapui.div(allocator)
            .flexCol()
            .itemsStretch()
            .gap(.{ .px = 10 })
            .p(.{ .px = 15 })
            .w(.{ .px = 200 })
            .bg(zapui.rgb(0xf7fafc))
            .roundedXl()
            .shadowMd()
            .child(col1.build())
            .child(col2.build())
            .child(col3.build());
        defer col_container.deinit(allocator);

        // Layout and paint the row container
        var row_elem = row_container.build();
        const row_layout_id = row_elem.requestLayout(&ctx);
        layout_engine.computeLayout(row_layout_id, .{
            .width = .{ .definite = @floatFromInt(width) },
            .height = .{ .definite = @floatFromInt(height) },
        });

        const row_bounds = zapui.Bounds(f32).fromXYWH(50, 50, 600, 140);
        row_elem.prepaint(row_bounds, &ctx);
        row_elem.paint(row_bounds, &ctx);

        // Layout and paint the column container
        var col_elem = col_container.build();
        const col_layout_id = col_elem.requestLayout(&ctx);
        layout_engine.computeLayout(col_layout_id, .{
            .width = .{ .definite = @floatFromInt(width) },
            .height = .{ .definite = @floatFromInt(height) },
        });

        const col_layout = layout_engine.getLayout(col_layout_id);
        const col_bounds = zapui.Bounds(f32).fromXYWH(50, 250, col_layout.size.width, col_layout.size.height);
        col_elem.prepaint(col_bounds, &ctx);
        col_elem.paint(col_bounds, &ctx);

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

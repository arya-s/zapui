//! zapui playground - Development sandbox for testing the library

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    std.debug.print("=== zapui Playground (Phase 8: Ui Orchestration) ===\n\n", .{});

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

    // Create UI
    var ui = try zapui.Ui.init(.{
        .allocator = allocator,
        .viewport_width = 800,
        .viewport_height = 600,
    });
    defer ui.deinit();

    // Initialize renderer
    try ui.initRenderer();
    std.debug.print("UI initialized\n", .{});

    // Main loop
    var frame_count: u64 = 0;
    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);
        ui.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);

        // Only render when needed
        if (ui.needsRedraw() or frame_count < 10) {
            ui.beginFrame();

            // Build UI using Ui.div() - allocates from frame arena
            const child1 = ui.div()
                .w(.{ .px = 100 })
                .h(.{ .px = 80 })
                .flexGrow(1)
                .bg(zapui.rgb(0x4299e1))
                .roundedLg();

            const child2 = ui.div()
                .w(.{ .px = 100 })
                .h(.{ .px = 80 })
                .flexGrow(2)
                .bg(zapui.rgb(0x48bb78))
                .roundedLg();

            const child3 = ui.div()
                .w(.{ .px = 100 })
                .h(.{ .px = 80 })
                .flexGrow(1)
                .bg(zapui.rgb(0x9f7aea))
                .roundedLg();

            const row_container = ui.div()
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

            // Second demo: Column layout
            const col1 = ui.div()
                .hFull()
                .h(.{ .px = 50 })
                .bg(zapui.rgb(0xfc8181))
                .roundedMd();

            const col2 = ui.div()
                .hFull()
                .h(.{ .px = 50 })
                .bg(zapui.rgb(0xf6ad55))
                .roundedMd();

            const col3 = ui.div()
                .hFull()
                .h(.{ .px = 50 })
                .bg(zapui.rgb(0x68d391))
                .roundedMd();

            const col_container = ui.div()
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

            // Root container
            const root = ui.div()
                .flexCol()
                .gap(.{ .px = 30 })
                .p(.{ .px = 50 })
                .wFull()
                .hFull()
                .bg(zapui.rgb(0x1a202c))
                .child(row_container.build())
                .child(col_container.build());

            var root_elem = root.build();
            ui.renderElement(&root_elem);

            try ui.endFrame(zapui.rgb(0x1a202c));
            c.glfwSwapBuffers(window);
        }

        frame_count += 1;

        if (frame_count % 300 == 0) {
            std.debug.print("Frame {}\n", .{frame_count});
        }
    }

    std.debug.print("\n=== Playground finished ({} frames) ===\n", .{frame_count});
}

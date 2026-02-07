//! Hello World example for zapui
//!
//! Demonstrates:
//! - Creating a zapui Ui instance
//! - Building a simple UI with divs
//! - Handling the main loop with redraw optimization
//!
//! Run with: zig build run-hello

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub fn main() !void {
    std.debug.print("=== zapui Hello World ===\n\n", .{});

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
    const window = c.glfwCreateWindow(800, 600, "zapui - Hello World", null, null) orelse {
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

    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize zapui
    var ui = try zapui.Ui.init(.{
        .allocator = allocator,
        .viewport_width = 800,
        .viewport_height = 600,
    });
    defer ui.deinit();
    try ui.initRenderer();

    // Main loop
    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        // Update viewport
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);
        ui.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);

        // Render when needed
        if (ui.needsRedraw()) {
            ui.beginFrame();

            // Build UI
            var root = buildHelloUI(&ui);
            ui.renderElement(&root);

            try ui.endFrame(zapui.rgb(0x1a202c));
            c.glfwSwapBuffers(window);
        }
    }

    std.debug.print("Goodbye!\n", .{});
}

fn buildHelloUI(ui: *zapui.Ui) zapui.AnyElement {
    // Header bar
    const header = ui.div()
        .flexRow()
        .justifyBetween()
        .itemsCenter()
        .wFull()
        .h(.{ .px = 60 })
        .p4()
        .bg(zapui.rgb(0x2d3748))
        .child(
        // Logo/title area
        ui.div()
            .w(.{ .px = 120 })
            .h(.{ .px = 32 })
            .bg(zapui.rgb(0x4299e1))
            .roundedMd()
            .build(),
    )
        .child(
        // Nav items
        ui.div()
            .flexRow()
            .gap3()
            .child(ui.div().w(.{ .px = 60 }).h(.{ .px = 28 }).bg(zapui.rgb(0x718096)).roundedSm().build())
            .child(ui.div().w(.{ .px = 60 }).h(.{ .px = 28 }).bg(zapui.rgb(0x718096)).roundedSm().build())
            .child(ui.div().w(.{ .px = 60 }).h(.{ .px = 28 }).bg(zapui.rgb(0x718096)).roundedSm().build())
            .build(),
    );

    // Main content area
    const main_content = ui.div()
        .flex()
        .flexRow()
        .grow()
        .gap4()
        .p4()
        .child(
        // Sidebar
        ui.div()
            .flexCol()
            .gap2()
            .w(.{ .px = 200 })
            .hFull()
            .p3()
            .bg(zapui.rgb(0x2d3748))
            .roundedLg()
            .child(ui.div().wFull().h(.{ .px = 36 }).bg(zapui.rgb(0x4a5568)).roundedMd().build())
            .child(ui.div().wFull().h(.{ .px = 36 }).bg(zapui.rgb(0x4a5568)).roundedMd().build())
            .child(ui.div().wFull().h(.{ .px = 36 }).bg(zapui.rgb(0x4a5568)).roundedMd().build())
            .child(ui.div().wFull().h(.{ .px = 36 }).bg(zapui.rgb(0x4a5568)).roundedMd().build())
            .build(),
    )
        .child(
        // Content area
        ui.div()
            .flexCol()
            .grow()
            .gap4()
            .child(
            // Hero card
            ui.div()
                .flexCol()
                .justifyCenter()
                .itemsCenter()
                .wFull()
                .h(.{ .px = 200 })
                .bg(zapui.rgb(0x667eea))
                .roundedXl()
                .shadowLg()
                .child(
                // "Hello World" text placeholder
                ui.div()
                    .w(.{ .px = 200 })
                    .h(.{ .px = 40 })
                    .bg(zapui.rgb(0xffffff).withAlpha(0.3))
                    .roundedMd()
                    .build(),
            )
                .build(),
        )
            .child(
            // Cards row
            ui.div()
                .flexRow()
                .gap4()
                .child(ui.div().grow().h(.{ .px = 120 }).bg(zapui.rgb(0x48bb78)).roundedLg().shadowMd().build())
                .child(ui.div().grow().h(.{ .px = 120 }).bg(zapui.rgb(0xed8936)).roundedLg().shadowMd().build())
                .child(ui.div().grow().h(.{ .px = 120 }).bg(zapui.rgb(0xf56565)).roundedLg().shadowMd().build())
                .build(),
        )
            .build(),
    );

    // Root layout
    return ui.div()
        .flexCol()
        .wFull()
        .hFull()
        .bg(zapui.rgb(0x1a202c))
        .child(header.build())
        .child(main_content.build())
        .build();
}

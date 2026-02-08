//! Hello World - Port of GPUI's hello_world.rs example
//!
//! This demonstrates the GPUI-style div API with:
//! - Flexbox layout (column with centered children)
//! - Text rendering
//! - Colored boxes with borders
//! - Rounded corners and shadows

const std = @import("std");
const zapui = @import("zapui");

const GlRenderer = zapui.GlRenderer;
const TextSystem = zapui.TextSystem;
const Scene = zapui.Scene;
const zaffy = zapui.zaffy;
const Pixels = zapui.Pixels;

// GPUI-style API
const div = zapui.elements.div.div;
const v_flex = zapui.elements.div.v_flex;
const h_flex = zapui.elements.div.h_flex;
const reset = zapui.elements.div.reset;
const px = zapui.elements.div.px;

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

// ============================================================================
// Colors - matching GPUI example
// ============================================================================

const bg_color = zapui.rgb(0x505050);
const border_color = zapui.rgb(0x0000ff);
const text_color = zapui.rgb(0xffffff);
const red = zapui.rgb(0xff0000);
const green = zapui.rgb(0x00ff00);
const blue = zapui.rgb(0x0000ff);
const yellow = zapui.rgb(0xffff00);
const black = zapui.rgb(0x000000);
const white = zapui.rgb(0xffffff);

// ============================================================================
// Hello World View
// ============================================================================

fn renderHelloWorld(tree: *zaffy.Zaffy, scene: *Scene, text_system: *TextSystem, name: []const u8) !void {
    reset();

    const rem: Pixels = 16.0;

    // Build the view matching GPUI's hello_world.rs:
    //
    // div()
    //     .flex()
    //     .flex_col()
    //     .gap_3()
    //     .bg(rgb(0x505050))
    //     .size(px(500.0))
    //     .justify_center()
    //     .items_center()
    //     .shadow_lg()
    //     .border_1()
    //     .border_color(rgb(0x0000ff))
    //     .text_xl()
    //     .text_color(rgb(0xffffff))
    //     .child(format!("Hello, {}!", &self.text))
    //     .child(color_boxes_row)

    // Format the greeting text
    var greeting_buf: [64]u8 = undefined;
    const greeting = std.fmt.bufPrint(&greeting_buf, "Hello, {s}!", .{name}) catch "Hello, World!";

    // Text label - in GPUI this would be .child("Hello, World!")
    // We still need a div wrapper since Zig can't have heterogeneous children
    const text_label = div().child_text(greeting);

    // Color boxes row - matches GPUI exactly:
    // div().flex().gap_2().child(div().size_8().bg(red).border_1().rounded_md().border_color(white))...
    const color_boxes = h_flex()
        .gap_2()
        .child(div().size_8().bg(red).border_1().rounded_md().border_color(white))
        .child(div().size_8().bg(green).border_1().rounded_md().border_color(white))
        .child(div().size_8().bg(blue).border_1().rounded_md().border_color(white))
        .child(div().size_8().bg(yellow).border_1().rounded_md().border_color(white))
        .child(div().size_8().bg(black).border_1().rounded_md().border_color(white))
        .child(div().size_8().bg(white).border_1().rounded_md().border_color(black));

    // Main container - matches GPUI exactly:
    // div().flex().flex_col().gap_3().bg(...).size(px(500)).justify_center().items_center()
    //     .shadow_lg().border_1().border_color(...).text_xl().text_color(...)
    //     .child("Hello, World!").child(color_boxes)
    const root = div()
        .flex()
        .flex_col()
        .gap_3()
        .bg(bg_color)
        .size(px(500))
        .justify_center()
        .items_center()
        .shadow_lg()
        .border_1()
        .border_color(border_color)
        .text_xl()
        .text_color(text_color)
        .child(text_label)
        .child(color_boxes);

    try root.buildWithTextSystem(tree, rem, text_system);
    tree.computeLayoutWithSize(root.node_id.?, 500, 500);
    
    // Debug: print layout info
    if (false) { // Set to true to debug
        std.debug.print("Root layout:\n", .{});
        tree.printTree(root.node_id.?);
    }
    
    root.paint(scene, text_system, 0, 0, tree, null, null);
}



// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    // Initialize GLFW
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    // Create a 500x500 window to match GPUI example
    const window = glfw.glfwCreateWindow(500, 500, "Hello World - ZapUI", null, null) orelse {
        std.debug.print("Failed to create window\n", .{});
        return;
    };
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1);

    // Load OpenGL functions
    const getProcWrapper = struct {
        fn get(name: [*:0]const u8) ?*anyopaque {
            const ptr = glfw.glfwGetProcAddress(name);
            return @ptrCast(@constCast(ptr));
        }
    }.get;
    zapui.renderer.gl.loadGlFunctions(getProcWrapper) catch {
        std.debug.print("Failed to load OpenGL functions\n", .{});
        return;
    };

    // Initialize rendering systems
    const allocator = std.heap.page_allocator;

    var renderer = try GlRenderer.init(allocator);
    defer renderer.deinit();

    var text_system = TextSystem.init(allocator) catch {
        std.debug.print("Failed to initialize text system\n", .{});
        return;
    };
    defer text_system.deinit();

    // Load font - try system fonts that GPUI uses as fallbacks
    _ = text_system.loadFontFile("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf") catch {
        std.debug.print("Failed to load DejaVu Sans, trying IBM Plex Sans\n", .{});
        _ = text_system.loadFontFile("assets/fonts/IBMPlexSans-Regular.ttf") catch {
            std.debug.print("Failed to load IBM Plex Sans, trying JetBrains Mono\n", .{});
            _ = text_system.loadFontFile("assets/fonts/JetBrainsMono-Regular.ttf") catch {
                std.debug.print("Failed to load font\n", .{});
                return;
            };
        };
    };

    text_system.setAtlas(renderer.getGlyphAtlas());
    text_system.setColorAtlas(renderer.getColorAtlas());

    std.debug.print("Hello World - ZapUI\n", .{});
    std.debug.print("Press ESC to exit\n", .{});

    // Main loop
    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();

        // Check for ESC
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            break;
        }

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &width, &height);

        renderer.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);
        renderer.clear(zapui.rgb(0x1a1a1a)); // Dark background around the box

        var scene = Scene.init(allocator);
        defer scene.deinit();

        var tree = zaffy.Zaffy.init(allocator);
        defer tree.deinit();

        // Render the hello world view
        renderHelloWorld(&tree, &scene, &text_system, "World") catch |err| {
            std.debug.print("Render error: {}\n", .{err});
        };

        renderer.drawScene(&scene) catch {};

        glfw.glfwSwapBuffers(window);
    }
}

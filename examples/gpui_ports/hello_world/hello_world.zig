//! Hello World - Port of GPUI's hello_world.rs example
//!
//! This demonstrates the GPUI-style div API with:
//! - Flexbox layout (column with centered children)
//! - Text rendering
//! - Colored boxes with borders
//! - Rounded corners and shadows

const std = @import("std");
const zapui = @import("zapui");
const zglfw = @import("zglfw");

const GlRenderer = zapui.GlRenderer;
const TextSystem = zapui.TextSystem;
const Scene = zapui.Scene;
const zaffy = zapui.zaffy;
const Pixels = zapui.Pixels;

// GPUI-style API
const div = zapui.elements.div.div;
const h_flex = zapui.elements.div.h_flex;
const reset = zapui.elements.div.reset;
const px = zapui.elements.div.px;

// ============================================================================
// Colors - matching GPUI example
// ============================================================================

const bg_color = zapui.rgb(0x505050);
const border_color = zapui.rgb(0x0000ff);
const text_color = zapui.rgb(0xffffff);
const red = zapui.rgb(0xff0000);
const green = zapui.hsla(0.333, 1.0, 0.25, 1.0); // GPUI's green()
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

    // Format the greeting text
    var greeting_buf: [64]u8 = undefined;
    const greeting = std.fmt.bufPrint(&greeting_buf, "Hello, {s}!", .{name}) catch "Hello, World!";

    // Build the view matching GPUI's hello_world.rs
    // Note: text needs div().child_text() wrapper in Zig (no heterogeneous children)
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
        .child(div().child_text(greeting))
        .child(h_flex()
            .gap_2()
            .child(div().size_8().bg(red).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(green).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(blue).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(yellow).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(black).border_1().border_dashed().rounded_md().border_color(white))
            .child(div().size_8().bg(white).border_1().border_dashed().rounded_md().border_color(black)));

    try root.buildWithTextSystem(tree, rem, text_system);
    tree.computeLayoutWithSize(root.node_id.?, 500, 500);
    root.paint(scene, text_system, 0, 0, tree, null, null);
}

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    // Initialize GLFW
    zglfw.init() catch {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return;
    };
    defer zglfw.terminate();

    // Set OpenGL 3.3 Core Profile
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);

    // Create a 500x500 window to match GPUI example
    const window = zglfw.Window.create(500, 500, "Hello World - ZapUI", null, null) catch {
        std.debug.print("Failed to create window\n", .{});
        return;
    };
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);

    // Load OpenGL functions
    zapui.renderer.gl.loadGlFunctions(zglfw.getProcAddress) catch {
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
        std.debug.print("Warning: Could not load DejaVu Sans\n", .{});
        _ = text_system.loadFontFile("assets/fonts/LiberationSans-Regular.ttf") catch {
            std.debug.print("Failed to load any font\n", .{});
            return;
        };
    };

    text_system.setAtlas(renderer.getGlyphAtlas());
    text_system.setColorAtlas(renderer.getColorAtlas());

    std.debug.print("Hello World - ZapUI\n", .{});
    std.debug.print("Press ESC to exit\n", .{});

    // Main loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        // Check for ESC
        if (window.getKey(.escape) == .press) {
            break;
        }

        // Get window size
        const fb_size = window.getFramebufferSize();

        renderer.setViewport(@floatFromInt(fb_size[0]), @floatFromInt(fb_size[1]), 1.0);
        renderer.clear(zapui.rgb(0x505050)); // Match root div background

        var scene = Scene.init(allocator);
        defer scene.deinit();

        var tree = zaffy.Zaffy.init(allocator);
        defer tree.deinit();

        // Render the hello world view
        renderHelloWorld(&tree, &scene, &text_system, "World") catch |err| {
            std.debug.print("Render error: {}\n", .{err});
        };

        renderer.drawScene(&scene) catch {};

        window.swapBuffers();
    }
}

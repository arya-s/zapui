//! zapui playground - Interactive Demo
//!
//! This demonstrates:
//! - Building UIs with the Div fluent API
//! - Hit testing for mouse interaction
//! - State changes triggering re-renders

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

// Application state
var click_count: i32 = 0;
var selected_color: usize = 3; // Start with orange
const colors = [_]u24{ 0x4299e1, 0x48bb78, 0x9f7aea, 0xed8936, 0xf56565 };

// Button bounds (computed during layout)
var inc_button_bounds: zapui.Bounds(f32) = zapui.Bounds(f32).zero;
var dec_button_bounds: zapui.Bounds(f32) = zapui.Bounds(f32).zero;
var color_button_bounds: [5]zapui.Bounds(f32) = .{zapui.Bounds(f32).zero} ** 5;

// Pointer to UI for callbacks
var global_ui: ?*zapui.Ui = null;

pub fn main() !void {
    std.debug.print("=== zapui Playground (Interactive Demo) ===\n\n", .{});
    std.debug.print("Click the + and - buttons to change the count\n", .{});
    std.debug.print("Click the colored squares to change the header color\n\n", .{});

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
    const window = c.glfwCreateWindow(800, 600, "zapui playground - Interactive Demo", null, null) orelse {
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
    global_ui = &ui;

    // Initialize renderer
    try ui.initRenderer();
    std.debug.print("UI initialized\n\n", .{});

    // Set up GLFW callbacks for mouse input
    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);
    _ = c.glfwSetCursorPosCallback(window, cursorPosCallback);

    // Main loop
    var frame_count: u64 = 0;
    var needs_render = true;

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);
        ui.setViewport(@floatFromInt(width), @floatFromInt(height), 1.0);

        if (needs_render or ui.needsRedraw()) {
            ui.beginFrame();

            // Instead of using the complex layout, render directly with known positions
            renderUI(&ui, @floatFromInt(width), @floatFromInt(height));

            try ui.endFrame(zapui.rgb(0x1a202c));
            c.glfwSwapBuffers(window);
            needs_render = false;
        }

        frame_count += 1;
    }

    std.debug.print("\n=== Playground finished ({} frames) ===\n", .{frame_count});
}

fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = window;
    _ = mods;

    if (button == c.GLFW_MOUSE_BUTTON_LEFT and action == c.GLFW_PRESS) {
        if (global_ui) |ui| {
            const pos = ui.mouse_state.position;

            // Check increment button
            if (inc_button_bounds.contains(pos)) {
                click_count += 1;
                std.debug.print("Count: {} (+)\n", .{click_count});
                ui.requestRedraw();
                return;
            }

            // Check decrement button
            if (dec_button_bounds.contains(pos)) {
                click_count -= 1;
                std.debug.print("Count: {} (-)\n", .{click_count});
                ui.requestRedraw();
                return;
            }

            // Check color buttons
            for (color_button_bounds, 0..) |bounds, i| {
                if (bounds.contains(pos)) {
                    selected_color = i;
                    std.debug.print("Color: {} \n", .{i});
                    ui.requestRedraw();
                    return;
                }
            }
        }
    }
}

fn cursorPosCallback(window: ?*c.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    _ = window;
    if (global_ui) |ui| {
        ui.mouse_state.position = .{ .x = @floatCast(xpos), .y = @floatCast(ypos) };
    }
}

fn renderUI(ui: *zapui.Ui, width: f32, height: f32) void {
    const scene = &ui.scene;
    const current_color = colors[selected_color];
    const center_x = width / 2;

    // Background
    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(0, 0, width, height),
        .background = .{ .solid = zapui.rgb(0x1a202c) },
    }) catch {};

    // Header bar
    const header_w: f32 = 500;
    const header_h: f32 = 80;
    const header_x = center_x - header_w / 2;
    const header_y: f32 = 60;

    scene.insertShadow(.{
        .bounds = zapui.Bounds(f32).fromXYWH(header_x, header_y, header_w, header_h),
        .corner_radii = zapui.Corners(f32).all(16),
        .blur_radius = 20,
        .color = zapui.black().withAlpha(0.3),
    }) catch {};

    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(header_x, header_y, header_w, header_h),
        .background = .{ .solid = zapui.rgb(current_color) },
        .corner_radii = zapui.Corners(f32).all(16),
    }) catch {};

    // Count indicator bar (width changes with count)
    const bar_base: f32 = 100;
    const bar_w: f32 = bar_base + @as(f32, @floatFromInt(@mod(click_count + 50, 30))) * 6;
    const bar_h: f32 = 30;
    const bar_x = center_x - bar_w / 2;
    const bar_y = header_y + (header_h - bar_h) / 2;

    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(bar_x, bar_y, bar_w, bar_h),
        .background = .{ .solid = zapui.rgb(0xffffff).withAlpha(0.4) },
        .corner_radii = zapui.Corners(f32).all(8),
    }) catch {};

    // Buttons
    const button_w: f32 = 100;
    const button_h: f32 = 50;
    const button_y: f32 = 180;
    const button_gap: f32 = 40;

    // Decrement button (red, left)
    const dec_x = center_x - button_w - button_gap / 2;
    dec_button_bounds = zapui.Bounds(f32).fromXYWH(dec_x, button_y, button_w, button_h);

    scene.insertShadow(.{
        .bounds = dec_button_bounds,
        .corner_radii = zapui.Corners(f32).all(12),
        .blur_radius = 10,
        .color = zapui.black().withAlpha(0.2),
    }) catch {};

    scene.insertQuad(.{
        .bounds = dec_button_bounds,
        .background = .{ .solid = zapui.rgb(0xf56565) },
        .corner_radii = zapui.Corners(f32).all(12),
    }) catch {};

    // Minus sign
    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(dec_x + button_w / 2 - 12, button_y + button_h / 2 - 2, 24, 4),
        .background = .{ .solid = zapui.rgb(0xffffff) },
        .corner_radii = zapui.Corners(f32).all(2),
    }) catch {};

    // Increment button (green, right)
    const inc_x = center_x + button_gap / 2;
    inc_button_bounds = zapui.Bounds(f32).fromXYWH(inc_x, button_y, button_w, button_h);

    scene.insertShadow(.{
        .bounds = inc_button_bounds,
        .corner_radii = zapui.Corners(f32).all(12),
        .blur_radius = 10,
        .color = zapui.black().withAlpha(0.2),
    }) catch {};

    scene.insertQuad(.{
        .bounds = inc_button_bounds,
        .background = .{ .solid = zapui.rgb(0x48bb78) },
        .corner_radii = zapui.Corners(f32).all(12),
    }) catch {};

    // Plus sign (horizontal)
    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(inc_x + button_w / 2 - 12, button_y + button_h / 2 - 2, 24, 4),
        .background = .{ .solid = zapui.rgb(0xffffff) },
        .corner_radii = zapui.Corners(f32).all(2),
    }) catch {};

    // Plus sign (vertical)
    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(inc_x + button_w / 2 - 2, button_y + button_h / 2 - 12, 4, 24),
        .background = .{ .solid = zapui.rgb(0xffffff) },
        .corner_radii = zapui.Corners(f32).all(2),
    }) catch {};

    // Color picker
    const color_size: f32 = 50;
    const color_gap: f32 = 15;
    const color_y: f32 = 280;
    const total_color_w = color_size * 5 + color_gap * 4;
    const color_start_x = center_x - total_color_w / 2;

    for (colors, 0..) |clr, i| {
        const is_selected = i == selected_color;
        const size: f32 = if (is_selected) 58 else color_size;
        const offset: f32 = if (is_selected) -4 else 0;
        const x = color_start_x + @as(f32, @floatFromInt(i)) * (color_size + color_gap) + offset;
        const y = color_y + offset;

        color_button_bounds[i] = zapui.Bounds(f32).fromXYWH(x, y, size, size);

        // Shadow
        scene.insertShadow(.{
            .bounds = color_button_bounds[i],
            .corner_radii = zapui.Corners(f32).all(if (is_selected) 14 else 10),
            .blur_radius = if (is_selected) 15 else 8,
            .color = zapui.black().withAlpha(if (is_selected) 0.3 else 0.2),
        }) catch {};

        // Color square
        scene.insertQuad(.{
            .bounds = color_button_bounds[i],
            .background = .{ .solid = zapui.rgb(clr) },
            .corner_radii = zapui.Corners(f32).all(if (is_selected) 14 else 10),
            .border_widths = if (is_selected) zapui.Edges(f32).all(3) else zapui.Edges(f32).zero,
            .border_color = if (is_selected) zapui.rgb(0xffffff) else null,
        }) catch {};
    }

    // Instructions (text placeholders)
    const text_y: f32 = 380;

    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(center_x - 140, text_y, 280, 18),
        .background = .{ .solid = zapui.rgb(0x4a5568) },
        .corner_radii = zapui.Corners(f32).all(4),
    }) catch {};

    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(center_x - 110, text_y + 30, 220, 14),
        .background = .{ .solid = zapui.rgb(0x4a5568) },
        .corner_radii = zapui.Corners(f32).all(4),
    }) catch {};

    // Count display text placeholder
    const count_text_w: f32 = 60;
    scene.insertQuad(.{
        .bounds = zapui.Bounds(f32).fromXYWH(center_x - count_text_w / 2, text_y + 60, count_text_w, 24),
        .background = .{ .solid = zapui.rgb(0x718096) },
        .corner_radii = zapui.Corners(f32).all(6),
    }) catch {};

    scene.finish();
}

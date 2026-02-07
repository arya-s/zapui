//! zapui playground - Interactive Demo with Text Rendering
//!
//! This demonstrates:
//! - Building UIs with styled primitives
//! - Hit testing for mouse interaction
//! - Text rendering with stb_truetype

const std = @import("std");
const zapui = @import("zapui");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

// Application state
var click_count: i32 = 0;
var selected_color: usize = 3; // Start with orange
const colors = [_]u24{ 0x4299e1, 0x48bb78, 0x9f7aea, 0xed8936, 0xf56565 };
const color_names = [_][]const u8{ "Blue", "Green", "Purple", "Orange", "Red" };

// Button bounds (computed during layout)
var inc_button_bounds: zapui.Bounds(f32) = zapui.Bounds(f32).zero;
var dec_button_bounds: zapui.Bounds(f32) = zapui.Bounds(f32).zero;
var color_button_bounds: [5]zapui.Bounds(f32) = .{zapui.Bounds(f32).zero} ** 5;

// Pointer to UI and text system for callbacks
var global_ui: ?*zapui.Ui = null;
var global_text: ?*zapui.TextSystem = null;
var global_font: ?zapui.FontId = null;

pub fn main() !void {
    std.debug.print("=== zapui Playground (Text Rendering Demo) ===\n\n", .{});

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
    const window = c.glfwCreateWindow(800, 600, "zapui playground - Text Demo", null, null) orelse {
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
    std.debug.print("Renderer initialized\n", .{});

    // Create text system
    var text_system = zapui.TextSystem.init(allocator);
    defer text_system.deinit();
    global_text = &text_system;

    // Use the renderer's glyph atlas for text
    if (ui.renderer) |*r| {
        text_system.setAtlas(r.getGlyphAtlas());
    }

    // Load font
    const font = text_system.loadFontFile("assets/fonts/LiberationSans-Regular.ttf") catch |err| {
        std.debug.print("Failed to load font: {}\n", .{err});
        std.debug.print("Please ensure assets/fonts/LiberationSans-Regular.ttf exists\n", .{});
        return err;
    };
    global_font = font;
    std.debug.print("Font loaded successfully\n\n", .{});

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

            renderUI(&ui, &text_system, font, @floatFromInt(width), @floatFromInt(height));

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
                    std.debug.print("Color: {s}\n", .{color_names[i]});
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

fn renderUI(ui: *zapui.Ui, text_system: *zapui.TextSystem, font: zapui.FontId, width: f32, height: f32) void {
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
    const header_h: f32 = 100;
    const header_x = center_x - header_w / 2;
    const header_y: f32 = 50;

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


    
    // Title text  
    const title = "zapui Text Demo";
    const title_size: f32 = 28;
    const title_width = text_system.measureText(title, font, title_size);
    const title_metrics = text_system.getFontMetrics(font, title_size);
    const title_x = center_x - title_width / 2;
    const title_y = header_y + header_h / 2 - title_metrics.ascent / 2;

    renderText(scene, text_system, font, title, title_x, title_y + title_metrics.ascent, title_size, zapui.rgb(0xffffff));

    // Subtitle with count
    var count_buf: [32]u8 = undefined;
    const count_text = std.fmt.bufPrint(&count_buf, "Count: {}", .{click_count}) catch "Count: ?";
    const count_size: f32 = 18;
    const count_width = text_system.measureText(count_text, font, count_size);
    const count_x = center_x - count_width / 2;

    renderText(scene, text_system, font, count_text, count_x, header_y + header_h - 15, count_size, zapui.rgb(0xffffff).withAlpha(0.8));

    // Buttons
    const button_w: f32 = 100;
    const button_h: f32 = 50;
    const button_y: f32 = 200;
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

    // Minus sign text
    renderText(scene, text_system, font, "-", dec_x + button_w / 2 - 6, button_y + button_h / 2 + 10, 32, zapui.rgb(0xffffff));

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

    // Plus sign text
    renderText(scene, text_system, font, "+", inc_x + button_w / 2 - 8, button_y + button_h / 2 + 10, 32, zapui.rgb(0xffffff));

    // Color picker
    const color_size: f32 = 50;
    const color_gap: f32 = 15;
    const color_y: f32 = 300;
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

    // Color name label
    const name_text = color_names[selected_color];
    const name_size: f32 = 16;
    const name_width = text_system.measureText(name_text, font, name_size);
    renderText(scene, text_system, font, name_text, center_x - name_width / 2, color_y + 80, name_size, zapui.rgb(0xa0aec0));

    // Instructions
    const instr1 = "Click + or - to change the count";
    const instr2 = "Click colors to change the header";
    const instr_size: f32 = 14;
    const instr1_w = text_system.measureText(instr1, font, instr_size);
    const instr2_w = text_system.measureText(instr2, font, instr_size);

    renderText(scene, text_system, font, instr1, center_x - instr1_w / 2, height - 70, instr_size, zapui.rgb(0x718096));
    renderText(scene, text_system, font, instr2, center_x - instr2_w / 2, height - 45, instr_size, zapui.rgb(0x718096));

    scene.finish();
}

fn renderText(scene: *zapui.Scene, text_system: *zapui.TextSystem, font: zapui.FontId, text: []const u8, x: f32, y: f32, size: f32, clr: zapui.Hsla) void {
    var run = text_system.shapeText(text, font, size) catch return;
    defer text_system.freeShapedRun(&run);

    var cursor_x = x;
    for (run.glyphs) |glyph| {
        if (text_system.rasterizeGlyph(font, glyph.glyph_id, size)) |cached| {
            if (cached.pixel_bounds.width() > 0 and cached.pixel_bounds.height() > 0) {
                const gx = cursor_x + cached.pixel_bounds.x();
                const gy = y + cached.pixel_bounds.y();
                const gw = cached.pixel_bounds.width();
                const gh = cached.pixel_bounds.height();

                // Add monochrome sprite to scene
                scene.insertMonoSprite(.{
                    .bounds = zapui.Bounds(f32).fromXYWH(gx, gy, gw, gh),
                    .tile_bounds = cached.atlas_bounds,
                    .color = clr,
                }) catch {};
            }
        }
        cursor_x += glyph.x_advance;
    }
}

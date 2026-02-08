//! ZapUI Playground - GPUI-compatible Div API Demo

const std = @import("std");
const zapui = @import("zapui");

const GlRenderer = zapui.GlRenderer;
const TextSystem = zapui.TextSystem;
const Scene = zapui.Scene;
const taffy = zapui.taffy;
const Bounds = zapui.Bounds;
const Point = zapui.Point;
const Pixels = zapui.Pixels;
const Hsla = zapui.Hsla;

// GPUI-style API
const Div = zapui.elements.div.Div;
const div = zapui.elements.div.div;
const v_flex = zapui.elements.div.v_flex;
const h_flex = zapui.elements.div.h_flex;
const reset = zapui.elements.div.reset;
const px = zapui.elements.div.px;

const glfw = @cImport({ @cInclude("GLFW/glfw3.h"); });

// ============================================================================
// Colors
// ============================================================================

const C = struct {
    const bg_dark = zapui.rgb(0x0f1419);
    const bg_card = zapui.rgb(0x1a1f26);
    const bg_elevated = zapui.rgb(0x2d3748);
    const bg_hover = zapui.rgb(0x3d4a5c);
    const primary = zapui.rgb(0x4299e1);
    const success = zapui.rgb(0x48bb78);
    const danger = zapui.rgb(0xf56565);
    const warning = zapui.rgb(0xed8936);
    const purple = zapui.rgb(0x9f7aea);
    const white = zapui.rgb(0xffffff);
    const text_primary = zapui.rgb(0xe2e8f0);
    const text_muted = zapui.rgb(0x718096);
    const border = zapui.rgb(0x4a5568);
};

// ============================================================================
// State
// ============================================================================

var g_mouse_pos: Point(Pixels) = .{ .x = 0, .y = 0 };
var g_mouse_down: bool = false;
var g_slider_value: f32 = 0.65;
var g_checkbox_checked: bool = true;
var g_toggle_on: bool = true;

// Hit testing
const Hitbox = struct { bounds: Bounds(Pixels), id: usize };
var g_hitboxes: [64]Hitbox = undefined;
var g_hitbox_count: usize = 0;

const ID_SLIDER = 1;
const ID_CHECKBOX = 2;
const ID_TOGGLE = 3;
const ID_BTN_PRIMARY = 10;
const ID_BTN_SUCCESS = 11;
const ID_BTN_DANGER = 12;

fn resetHitboxes() void { g_hitbox_count = 0; }

fn addHitbox(bounds: Bounds(Pixels), id: usize) void {
    if (g_hitbox_count < g_hitboxes.len) {
        g_hitboxes[g_hitbox_count] = .{ .bounds = bounds, .id = id };
        g_hitbox_count += 1;
    }
}

fn hitTest(pos: Point(Pixels)) ?usize {
    var i: usize = g_hitbox_count;
    while (i > 0) { i -= 1; if (g_hitboxes[i].bounds.contains(pos)) return g_hitboxes[i].id; }
    return null;
}

fn isHovered(id: usize) bool {
    return if (hitTest(g_mouse_pos)) |hid| hid == id else false;
}

// ============================================================================
// Components (GPUI-style)
// ============================================================================

fn button(label: []const u8, color: Hsla, id: usize) *Div {
    return div()
        .w(px(100)).h(px(40))
        .bg(color)
        .hover_bg(color.lighten(0.1))
        .rounded(px(8))
        .id(id)
        .justify_center().items_center()
        .child_text(label)
        .text_color(C.white);
}

fn checkbox(label: []const u8, checked: bool, id: usize) *Div {
    const box_color = if (checked) C.primary else C.bg_elevated;
    const bord_color = if (checked) C.primary else C.border;
    
    // Using .when() to conditionally add the checkmark
    const addCheckmark = struct {
        fn f(d: *Div) *Div {
            return d.child(div().w(px(10)).h(px(10)).bg(C.white).rounded(px(2)));
        }
    }.f;
    
    const box = div()
        .w(px(20)).h(px(20))
        .bg(box_color)
        .hover_bg(if (checked) C.primary else C.bg_hover)  // hover style!
        .rounded(px(4))
        .border_2().border_color(bord_color)
        .justify_center().items_center()
        .id(id)
        .when(checked, addCheckmark);
    
    const lbl = div().h(px(20)).px(px(8)).child_text(label).text_sm().text_color(C.text_primary);
    
    return h_flex().gap(px(10)).items_center().child(box).child(lbl);
}

fn toggle(enabled: bool, id: usize) *Div {
    const track_color = if (enabled) C.primary else C.bg_elevated;
    const knob_x: Pixels = if (enabled) 26 else 4;
    
    const track = div()
        .w(px(48)).h(px(26))
        .bg(track_color)
        .hover_bg(if (enabled) C.primary.lighten(0.1) else C.bg_hover)  // hover style!
        .rounded_full()
        .id(id);
    const knob = div().w(px(18)).h(px(18)).bg(C.white).rounded_full().absolute().left(px(knob_x)).top(px(4));
    
    return track.child(knob);
}

fn slider(value: f32, id: usize) *Div {
    const track_w: Pixels = 200;
    const knob_size: Pixels = 20;
    const container_h: Pixels = 24;
    const track_h: Pixels = 8;
    
    const filled_w = track_w * value;
    const knob_x = track_w * value - knob_size / 2;
    const knob_y = (container_h - knob_size) / 2;
    const track_y = (container_h - track_h) / 2;
    
    const track_bg = div().w(px(track_w)).h(px(track_h)).bg(C.bg_elevated).rounded(px(4))
        .absolute().top(px(track_y));
    const filled = div().w(px(filled_w)).h(px(track_h)).bg(C.primary).rounded(px(4))
        .absolute().top(px(track_y));
    const knob = div().w(px(knob_size)).h(px(knob_size)).bg(C.primary).rounded_full()
        .border_3().border_color(C.white)
        .absolute().left(px(@max(0, knob_x))).top(px(knob_y));
    
    return div().w(px(track_w)).h(px(container_h)).id(id)
        .child(track_bg).child(filled).child(knob);
}

fn progressBar(value: f32, color: Hsla) *Div {
    const bar_w: Pixels = 200;
    const filled_w = bar_w * std.math.clamp(value, 0, 1);
    
    const track = div().w(px(bar_w)).h(px(10)).bg(C.bg_elevated).rounded(px(5));
    const filled = div().w(px(filled_w)).h(px(10)).bg(color).rounded(px(5)).absolute();
    
    return track.child(filled);
}

fn sectionTitle(title: []const u8) *Div {
    return div().h(px(36)).child_text(title).text_lg().text_color(C.text_primary);
}

// ============================================================================
// Main UI
// ============================================================================

var g_slider_buf: [32]u8 = undefined;

fn buildUI(tree: *taffy.Taffy, scene: *Scene, text_system: *TextSystem, width: Pixels, height: Pixels) !void {
    reset();
    resetHitboxes();
    
    const rem: Pixels = 16.0;
    
    // Header - full width with centered text
    const header = div()
        .w(px(width))
        .h(px(70))
        .bg(C.bg_card)
        .justify_center()
        .items_center()
        .child_text("ZapUI Div API Demo")
        .text_2xl()
        .text_color(C.primary);
    
    // Buttons section
    const btn_section = v_flex().gap(px(12))
        .child(sectionTitle("Buttons"))
        .child(h_flex().gap(px(12))
            .child(button("Primary", C.primary, ID_BTN_PRIMARY))
            .child(button("Success", C.success, ID_BTN_SUCCESS))
            .child(button("Danger", C.danger, ID_BTN_DANGER)));
    
    // Checkbox section
    const cb_section = v_flex().gap(px(12))
        .child(sectionTitle("Checkbox"))
        .child(checkbox("Enable feature", g_checkbox_checked, ID_CHECKBOX));
    
    // Toggle section
    const toggle_section = v_flex().gap(px(12))
        .child(sectionTitle("Toggle"))
        .child(h_flex().gap(px(12)).items_center()
            .child(toggle(g_toggle_on, ID_TOGGLE))
            .child(div().child_text(if (g_toggle_on) "On" else "Off").text_sm().text_color(C.text_primary)));
    
    // Slider section
    const slider_text = std.fmt.bufPrint(&g_slider_buf, "{d:.0}%", .{g_slider_value * 100}) catch "0%";
    const slider_section = v_flex().gap(px(12))
        .child(sectionTitle("Slider"))
        .child(h_flex().gap(px(16)).items_center()
            .child(slider(g_slider_value, ID_SLIDER))
            .child(div().child_text(slider_text).text_sm().text_color(C.text_muted)));
    
    // Progress section
    const progress_section = v_flex().gap(px(12))
        .child(sectionTitle("Progress"))
        .child(v_flex().gap(px(8))
            .child(progressBar(0.75, C.primary))
            .child(progressBar(0.45, C.success))
            .child(progressBar(0.25, C.warning)));
    
    // Content area
    const content = v_flex().gap(px(24)).p(px(24)).flex_1()
        .child(btn_section)
        .child(cb_section)
        .child(toggle_section)
        .child(slider_section)
        .child(progress_section);
    
    // Root
    const root = v_flex().w(px(width)).h(px(height)).bg(C.bg_dark)
        .child(header).child(content);
    
    try root.build(tree, rem);
    tree.computeLayoutWithSize(root.node_id.?, width, height);
    root.paint(scene, text_system, 0, 0, tree, addHitbox, isHovered);

    // Test emoji rendering (font_id 1 = emoji font)
    if (text_system.fonts.items.len > 1) {
        text_system.renderTextWithFont(scene, "🎉🚀✨", width - 120, 50, 24, C.white, 1) catch {};
    }
}

// ============================================================================
// Input
// ============================================================================

fn handleClick() void {
    if (hitTest(g_mouse_pos)) |id| {
        switch (id) {
            ID_CHECKBOX => g_checkbox_checked = !g_checkbox_checked,
            ID_TOGGLE => g_toggle_on = !g_toggle_on,
            else => {},
        }
    }
}

fn handleSliderDrag() void {
    if (g_mouse_down) {
        for (g_hitboxes[0..g_hitbox_count]) |hb| {
            if (hb.id == ID_SLIDER and hb.bounds.contains(g_mouse_pos)) {
                g_slider_value = std.math.clamp((g_mouse_pos.x - hb.bounds.origin.x) / hb.bounds.size.width, 0, 1);
                break;
            }
        }
    }
}

fn mouseButtonCallback(_: ?*glfw.GLFWwindow, btn: c_int, action: c_int, _: c_int) callconv(.c) void {
    if (btn == glfw.GLFW_MOUSE_BUTTON_LEFT) {
        if (action == glfw.GLFW_PRESS) { g_mouse_down = true; handleSliderDrag(); }
        else if (action == glfw.GLFW_RELEASE) { g_mouse_down = false; handleClick(); }
    }
}

fn cursorPosCallback(_: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    g_mouse_pos = .{ .x = @floatCast(xpos), .y = @floatCast(ypos) };
    handleSliderDrag();
}

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    if (glfw.glfwInit() == 0) return;
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, 1);

    const win = glfw.glfwCreateWindow(800, 600, "ZapUI - Div API Demo", null, null) orelse return;
    defer glfw.glfwDestroyWindow(win);

    glfw.glfwMakeContextCurrent(win);
    glfw.glfwSwapInterval(1);
    _ = glfw.glfwSetMouseButtonCallback(win, mouseButtonCallback);
    _ = glfw.glfwSetCursorPosCallback(win, cursorPosCallback);

    try zapui.loadGl(struct {
        pub fn getProcAddress(name: [*:0]const u8) ?*anyopaque {
            return @ptrCast(@constCast(glfw.glfwGetProcAddress(name)));
        }
    }.getProcAddress);

    const allocator = std.heap.page_allocator;
    var renderer = try GlRenderer.init(allocator);
    defer renderer.deinit();

    var text_system = TextSystem.init(allocator) catch {
        std.debug.print("Failed to initialize text system\n", .{});
        return;
    };
    defer text_system.deinit();
    _ = text_system.loadFontFile("assets/fonts/JetBrainsMono-Regular.ttf") catch {
        std.debug.print("Failed to load font\n", .{});
        return;
    };
    // Load emoji font for color emoji support
    _ = text_system.loadFontFile("assets/fonts/NotoColorEmoji.ttf") catch null;
    
    text_system.setAtlas(renderer.getGlyphAtlas());
    text_system.setColorAtlas(renderer.getColorAtlas());

    while (glfw.glfwWindowShouldClose(win) == 0) {
        glfw.glfwPollEvents();

        var ww: c_int = 0;
        var wh: c_int = 0;
        glfw.glfwGetFramebufferSize(win, &ww, &wh);
        const width: Pixels = @floatFromInt(ww);
        const height: Pixels = @floatFromInt(wh);
        
        renderer.setViewport(width, height, 1.0);

        var tree = taffy.Taffy.init(allocator);
        defer tree.deinit();
        var scene = Scene.init(allocator);
        defer scene.deinit();
        
        try buildUI(&tree, &scene, &text_system, width, height);

        renderer.clear(C.bg_dark);
        try renderer.drawScene(&scene);
        glfw.glfwSwapBuffers(win);
    }
}

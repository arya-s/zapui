//! ZapUI Playground - Component Showcase

const std = @import("std");
const zapui = @import("zapui");
const zglfw = @import("zglfw");

const GlRenderer = zapui.GlRenderer;
const TextSystem = zapui.TextSystem;
const Scene = zapui.Scene;
const zaffy = zapui.zaffy;
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

// ============================================================================
// Colors - Modern dark theme
// ============================================================================

const C = struct {
    // Backgrounds
    const bg_dark = zapui.rgb(0x0f1419);
    const bg_card = zapui.rgb(0x1a1f26);
    const bg_elevated = zapui.rgb(0x2d3748);
    const bg_hover = zapui.rgb(0x3d4a5c);
    const bg_input = zapui.rgb(0x1e2530);
    
    // Accent colors
    const primary = zapui.rgb(0x4299e1);
    const secondary = zapui.rgb(0x667eea);
    const success = zapui.rgb(0x48bb78);
    const danger = zapui.rgb(0xf56565);
    const warning = zapui.rgb(0xed8936);
    const purple = zapui.rgb(0x9f7aea);
    const pink = zapui.rgb(0xed64a6);
    const cyan = zapui.rgb(0x38b2ac);
    
    // Text
    const white = zapui.rgb(0xffffff);
    const text_primary = zapui.rgb(0xe2e8f0);
    const text_secondary = zapui.rgb(0xa0aec0);
    const text_muted = zapui.rgb(0x718096);
    
    // Borders
    const border = zapui.rgb(0x4a5568);
    const border_light = zapui.rgb(0x2d3748);
};

// ============================================================================
// State
// ============================================================================

var g_mouse_pos: Point(Pixels) = .{ .x = 0, .y = 0 };
var g_mouse_down: bool = false;
var g_slider_value: f32 = 0.65;
var g_slider2_value: f32 = 0.35;
var g_checkbox1_checked: bool = true;
var g_checkbox2_checked: bool = false;
var g_checkbox3_checked: bool = true;
var g_toggle1_on: bool = true;
var g_toggle2_on: bool = false;
var g_selected_tab: usize = 0;

// Hit testing
const Hitbox = struct { bounds: Bounds(Pixels), id: usize };
var g_hitboxes: [128]Hitbox = undefined;
var g_hitbox_count: usize = 0;

// Component IDs
const ID_SLIDER1 = 1;
const ID_SLIDER2 = 2;
const ID_CHECKBOX1 = 10;
const ID_CHECKBOX2 = 11;
const ID_CHECKBOX3 = 12;
const ID_TOGGLE1 = 20;
const ID_TOGGLE2 = 21;
const ID_TAB1 = 30;
const ID_TAB2 = 31;
const ID_TAB3 = 32;
const ID_BTN_PRIMARY = 40;
const ID_BTN_SECONDARY = 41;
const ID_BTN_SUCCESS = 42;
const ID_BTN_DANGER = 43;
const ID_BTN_OUTLINE = 44;
const ID_BTN_GHOST = 45;
const ID_INPUT1 = 50;
const ID_INPUT2 = 51;

// Text input state
var g_focused_input: ?usize = null;
var g_input1_buf: [64]u8 = undefined;
var g_input1_len: usize = 0;
var g_input2_buf: [64]u8 = undefined;
var g_input2_len: usize = 0;
var g_cursor_blink: u32 = 0;

fn resetHitboxes() void { g_hitbox_count = 0; }

fn addHitbox(id: usize, bounds: Bounds(Pixels)) void {
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
// Components
// ============================================================================

fn solidButton(label: []const u8, color: Hsla, id: usize) *Div {
    const hovered = isHovered(id);
    const bg = if (hovered) color.lighten(0.1) else color;
    return div()
        .w(px(110)).h(px(38))
        .bg(bg)
        .rounded(px(6))
        .id(id)
        .justify_center().items_center()
        .child_text(label)
        .text_color(C.white)
        .text_sm();
}

fn outlineButton(label: []const u8, color: Hsla, id: usize) *Div {
    const hovered = isHovered(id);
    const bg = if (hovered) color.withAlpha(0.15) else zapui.Hsla.transparent;
    return div()
        .w(px(110)).h(px(38))
        .bg(bg)
        .border_1().border_color(color)
        .rounded(px(6))
        .id(id)
        .justify_center().items_center()
        .child_text(label)
        .text_color(color)
        .text_sm();
}

fn ghostButton(label: []const u8, color: Hsla, id: usize) *Div {
    const hovered = isHovered(id);
    const bg = if (hovered) color.withAlpha(0.15) else zapui.Hsla.transparent;
    const border_c = if (hovered) color.withAlpha(0.3) else color.withAlpha(0.15);
    return div()
        .w(px(110)).h(px(38))
        .bg(bg)
        .border_1().border_color(border_c)
        .rounded(px(6))
        .id(id)
        .justify_center().items_center()
        .child_text(label)
        .text_color(color)
        .text_sm();
}

fn checkbox(label: []const u8, checked: bool, id: usize) *Div {
    const hovered = isHovered(id);
    const box_bg = if (checked) C.primary else if (hovered) C.bg_hover else C.bg_elevated;
    const border_c = if (checked) C.primary else C.border;
    
    const addCheckmark = struct {
        fn f(d: *Div) *Div {
            return d.child(div().w(px(10)).h(px(10)).bg(C.white).rounded(px(2)));
        }
    }.f;
    
    const box = div()
        .w(px(20)).h(px(20))
        .bg(box_bg)
        .rounded(px(4))
        .border_1().border_color(border_c)
        .justify_center().items_center()
        .id(id)
        .when(checked, addCheckmark);
    
    const lbl = div().child_text(label).text_sm().text_color(C.text_primary);
    
    return h_flex().gap(px(10)).items_center().child(box).child(lbl);
}

fn toggle(label: []const u8, enabled: bool, id: usize) *Div {
    const hovered = isHovered(id);
    const track_color = if (enabled) C.primary else if (hovered) C.bg_hover else C.bg_elevated;
    const knob_x: Pixels = if (enabled) 22 else 2;
    
    const track = div()
        .w(px(44)).h(px(24))
        .bg(track_color)
        .rounded_full()
        .id(id);
    const knob = div().w(px(20)).h(px(20)).bg(C.white).rounded_full()
        .absolute().left(px(knob_x)).top(px(2));
    
    const lbl = div().child_text(label).text_sm().text_color(C.text_primary);
    
    return h_flex().gap(px(12)).items_center().child(track.child(knob)).child(lbl);
}

fn slider(value: f32, color: Hsla, id: usize) *Div {
    const track_w: Pixels = 180;
    const knob_size: Pixels = 18;
    const track_h: Pixels = 6;
    const container_h: Pixels = 24;
    
    const filled_w = track_w * value;
    const knob_x = track_w * value - knob_size / 2;
    const track_y = (container_h - track_h) / 2;
    const knob_y = (container_h - knob_size) / 2;
    
    const track_bg = div().w(px(track_w)).h(px(track_h)).bg(C.bg_elevated).rounded(px(3))
        .absolute().top(px(track_y));
    const filled = div().w(px(filled_w)).h(px(track_h)).bg(color).rounded(px(3))
        .absolute().top(px(track_y));
    const knob = div().w(px(knob_size)).h(px(knob_size)).bg(color).rounded_full()
        .border_2().border_color(C.white)
        .absolute().left(px(@max(0, knob_x))).top(px(knob_y));
    
    return div().w(px(track_w)).h(px(container_h)).id(id)
        .child(track_bg).child(filled).child(knob);
}

fn progressBar(value: f32, color: Hsla, label: []const u8) *Div {
    const bar_w: Pixels = 200;
    const filled_w = bar_w * std.math.clamp(value, 0, 1);
    
    const track = div().w(px(bar_w)).h(px(8)).bg(C.bg_elevated).rounded(px(4));
    const filled = div().w(px(filled_w)).h(px(8)).bg(color).rounded(px(4)).absolute();
    
    const lbl = div().child_text(label).text_sm().text_color(C.text_muted);
    
    return h_flex().gap(px(12)).items_center().child(track.child(filled)).child(lbl);
}

fn badge(text: []const u8, color: Hsla) *Div {
    return div()
        .px(px(10)).py(px(4))
        .bg(color.withAlpha(0.2))
        .rounded(px(12))
        .child_text(text)
        .text_xs()
        .text_color(color);
}

fn avatar(initials: []const u8, color: Hsla, size: Pixels) *Div {
    return div()
        .w(px(size)).h(px(size))
        .bg(color)
        .rounded_full()
        .justify_center().items_center()
        .child_text(initials)
        .text_color(C.white);
}

fn card() *Div {
    return v_flex().gap(px(16))
        .p(px(20))
        .bg(C.bg_card)
        .rounded(px(12))
        .border_1().border_color(C.border_light);
}

fn tabButton(label: []const u8, selected: bool, id: usize) *Div {
    const hovered = isHovered(id);
    const bg = if (selected) C.primary else if (hovered) C.bg_hover else zapui.Hsla.transparent;
    const text_c = if (selected) C.white else C.text_secondary;
    return div()
        .px(px(16)).h(px(36))
        .bg(bg)
        .rounded(px(6))
        .justify_center().items_center()
        .id(id)
        .child_text(label)
        .text_sm()
        .text_color(text_c);
}

fn divider() *Div {
    return div().w(px(1)).h(px(20)).bg(C.border_light);
}

fn hDivider() *Div {
    return div().h(px(1)).bg(C.border_light);
}

fn sectionTitle(title: []const u8) *Div {
    return div().child_text(title).text_color(C.text_muted).text_xs();
}

var g_input_display_buf: [128]u8 = undefined;

fn inputField(placeholder: []const u8, value: []const u8, id: usize) *Div {
    const focused = g_focused_input == id;
    const hovered = isHovered(id);
    const border_c = if (focused) C.primary else if (hovered) C.text_muted else C.border;
    
    const has_value = value.len > 0;
    
    // Build display string with cursor if focused
    const display_text = if (focused) blk: {
        const show_cursor = (g_cursor_blink / 30) % 2 == 0;
        
        if (has_value) {
            @memcpy(g_input_display_buf[0..value.len], value);
            if (show_cursor) {
                // Use thin bar Unicode: ▏ (U+258F) = 0xE2 0x96 0x8F in UTF-8
                g_input_display_buf[value.len] = 0xE2;
                g_input_display_buf[value.len + 1] = 0x96;
                g_input_display_buf[value.len + 2] = 0x8F;
                break :blk g_input_display_buf[0 .. value.len + 3];
            } else {
                break :blk g_input_display_buf[0..value.len];
            }
        } else {
            if (show_cursor) {
                g_input_display_buf[0] = 0xE2;
                g_input_display_buf[1] = 0x96;
                g_input_display_buf[2] = 0x8F;
                break :blk g_input_display_buf[0..3];
            } else {
                break :blk placeholder;
            }
        }
    } else if (has_value) value else placeholder;
    
    const text_c = if (has_value or focused) C.text_primary else C.text_muted;
    
    return div()
        .w(px(300)).h(px(38))
        .bg(C.bg_input)
        .border_1().border_color(border_c)
        .rounded(px(6))
        .px(px(12))
        .items_center()
        .id(id)
        .child_text(display_text)
        .text_sm()
        .text_color(text_c);
}

// ============================================================================
// Main UI
// ============================================================================

var g_slider1_buf: [32]u8 = undefined;
var g_slider2_buf: [32]u8 = undefined;

fn buildUI(tree: *zaffy.Zaffy, scene: *Scene, text_system: *TextSystem, width: Pixels, height: Pixels) !void {
    reset();
    resetHitboxes();
    
    const rem: Pixels = 16.0;
    
    // Header
    const header = h_flex()
        .w(px(width))
        .h(px(60))
        .px(px(24))
        .bg(C.bg_card)
        .items_center()
        .justify_between()
        .child(
            div().child_text("ZapUI Component Showcase").text_xl().text_color(C.white)
        )
        .child(
            h_flex().gap(px(16)).items_center()
                .child(badge("v0.1", C.primary))
                .child(badge("Beta", C.warning))
                .child(div().w(px(40))) // spacer for emoji
        );
    
    // Left sidebar - Navigation
    const sidebar = v_flex()
        .w(px(200))
        .h(px(height - 60))
        .bg(C.bg_card)
        .p(px(16))
        .gap(px(4))
        .child(sectionTitle("COMPONENTS"))
        .child(div().h(px(8)))
        .child(tabButton("Buttons", g_selected_tab == 0, ID_TAB1))
        .child(tabButton("Form Controls", g_selected_tab == 1, ID_TAB2))
        .child(tabButton("Display", g_selected_tab == 2, ID_TAB3));
    
    // Content area based on selected tab
    const content = switch (g_selected_tab) {
        0 => buildButtonsTab(),
        1 => buildFormControlsTab(),
        2 => buildDisplayTab(),
        else => buildButtonsTab(),
    };
    
    // Main content area
    const main_content = div()
        .flex_1()
        .h(px(height - 60))
        .p(px(24))
        .bg(C.bg_dark)
        .child(content);
    
    // Body (sidebar + content)
    const body = h_flex()
        .w(px(width))
        .child(sidebar)
        .child(main_content);
    
    // Root
    const root = v_flex().w(px(width)).h(px(height)).bg(C.bg_dark)
        .child(header)
        .child(body);
    
    try root.build(tree, rem);
    tree.computeLayoutWithSize(root.node_id.?, width, height);
    root.paint(scene, text_system, 0, 0, tree, addHitbox, isHovered);

    // Emoji decoration in header
    if (text_system.fonts.items.len > 1) {
        text_system.renderTextWithFont(scene, "🎨", width - 46, 32, 24, C.white, 1) catch {};
    }
}

fn buildButtonsTab() *Div {
    return v_flex().gap(px(20))
        .child(
            card()
                .child(div().child_text("Solid Buttons").text_color(C.text_primary))
                .child(h_flex().gap(px(12))
                    .child(solidButton("Primary", C.primary, ID_BTN_PRIMARY))
                    .child(solidButton("Secondary", C.secondary, ID_BTN_SECONDARY))
                    .child(solidButton("Success", C.success, ID_BTN_SUCCESS))
                    .child(solidButton("Danger", C.danger, ID_BTN_DANGER)))
        )
        .child(
            card()
                .child(div().child_text("Outline Buttons").text_color(C.text_primary))
                .child(h_flex().gap(px(12))
                    .child(outlineButton("Primary", C.primary, ID_BTN_OUTLINE))
                    .child(outlineButton("Success", C.success, ID_BTN_OUTLINE + 1))
                    .child(outlineButton("Danger", C.danger, ID_BTN_OUTLINE + 2)))
        )
        .child(
            card()
                .child(div().child_text("Ghost Buttons").text_color(C.text_primary))
                .child(h_flex().gap(px(12))
                    .child(ghostButton("Primary", C.primary, ID_BTN_GHOST))
                    .child(ghostButton("Secondary", C.secondary, ID_BTN_GHOST + 1)))
        );
}

fn buildFormControlsTab() *Div {
    const slider1_text = std.fmt.bufPrint(&g_slider1_buf, "{d:.0}%", .{g_slider_value * 100}) catch "0%";
    const slider2_text = std.fmt.bufPrint(&g_slider2_buf, "{d:.0}%", .{g_slider2_value * 100}) catch "0%";
    
    return v_flex().gap(px(20))
        .child(
            h_flex().gap(px(20))
                .child(
                    card().w(px(280))
                        .child(div().child_text("Checkboxes").text_color(C.text_primary))
                        .child(v_flex().gap(px(14))
                            .child(checkbox("Enable notifications", g_checkbox1_checked, ID_CHECKBOX1))
                            .child(checkbox("Auto-save drafts", g_checkbox2_checked, ID_CHECKBOX2))
                            .child(checkbox("Dark mode", g_checkbox3_checked, ID_CHECKBOX3)))
                )
                .child(
                    card().w(px(280))
                        .child(div().child_text("Toggle Switches").text_color(C.text_primary))
                        .child(v_flex().gap(px(14))
                            .child(toggle("Push notifications", g_toggle1_on, ID_TOGGLE1))
                            .child(toggle("Email updates", g_toggle2_on, ID_TOGGLE2)))
                )
        )
        .child(
            card()
                .child(div().child_text("Sliders").text_color(C.text_primary))
                .child(v_flex().gap(px(16))
                    .child(h_flex().gap(px(16)).items_center()
                        .child(slider(g_slider_value, C.primary, ID_SLIDER1))
                        .child(div().w(px(50)).child_text(slider1_text).text_sm().text_color(C.text_muted)))
                    .child(h_flex().gap(px(16)).items_center()
                        .child(slider(g_slider2_value, C.success, ID_SLIDER2))
                        .child(div().w(px(50)).child_text(slider2_text).text_sm().text_color(C.text_muted))))
        )
        .child(
            card()
                .child(div().child_text("Text Inputs").text_color(C.text_primary))
                .child(v_flex().gap(px(12))
                    .child(inputField("Enter your name...", g_input1_buf[0..g_input1_len], ID_INPUT1))
                    .child(inputField("Email address...", g_input2_buf[0..g_input2_len], ID_INPUT2)))
        );
}

fn buildDisplayTab() *Div {
    return v_flex().gap(px(20))
        .child(
            card()
                .child(div().child_text("Badges").text_color(C.text_primary))
                .child(h_flex().gap(px(10))
                    .child(badge("New", C.primary))
                    .child(badge("Sale", C.success))
                    .child(badge("Hot", C.danger))
                    .child(badge("Soon", C.warning)))
        )
        .child(
            card()
                .child(div().child_text("Avatars").text_color(C.text_primary))
                .child(h_flex().gap(px(16)).items_center()
                    .child(avatar("JD", C.primary, 32))
                    .child(avatar("AB", C.success, 40))
                    .child(avatar("XY", C.purple, 48))
                    .child(avatar("MN", C.danger, 56)))
        )
        .child(
            card()
                .child(div().child_text("Progress Bars").text_color(C.text_primary))
                .child(v_flex().gap(px(12))
                    .child(progressBar(0.85, C.primary, "85%"))
                    .child(progressBar(0.60, C.success, "60%"))
                    .child(progressBar(0.35, C.warning, "35%"))
                    .child(progressBar(0.15, C.danger, "15%")))
        );
}

// ============================================================================
// Input
// ============================================================================

fn handleClick() void {
    if (hitTest(g_mouse_pos)) |id| {
        switch (id) {
            ID_CHECKBOX1 => g_checkbox1_checked = !g_checkbox1_checked,
            ID_CHECKBOX2 => g_checkbox2_checked = !g_checkbox2_checked,
            ID_CHECKBOX3 => g_checkbox3_checked = !g_checkbox3_checked,
            ID_TOGGLE1 => g_toggle1_on = !g_toggle1_on,
            ID_TOGGLE2 => g_toggle2_on = !g_toggle2_on,
            ID_TAB1 => g_selected_tab = 0,
            ID_TAB2 => g_selected_tab = 1,
            ID_TAB3 => g_selected_tab = 2,
            ID_INPUT1, ID_INPUT2 => g_focused_input = id,
            else => g_focused_input = null,
        }
    } else {
        g_focused_input = null;
    }
}

fn handleCharInput(codepoint: u21) void {
    if (g_focused_input) |id| {
        // Only handle printable ASCII for simplicity
        if (codepoint >= 32 and codepoint < 127) {
            const char: u8 = @intCast(codepoint);
            if (id == ID_INPUT1 and g_input1_len < g_input1_buf.len - 1) {
                g_input1_buf[g_input1_len] = char;
                g_input1_len += 1;
            } else if (id == ID_INPUT2 and g_input2_len < g_input2_buf.len - 1) {
                g_input2_buf[g_input2_len] = char;
                g_input2_len += 1;
            }
        }
    }
}

fn handleKeyInput(key: zglfw.Key) void {
    if (key == .escape) {
        g_focused_input = null;
        return;
    }
    
    if (g_focused_input) |id| {
        if (key == .backspace) {
            if (id == ID_INPUT1 and g_input1_len > 0) {
                g_input1_len -= 1;
            } else if (id == ID_INPUT2 and g_input2_len > 0) {
                g_input2_len -= 1;
            }
        }
    }
}

fn handleSliderDrag() void {
    if (g_mouse_down) {
        for (g_hitboxes[0..g_hitbox_count]) |hb| {
            if (hb.id == ID_SLIDER1 and hb.bounds.contains(g_mouse_pos)) {
                g_slider_value = std.math.clamp((g_mouse_pos.x - hb.bounds.origin.x) / hb.bounds.size.width, 0, 1);
            }
            if (hb.id == ID_SLIDER2 and hb.bounds.contains(g_mouse_pos)) {
                g_slider2_value = std.math.clamp((g_mouse_pos.x - hb.bounds.origin.x) / hb.bounds.size.width, 0, 1);
            }
        }
    }
}

// ============================================================================
// Main
// ============================================================================

pub fn main() !void {
    zglfw.init() catch return;
    defer zglfw.terminate();

    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);

    const win = zglfw.Window.create(900, 650, "ZapUI Playground", null, null) catch return;
    defer win.destroy();
    zglfw.makeContextCurrent(win);
    zglfw.swapInterval(1);

    // Set callbacks
    _ = win.setCursorPosCallback(struct {
        fn cb(_: *zglfw.Window, x: f64, y: f64) callconv(.c) void {
            g_mouse_pos = .{ .x = @floatCast(x), .y = @floatCast(y) };
            handleSliderDrag();
        }
    }.cb);

    _ = win.setMouseButtonCallback(struct {
        fn cb(_: *zglfw.Window, button: zglfw.MouseButton, action: zglfw.Action, _: zglfw.Mods) callconv(.c) void {
            if (button == .left) {
                if (action == .press) { g_mouse_down = true; handleClick(); }
                else if (action == .release) { g_mouse_down = false; }
            }
        }
    }.cb);

    _ = win.setCharCallback(struct {
        fn cb(_: *zglfw.Window, codepoint: u32) callconv(.c) void {
            handleCharInput(@intCast(codepoint));
        }
    }.cb);

    _ = win.setKeyCallback(struct {
        fn cb(_: *zglfw.Window, key: zglfw.Key, _: i32, action: zglfw.Action, _: zglfw.Mods) callconv(.c) void {
            if (action == .press or action == .repeat) {
                handleKeyInput(key);
            }
        }
    }.cb);

    // Load OpenGL functions
    zapui.renderer.gl.loadGlFunctions(zglfw.getProcAddress) catch {
        std.debug.print("Failed to load OpenGL functions\n", .{});
        return;
    };

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

    while (!win.shouldClose()) {
        zglfw.pollEvents();
        
        // Update cursor blink
        g_cursor_blink +%= 1;

        const fb_size = win.getFramebufferSize();
        const width: Pixels = @floatFromInt(fb_size[0]);
        const height: Pixels = @floatFromInt(fb_size[1]);

        renderer.setViewport(width, height, 1.0);
        renderer.clear(C.bg_dark);

        var scene = Scene.init(allocator);
        defer scene.deinit();

        var tree = zaffy.Zaffy.init(allocator);
        defer tree.deinit();

        buildUI(&tree, &scene, &text_system, width, height) catch {};

        renderer.drawScene(&scene) catch {};

        win.swapBuffers();
    }
}

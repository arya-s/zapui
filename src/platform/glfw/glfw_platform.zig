//! GLFW-based platform implementation
//!
//! This backend uses GLFW for cross-platform windowing and OpenGL for rendering.
//! It's the default backend for Linux, macOS, and can be used on Windows as well.

const std = @import("std");
const zglfw = @import("zglfw");
const platform = @import("../platform.zig");

pub const Platform = struct {
    initialized: bool,

    pub fn deinit(self: *Platform) void {
        if (self.initialized) {
            zglfw.terminate();
            self.initialized = false;
        }
    }
};

pub const Window = struct {
    handle: *zglfw.Window,
    event_queue: std.ArrayList(platform.Event),
    allocator: std.mem.Allocator,

    pub fn shouldClose(self: *Window) bool {
        return self.handle.shouldClose();
    }

    pub fn pollEvents(self: *Window) []platform.Event {
        zglfw.pollEvents();
        defer self.event_queue.clearRetainingCapacity();
        return self.event_queue.items;
    }

    pub fn swapBuffers(self: *Window) void {
        self.handle.swapBuffers();
    }

    pub fn getFramebufferSize(self: *Window) struct { width: u32, height: u32 } {
        const size = self.handle.getFramebufferSize();
        return .{
            .width = @intCast(size[0]),
            .height = @intCast(size[1]),
        };
    }

    pub fn getKey(self: *Window, key: platform.Key) platform.Action {
        const glfw_key = keyToGlfw(key);
        const state = self.handle.getKey(glfw_key);
        return switch (state) {
            .press => .press,
            .release => .release,
            .repeat => .repeat,
        };
    }

    pub fn makeContextCurrent(self: *Window) void {
        zglfw.makeContextCurrent(self.handle);
    }

    pub fn destroy(self: *Window) void {
        self.handle.destroy();
        self.event_queue.deinit();
    }
};

pub fn init() !Platform {
    zglfw.init() catch |err| {
        std.debug.print("Failed to initialize GLFW: {}\n", .{err});
        return err;
    };

    return Platform{ .initialized = true };
}

pub fn createWindow(plat: *Platform, config: platform.WindowConfig) !Window {
    _ = plat;

    // Set window hints
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.resizable, config.resizable);
    zglfw.windowHint(.decorated, config.decorated);

    const handle = zglfw.Window.create(
        @intCast(config.width),
        @intCast(config.height),
        config.title,
        null,
        null,
    ) catch |err| {
        std.debug.print("Failed to create window: {}\n", .{err});
        return err;
    };

    zglfw.makeContextCurrent(handle);

    if (config.vsync) {
        zglfw.swapInterval(1);
    } else {
        zglfw.swapInterval(0);
    }

    var window = Window{
        .handle = handle,
        .event_queue = std.ArrayList(platform.Event).init(std.heap.page_allocator),
        .allocator = std.heap.page_allocator,
    };

    // Set up callbacks
    _ = handle.setKeyCallback(keyCallback);
    _ = handle.setMouseButtonCallback(mouseButtonCallback);
    _ = handle.setCursorPosCallback(cursorPosCallback);
    _ = handle.setScrollCallback(scrollCallback);
    _ = handle.setFramebufferSizeCallback(framebufferSizeCallback);

    // Store window pointer for callbacks
    handle.setUserPointer(&window);

    return window;
}

fn keyCallback(window: *zglfw.Window, key: zglfw.Key, scancode: i32, action: zglfw.Action, mods: zglfw.Mods) void {
    _ = scancode;
    const win = getWindowFromHandle(window) orelse return;

    win.event_queue.append(.{
        .key = .{
            .key = glfwToKey(key),
            .action = glfwToAction(action),
            .mods = glfwToMods(mods),
        },
    }) catch {};
}

fn mouseButtonCallback(window: *zglfw.Window, button: zglfw.MouseButton, action: zglfw.Action, mods: zglfw.Mods) void {
    const win = getWindowFromHandle(window) orelse return;

    win.event_queue.append(.{
        .mouse_button = .{
            .button = @enumFromInt(@intFromEnum(button)),
            .action = glfwToAction(action),
            .mods = glfwToMods(mods),
        },
    }) catch {};
}

fn cursorPosCallback(window: *zglfw.Window, xpos: f64, ypos: f64) void {
    const win = getWindowFromHandle(window) orelse return;

    win.event_queue.append(.{
        .cursor_pos = .{ .x = xpos, .y = ypos },
    }) catch {};
}

fn scrollCallback(window: *zglfw.Window, xoffset: f64, yoffset: f64) void {
    const win = getWindowFromHandle(window) orelse return;

    win.event_queue.append(.{
        .scroll = .{ .x = xoffset, .y = yoffset },
    }) catch {};
}

fn framebufferSizeCallback(window: *zglfw.Window, width: i32, height: i32) void {
    const win = getWindowFromHandle(window) orelse return;

    win.event_queue.append(.{
        .resize = .{
            .width = @intCast(width),
            .height = @intCast(height),
        },
    }) catch {};
}

fn getWindowFromHandle(handle: *zglfw.Window) ?*Window {
    return @ptrCast(@alignCast(handle.getUserPointer()));
}

fn glfwToAction(action: zglfw.Action) platform.Action {
    return switch (action) {
        .press => .press,
        .release => .release,
        .repeat => .repeat,
    };
}

fn glfwToMods(mods: zglfw.Mods) platform.Mods {
    return .{
        .shift = mods.shift,
        .control = mods.control,
        .alt = mods.alt,
        .super = mods.super,
        .caps_lock = mods.caps_lock,
        .num_lock = mods.num_lock,
    };
}

fn glfwToKey(key: zglfw.Key) platform.Key {
    return switch (key) {
        .space => .space,
        .apostrophe => .apostrophe,
        .comma => .comma,
        .minus => .minus,
        .period => .period,
        .slash => .slash,
        .zero => .@"0",
        .one => .@"1",
        .two => .@"2",
        .three => .@"3",
        .four => .@"4",
        .five => .@"5",
        .six => .@"6",
        .seven => .@"7",
        .eight => .@"8",
        .nine => .@"9",
        .semicolon => .semicolon,
        .equal => .equal,
        .a => .a,
        .b => .b,
        .c => .c,
        .d => .d,
        .e => .e,
        .f => .f,
        .g => .g,
        .h => .h,
        .i => .i,
        .j => .j,
        .k => .k,
        .l => .l,
        .m => .m,
        .n => .n,
        .o => .o,
        .p => .p,
        .q => .q,
        .r => .r,
        .s => .s,
        .t => .t,
        .u => .u,
        .v => .v,
        .w => .w,
        .x => .x,
        .y => .y,
        .z => .z,
        .left_bracket => .left_bracket,
        .backslash => .backslash,
        .right_bracket => .right_bracket,
        .grave_accent => .grave_accent,
        .escape => .escape,
        .enter => .enter,
        .tab => .tab,
        .backspace => .backspace,
        .insert => .insert,
        .delete => .delete,
        .right => .right,
        .left => .left,
        .down => .down,
        .up => .up,
        .page_up => .page_up,
        .page_down => .page_down,
        .home => .home,
        .end => .end,
        .caps_lock => .caps_lock,
        .scroll_lock => .scroll_lock,
        .num_lock => .num_lock,
        .print_screen => .print_screen,
        .pause => .pause,
        .F1 => .f1,
        .F2 => .f2,
        .F3 => .f3,
        .F4 => .f4,
        .F5 => .f5,
        .F6 => .f6,
        .F7 => .f7,
        .F8 => .f8,
        .F9 => .f9,
        .F10 => .f10,
        .F11 => .f11,
        .F12 => .f12,
        .left_shift => .left_shift,
        .left_control => .left_control,
        .left_alt => .left_alt,
        .left_super => .left_super,
        .right_shift => .right_shift,
        .right_control => .right_control,
        .right_alt => .right_alt,
        .right_super => .right_super,
        .menu => .menu,
        else => .unknown,
    };
}

fn keyToGlfw(key: platform.Key) zglfw.Key {
    return switch (key) {
        .space => .space,
        .apostrophe => .apostrophe,
        .comma => .comma,
        .minus => .minus,
        .period => .period,
        .slash => .slash,
        .@"0" => .zero,
        .@"1" => .one,
        .@"2" => .two,
        .@"3" => .three,
        .@"4" => .four,
        .@"5" => .five,
        .@"6" => .six,
        .@"7" => .seven,
        .@"8" => .eight,
        .@"9" => .nine,
        .semicolon => .semicolon,
        .equal => .equal,
        .a => .a,
        .b => .b,
        .c => .c,
        .d => .d,
        .e => .e,
        .f => .f,
        .g => .g,
        .h => .h,
        .i => .i,
        .j => .j,
        .k => .k,
        .l => .l,
        .m => .m,
        .n => .n,
        .o => .o,
        .p => .p,
        .q => .q,
        .r => .r,
        .s => .s,
        .t => .t,
        .u => .u,
        .v => .v,
        .w => .w,
        .x => .x,
        .y => .y,
        .z => .z,
        .left_bracket => .left_bracket,
        .backslash => .backslash,
        .right_bracket => .right_bracket,
        .grave_accent => .grave_accent,
        .escape => .escape,
        .enter => .enter,
        .tab => .tab,
        .backspace => .backspace,
        .insert => .insert,
        .delete => .delete,
        .right => .right,
        .left => .left,
        .down => .down,
        .up => .up,
        .page_up => .page_up,
        .page_down => .page_down,
        .home => .home,
        .end => .end,
        .caps_lock => .caps_lock,
        .scroll_lock => .scroll_lock,
        .num_lock => .num_lock,
        .print_screen => .print_screen,
        .pause => .pause,
        .f1 => .F1,
        .f2 => .F2,
        .f3 => .F3,
        .f4 => .F4,
        .f5 => .F5,
        .f6 => .F6,
        .f7 => .F7,
        .f8 => .F8,
        .f9 => .F9,
        .f10 => .F10,
        .f11 => .F11,
        .f12 => .F12,
        .left_shift => .left_shift,
        .left_control => .left_control,
        .left_alt => .left_alt,
        .left_super => .left_super,
        .right_shift => .right_shift,
        .right_control => .right_control,
        .right_alt => .right_alt,
        .right_super => .right_super,
        .menu => .menu,
        else => .unknown,
    };
}

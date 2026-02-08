//! Platform abstraction layer for windowing and input
//!
//! This module provides a unified interface for platform-specific functionality:
//! - Window creation and management
//! - Input handling (keyboard, mouse)
//! - OpenGL/DirectX context management
//!
//! Backends:
//! - GLFW (Linux, macOS, Windows fallback)
//! - Win32 + DirectX (Windows native)

const std = @import("std");
const builtin = @import("builtin");

/// Platform-specific implementation
pub const Backend = if (builtin.os.tag == .windows and @import("build_options").use_win32)
    @import("windows/win32_platform.zig")
else
    @import("glfw/glfw_platform.zig");

/// Window handle
pub const Window = Backend.Window;

/// Platform context
pub const Platform = Backend.Platform;

/// Key codes (unified across platforms)
pub const Key = enum(u32) {
    unknown = 0,

    // Printable keys
    space = 32,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    left_bracket = 91,
    backslash = 92,
    right_bracket = 93,
    grave_accent = 96,

    // Function keys
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,

    // Modifier keys
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    menu = 348,

    _,
};

/// Key action
pub const Action = enum {
    release,
    press,
    repeat,
};

/// Mouse button
pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
    button_4 = 3,
    button_5 = 4,
    button_6 = 5,
    button_7 = 6,
    button_8 = 7,
    _,
};

/// Window configuration
pub const WindowConfig = struct {
    width: u32 = 800,
    height: u32 = 600,
    title: [:0]const u8 = "ZapUI",
    resizable: bool = true,
    decorated: bool = true,
    transparent: bool = false,
    vsync: bool = true,
};

/// Event types
pub const Event = union(enum) {
    key: struct {
        key: Key,
        action: Action,
        mods: Mods,
    },
    mouse_button: struct {
        button: MouseButton,
        action: Action,
        mods: Mods,
    },
    cursor_pos: struct {
        x: f64,
        y: f64,
    },
    scroll: struct {
        x: f64,
        y: f64,
    },
    resize: struct {
        width: u32,
        height: u32,
    },
    close: void,
    focus: bool,
};

/// Modifier keys
pub const Mods = packed struct {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
    _padding: u2 = 0,
};

/// Initialize the platform
pub fn init() !Platform {
    return Backend.init();
}

/// Create a window
pub fn createWindow(platform: *Platform, config: WindowConfig) !Window {
    return Backend.createWindow(platform, config);
}

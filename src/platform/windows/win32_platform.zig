//! Win32 + DirectX 11 platform implementation
//!
//! Native Windows windowing and D3D11 rendering backend.

const std = @import("std");
const platform = @import("../platform.zig");

// Import win32 bindings
const win32 = @import("win32");
const wam = win32.ui.windows_and_messaging;
const foundation = win32.foundation;
const gdi = win32.graphics.gdi;
const input = win32.ui.input.keyboard_and_mouse;
const lib_loader = win32.system.library_loader;

const HWND = foundation.HWND;
const HINSTANCE = foundation.HINSTANCE;
const LPARAM = foundation.LPARAM;
const WPARAM = foundation.WPARAM;
const LRESULT = foundation.LRESULT;
const RECT = foundation.RECT;

pub const Platform = struct {
    hinstance: HINSTANCE,

    pub fn deinit(_: *Platform) void {
        // Nothing to clean up
    }
};

pub const Window = struct {
    hwnd: ?HWND,
    event_queue: std.ArrayListUnmanaged(platform.Event),
    allocator: std.mem.Allocator,
    should_close: bool,
    width: u32,
    height: u32,

    pub fn shouldClose(self: *Window) bool {
        return self.should_close;
    }

    pub fn pollEvents(self: *Window) []platform.Event {
        var msg: wam.MSG = undefined;
        while (wam.PeekMessageA(&msg, self.hwnd, 0, 0, wam.PM_REMOVE) != 0) {
            _ = wam.TranslateMessage(&msg);
            _ = wam.DispatchMessageA(&msg);
        }

        defer self.event_queue.clearRetainingCapacity();
        return self.event_queue.items;
    }

    pub fn swapBuffers(_: *Window) void {
        // D3D11 uses Present() instead
    }

    pub fn getFramebufferSize(self: *Window) struct { width: u32, height: u32 } {
        return .{ .width = self.width, .height = self.height };
    }

    pub fn getKey(_: *Window, _: platform.Key) platform.Action {
        // TODO: implement key state tracking
        return .release;
    }

    pub fn makeContextCurrent(_: *Window) void {
        // D3D11 context is per-device, not per-window
    }

    pub fn destroy(self: *Window) void {
        if (self.hwnd) |hwnd| {
            _ = wam.DestroyWindow(hwnd);
        }
        self.event_queue.deinit(self.allocator);
    }

    fn appendEvent(self: *Window, event: platform.Event) void {
        self.event_queue.append(self.allocator, event) catch {};
    }
};

// Thread-local storage for window creation (needed during CreateWindowEx)
threadlocal var g_creating_window: ?*Window = null;

pub fn init() !Platform {
    const hinstance = lib_loader.GetModuleHandleA(null) orelse
        return error.FailedToGetModuleHandle;

    // Register window class
    const wc = wam.WNDCLASSEXA{
        .cbSize = @sizeOf(wam.WNDCLASSEXA),
        .style = wam.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1, .OWNDC = 1 },
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = @sizeOf(usize), // Space for window pointer
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = wam.LoadCursorA(null, @ptrFromInt(32512)), // IDC_ARROW
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "ZapUIWindowClass",
        .hIconSm = null,
    };

    if (wam.RegisterClassExA(&wc) == 0) {
        return error.FailedToRegisterWindowClass;
    }

    return Platform{ .hinstance = hinstance };
}

pub fn createWindow(plat: *Platform, config: platform.WindowConfig) !*Window {
    const allocator = std.heap.page_allocator;

    // Allocate window on heap so the pointer stays valid
    const window = try allocator.create(Window);
    window.* = Window{
        .hwnd = null,
        .event_queue = .{},
        .allocator = allocator,
        .should_close = false,
        .width = config.width,
        .height = config.height,
    };

    // Calculate window size to get desired client area
    var rect = RECT{
        .left = 0,
        .top = 0,
        .right = @intCast(config.width),
        .bottom = @intCast(config.height),
    };

    const style: wam.WINDOW_STYLE = if (config.decorated)
        wam.WS_OVERLAPPEDWINDOW
    else
        wam.WS_POPUP;

    _ = wam.AdjustWindowRect(&rect, style, 0); // FALSE

    const window_width = rect.right - rect.left;
    const window_height = rect.bottom - rect.top;

    // Store pointer for WndProc to pick up during WM_NCCREATE
    g_creating_window = window;
    defer g_creating_window = null;

    const hwnd = wam.CreateWindowExA(
        .{}, // dwExStyle
        "ZapUIWindowClass",
        config.title.ptr,
        style,
        wam.CW_USEDEFAULT,
        wam.CW_USEDEFAULT,
        window_width,
        window_height,
        null,
        null,
        plat.hinstance,
        null,
    ) orelse {
        allocator.destroy(window);
        return error.FailedToCreateWindow;
    };

    window.hwnd = hwnd;

    _ = wam.ShowWindow(hwnd, wam.SW_SHOW);
    _ = gdi.UpdateWindow(hwnd);

    return window;
}

fn getWindowPtr(hwnd: HWND) ?*Window {
    const ptr = wam.GetWindowLongPtrA(hwnd, wam.GWLP_USERDATA);
    if (ptr == 0) return null;
    return @ptrFromInt(@as(usize, @bitCast(ptr)));
}

fn setWindowPtr(hwnd: HWND, window: *Window) void {
    _ = wam.SetWindowLongPtrA(hwnd, wam.GWLP_USERDATA, @bitCast(@intFromPtr(window)));
}

fn windowProc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    // During creation, store the window pointer
    if (msg == wam.WM_NCCREATE) {
        if (g_creating_window) |win| {
            setWindowPtr(hwnd, win);
        }
        return wam.DefWindowProcA(hwnd, msg, wparam, lparam);
    }

    const window = getWindowPtr(hwnd) orelse {
        return wam.DefWindowProcA(hwnd, msg, wparam, lparam);
    };

    switch (msg) {
        wam.WM_CLOSE => {
            window.should_close = true;
            window.appendEvent(.{ .close = {} });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_DESTROY => {
            wam.PostQuitMessage(0);
            return @bitCast(@as(isize, 0));
        },
        wam.WM_SIZE => {
            const lparam_uint: usize = @bitCast(lparam);
            const width: u32 = @intCast(lparam_uint & 0xFFFF);
            const height: u32 = @intCast((lparam_uint >> 16) & 0xFFFF);
            window.width = width;
            window.height = height;
            window.appendEvent(.{ .resize = .{ .width = width, .height = height } });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_KEYDOWN, wam.WM_SYSKEYDOWN => {
            const key = vkeyToKey(@intCast(@as(usize, @bitCast(wparam))));
            const lparam_uint: usize = @bitCast(lparam);
            const repeat = (lparam_uint & 0x40000000) != 0;
            window.appendEvent(.{
                .key = .{
                    .key = key,
                    .action = if (repeat) .repeat else .press,
                    .mods = getKeyMods(),
                },
            });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_KEYUP, wam.WM_SYSKEYUP => {
            const key = vkeyToKey(@intCast(@as(usize, @bitCast(wparam))));
            window.appendEvent(.{
                .key = .{
                    .key = key,
                    .action = .release,
                    .mods = getKeyMods(),
                },
            });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_MOUSEMOVE => {
            const lparam_uint: usize = @bitCast(lparam);
            const x: i16 = @bitCast(@as(u16, @truncate(lparam_uint)));
            const y: i16 = @bitCast(@as(u16, @truncate(lparam_uint >> 16)));
            window.appendEvent(.{
                .cursor_pos = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
            });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_LBUTTONDOWN, wam.WM_RBUTTONDOWN, wam.WM_MBUTTONDOWN => {
            const button: platform.MouseButton = switch (msg) {
                wam.WM_LBUTTONDOWN => .left,
                wam.WM_RBUTTONDOWN => .right,
                wam.WM_MBUTTONDOWN => .middle,
                else => .left,
            };
            window.appendEvent(.{
                .mouse_button = .{
                    .button = button,
                    .action = .press,
                    .mods = getKeyMods(),
                },
            });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_LBUTTONUP, wam.WM_RBUTTONUP, wam.WM_MBUTTONUP => {
            const button: platform.MouseButton = switch (msg) {
                wam.WM_LBUTTONUP => .left,
                wam.WM_RBUTTONUP => .right,
                wam.WM_MBUTTONUP => .middle,
                else => .left,
            };
            window.appendEvent(.{
                .mouse_button = .{
                    .button = button,
                    .action = .release,
                    .mods = getKeyMods(),
                },
            });
            return @bitCast(@as(isize, 0));
        },
        wam.WM_MOUSEWHEEL => {
            const wparam_uint: usize = @bitCast(wparam);
            const delta: i16 = @bitCast(@as(u16, @truncate(wparam_uint >> 16)));
            window.appendEvent(.{
                .scroll = .{ .x = 0, .y = @as(f64, @floatFromInt(delta)) / 120.0 },
            });
            return @bitCast(@as(isize, 0));
        },
        else => {},
    }

    return wam.DefWindowProcA(hwnd, msg, wparam, lparam);
}

fn getKeyMods() platform.Mods {
    // GetKeyState returns i16, high bit (0x8000) indicates key is down
    const shift_state: u16 = @bitCast(input.GetKeyState(@intFromEnum(input.VK_SHIFT)));
    const ctrl_state: u16 = @bitCast(input.GetKeyState(@intFromEnum(input.VK_CONTROL)));
    const alt_state: u16 = @bitCast(input.GetKeyState(@intFromEnum(input.VK_MENU)));
    const lwin_state: u16 = @bitCast(input.GetKeyState(@intFromEnum(input.VK_LWIN)));
    const rwin_state: u16 = @bitCast(input.GetKeyState(@intFromEnum(input.VK_RWIN)));

    return .{
        .shift = (shift_state & 0x8000) != 0,
        .control = (ctrl_state & 0x8000) != 0,
        .alt = (alt_state & 0x8000) != 0,
        .super = (lwin_state & 0x8000) != 0 or (rwin_state & 0x8000) != 0,
    };
}

fn vkeyToKey(vkey: u32) platform.Key {
    return switch (vkey) {
        0x1B => .escape, // VK_ESCAPE
        0x0D => .enter, // VK_RETURN
        0x09 => .tab, // VK_TAB
        0x08 => .backspace, // VK_BACK
        0x2D => .insert, // VK_INSERT
        0x2E => .delete, // VK_DELETE
        0x27 => .right, // VK_RIGHT
        0x25 => .left, // VK_LEFT
        0x28 => .down, // VK_DOWN
        0x26 => .up, // VK_UP
        0x21 => .page_up, // VK_PRIOR
        0x22 => .page_down, // VK_NEXT
        0x24 => .home, // VK_HOME
        0x23 => .end, // VK_END
        0x14 => .caps_lock, // VK_CAPITAL
        0x91 => .scroll_lock, // VK_SCROLL
        0x90 => .num_lock, // VK_NUMLOCK
        0x2C => .print_screen, // VK_SNAPSHOT
        0x13 => .pause, // VK_PAUSE
        0x70 => .f1,
        0x71 => .f2,
        0x72 => .f3,
        0x73 => .f4,
        0x74 => .f5,
        0x75 => .f6,
        0x76 => .f7,
        0x77 => .f8,
        0x78 => .f9,
        0x79 => .f10,
        0x7A => .f11,
        0x7B => .f12,
        0xA0 => .left_shift, // VK_LSHIFT
        0xA1 => .right_shift, // VK_RSHIFT
        0xA2 => .left_control, // VK_LCONTROL
        0xA3 => .right_control, // VK_RCONTROL
        0xA4 => .left_alt, // VK_LMENU
        0xA5 => .right_alt, // VK_RMENU
        0x5B => .left_super, // VK_LWIN
        0x5C => .right_super, // VK_RWIN
        0x20 => .space, // VK_SPACE
        // Letters A-Z (0x41-0x5A)
        0x41 => .a,
        0x42 => .b,
        0x43 => .c,
        0x44 => .d,
        0x45 => .e,
        0x46 => .f,
        0x47 => .g,
        0x48 => .h,
        0x49 => .i,
        0x4A => .j,
        0x4B => .k,
        0x4C => .l,
        0x4D => .m,
        0x4E => .n,
        0x4F => .o,
        0x50 => .p,
        0x51 => .q,
        0x52 => .r,
        0x53 => .s,
        0x54 => .t,
        0x55 => .u,
        0x56 => .v,
        0x57 => .w,
        0x58 => .x,
        0x59 => .y,
        0x5A => .z,
        // Numbers 0-9 (0x30-0x39)
        0x30 => .@"0",
        0x31 => .@"1",
        0x32 => .@"2",
        0x33 => .@"3",
        0x34 => .@"4",
        0x35 => .@"5",
        0x36 => .@"6",
        0x37 => .@"7",
        0x38 => .@"8",
        0x39 => .@"9",
        else => .unknown,
    };
}

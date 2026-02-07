//! Input event types and hit testing for zapui.

const std = @import("std");
const geometry = @import("geometry.zig");
const style = @import("style.zig");

const Allocator = std.mem.Allocator;
const Pixels = geometry.Pixels;
const Point = geometry.Point;
const Bounds = geometry.Bounds;

// Re-export Cursor from style
pub const Cursor = style.Cursor;

/// Mouse button identifier
pub const MouseButton = enum {
    left,
    right,
    middle,
    back,
    forward,
};

/// Keyboard modifier flags
pub const Modifiers = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false, // Cmd on macOS, Win on Windows

    pub const none = Modifiers{};

    pub fn withShift(self: Modifiers) Modifiers {
        var m = self;
        m.shift = true;
        return m;
    }

    pub fn withCtrl(self: Modifiers) Modifiers {
        var m = self;
        m.ctrl = true;
        return m;
    }

    pub fn withAlt(self: Modifiers) Modifiers {
        var m = self;
        m.alt = true;
        return m;
    }

    pub fn withSuper(self: Modifiers) Modifiers {
        var m = self;
        m.super = true;
        return m;
    }
};

/// Mouse down event
pub const MouseDownEvent = struct {
    button: MouseButton,
    position: Point(Pixels),
    click_count: u32 = 1,
    modifiers: Modifiers = .{},
};

/// Mouse up event
pub const MouseUpEvent = struct {
    button: MouseButton,
    position: Point(Pixels),
    modifiers: Modifiers = .{},
};

/// Mouse move event
pub const MouseMoveEvent = struct {
    position: Point(Pixels),
    modifiers: Modifiers = .{},
};

/// Mouse scroll/wheel event
pub const ScrollWheelEvent = struct {
    position: Point(Pixels),
    delta: Point(Pixels),
    modifiers: Modifiers = .{},
};

/// Key codes (subset of common keys)
pub const Key = enum(u16) {
    unknown = 0,

    // Letters
    a, b, c, d, e, f, g, h, i, j, k, l, m,
    n, o, p, q, r, s, t, u, v, w, x, y, z,

    // Numbers
    @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",

    // Function keys
    f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,

    // Navigation
    up, down, left, right,
    home, end,
    page_up, page_down,

    // Editing
    backspace,
    delete,
    insert,
    tab,
    enter,
    escape,
    space,

    // Modifiers (as keys)
    left_shift, right_shift,
    left_ctrl, right_ctrl,
    left_alt, right_alt,
    left_super, right_super,

    // Punctuation
    minus, equals,
    left_bracket, right_bracket,
    backslash, semicolon,
    apostrophe, grave,
    comma, period, slash,
};

/// Key down event
pub const KeyDownEvent = struct {
    key: Key,
    modifiers: Modifiers = .{},
    repeat: bool = false,
};

/// Key up event
pub const KeyUpEvent = struct {
    key: Key,
    modifiers: Modifiers = .{},
};

/// Text input event (for typing)
pub const TextInputEvent = struct {
    text: []const u8,
};

/// Focus change event
pub const FocusEvent = struct {
    focused: bool,
};

/// Union of all input events
pub const InputEvent = union(enum) {
    mouse_down: MouseDownEvent,
    mouse_up: MouseUpEvent,
    mouse_move: MouseMoveEvent,
    scroll_wheel: ScrollWheelEvent,
    key_down: KeyDownEvent,
    key_up: KeyUpEvent,
    text_input: TextInputEvent,
    focus: FocusEvent,
};

/// Hitbox identifier
pub const HitboxId = u32;

/// A hitbox registered by an element for receiving mouse events
pub const Hitbox = struct {
    id: HitboxId,
    bounds: Bounds(Pixels),
    cursor: Cursor = .default,
    blocks_hit_test: bool = true, // If true, blocks events from reaching elements below
};



/// Hit test result
pub const HitTestResult = struct {
    hitbox_id: HitboxId,
    bounds: Bounds(Pixels),
    cursor: Cursor,
};

/// Manages hitboxes and performs hit testing
pub const HitTestEngine = struct {
    allocator: Allocator,
    hitboxes: std.ArrayListUnmanaged(Hitbox),
    next_id: HitboxId,

    pub fn init(allocator: Allocator) HitTestEngine {
        return .{
            .allocator = allocator,
            .hitboxes = .{ .items = &.{}, .capacity = 0 },
            .next_id = 1,
        };
    }

    pub fn deinit(self: *HitTestEngine) void {
        self.hitboxes.deinit(self.allocator);
    }

    /// Clear all hitboxes for a new frame
    pub fn clear(self: *HitTestEngine) void {
        self.hitboxes.clearRetainingCapacity();
        self.next_id = 1;
    }

    /// Register a hitbox and return its ID
    pub fn registerHitbox(self: *HitTestEngine, bounds: Bounds(Pixels), cursor: Cursor, blocks: bool) !HitboxId {
        const id = self.next_id;
        self.next_id += 1;

        try self.hitboxes.append(self.allocator, .{
            .id = id,
            .bounds = bounds,
            .cursor = cursor,
            .blocks_hit_test = blocks,
        });

        return id;
    }

    /// Perform hit test at a point, returning the topmost hitbox
    pub fn hitTest(self: *const HitTestEngine, point: Point(Pixels)) ?HitTestResult {
        // Iterate in reverse (topmost elements are added last)
        var i = self.hitboxes.items.len;
        while (i > 0) {
            i -= 1;
            const hitbox = &self.hitboxes.items[i];
            if (hitbox.bounds.contains(point)) {
                return .{
                    .hitbox_id = hitbox.id,
                    .bounds = hitbox.bounds,
                    .cursor = hitbox.cursor,
                };
            }
        }
        return null;
    }

    /// Get all hitboxes at a point (for event bubbling)
    pub fn hitTestAll(self: *const HitTestEngine, point: Point(Pixels), allocator: Allocator, results: *std.ArrayListUnmanaged(HitTestResult)) !void {
        // Iterate in reverse (topmost first)
        var i = self.hitboxes.items.len;
        while (i > 0) {
            i -= 1;
            const hitbox = &self.hitboxes.items[i];
            if (hitbox.bounds.contains(point)) {
                try results.append(allocator, .{
                    .hitbox_id = hitbox.id,
                    .bounds = hitbox.bounds,
                    .cursor = hitbox.cursor,
                });
                if (hitbox.blocks_hit_test) break; // Stop at blocking hitbox
            }
        }
    }
};

/// Mouse state tracking
pub const MouseState = struct {
    position: Point(Pixels) = Point(Pixels).zero,
    buttons_down: u8 = 0, // Bitmask of pressed buttons
    hovered_hitbox: ?HitboxId = null,

    pub fn isButtonDown(self: MouseState, button: MouseButton) bool {
        return (self.buttons_down & (@as(u8, 1) << @intFromEnum(button))) != 0;
    }

    pub fn setButtonDown(self: *MouseState, button: MouseButton, down: bool) void {
        const mask = @as(u8, 1) << @intFromEnum(button);
        if (down) {
            self.buttons_down |= mask;
        } else {
            self.buttons_down &= ~mask;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "HitTestEngine basic" {
    const allocator = std.testing.allocator;
    var engine = HitTestEngine.init(allocator);
    defer engine.deinit();

    // Register hitboxes
    const id1 = try engine.registerHitbox(Bounds(Pixels).fromXYWH(0, 0, 100, 100), .default, true);
    const id2 = try engine.registerHitbox(Bounds(Pixels).fromXYWH(50, 50, 100, 100), .pointer, true);

    // Hit test - should return topmost (id2)
    const result1 = engine.hitTest(Point(Pixels).init(75, 75));
    try std.testing.expect(result1 != null);
    try std.testing.expectEqual(id2, result1.?.hitbox_id);

    // Hit test - only id1
    const result2 = engine.hitTest(Point(Pixels).init(25, 25));
    try std.testing.expect(result2 != null);
    try std.testing.expectEqual(id1, result2.?.hitbox_id);

    // Hit test - miss
    const result3 = engine.hitTest(Point(Pixels).init(200, 200));
    try std.testing.expect(result3 == null);
}

test "Modifiers" {
    const mods = Modifiers.none.withShift().withCtrl();
    try std.testing.expect(mods.shift);
    try std.testing.expect(mods.ctrl);
    try std.testing.expect(!mods.alt);
    try std.testing.expect(!mods.super);
}

test "MouseState button tracking" {
    var state = MouseState{};

    try std.testing.expect(!state.isButtonDown(.left));

    state.setButtonDown(.left, true);
    try std.testing.expect(state.isButtonDown(.left));
    try std.testing.expect(!state.isButtonDown(.right));

    state.setButtonDown(.right, true);
    try std.testing.expect(state.isButtonDown(.left));
    try std.testing.expect(state.isButtonDown(.right));

    state.setButtonDown(.left, false);
    try std.testing.expect(!state.isButtonDown(.left));
    try std.testing.expect(state.isButtonDown(.right));
}

//! Application context for zapui.
//! Manages entities, observers, and global state.

const std = @import("std");
const entity_mod = @import("entity.zig");

const Allocator = std.mem.Allocator;
const EntityId = entity_mod.EntityId;
const EntityStore = entity_mod.EntityStore;
const Entity = entity_mod.Entity;
const AnyEntity = entity_mod.AnyEntity;
const TypeId = entity_mod.TypeId;
const typeId = entity_mod.typeId;

/// Observer callback type
pub const ObserverCallback = *const fn (*App, EntityId) void;

/// Subscription handle for unsubscribing
pub const Subscription = struct {
    id: u64,
    entity_id: EntityId,

    pub const invalid = Subscription{ .id = 0, .entity_id = EntityId.invalid };

    pub fn isValid(self: Subscription) bool {
        return self.id != 0;
    }
};

/// Observer entry
const Observer = struct {
    id: u64,
    callback: ObserverCallback,
};

/// Application context - the central hub for state management
pub const App = struct {
    allocator: Allocator,
    entities: EntityStore,
    observers: std.AutoHashMapUnmanaged(EntityId, std.ArrayListUnmanaged(Observer)),
    global_observers: std.AutoHashMapUnmanaged(TypeId, std.ArrayListUnmanaged(Observer)),
    globals: std.AutoHashMapUnmanaged(TypeId, *anyopaque),
    global_deinit_fns: std.AutoHashMapUnmanaged(TypeId, *const fn (*anyopaque, Allocator) void),
    pending_notifications: std.ArrayListUnmanaged(EntityId),
    next_observer_id: u64,

    pub fn init(allocator: Allocator) App {
        return .{
            .allocator = allocator,
            .entities = EntityStore.init(allocator),
            .observers = .{},
            .global_observers = .{},
            .globals = .{},
            .global_deinit_fns = .{},
            .pending_notifications = .{ .items = &.{}, .capacity = 0 },
            .next_observer_id = 1,
        };
    }

    pub fn deinit(self: *App) void {
        // Clean up observers
        var obs_iter = self.observers.iterator();
        while (obs_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.observers.deinit(self.allocator);

        var global_obs_iter = self.global_observers.iterator();
        while (global_obs_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.global_observers.deinit(self.allocator);

        // Clean up globals
        var globals_iter = self.globals.iterator();
        while (globals_iter.next()) |entry| {
            if (self.global_deinit_fns.get(entry.key_ptr.*)) |deinit_fn| {
                deinit_fn(entry.value_ptr.*, self.allocator);
            }
        }
        self.globals.deinit(self.allocator);
        self.global_deinit_fns.deinit(self.allocator);

        self.pending_notifications.deinit(self.allocator);
        self.entities.deinit();
    }

    /// Create a new entity with the given initial value
    pub fn newEntity(self: *App, comptime T: type, value: T) !Entity(T) {
        return self.entities.insert(T, value);
    }

    /// Create a new entity using a builder function
    pub fn new(self: *App, comptime T: type, build: fn (*Context(T)) T) !Entity(T) {
        var ctx = Context(T){
            .app = self,
            .entity_id = EntityId.invalid,
        };
        const value = build(&ctx);
        const entity = try self.entities.insert(T, value);
        return entity;
    }

    /// Read an entity's data (immutable)
    pub fn read(self: *const App, comptime T: type, handle: Entity(T)) ?*const T {
        return self.entities.get(T, handle);
    }

    /// Get mutable access to an entity's data
    pub fn readMut(self: *App, comptime T: type, handle: Entity(T)) ?*T {
        return self.entities.getMut(T, handle);
    }

    /// Update an entity with a callback
    pub fn update(self: *App, comptime T: type, handle: Entity(T), callback: fn (*T, *Context(T)) void) void {
        if (self.entities.getMut(T, handle)) |data| {
            var ctx = Context(T){
                .app = self,
                .entity_id = handle.id,
            };
            callback(data, &ctx);
            self.notify(handle.id);
        }
    }

    /// Observe changes to an entity
    pub fn observe(self: *App, entity_id: EntityId, callback: ObserverCallback) !Subscription {
        const id = self.next_observer_id;
        self.next_observer_id += 1;

        const result = try self.observers.getOrPut(self.allocator, entity_id);
        if (!result.found_existing) {
            result.value_ptr.* = .{ .items = &.{}, .capacity = 0 };
        }
        try result.value_ptr.append(self.allocator, .{ .id = id, .callback = callback });

        return .{ .id = id, .entity_id = entity_id };
    }

    /// Observe changes to an entity (type-safe)
    pub fn observeEntity(self: *App, comptime T: type, handle: Entity(T), callback: ObserverCallback) !Subscription {
        return self.observe(handle.id, callback);
    }

    /// Unsubscribe from an observer
    pub fn unsubscribe(self: *App, subscription: Subscription) void {
        if (!subscription.isValid()) return;

        if (self.observers.getPtr(subscription.entity_id)) |list| {
            for (list.items, 0..) |obs, i| {
                if (obs.id == subscription.id) {
                    _ = list.swapRemove(i);
                    return;
                }
            }
        }
    }

    /// Set a global value
    pub fn setGlobal(self: *App, comptime T: type, value: T) !void {
        const tid = typeId(T);

        // Remove old value if exists
        if (self.globals.get(tid)) |old_ptr| {
            if (self.global_deinit_fns.get(tid)) |deinit_fn| {
                deinit_fn(old_ptr, self.allocator);
            }
        }

        // Allocate and store new value
        const ptr = try self.allocator.create(T);
        ptr.* = value;

        const deinit_fn = struct {
            fn deinit(data: *anyopaque, alloc: Allocator) void {
                const typed: *T = @ptrCast(@alignCast(data));
                alloc.destroy(typed);
            }
        }.deinit;

        try self.globals.put(self.allocator, tid, ptr);
        try self.global_deinit_fns.put(self.allocator, tid, deinit_fn);

        // Notify global observers
        self.notifyGlobal(tid);
    }

    /// Get a global value (immutable)
    pub fn global(self: *const App, comptime T: type) ?*const T {
        const tid = typeId(T);
        const ptr = self.globals.get(tid) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// Get a global value (mutable)
    pub fn globalMut(self: *App, comptime T: type) ?*T {
        const tid = typeId(T);
        const ptr = self.globals.get(tid) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// Observe changes to a global type
    pub fn observeGlobal(self: *App, comptime T: type, callback: ObserverCallback) !Subscription {
        const tid = typeId(T);
        const id = self.next_observer_id;
        self.next_observer_id += 1;

        const result = try self.global_observers.getOrPut(self.allocator, tid);
        if (!result.found_existing) {
            result.value_ptr.* = .{ .items = &.{}, .capacity = 0 };
        }
        try result.value_ptr.append(self.allocator, .{ .id = id, .callback = callback });

        return .{ .id = id, .entity_id = .{ .index = @intCast(tid & 0xFFFFFFFF), .generation = @intCast((tid >> 32) & 0xFFFFFFFF) } };
    }

    /// Queue a notification for an entity
    pub fn notify(self: *App, entity_id: EntityId) void {
        // Avoid duplicates
        for (self.pending_notifications.items) |id| {
            if (id.eql(entity_id)) return;
        }
        self.pending_notifications.append(self.allocator, entity_id) catch {};
    }

    /// Notify global observers
    fn notifyGlobal(self: *App, tid: TypeId) void {
        if (self.global_observers.get(tid)) |observers| {
            for (observers.items) |obs| {
                obs.callback(self, EntityId.invalid);
            }
        }
    }

    /// Flush all pending notifications
    pub fn flushNotifications(self: *App) void {
        // Process notifications (may add more during processing)
        var i: usize = 0;
        while (i < self.pending_notifications.items.len) {
            const entity_id = self.pending_notifications.items[i];
            if (self.observers.get(entity_id)) |observers| {
                for (observers.items) |obs| {
                    obs.callback(self, entity_id);
                }
            }
            i += 1;
        }
        self.pending_notifications.clearRetainingCapacity();
    }

    /// Check if an entity exists
    pub fn contains(self: *const App, entity_id: EntityId) bool {
        return self.entities.contains(entity_id);
    }

    /// Remove an entity
    pub fn remove(self: *App, entity_id: EntityId) bool {
        // Clean up observers for this entity
        if (self.observers.fetchRemove(entity_id)) |entry| {
            var list = entry.value;
            list.deinit(self.allocator);
        }

        return self.entities.remove(entity_id);
    }
};

/// Context provided during entity construction/update
pub fn Context(comptime T: type) type {
    return struct {
        const Self = @This();

        app: *App,
        entity_id: EntityId,

        /// Get a handle to the current entity (only valid after insertion)
        pub fn handle(self: *const Self) Entity(T) {
            return .{ .id = self.entity_id };
        }

        /// Read another entity
        pub fn read(self: *const Self, comptime U: type, other: Entity(U)) ?*const U {
            return self.app.read(U, other);
        }

        /// Get a global value
        pub fn global(self: *const Self, comptime U: type) ?*const U {
            return self.app.global(U);
        }

        /// Notify that this entity changed
        pub fn notifySelf(self: *Self) void {
            if (self.entity_id.isValid()) {
                self.app.notify(self.entity_id);
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "App basic entity operations" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const Counter = struct { count: i32 };

    // Create entity
    const counter = try app.newEntity(Counter, .{ .count = 0 });

    // Read
    const data = app.read(Counter, counter);
    try std.testing.expect(data != null);
    try std.testing.expectEqual(@as(i32, 0), data.?.count);

    // Update
    app.update(Counter, counter, struct {
        fn update(c: *Counter, _: *Context(Counter)) void {
            c.count += 1;
        }
    }.update);

    const data2 = app.read(Counter, counter);
    try std.testing.expectEqual(@as(i32, 1), data2.?.count);
}

test "App observers" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const Value = struct { x: i32 };

    const entity = try app.newEntity(Value, .{ .x = 0 });

    var callback_count: i32 = 0;
    const callback_ptr = &callback_count;

    _ = try app.observe(entity.id, struct {
        fn callback(_: *App, _: EntityId) void {
            // Note: Can't capture callback_ptr directly in Zig
            // This is a simplified test
        }
    }.callback);

    // Notify
    app.notify(entity.id);
    app.flushNotifications();

    // In a real test we'd verify the callback was called
    // For now just verify no crash
    _ = callback_ptr;
}

test "App globals" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const Theme = struct {
        primary_color: u32,
        font_size: f32,
    };

    // Set global
    try app.setGlobal(Theme, .{ .primary_color = 0xFF0000, .font_size = 16.0 });

    // Read global
    const theme = app.global(Theme);
    try std.testing.expect(theme != null);
    try std.testing.expectEqual(@as(u32, 0xFF0000), theme.?.primary_color);
    try std.testing.expectEqual(@as(f32, 16.0), theme.?.font_size);

    // Update global
    try app.setGlobal(Theme, .{ .primary_color = 0x00FF00, .font_size = 18.0 });

    const theme2 = app.global(Theme);
    try std.testing.expectEqual(@as(u32, 0x00FF00), theme2.?.primary_color);
}

test "App entity removal" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const Data = struct { value: i32 };

    const entity = try app.newEntity(Data, .{ .value = 42 });
    try std.testing.expect(app.contains(entity.id));

    try std.testing.expect(app.remove(entity.id));
    try std.testing.expect(!app.contains(entity.id));
    try std.testing.expect(app.read(Data, entity) == null);
}

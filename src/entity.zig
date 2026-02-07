//! Entity system for zapui.
//! Provides generational arena storage for application state.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// Entity identifier with generation for safe reuse
pub const EntityId = struct {
    index: u32,
    generation: u32,

    pub const invalid = EntityId{ .index = std.math.maxInt(u32), .generation = 0 };

    pub fn eql(self: EntityId, other: EntityId) bool {
        return self.index == other.index and self.generation == other.generation;
    }

    pub fn isValid(self: EntityId) bool {
        return self.index != std.math.maxInt(u32);
    }
};

/// Type-safe entity handle
pub fn Entity(comptime T: type) type {
    return struct {
        const Self = @This();

        id: EntityId,

        pub fn toAny(self: Self) AnyEntity {
            return .{
                .id = self.id,
                .type_id = typeId(T),
            };
        }
    };
}

/// Type-erased entity handle
pub const AnyEntity = struct {
    id: EntityId,
    type_id: TypeId,

    pub fn eql(self: AnyEntity, other: AnyEntity) bool {
        return self.id.eql(other.id) and self.type_id == other.type_id;
    }
};

/// Runtime type identifier
pub const TypeId = usize;

/// Get the type ID for a type using @typeName address
pub fn typeId(comptime T: type) TypeId {
    const name = @typeName(T);
    return @intFromPtr(name.ptr);
}

/// Storage slot for entity data
const Slot = struct {
    generation: u32,
    data: ?*anyopaque,
    type_id: TypeId,
    deinit_fn: ?*const fn (*anyopaque, Allocator) void,
};

/// Generational arena for entity storage
pub const EntityStore = struct {
    allocator: Allocator,
    slots: std.ArrayListUnmanaged(Slot),
    free_list: std.ArrayListUnmanaged(u32),

    pub fn init(allocator: Allocator) EntityStore {
        return .{
            .allocator = allocator,
            .slots = .{ .items = &.{}, .capacity = 0 },
            .free_list = .{ .items = &.{}, .capacity = 0 },
        };
    }

    pub fn deinit(self: *EntityStore) void {
        // Free all stored entities
        for (self.slots.items) |*slot| {
            if (slot.data) |data| {
                if (slot.deinit_fn) |deinit_fn| {
                    deinit_fn(data, self.allocator);
                }
            }
        }
        self.slots.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    /// Insert a value and return its entity handle
    pub fn insert(self: *EntityStore, comptime T: type, value: T) !Entity(T) {
        // Allocate storage for the value
        const ptr = try self.allocator.create(T);
        ptr.* = value;

        const deinit_fn = struct {
            fn deinit(data: *anyopaque, alloc: Allocator) void {
                const typed: *T = @ptrCast(@alignCast(data));
                alloc.destroy(typed);
            }
        }.deinit;

        // Get or create a slot
        var index: u32 = undefined;
        var generation: u32 = undefined;

        if (self.free_list.items.len > 0) {
            index = self.free_list.pop().?;
            generation = self.slots.items[index].generation;
            self.slots.items[index] = .{
                .generation = generation,
                .data = ptr,
                .type_id = typeId(T),
                .deinit_fn = deinit_fn,
            };
        } else {
            index = @intCast(self.slots.items.len);
            generation = 0;
            try self.slots.append(self.allocator, .{
                .generation = generation,
                .data = ptr,
                .type_id = typeId(T),
                .deinit_fn = deinit_fn,
            });
        }

        return .{ .id = .{ .index = index, .generation = generation } };
    }

    /// Get a reference to an entity's data
    pub fn get(self: *const EntityStore, comptime T: type, handle: Entity(T)) ?*T {
        return self.getById(T, handle.id);
    }

    /// Get a reference to an entity's data by ID
    pub fn getById(self: *const EntityStore, comptime T: type, id: EntityId) ?*T {
        if (id.index >= self.slots.items.len) return null;

        const slot = &self.slots.items[id.index];
        if (slot.generation != id.generation) return null;
        if (slot.type_id != typeId(T)) return null;

        const data = slot.data orelse return null;
        return @ptrCast(@alignCast(data));
    }

    /// Get a mutable reference to an entity's data
    pub fn getMut(self: *EntityStore, comptime T: type, handle: Entity(T)) ?*T {
        return self.get(T, handle);
    }

    /// Check if an entity exists
    pub fn contains(self: *const EntityStore, id: EntityId) bool {
        if (id.index >= self.slots.items.len) return false;
        const slot = &self.slots.items[id.index];
        return slot.generation == id.generation and slot.data != null;
    }

    /// Remove an entity
    pub fn remove(self: *EntityStore, id: EntityId) bool {
        if (id.index >= self.slots.items.len) return false;

        var slot = &self.slots.items[id.index];
        if (slot.generation != id.generation) return false;

        if (slot.data) |data| {
            if (slot.deinit_fn) |deinit_fn| {
                deinit_fn(data, self.allocator);
            }
            slot.data = null;
            slot.generation +%= 1; // Wrapping add for generation
            self.free_list.append(self.allocator, id.index) catch {};
            return true;
        }

        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "EntityStore basic operations" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const TestData = struct {
        value: i32,
        name: []const u8,
    };

    // Insert
    const entity = try store.insert(TestData, .{ .value = 42, .name = "test" });
    try std.testing.expect(entity.id.isValid());

    // Get
    const data = store.get(TestData, entity);
    try std.testing.expect(data != null);
    try std.testing.expectEqual(@as(i32, 42), data.?.value);
    try std.testing.expectEqualStrings("test", data.?.name);

    // Modify
    data.?.value = 100;
    const data2 = store.get(TestData, entity);
    try std.testing.expectEqual(@as(i32, 100), data2.?.value);

    // Contains
    try std.testing.expect(store.contains(entity.id));

    // Remove
    try std.testing.expect(store.remove(entity.id));
    try std.testing.expect(!store.contains(entity.id));
    try std.testing.expect(store.get(TestData, entity) == null);
}

test "EntityStore generation safety" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const Value = struct { x: i32 };

    // Insert and remove
    const entity1 = try store.insert(Value, .{ .x = 1 });
    _ = store.remove(entity1.id);

    // Insert again - reuses slot with new generation
    const entity2 = try store.insert(Value, .{ .x = 2 });
    try std.testing.expectEqual(entity1.id.index, entity2.id.index);
    try std.testing.expect(entity1.id.generation != entity2.id.generation);

    // Old handle should not work
    try std.testing.expect(store.get(Value, entity1) == null);

    // New handle should work
    const data = store.get(Value, entity2);
    try std.testing.expect(data != null);
    try std.testing.expectEqual(@as(i32, 2), data.?.x);
}

test "EntityStore type safety" {
    const allocator = std.testing.allocator;
    var store = EntityStore.init(allocator);
    defer store.deinit();

    const TypeA = struct { a: i32 };
    const TypeB = struct { b: i32 };

    const entity_a = try store.insert(TypeA, .{ .a = 1 });

    // Should get correct type
    try std.testing.expect(store.get(TypeA, entity_a) != null);

    // Should fail with wrong type (different Entity type, can't directly test but getById can)
    const wrong_id = entity_a.id;
    try std.testing.expect(store.getById(TypeB, wrong_id) == null);
}

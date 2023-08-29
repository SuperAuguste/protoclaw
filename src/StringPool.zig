const std = @import("std");

const StringPool = @This();

allocator: std.mem.Allocator,
map: std.StringArrayHashMapUnmanaged(u16) = .{},

pub fn get(pool: StringPool, index: u32) []const u8 {
    return pool.map.keys()[index];
}

/// Stores string in pool, returns index
pub fn store(pool: *StringPool, string: []const u8) std.mem.Allocator.Error!u32 {
    const gop = try pool.map.getOrPutValue(pool.allocator, string, 0);
    gop.value_ptr.* += 1;
    return @intCast(gop.index);
}

/// Returns `true` if string is actually freed,
/// `false` if it still has a reference elsewhere
pub fn free(pool: *StringPool, string: []const u8) bool {
    const ptr = pool.map.getPtr(string).?;
    ptr.* -= 1;
    return ptr == 0;
}

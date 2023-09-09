const std = @import("std");

pub const WireType = enum(u3) { varint, i64, len, sgroup, egroup, i32 };
pub const RecordTag = packed struct(u16) {
    wire_type: WireType,
    field_number: u13,

    pub fn read(reader: anytype) (@TypeOf(reader).Error || error{ Overflow, EndOfStream })!RecordTag {
        return @bitCast(try std.leb.readULEB128(u16, reader));
    }

    pub fn write(tag: RecordTag, writer: anytype) @TypeOf(writer).Error!void {
        try std.leb.writeULEB128(writer, @as(u16, @bitCast(tag)));
    }
};

pub const RawRecord = struct {
    field_number: u16,
    value: union(WireType) {
        varint: u64,
        i64: u64,
        len: u32,
        sgroup: void,
        egroup: void,
        i32: u32,
    },
};

pub fn readRaw(reader: anytype) !RawRecord {
    const tag = try RecordTag.read(reader);
    return .{
        .field_number = tag.field_number,
        .value = switch (tag.wire_type) {
            .varint => .{ .varint = try std.leb.readULEB128(u64, reader) },
            .i64 => .{ .i64 = try std.leb.readULEB128(u64, reader) },
            .len => .{ .len = try std.leb.readULEB128(u32, reader) },
            .sgroup => .{ .sgroup = void{} },
            .egroup => .{ .egroup = void{} },
            .i32 => .{ .i32 = try std.leb.readULEB128(u32, reader) },
        },
    };
}

fn isArrayList(comptime T: type) bool {
    return @typeInfo(T) == .Struct and @hasField(T, "items") and @hasField(T, "capacity");
}

pub fn decode(comptime T: type, allocator: std.mem.Allocator, reader: anytype) !T {
    var value: T = undefined;
    try decodeInternal(T, &value, allocator, reader, true);
    return value;
}

fn decodeMessageFields(comptime T: type, allocator: std.mem.Allocator, reader: anytype, length: usize) !T {
    var counting_reader = std.io.countingReader(reader);
    var value = if (@hasField(T, "items") and @hasField(T, "capacity")) .{} else std.mem.zeroInit(T, .{});

    while (length == 0 or counting_reader.bytes_read < length) {
        // TODO: Add type sameness checks
        const split = RecordTag.read(counting_reader.reader()) catch |err| switch (err) {
            error.EndOfStream => return value,
            else => return err,
        };

        inline for (@field(T, "tags")) |rel| {
            if (split.field_number == rel[1]) {
                decodeInternal(@TypeOf(@field(value, rel[0])), &@field(value, rel[0]), allocator, counting_reader.reader(), false) catch |err| switch (err) {
                    error.EndOfStream => return value,
                    else => return err,
                };
            }
        }
    }

    return value;
}

fn decodeInternal(
    comptime T: type,
    value: *T,
    allocator: std.mem.Allocator,
    reader: anytype,
    top: bool,
) !void {
    switch (@typeInfo(T)) {
        .Struct => {
            if (comptime isArrayList(T)) {
                const Child = @typeInfo(@field(T, "Slice")).Pointer.child;
                const cti = @typeInfo(Child);

                if (cti == .Int or cti == .Enum) {
                    var lim = std.io.limitedReader(reader, try std.leb.readULEB128(usize, reader));
                    while (true)
                        try value.append(allocator, decode(Child, allocator, lim.reader()) catch return);
                } else {
                    var new_elem: Child = undefined;
                    try decodeInternal(Child, &new_elem, allocator, reader, false);
                    try value.append(allocator, new_elem);
                }
            } else {
                var length = if (top) 0 else try std.leb.readULEB128(usize, reader);
                value.* = try decodeMessageFields(T, allocator, reader, length);
            }
        },
        .Pointer => |ptr| {
            _ = ptr;
            // TODO: Handle non-slices
            if (T == []const u8) {
                var data = try allocator.alloc(u8, try std.leb.readULEB128(usize, reader));
                _ = try reader.readAll(data);
                value.* = data;
            } else @compileError("Slices not implemented");
        },
        // TODO: non-usize enums
        .Enum => value.* = @as(T, @enumFromInt(try std.leb.readULEB128(usize, reader))),
        .Int => |i| value.* = switch (i.signedness) {
            .signed => try std.leb.readILEB128(T, reader),
            .unsigned => try std.leb.readULEB128(T, reader),
        },
        .Bool => value.* = ((try std.leb.readULEB128(usize, reader)) != 0),
        .Array => |arr| {
            const Child = arr.child;
            const cti = @typeInfo(Child);

            if (cti == .Int or cti == .Enum) {
                var lim = std.io.limitedReader(reader, try std.leb.readULEB128(usize, reader));
                var array: [arr.len]Child = undefined;
                var index: usize = 0;
                while (true) : (index += 1) {
                    const new_item = decode(Child, allocator, lim.reader()) catch break;
                    if (index == array.len) return error.IndexOutOfRange;
                    array[index] = new_item;
                }
                if (index != array.len) return error.ArrayNotFilled;

                value.* = array;
            } else {
                @compileError("Array not of ints/enums not supported for decoding!");
            }
        },
        else => @compileError("Unsupported: " ++ @typeName(T)),
    }
}

pub fn encode(value: anytype, writer: anytype) !void {
    try encodeInternal(value, writer, true);
}

fn typeToWireType(comptime T: type) WireType {
    if (@typeInfo(T) == .Struct or @typeInfo(T) == .Pointer or @typeInfo(T) == .Array) return .len;
    if (@typeInfo(T) == .Int or @typeInfo(T) == .Bool or @typeInfo(T) == .Enum) return .varint;
    @compileError("Wire type not handled: " ++ @typeName(T));
}

fn encodeMessageFields(value: anytype, writer: anytype) !void {
    const T = @TypeOf(value);
    inline for (@field(T, "tags")) |rel| {
        const subval = @field(value, rel[0]);
        const SubT = @TypeOf(subval);

        if (comptime isArrayList(SubT) and !b: {
            const Child = @typeInfo(@field(SubT, "Slice")).Pointer.child;
            const cti = @typeInfo(Child);
            break :b cti == .Int or cti == .Enum;
        }) {
            for (subval.items) |item| {
                try RecordTag.write(.{ .field_number = rel[1], .type = typeToWireType(@TypeOf(item)) }, writer);
                try encodeInternal(item, writer, false);
            }
        } else {
            try RecordTag.write(.{ .field_number = rel[1], .type = typeToWireType(SubT) }, writer);
            try encodeInternal(subval, writer, false);
        }
    }
}

fn encodeInternal(
    value: anytype,
    writer: anytype,
    top: bool,
) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .Struct => {
            if (comptime isArrayList(T)) {
                var count_writer = std.io.countingWriter(std.io.null_writer);
                for (value.items) |item| try encodeInternal(item, count_writer.writer(), false);
                try std.leb.writeULEB128(writer, count_writer.bytes_written);
                for (value.items) |item| try encodeInternal(item, writer, false);
            } else {
                if (!top) {
                    var count_writer = std.io.countingWriter(std.io.null_writer);
                    try encodeMessageFields(value, count_writer.writer());
                    try std.leb.writeULEB128(writer, count_writer.bytes_written);
                }
                try encodeMessageFields(value, writer);
            }
        },
        .Pointer => |ptr| {
            _ = ptr;
            // TODO: Handle non-slices
            if (T == []const u8) {
                try std.leb.writeULEB128(writer, value.len);
                try writer.writeAll(value);
            } else @compileError("Slices not implemented");
        },
        .Enum => try encodeInternal(@intFromEnum(value), writer, false),
        .Int => |i| switch (i.signedness) {
            .signed => try std.leb.writeILEB128(writer, value),
            .unsigned => try std.leb.writeULEB128(writer, value),
        },
        .Bool => try std.leb.writeULEB128(writer, @intFromBool(value)),
        .Array => {
            var count_writer = std.io.countingWriter(std.io.null_writer);
            for (value) |item| try encodeInternal(item, count_writer.writer(), false);
            try std.leb.writeULEB128(writer, count_writer.bytes_written);
            for (value) |item| try encodeInternal(item, writer, false);
        },
        else => @compileError("Unsupported: " ++ @typeName(T)),
    }
}

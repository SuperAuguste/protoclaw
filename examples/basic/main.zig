const std = @import("std");
const protoclaw = @import("protoclaw");
const proto = @import("proto.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try protoclaw.encoding.encode(proto.hello.pog.Variant.Cool, fbs.writer());
    fbs.reset();
    std.log.info("{any}", .{try protoclaw.encoding.decode(proto.hello.pog.Variant, allocator, fbs.reader())});
}

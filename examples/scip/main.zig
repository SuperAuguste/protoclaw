const std = @import("std");
const protoclaw = @import("protoclaw");
const scip = @import("scip.zig").scip;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    _ = allocator;

    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    try protoclaw.encoding.encode(scip.Document{}, fbs.writer());
    std.log.info("{d}", .{fbs.getWritten()});
    fbs.reset();
    // std.log.info("{any}", .{try protoclaw.encoding.decode(proto.hello.Greeting, allocator, fbs.reader())});
}

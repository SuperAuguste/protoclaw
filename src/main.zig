const std = @import("std");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // var example = try std.fs.cwd().openFile("include/google/protobuf/descriptor.proto", .{});
    var example = try std.fs.cwd().openFile("example/hello.proto", .{});
    defer example.close();

    const buf = try example.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(buf);

    var tokenizer = Tokenizer{};
    try tokenizer.tokenize(allocator, buf);

    var parser = Parser.init(allocator, buf, tokenizer.tokens.slice());
    const ast = parser.parse() catch |err| {
        const token = parser.token_index;
        const start = parser.token_starts[token];
        const end = parser.token_ends[token];

        std.log.err("{d}: {s}", .{ start, parser.source[start..end] });
        return err;
    };

    try ast.print(std.io.getStdErr().writer(), 0, 0);
}

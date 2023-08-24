const std = @import("std");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var example = try std.fs.cwd().openFile("example/hello.proto", .{});
    defer example.close();

    const buf = try example.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(buf);

    var tokenizer = Tokenizer{};
    try tokenizer.tokenize(allocator, buf);

    var parser = Parser.init(allocator, buf, tokenizer.tokens.slice());
    const ast = try parser.parse();

    try ast.print(std.io.getStdErr().writer(), 0, 0);
}

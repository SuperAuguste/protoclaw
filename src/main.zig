const std = @import("std");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");
const DocumentStore = @import("DocumentStore.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var store = DocumentStore{ .allocator = allocator };

    try store.addIncludePath("example");
    try store.analyze();

    // std.log.info("{any}", .{store.import_path_to_document.get("pog/swag.proto")});

    // const hello = try std.fs.cwd().readFileAlloc(allocator, "example/hello.proto", std.math.maxInt(usize));
    // defer allocator.free(hello);
    // const swag = try std.fs.cwd().readFileAlloc(allocator, "example/swag.proto", std.math.maxInt(usize));
    // defer allocator.free(swag);

    // var tokenizer = Tokenizer{};
    // try tokenizer.tokenize(allocator, buf);

    // var parser = Parser.init(allocator, buf, tokenizer.tokens.slice());
    // const ast = parser.parse() catch |err| {
    //     const token = parser.token_index;
    //     const start = parser.token_starts[token];
    //     const end = parser.token_ends[token];

    //     std.log.err("{d}: {s}", .{ start, parser.source[start..end] });
    //     return err;
    // };

    // try ast.print(std.io.getStdErr().writer(), 0, 0);
}

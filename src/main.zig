const std = @import("std");
const Parser = @import("Parser.zig");
const Tokenizer = @import("Tokenizer.zig");
const DocumentStore = @import("DocumentStore.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = try DocumentStore.create(allocator);

    try store.addIncludePath("example");
    // try store.addIncludePath("/Users/auguste.rame/Documents/Repos/opentelemetry-proto");
    try store.analyze();

    var list = std.ArrayList(u8).init(allocator);
    try store.emit(list.writer());

    const sentineled = try list.toOwnedSliceSentinel(0);
    defer allocator.free(sentineled);

    var ast = try std.zig.Ast.parse(allocator, sentineled, .zig);
    defer ast.deinit(allocator);

    const rendered = try ast.render(allocator);
    defer allocator.free(rendered);

    try std.fs.cwd().writeFile("example/example.zig", rendered);
}

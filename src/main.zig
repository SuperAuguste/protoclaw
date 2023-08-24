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

    // std.log.info("{any}", .{tokenizer.tokens.items(.tag)});

    var parser = Parser.init(allocator, buf, tokenizer.tokens.slice());
    try parser.parse();

    for (0..parser.nodes.len) |idx| {
        const node = parser.nodes.get(idx);
        std.log.info("{any}", .{node});
        switch (node.tag) {
            // .number_literal => {
            //     std.log.info("{s}: {any} ", .{
            //         buf[tokenizer.tokens.items(.start)[node.main_token]..tokenizer.tokens.items(.end)[node.main_token]],
            //         node.data.number_literal,
            //     });
            // },
            // .message_decl => {
            //     std.log.info("{any}", .{parser.extra.items[node.data.message_decl.start_extra..node.data.message_decl.end_extra]});
            // },
            else => {},
        }
    }

    // std.log.info("{any}", .{parser.tokens.items(.tag)[parser.index]});
    // std.log.info("{any}", .{parser.nodes.items(.tag)});

    // var len: usize = 0;
    // var extended_len_offset: u32 = 0;
    // for (tokenizer.tokens.items) |token| {
    //     std.log.info("{any}", .{token});
    //     if (token.len == 0 and token.tag != .eof) {
    //         len += tokenizer.extended_lens.items[extended_len_offset];
    //         extended_len_offset += 1;
    //     } else {
    //         len += token.len;
    //     }
    // }

    // if (len != buf.len) {
    //     std.log.info("INVALID! {d} vs {d}", .{ len, buf.len });
    // }
}

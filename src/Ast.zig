const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Parser = @import("Parser.zig");

const Token = Tokenizer.Token;
const Node = Parser.Node;

const Ast = @This();

source: []const u8,

token_tags: []const Token.Tag,
token_starts: []const u32,
token_ends: []const u32,

node_tags: []const Node.Tag,
node_main_tokens: []const u32,
node_data: []const Node.Data,

extra: []const u32,

pub fn getChildrenInExtra(ast: Ast, node: u32) []const u32 {
    switch (ast.node_tags[node]) {
        .root, .message_decl, .enum_decl, .message_literal, .option_name => {
            const cie = ast.node_data[node].children_in_extra;
            return ast.extra[cie.start..cie.end];
        },
        else => @panic("node does not have children in extra"),
    }
}

pub fn tokenSlice(ast: Ast, token: u32) []const u8 {
    return ast.source[ast.token_starts[token]..ast.token_ends[token]];
}

pub fn qualifiedIdentifierSlice(ast: Ast, node: u32) []const u8 {
    std.debug.assert(ast.node_tags[node] == .qualified_identifier);
    return ast.source[ast.token_starts[ast.node_main_tokens[node]]..ast.token_ends[ast.node_data[node].qualified_identifier]];
}

pub fn print(ast: Ast, writer: anytype, node: u32, depth: u32) @TypeOf(writer).Error!void {
    try writer.writeByteNTimes(' ', depth * 4);
    try writer.print("{s} (main token: {s})\n", .{
        @tagName(ast.node_tags[node]),
        if (ast.node_main_tokens[node] == 0)
            "none"
        else
            ast.source[ast.token_starts[ast.node_main_tokens[node]]..ast.token_ends[ast.node_main_tokens[node]]],
    });

    switch (ast.node_tags[node]) {
        .root, .message_decl, .enum_decl, .message_literal, .option_name => {
            const children = ast.getChildrenInExtra(node);
            for (children) |child| {
                try ast.print(writer, child, depth + 1);
            }
        },
        .option => {
            const option_data = ast.node_data[node].option;
            try ast.print(writer, option_data.name_node, depth + 1);
            try ast.print(writer, option_data.value_node, depth + 1);
        },
        else => {},
    }
}

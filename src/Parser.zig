const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

const Token = Tokenizer.Token;

const Parser = @This();

allocator: std.mem.Allocator,

source: []const u8,
token_tags: []const Token.Tag,
token_starts: []const u32,
token_ends: []const u32,
token_index: u32 = 0,

nodes: NodeList = .{},

pub const NodeList = std.MultiArrayList(Node);
pub const Node = struct {
    pub const Tag = enum(u8) {
        syntax,
        import,
        package,
    };

    pub const Data = union {
        pub const Syntax = enum(u64) {
            proto2,
            proto3,
        };

        pub const Import = packed struct {
            pub const Kind = enum(u32) {
                default,
                weak,
                public,
            };

            kind: Kind,
            string_token: u32,
        };

        pub const Package = packed struct {
            start: u32,
            end: u32,
        };

        syntax: Syntax,
        import: Import,
        package: Package,
    };

    tag: Tag,
    main_token: u32,
    data: Data,
};

pub fn init(allocator: std.mem.Allocator, source: []const u8, slice: Tokenizer.TokenList.Slice) Parser {
    return .{
        .allocator = allocator,
        .source = source,
        .token_tags = slice.items(.tag),
        .token_starts = slice.items(.start),
        .token_ends = slice.items(.end),
    };
}

fn nextToken(parser: *Parser) u32 {
    const result = parser.token_index;
    parser.token_index += 1;
    return result;
}

fn eatToken(parser: *Parser, tag: Token.Tag) ?u32 {
    return if (parser.token_tags[parser.token_index] == tag) parser.nextToken() else null;
}

fn expectToken(parser: *Parser, tag: Token.Tag) ParseError!u32 {
    if (parser.token_tags[parser.token_index] != tag) {
        return error.Invalid;
    }
    return parser.nextToken();
}

const ParseError = std.mem.Allocator.Error || error{Invalid};
pub fn parse(parser: *Parser) ParseError!void {
    if (parser.eatToken(.keyword_syntax)) |syntax_token| {
        _ = try parser.expectToken(.equals);
        const spec_index = try parser.expectToken(.string_literal);
        _ = try parser.expectToken(.semicolon);
        const spec = parser.source[parser.token_starts[spec_index]..parser.token_ends[spec_index]];

        try parser.nodes.append(parser.allocator, .{
            .tag = .syntax,
            .main_token = syntax_token,
            .data = .{
                .syntax = if (std.mem.eql(u8, spec, "\"proto2\""))
                    .proto2
                else if (std.mem.eql(u8, spec, "\"proto3\""))
                    .proto3
                else
                    return error.Invalid,
            },
        });
    }

    while (try parser.parseFileElement()) |_| {}
}

fn parseFileElement(parser: *Parser) ParseError!?u32 {
    const token = parser.nextToken();
    switch (parser.token_tags[token]) {
        .keyword_import => {
            const kind: Node.Data.Import.Kind = switch (parser.token_tags[parser.token_index]) {
                .keyword_weak => b: {
                    parser.token_index += 1;
                    break :b .weak;
                },
                .keyword_public => b: {
                    parser.token_index += 1;
                    break :b .public;
                },
                else => .default,
            };
            const string_token = try parser.expectToken(.string_literal);
            _ = try parser.expectToken(.semicolon);

            try parser.nodes.append(parser.allocator, .{
                .tag = .import,
                .main_token = token,
                .data = .{
                    .import = .{
                        .kind = kind,
                        .string_token = string_token,
                    },
                },
            });

            return @intCast(parser.nodes.len - 1);
        },
        .keyword_package => {
            const start = try parser.expectToken(.identifier);
            var end: u32 = start;
            while (parser.eatToken(.dot)) |_| {
                end = parser.eatToken(.identifier) orelse break;
            }

            _ = try parser.expectToken(.semicolon);

            try parser.nodes.append(parser.allocator, .{
                .tag = .package,
                .main_token = token,
                .data = .{
                    .package = .{
                        .start = start,
                        .end = end,
                    },
                },
            });
            return @intCast(parser.nodes.len - 1);
        },
        else => return null,
    }
}

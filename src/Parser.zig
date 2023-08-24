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
extra: std.ArrayListUnmanaged(u32) = .{},
scratch: std.ArrayListUnmanaged(u32) = .{},

pub const NodeList = std.MultiArrayList(Node);
pub const Node = struct {
    comptime {
        if (@bitSizeOf(Data) != 64)
            @compileError("Data should be 64 bits");
    }

    pub const Tag = enum(u8) {
        string_literal,
        number_literal,

        syntax,
        import,
        package,
        option,

        /// main_token is message name
        message_decl,
        /// data is index into extra
        message_field,
    };

    pub const Data = packed union {
        pub const Sign = enum(u64) {
            positive,
            negative,
        };

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
            start_token: u32,
            end_token: u32,
        };

        pub const Option = packed struct {
            // TODO: https://protobuf.com/docs/language-spec#option-names
            name_token: u32,
            value_node: u32,
        };

        pub const MessageDecl = packed struct {
            start_extra: u32,
            end_extra: u32,
        };

        pub const MessageField = packed struct(u64) {
            identifier_node: u32,
            start_extra: u32,
        };

        pub const MessageFieldExtra = packed struct(u160) {
            pub const Cardinality = enum(u32) {
                required,
                optional,
                repeated,
            };

            cardinality: Cardinality,
            type_node: u32,
            identifier_node: u32,
            field_number_node: u32,
            compact_options_node: u32,
        };

        none: void,
        number_literal: Sign,

        syntax: Syntax,
        import: Import,
        package: Package,
        option: Option,

        message_decl: MessageDecl,
        message_field: u32,
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
            const start_token = try parser.expectToken(.identifier);
            var end_token: u32 = start_token;

            while (parser.eatToken(.dot)) |_| {
                end_token = parser.eatToken(.identifier) orelse break;
            }

            _ = try parser.expectToken(.semicolon);

            try parser.nodes.append(parser.allocator, .{
                .tag = .package,
                .main_token = token,
                .data = .{
                    .package = .{
                        .start_token = start_token,
                        .end_token = end_token,
                    },
                },
            });
            return @intCast(parser.nodes.len - 1);
        },
        .keyword_option => return try parser.parseOption(token),
        .keyword_message => return try parser.parseMessageDecl(token),
        else => return null,
    }
}

/// Assumes option keyword has already been consumed
/// TODO: Support MessageLiteralWithBraces
fn parseOption(parser: *Parser, keyword_token: u32) ParseError!u32 {
    // TODO: Parse full name system
    const name_token = try parser.expectToken(.identifier);
    _ = try parser.expectToken(.equals);

    const value_token = parser.nextToken();
    switch (parser.token_tags[value_token]) {
        .string_literal => try parser.nodes.append(parser.allocator, .{
            .tag = .string_literal,
            .main_token = value_token,
            .data = .{ .none = void{} },
        }),
        // NOTE: Seems like -inf and co are actually invalid; check in ast processor?
        .int_literal, .float_literal, .keyword_inf => try parser.nodes.append(parser.allocator, .{
            .tag = .number_literal,
            .main_token = value_token,
            .data = .{ .number_literal = .positive },
        }),
        .plus, .minus => |sign| {
            const real_value_token = parser.nextToken();

            switch (parser.token_tags[real_value_token]) {
                .int_literal, .float_literal, .keyword_inf => {},
                else => return error.Invalid,
            }

            try parser.nodes.append(parser.allocator, .{
                .tag = .number_literal,
                .main_token = real_value_token,
                .data = .{ .number_literal = switch (sign) {
                    .plus => .positive,
                    .minus => .negative,
                    else => unreachable,
                } },
            });
        },
        else => return error.Invalid,
    }

    try parser.nodes.append(parser.allocator, .{
        .tag = .option,
        .main_token = keyword_token,
        .data = .{
            .option = .{
                .name_token = name_token,
                .value_node = @intCast(parser.nodes.len - 1),
            },
        },
    });

    _ = try parser.expectToken(.semicolon);

    return @intCast(parser.nodes.len - 1);
}

fn parseMessageDecl(parser: *Parser, keyword_token: u32) ParseError!u32 {
    _ = keyword_token;
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    const main_token = try parser.expectToken(.identifier);
    _ = try parser.expectToken(.l_brace);

    while (true) {
        const token = parser.nextToken();
        try parser.scratch.append(parser.allocator, switch (parser.token_tags[token]) {
            .keyword_message => try parser.parseMessageDecl(token),
            .r_brace => break,
            else => return error.Invalid,
        });
    }

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    try parser.nodes.append(parser.allocator, .{
        .tag = .message_decl,
        .main_token = main_token,
        .data = .{
            .message_decl = .{
                .start_extra = @intCast(start_extra),
                .end_extra = @intCast(parser.extra.items.len),
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

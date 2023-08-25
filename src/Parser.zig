const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Ast = @import("Ast.zig");

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
        root,

        string_literal,
        number_literal,

        builtin_type,
        /// (fully) qualified identifier
        ///
        /// main_token is first token in sequence
        /// data is last token in sequence
        ///
        /// if main_token is a dot, the qualified
        /// identifier is fully qualified
        qualified_identifier,
        option_name,
        extension_name,

        /// main_token is variant
        syntax,
        import,
        /// data is qualified_identifier
        package,
        option,

        message_literal,
        list_literal,
        type_url,

        /// main_token is message name
        message_decl,
        /// main_token is enum name
        enum_decl,

        /// main_token is field name
        ///
        /// cardinality (required/optional/repeated) is type_name_node - 1
        /// field number is type_name_node + 1
        message_field_decl,
        /// main_token is value name
        enum_value_decl,
    };

    pub const Data = packed union {
        pub const Sign = enum(u64) {
            positive,
            negative,
        };

        pub const ImportKind = enum(u32) {
            default,
            weak,
            public,
        };

        pub const Option = packed struct {
            // TODO: https://protobuf.com/docs/language-spec#option-names
            name_node: u32,
            value_node: u32,
        };

        pub const TypeUrl = packed struct {
            root_node: u32,
            path_node: u32,
        };

        pub const ChildrenInExtra = packed struct {
            start: u32,
            end: u32,
        };

        pub const MessageFieldDecl = packed struct(u64) {
            type_name_node: u32,
            compact_options_node: u32,
        };

        pub const EnumValueDecl = packed struct(u64) {
            number_node: u32,
            compact_options_node: u32,
        };

        none: void,
        number_literal: Sign,

        qualified_identifier: u32,
        extension_name: u32,

        import: ImportKind,
        package: u32,
        option: Option,

        type_url: TypeUrl,

        children_in_extra: ChildrenInExtra,
        message_field_decl: MessageFieldDecl,
        enum_value_decl: EnumValueDecl,
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
pub fn parse(parser: *Parser) ParseError!Ast {
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    try parser.nodes.append(parser.allocator, .{
        .tag = .root,
        .main_token = 0,
        .data = .{
            .children_in_extra = .{
                .start = 0,
                .end = 0,
            },
        },
    });

    if (parser.eatToken(.keyword_syntax)) |syntax_token| {
        _ = syntax_token;
        _ = try parser.expectToken(.equals);
        const spec_token = try parser.expectToken(.string_literal);
        _ = try parser.expectToken(.semicolon);

        try parser.nodes.append(parser.allocator, .{
            .tag = .syntax,
            .main_token = spec_token,
            .data = .{ .none = void{} },
        });
        try parser.scratch.append(parser.allocator, @intCast(parser.nodes.len - 1));
    }

    while (try parser.parseFileElement()) |node|
        try parser.scratch.append(parser.allocator, node);

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    parser.nodes.items(.data)[0].children_in_extra = .{
        .start = @intCast(start_extra),
        .end = @intCast(parser.extra.items.len),
    };

    const node_slices = parser.nodes.slice();
    return .{
        .source = parser.source,

        .token_tags = parser.token_tags,
        .token_starts = parser.token_starts,
        .token_ends = parser.token_ends,

        .node_tags = node_slices.items(.tag),
        .node_main_tokens = node_slices.items(.main_token),
        .node_data = node_slices.items(.data),

        .extra = try parser.extra.toOwnedSlice(parser.allocator),
    };
}

fn parseFileElement(parser: *Parser) ParseError!?u32 {
    const token = parser.nextToken();
    switch (parser.token_tags[token]) {
        .keyword_import => {
            const kind_token: Node.Data.ImportKind = switch (parser.token_tags[parser.token_index]) {
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
                .main_token = string_token,
                .data = .{ .import = kind_token },
            });

            return @intCast(parser.nodes.len - 1);
        },
        .keyword_package => {
            const fqi = try parser.parseQualifiedIdentifier();
            _ = try parser.expectToken(.semicolon);

            try parser.nodes.append(parser.allocator, .{
                .tag = .package,
                .main_token = token,
                .data = .{ .package = fqi },
            });
            return @intCast(parser.nodes.len - 1);
        },
        .keyword_option => {
            const option_node = try parser.parseOption(token);
            _ = try parser.expectToken(.semicolon);
            return option_node;
        },
        .keyword_message => return try parser.parseMessageDecl(),
        .keyword_enum => return try parser.parseEnumDecl(),
        else => return null,
    }
}

fn parseScalarValue(parser: *Parser) ParseError!u32 {
    const value_token = parser.nextToken();
    switch (parser.token_tags[value_token]) {
        .identifier => try parser.nodes.append(parser.allocator, .{
            .tag = .qualified_identifier,
            .main_token = value_token,
            .data = .{ .qualified_identifier = value_token },
        }),
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

    return @intCast(parser.nodes.len - 1);
}

fn parseExtensionName(parser: *Parser) ParseError!u32 {
    const main_token = try parser.expectToken(.l_paren);
    try parser.nodes.append(parser.allocator, .{
        .tag = .extension_name,
        .main_token = main_token,
        .data = .{ .extension_name = try parser.parseFullyQualifiedIdentifier() },
    });
    _ = try parser.expectToken(.r_paren);
    return @intCast(parser.nodes.len - 1);
}

fn parseOptionName(parser: *Parser) ParseError!u32 {
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    while (true) {
        try parser.scratch.append(parser.allocator, switch (parser.token_tags[parser.token_index]) {
            .equals => break,
            .l_paren => try parser.parseExtensionName(),
            else => b: {
                const fq_dot = parser.eatToken(.dot);
                const first = try parser.expectToken(.identifier);
                var last: u32 = first;

                while (parser.eatToken(.dot)) |_|
                    last = parser.eatToken(.identifier) orelse continue;

                try parser.nodes.append(parser.allocator, .{
                    .tag = .qualified_identifier,
                    .main_token = fq_dot orelse first,
                    .data = .{ .qualified_identifier = last },
                });

                break :b @intCast(parser.nodes.len - 1);
            },
        });

        _ = parser.eatToken(.dot);
    }

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    try parser.nodes.append(parser.allocator, .{
        .tag = .option_name,
        .main_token = 0,
        .data = .{
            .children_in_extra = .{
                .start = @intCast(start_extra),
                .end = @intCast(parser.extra.items.len),
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

fn parseOptionValue(parser: *Parser) ParseError!u32 {
    switch (parser.token_tags[parser.token_index]) {
        .identifier,
        .string_literal,
        .int_literal,
        .float_literal,
        .keyword_inf,
        .plus,
        .minus,
        => _ = return parser.parseScalarValue(),
        .l_brace => {
            parser.token_index += 1;
            const message_literal_node = try parser.parseMessageLiteral();
            _ = try parser.expectToken(.r_brace);
            return message_literal_node;
        },
        else => return error.Invalid,
    }
}

/// Assumes option keyword has already been consumed
/// TODO: Support MessageLiteralWithBraces
fn parseOption(parser: *Parser, first_token: u32) ParseError!u32 {
    const name_node = try parser.parseOptionName();
    _ = try parser.expectToken(.equals);
    const value_node = try parser.parseOptionValue();

    try parser.nodes.append(parser.allocator, .{
        .tag = .option,
        .main_token = first_token,
        .data = .{
            .option = .{
                .name_node = name_node,
                .value_node = value_node,
            },
        },
    });

    return @intCast(parser.nodes.len - 1);
}

fn parseMessageDecl(parser: *Parser) ParseError!u32 {
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    const main_token = try parser.expectToken(.identifier);
    _ = try parser.expectToken(.l_brace);

    while (true) {
        const token = parser.nextToken();
        try parser.scratch.append(parser.allocator, switch (parser.token_tags[token]) {
            .keyword_option => b: {
                const option_node = try parser.parseOption(token);
                _ = try parser.expectToken(.semicolon);
                break :b option_node;
            },
            .keyword_message => try parser.parseMessageDecl(),
            .keyword_enum => try parser.parseEnumDecl(),

            .r_brace => break,

            .keyword_required,
            .keyword_optional,
            .keyword_repeated,
            .dot,
            .identifier,
            .keyword_int32,
            .keyword_sint32,
            .keyword_sfixed32,
            .keyword_int64,
            .keyword_sint64,
            .keyword_sfixed64,
            .keyword_uint32,
            .keyword_fixed32,
            .keyword_uint64,
            .keyword_fixed64,
            .keyword_float,
            .keyword_double,
            .keyword_bool,
            .keyword_string,
            .keyword_bytes,
            => b: {
                parser.token_index -= 1;
                break :b try parser.parseMessageFieldDecl();
            },
            else => return error.Invalid,
        });
    }

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    try parser.nodes.append(parser.allocator, .{
        .tag = .message_decl,
        .main_token = main_token,
        .data = .{
            .children_in_extra = .{
                .start = @intCast(start_extra),
                .end = @intCast(parser.extra.items.len),
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

fn parseEnumDecl(parser: *Parser) ParseError!u32 {
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    const main_token = try parser.expectToken(.identifier);
    _ = try parser.expectToken(.l_brace);

    while (true) {
        const token = parser.nextToken();
        try parser.scratch.append(parser.allocator, switch (parser.token_tags[token]) {
            .keyword_option => b: {
                const option_node = try parser.parseOption(token);
                _ = try parser.expectToken(.semicolon);
                break :b option_node;
            },
            .r_brace => break,
            .identifier => b: {
                parser.token_index -= 1;
                break :b try parser.parseEnumValueDecl();
            },
            else => return error.Invalid,
        });
    }

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    try parser.nodes.append(parser.allocator, .{
        .tag = .enum_decl,
        .main_token = main_token,
        .data = .{
            .children_in_extra = .{
                .start = @intCast(start_extra),
                .end = @intCast(parser.extra.items.len),
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

fn parseQualifiedIdentifier(parser: *Parser) ParseError!u32 {
    const first = try parser.expectToken(.identifier);
    var last: u32 = first;

    while (parser.eatToken(.dot)) |_|
        last = try parser.expectToken(.identifier);

    try parser.nodes.append(parser.allocator, .{
        .tag = .qualified_identifier,
        .main_token = first,
        .data = .{ .qualified_identifier = last },
    });
    return @intCast(parser.nodes.len - 1);
}

fn parseFullyQualifiedIdentifier(parser: *Parser) ParseError!u32 {
    const fq_dot = parser.eatToken(.dot);
    const first = try parser.expectToken(.identifier);
    var last: u32 = first;

    while (parser.eatToken(.dot)) |_|
        last = parser.eatToken(.identifier) orelse return error.Invalid;

    try parser.nodes.append(parser.allocator, .{
        .tag = .qualified_identifier,
        .main_token = fq_dot orelse first,
        .data = .{ .qualified_identifier = last },
    });
    return @intCast(parser.nodes.len - 1);
}

fn expectIdentifierToken(parser: *Parser, comptime exclude: []const Token.Tag) ParseError!u32 {
    const token_tag = parser.token_tags[parser.token_index];
    inline for (exclude) |tag| {
        if (token_tag == tag) return error.Invalid;
    }

    return switch (token_tag) {
        .identifier,
        .keyword_syntax,
        .keyword_float,
        .keyword_oneof,
        .keyword_import,
        .keyword_double,
        .keyword_map,
        .keyword_weak,
        .keyword_int32,
        .keyword_extensions,
        .keyword_public,
        .keyword_int64,
        .keyword_to,
        .keyword_package,
        .keyword_uint32,
        .keyword_max,
        .keyword_option,
        .keyword_uint64,
        .keyword_reserved,
        .keyword_inf,
        .keyword_sint32,
        .keyword_enum,
        .keyword_repeated,
        .keyword_sint64,
        .keyword_message,
        .keyword_optional,
        .keyword_fixed32,
        .keyword_extend,
        .keyword_required,
        .keyword_fixed64,
        .keyword_service,
        .keyword_bool,
        .keyword_sfixed32,
        .keyword_rpc,
        .keyword_string,
        .keyword_sfixed64,
        .keyword_stream,
        .keyword_bytes,
        .keyword_group,
        .keyword_returns,
        => parser.nextToken(),
        else => error.Invalid,
    };
}

/// TODO: Support compact options
fn parseMessageFieldDecl(parser: *Parser) ParseError!u32 {
    switch (parser.token_tags[parser.token_index]) {
        .keyword_required,
        .keyword_optional,
        .keyword_repeated,
        => {
            parser.token_index += 1;
        },
        else => {},
    }

    const type_name_node: u32 = switch (parser.token_tags[parser.token_index]) {
        .dot, .identifier => try parser.parseFullyQualifiedIdentifier(),
        .keyword_int32,
        .keyword_sint32,
        .keyword_sfixed32,
        .keyword_int64,
        .keyword_sint64,
        .keyword_sfixed64,
        .keyword_uint32,
        .keyword_fixed32,
        .keyword_uint64,
        .keyword_fixed64,
        .keyword_float,
        .keyword_double,
        .keyword_bool,
        .keyword_string,
        .keyword_bytes,
        => b: {
            try parser.nodes.append(parser.allocator, .{
                .tag = .builtin_type,
                .main_token = parser.nextToken(),
                .data = .{ .none = void{} },
            });
            break :b @intCast(parser.nodes.len - 1);
        },
        else => return error.Invalid,
    };
    const main_token = try parser.expectIdentifierToken(&.{});

    _ = try parser.expectToken(.equals);
    _ = try parser.expectToken(.int_literal);

    const compact_options_node = if (parser.eatToken(.l_bracket)) |bracket_token| b: {
        const option_node = try parser.parseOption(bracket_token);
        _ = try parser.expectToken(.r_bracket);
        break :b option_node;
    } else 0;

    _ = try parser.expectToken(.semicolon);

    try parser.nodes.append(parser.allocator, .{
        .tag = .message_field_decl,
        .main_token = main_token,
        .data = .{
            .message_field_decl = .{
                .type_name_node = type_name_node,
                .compact_options_node = compact_options_node,
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

/// TODO: Support compact options
fn parseEnumValueDecl(parser: *Parser) ParseError!u32 {
    const main_token = try parser.expectIdentifierToken(&.{ .keyword_option, .keyword_reserved });

    _ = try parser.expectToken(.equals);
    const sign: Node.Data.Sign = if (parser.eatToken(.minus)) |_| .negative else .positive;
    const int_token = try parser.expectToken(.int_literal);
    _ = try parser.expectToken(.semicolon);

    try parser.nodes.append(parser.allocator, .{
        .tag = .number_literal,
        .main_token = int_token,
        .data = .{ .number_literal = sign },
    });
    const int_node: u32 = @intCast(parser.nodes.len - 1);

    try parser.nodes.append(parser.allocator, .{
        .tag = .enum_value_decl,
        .main_token = main_token,
        .data = .{
            .enum_value_decl = .{
                .number_node = int_node,
                .compact_options_node = 0,
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

pub fn parseMessageLiteral(parser: *Parser) ParseError!u32 {
    const initial_scratch_len = parser.scratch.items.len;
    defer parser.scratch.items.len = initial_scratch_len;

    while (true) {
        switch (parser.token_tags[parser.token_index]) {
            .identifier => {
                const token = parser.nextToken();
                try parser.nodes.append(parser.allocator, .{
                    .tag = .qualified_identifier,
                    .main_token = token,
                    .data = .{ .qualified_identifier = token },
                });
            },
            .l_bracket => {
                parser.token_index += 1;
                const qi_node = try parser.parseQualifiedIdentifier();

                if (parser.eatToken(.slash)) |slash_token| {
                    const qi_path_node = try parser.parseQualifiedIdentifier();

                    try parser.nodes.append(parser.allocator, .{
                        .tag = .type_url,
                        .main_token = slash_token,
                        .data = .{
                            .type_url = .{
                                .root_node = qi_node,
                                .path_node = qi_path_node,
                            },
                        },
                    });
                }
            },
            else => break,
        }

        try parser.scratch.append(parser.allocator, @intCast(parser.nodes.len - 1));

        if (parser.eatToken(.colon)) |_| {
            try parser.scratch.append(parser.allocator, switch (parser.token_tags[parser.token_index]) {
                .l_brace => b: {
                    parser.token_index += 1;
                    const lit = try parser.parseMessageLiteral();
                    _ = try parser.expectToken(.r_brace);
                    break :b lit;
                },
                .l_angle => b: {
                    parser.token_index += 1;
                    const lit = try parser.parseMessageLiteral();
                    _ = try parser.expectToken(.r_angle);
                    break :b lit;
                },
                else => try parser.parseScalarValue(),
            });
        } else {
            try parser.scratch.append(parser.allocator, switch (parser.token_tags[parser.token_index]) {
                .l_brace => b: {
                    parser.token_index += 1;
                    const lit = try parser.parseMessageLiteral();
                    _ = try parser.expectToken(.r_brace);
                    break :b lit;
                },
                .l_angle => b: {
                    parser.token_index += 1;
                    const lit = try parser.parseMessageLiteral();
                    _ = try parser.expectToken(.r_angle);
                    break :b lit;
                },
                else => return error.Invalid,
            });
        }

        switch (parser.token_tags[parser.token_index]) {
            .colon, .semicolon => parser.token_index += 1,
            else => {},
        }
    }

    const start_extra = parser.extra.items.len;
    try parser.extra.appendSlice(parser.allocator, parser.scratch.items[initial_scratch_len..]);

    try parser.nodes.append(parser.allocator, .{
        .tag = .message_literal,
        .main_token = 0,
        .data = .{
            .children_in_extra = .{
                .start = @intCast(start_extra),
                .end = @intCast(parser.extra.items.len),
            },
        },
    });
    return @intCast(parser.nodes.len - 1);
}

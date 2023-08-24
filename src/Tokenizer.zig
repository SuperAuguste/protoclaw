const std = @import("std");

const Tokenizer = @This();

tokens: TokenList = .{},

pub const TokenList = std.MultiArrayList(Token);
pub const Token = struct {
    tag: Tag,
    start: u32,
    end: u32,

    pub const Tag = enum(u8) {
        invalid,
        eof,

        identifier,
        keyword_syntax,
        keyword_float,
        keyword_oneof,
        keyword_import,
        keyword_double,
        keyword_map,
        keyword_weak,
        keyword_int32,
        keyword_extensions,
        keyword_public,
        keyword_int64,
        keyword_to,
        keyword_package,
        keyword_uint32,
        keyword_max,
        keyword_option,
        keyword_uint64,
        keyword_reserved,
        keyword_inf,
        keyword_sint32,
        keyword_enum,
        keyword_repeated,
        keyword_sint64,
        keyword_message,
        keyword_optional,
        keyword_fixed32,
        keyword_extend,
        keyword_required,
        keyword_fixed64,
        keyword_service,
        keyword_bool,
        keyword_sfixed32,
        keyword_rpc,
        keyword_string,
        keyword_sfixed64,
        keyword_stream,
        keyword_bytes,
        keyword_group,
        keyword_returns,

        int_literal,
        float_literal,

        string_literal,

        semicolon,
        comma,
        dot,
        slash,
        colon,
        equals,
        minus,
        plus,
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        l_angle,
        r_angle,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "syntax", .keyword_syntax },
        .{ "float", .keyword_float },
        .{ "oneof", .keyword_oneof },
        .{ "import", .keyword_import },
        .{ "double", .keyword_double },
        .{ "map", .keyword_map },
        .{ "weak", .keyword_weak },
        .{ "int32", .keyword_int32 },
        .{ "extensions", .keyword_extensions },
        .{ "public", .keyword_public },
        .{ "int64", .keyword_int64 },
        .{ "to", .keyword_to },
        .{ "package", .keyword_package },
        .{ "uint32", .keyword_uint32 },
        .{ "max", .keyword_max },
        .{ "option", .keyword_option },
        .{ "uint64", .keyword_uint64 },
        .{ "reserved", .keyword_reserved },
        .{ "inf", .keyword_inf },
        .{ "sint32", .keyword_sint32 },
        .{ "enum", .keyword_enum },
        .{ "repeated", .keyword_repeated },
        .{ "sint64", .keyword_sint64 },
        .{ "message", .keyword_message },
        .{ "optional", .keyword_optional },
        .{ "fixed32", .keyword_fixed32 },
        .{ "extend", .keyword_extend },
        .{ "required", .keyword_required },
        .{ "fixed64", .keyword_fixed64 },
        .{ "service", .keyword_service },
        .{ "bool", .keyword_bool },
        .{ "sfixed32", .keyword_sfixed32 },
        .{ "rpc", .keyword_rpc },
        .{ "string", .keyword_string },
        .{ "sfixed64", .keyword_sfixed64 },
        .{ "stream", .keyword_stream },
        .{ "bytes", .keyword_bytes },
        .{ "group", .keyword_group },
        .{ "returns", .keyword_returns },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }
};

pub const State = enum {
    start,
    identifier,
    comment,
    whitespace,
    string_literal,
    number_literal,
    number_literal_float_hint,
};

pub fn tokenize(tokenizer: *Tokenizer, allocator: std.mem.Allocator, buffer: []const u8) std.mem.Allocator.Error!void {
    var index: u32 = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;

    tokenizer.tokens.len = 0;

    all_loop: while (true) {
        var state: State = .start;
        var tag: Token.Tag = .invalid;
        const start: u32 = index;

        while (true) : (index += 1) {
            if (index >= buffer.len) {
                tag = .eof;
                break;
            }
            const char = buffer[index];

            switch (state) {
                .start => switch (char) {
                    'a'...'z', 'A'...'Z' => {
                        tag = .identifier;
                        state = .identifier;
                    },
                    '/' => {
                        if (index + 1 >= buffer.len) {
                            tag = .eof;
                            break;
                        }

                        if (buffer[index + 1] == '/') {
                            state = .comment;
                        } else {
                            index += 1;
                            break;
                        }
                    },
                    '\n', ' ', '\t', '\r' => {
                        state = .whitespace;
                    },
                    '"' => {
                        tag = .string_literal;
                        state = .string_literal;
                    },
                    '.' => {
                        if (index + 1 >= buffer.len) {
                            tag = .eof;
                            break;
                        }

                        switch (buffer[index + 1]) {
                            '0'...'9' => {
                                state = .number_literal_float_hint;
                            },
                            else => {
                                tag = .dot;
                                index += 1;
                                break;
                            },
                        }
                    },
                    '0'...'9' => {
                        state = .number_literal;
                    },

                    inline ';',
                    ',',
                    // '.',
                    // '/',
                    ':',
                    '=',
                    '-',
                    '+',
                    '(',
                    ')',
                    '{',
                    '}',
                    '[',
                    ']',
                    '<',
                    '>',
                    => |v| {
                        tag = switch (v) {
                            ';' => .semicolon,
                            ',' => .comma,
                            // '.' => .dot,
                            // '/' => .slash,
                            ':' => .colon,
                            '=' => .equals,
                            '-' => .minus,
                            '+' => .plus,
                            '(' => .l_paren,
                            ')' => .r_paren,
                            '{' => .l_brace,
                            '}' => .r_brace,
                            '[' => .l_bracket,
                            ']' => .r_bracket,
                            '<' => .l_angle,
                            '>' => .r_angle,
                            else => unreachable,
                        };
                        index += 1;
                        break;
                    },

                    else => break,
                },
                .identifier => switch (char) {
                    'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                    else => {
                        if (Token.getKeyword(buffer[start..index])) |kw_tag| {
                            tag = kw_tag;
                        }
                        break;
                    },
                },
                .comment => switch (char) {
                    '\n' => continue :all_loop,
                    else => {},
                },
                .whitespace => switch (char) {
                    '\n', ' ', '\t', '\r' => {},
                    else => continue :all_loop,
                },
                // TODO: Proper string handling (escapes, unicode, etc.)
                .string_literal => switch (char) {
                    '"' => {
                        index += 1;
                        break;
                    },
                    else => {},
                },
                .number_literal, .number_literal_float_hint => switch (char) {
                    '.', '0'...'9', 'a'...'z', 'A'...'Z', '_' => switch (char) {
                        '.' => state = .number_literal_float_hint,
                        'e', 'E' => e_check: {
                            state = .number_literal_float_hint;
                            if (index + 1 >= buffer.len) break :e_check;
                            switch (buffer[index + 1]) {
                                '+', '-' => {
                                    index += 1;
                                },
                                else => {},
                            }
                        },
                        else => {},
                    },
                    else => {
                        const num = buffer[start..index];

                        switch (state) {
                            .number_literal => {
                                if (std.mem.eql(u8, num, "0")) {
                                    tag = .int_literal;
                                } else if (std.mem.startsWith(u8, num, "0x") or std.mem.startsWith(u8, num, "0X")) {
                                    if (num.len == 2) break;

                                    for (num[2..]) |n| {
                                        switch (n) {
                                            '0'...'9', 'a'...'f', 'A'...'F' => {},
                                            else => break,
                                        }
                                    } else {
                                        tag = .int_literal;
                                    }
                                } else if (std.mem.startsWith(u8, num, "0")) {
                                    if (num.len == 1) break;

                                    for (num[1..]) |n| {
                                        switch (n) {
                                            '0'...'7' => {},
                                            else => break,
                                        }
                                    } else {
                                        tag = .int_literal;
                                    }
                                } else {
                                    for (num) |n| {
                                        switch (n) {
                                            '0'...'9' => {},
                                            else => break,
                                        }
                                    } else {
                                        tag = .int_literal;
                                    }
                                }
                            },
                            .number_literal_float_hint => {
                                // TODO: Properly parse float literals
                                tag = .float_literal;
                            },
                            else => unreachable,
                        }

                        break;
                    },
                },
            }
        }

        try tokenizer.tokens.append(allocator, .{
            .tag = tag,
            .start = start,
            .end = index,
        });

        if (tag == .eof)
            break;
    }
}

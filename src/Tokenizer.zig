//! https://protobuf.dev/reference/protobuf/proto3-spec/

const std = @import("std");

const Tokenizer = @This();

buffer: []const u8,
index: usize,

pub fn init(buffer: []const u8) Tokenizer {
    // Skip the UTF-8 BOM if present
    const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
    return Tokenizer{
        .buffer = buffer,
        .index = src_start,
    };
}

const Token = packed struct {
    kind: Tag,
    len: u8,

    pub const Tag = enum(u8) {
        invalid,

        identifier,
        string_literal,
        integer,
        float,

        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        l_paren,
        r_paren,
        l_angle,
        r_angle,
        semicolon,

        keyword_import,
        keyword_package,
        keyword_option,
        keyword_repeated,
        keyword_oneof,
        keyword_map,
        keyword_reserved,
        keyword_enum,
        keyword_message,
        keyword_service,
        keyword_rpc,
        keyword_returns,
    };
};

pub const State = enum {
    start,
};

pub fn next() Token {
    var state: State = .start;
    _ = state;
}

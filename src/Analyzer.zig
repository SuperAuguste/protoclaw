const std = @import("std");
const Ast = @import("Ast.zig");
const DocumentStore = @import("DocumentStore.zig");

const Analyzer = @This();

allocator: std.mem.Allocator,
store: *const DocumentStore,

imports: std.ArrayListUnmanaged(u32) = .{},

top_level_decls: std.StringArrayHashMapUnmanaged(UnknownDecl) = .{},
message_decls: std.MultiArrayList(MessageDecl) = .{},
message_field_decls: std.MultiArrayList(MessageFieldDecl) = .{},
enum_decls: std.MultiArrayList(EnumDecl) = .{},
enum_value_decls: std.MultiArrayList(EnumValueDecl) = .{},

pub const UnknownDecl = packed struct(u32) {
    which: enum(u3) { message, @"enum" },
    index: u29,
};

pub const MessageDecl = struct {
    name: []const u8,
    field_decls: std.StringArrayHashMapUnmanaged(u32),
    message_decls: std.StringArrayHashMapUnmanaged(u32),
    enum_decls: std.StringArrayHashMapUnmanaged(u32),
};

pub const MessageFieldDecl = struct {
    name: []const u8,
    type: []const u8,
    field_number: u64,
};

pub const EnumDecl = struct {
    name: []const u8,
    value_decls: std.StringArrayHashMapUnmanaged(u32),
};

pub const EnumValueDecl = struct {
    name: []const u8,
    value: i64,
};

pub const WalkError = std.mem.Allocator.Error || std.fmt.ParseIntError || error{Invalid};
pub fn walk(analyzer: *Analyzer, ast: *const Ast) WalkError!void {
    const allocator = analyzer.allocator;

    const children = ast.getChildrenInExtra(0);
    for (children) |child| {
        switch (ast.node_tags[child]) {
            .import => {
                const str = ast.tokenSlice(ast.node_main_tokens[child]);
                const import_str = str[1 .. str.len - 1];

                if (analyzer.store.import_path_to_document.get(import_str)) |import| {
                    try analyzer.imports.append(allocator, import);
                } else {
                    std.log.err("Could not resolve import '{s}'", .{import_str});
                    return error.Invalid;
                }
            },
            .message_decl => {
                const index = try analyzer.walkMessageDecl(ast, child);
                try analyzer.top_level_decls.put(
                    allocator,
                    analyzer.message_decls.items(.name)[index],
                    .{ .which = .message, .index = @intCast(index) },
                );
            },
            else => {},
        }
    }
}

pub fn walkMessageDecl(analyzer: *Analyzer, ast: *const Ast, node: u32) WalkError!u32 {
    const allocator = analyzer.allocator;
    std.debug.assert(ast.node_tags[node] == .message_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);

    var field_decls = std.StringArrayHashMapUnmanaged(u32){};
    var message_decls = std.StringArrayHashMapUnmanaged(u32){};
    var enum_decls = std.StringArrayHashMapUnmanaged(u32){};

    const children = ast.getChildrenInExtra(node);
    for (children) |child| {
        switch (ast.node_tags[child]) {
            .message_field_decl => {
                const index = try analyzer.walkMessageFieldDecl(ast, child);
                try field_decls.put(allocator, analyzer.message_field_decls.items(.name)[index], @intCast(index));
            },
            .message_decl => {
                const index = try analyzer.walkMessageDecl(ast, child);
                try message_decls.put(allocator, analyzer.message_decls.items(.name)[index], @intCast(index));
            },
            else => {},
        }
    }

    try analyzer.message_decls.append(allocator, .{
        .name = name,
        .field_decls = field_decls,
        .message_decls = message_decls,
        .enum_decls = enum_decls,
    });
    return @intCast(analyzer.message_decls.len - 1);
}

pub fn walkMessageFieldDecl(analyzer: *Analyzer, ast: *const Ast, node: u32) WalkError!u32 {
    const allocator = analyzer.allocator;
    std.debug.assert(ast.node_tags[node] == .message_field_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);
    const data = ast.node_data[node].message_field_decl;

    try analyzer.message_field_decls.append(allocator, .{
        .name = name,
        .type = switch (ast.node_tags[data.type_name_node]) {
            .qualified_identifier => ast.qualifiedIdentifierSlice(data.type_name_node),
            .builtin_type => ast.tokenSlice(data.type_name_node),
            else => unreachable,
        },
        // TODO: Parse all int types properly
        .field_number = try std.fmt.parseUnsigned(u64, ast.tokenSlice(ast.node_main_tokens[node] + 2), 10),
    });
    return @intCast(analyzer.message_field_decls.len - 1);
}

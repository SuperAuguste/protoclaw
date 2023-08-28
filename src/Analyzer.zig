const std = @import("std");
const Ast = @import("Ast.zig");
const DocumentStore = @import("DocumentStore.zig");

const Analyzer = @This();

allocator: std.mem.Allocator,
store: *DocumentStore,
document: u32,

syntax: enum { proto2, proto3 } = .proto2,
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

// AST Walking

pub const WalkError = std.mem.Allocator.Error || std.fmt.ParseIntError || error{Invalid};
pub fn walk(analyzer: *Analyzer, ast: *const Ast) WalkError!void {
    const allocator = analyzer.allocator;

    var syntax_already_found = false;
    var package_already_found = false;

    const children = ast.getChildrenInExtra(0);
    for (children) |child| {
        switch (ast.node_tags[child]) {
            .syntax => {
                if (syntax_already_found)
                    return error.Invalid;
                syntax_already_found = true;

                const spec = ast.tokenSlice(ast.node_main_tokens[child]);
                if (std.mem.eql(u8, spec, "\"proto2\"")) {
                    analyzer.syntax = .proto2;
                } else if (std.mem.eql(u8, spec, "\"proto3\"")) {
                    analyzer.syntax = .proto3;
                } else {
                    return error.Invalid;
                }
            },
            .package => {
                if (package_already_found)
                    return error.Invalid;
                package_already_found = true;

                const fqi = ast.node_data[child].package;

                var token = ast.node_main_tokens[fqi];
                const end = ast.node_data[fqi].package;

                var packages = analyzer.store.packages;

                while (token <= end) : (token += 2) {
                    const gop = try packages.subpackages.getOrPut(allocator, ast.tokenSlice(token));
                    if (!gop.found_existing) {
                        var new_packages = try allocator.create(DocumentStore.Packages);
                        new_packages.* = .{};
                        gop.value_ptr.* = new_packages;
                    }

                    packages = gop.value_ptr.*;
                }

                try packages.documents.append(allocator, analyzer.document);
            },
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
            .enum_decl => {
                const index = try analyzer.walkEnumDecl(ast, child);
                try analyzer.top_level_decls.put(
                    allocator,
                    analyzer.enum_decls.items(.name)[index],
                    .{ .which = .@"enum", .index = @intCast(index) },
                );
            },
            else => {},
        }
    }

    if (!package_already_found)
        try analyzer.store.packages.documents.append(allocator, analyzer.document);
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
            .enum_decl => {
                const index = try analyzer.walkEnumDecl(ast, child);
                try enum_decls.put(allocator, analyzer.enum_decls.items(.name)[index], @intCast(index));
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

pub fn walkEnumDecl(analyzer: *Analyzer, ast: *const Ast, node: u32) WalkError!u32 {
    const allocator = analyzer.allocator;
    std.debug.assert(ast.node_tags[node] == .enum_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);

    var value_decls = std.StringArrayHashMapUnmanaged(u32){};

    const children = ast.getChildrenInExtra(node);
    for (children) |child| {
        switch (ast.node_tags[child]) {
            .enum_value_decl => {
                const index = try analyzer.walkEnumValueDecl(ast, child);
                try value_decls.put(allocator, analyzer.enum_value_decls.items(.name)[index], @intCast(index));
            },
            else => {},
        }
    }

    try analyzer.enum_decls.append(allocator, .{
        .name = name,
        .value_decls = value_decls,
    });
    return @intCast(analyzer.enum_decls.len - 1);
}

pub fn walkEnumValueDecl(analyzer: *Analyzer, ast: *const Ast, node: u32) WalkError!u32 {
    const allocator = analyzer.allocator;
    std.debug.assert(ast.node_tags[node] == .enum_value_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);
    const data = ast.node_data[node].enum_value_decl;

    try analyzer.enum_value_decls.append(allocator, .{
        .name = name,
        // TODO: Parse all int types properly
        .value = @intFromEnum(ast.node_data[data.number_node].number_literal) * @as(i64, @intCast(try std.fmt.parseInt(u64, ast.tokenSlice(ast.node_main_tokens[data.number_node]), 10))),
    });
    return @intCast(analyzer.enum_value_decls.len - 1);
}

// Semantic analysis ("Linking" as protobuf calls it)

pub const AnalyzeError = error{};

pub fn analyze(analyzer: *Analyzer) AnalyzeError!void {
    _ = analyzer;
}

// Emission

pub fn EmitError(comptime Writer: type) type {
    return error{} || Writer.Error;
}

pub fn emit(analyzer: *Analyzer, writer: anytype) EmitError(@TypeOf(writer))!void {
    for (analyzer.top_level_decls.entries.items(.value)) |value| {
        switch (value.which) {
            .message => try analyzer.emitMessage(writer, value.index),
            .@"enum" => try analyzer.emitEnum(writer, value.index),
        }
    }
}

fn emitMessage(analyzer: *Analyzer, writer: anytype, message: u32) EmitError(@TypeOf(writer))!void {
    const slice = analyzer.message_decls.slice();
    const name = slice.items(.name)[message];
    const field_decls = slice.items(.field_decls)[message];
    const message_decls = slice.items(.message_decls)[message];
    const enum_decls = slice.items(.enum_decls)[message];

    const message_field_decls_slice = analyzer.message_field_decls.slice();
    const field_names = message_field_decls_slice.items(.name);
    const field_numbers = message_field_decls_slice.items(.field_number);

    try writer.print("pub const {} = struct {{\n", .{std.zig.fmtId(name)});

    try writer.print("pub const protobuf_metadata = .{{.syntax = .{s},", .{@tagName(analyzer.syntax)});
    try writer.writeAll(".field_numbers = .{");
    for (field_decls.entries.items(.value)) |field_decl| {
        try writer.print(".{} = {d},\n", .{ std.zig.fmtId(field_names[field_decl]), field_numbers[field_decl] });
    }
    try writer.writeAll("},");
    try writer.writeAll("};\n\n");

    for (message_decls.entries.items(.value)) |index| try analyzer.emitMessage(writer, index);
    for (enum_decls.entries.items(.value)) |index| try analyzer.emitEnum(writer, index);
    try writer.writeAll("};\n\n");
}

fn emitEnum(analyzer: *Analyzer, writer: anytype, @"enum": u32) EmitError(@TypeOf(writer))!void {
    const slice = analyzer.enum_decls.slice();
    const name = slice.items(.name)[@"enum"];
    const value_decls = slice.items(.value_decls)[@"enum"];

    const enum_value_decls_slice = analyzer.enum_value_decls.slice();
    const value_names = enum_value_decls_slice.items(.name);
    const value_values = enum_value_decls_slice.items(.value);

    try writer.print("pub const {} = enum(i64) {{\n", .{std.zig.fmtId(name)});
    try writer.print("pub const protobuf_metadata = .{{.syntax = .{s},}};\n\n", .{@tagName(analyzer.syntax)});

    for (value_decls.entries.items(.value)) |value_decl| {
        try writer.print("{} = {d},\n", .{ std.zig.fmtId(value_names[value_decl]), value_values[value_decl] });
    }
    try writer.writeAll("};\n\n");
}

const std = @import("std");
const Ast = @import("Ast.zig");
const Tokenizer = @import("Tokenizer.zig");
const StringPool = @import("StringPool.zig");
const DocumentStore = @import("DocumentStore.zig");

const Analyzer = @This();

allocator: std.mem.Allocator,
store: *DocumentStore,
string_pool: *StringPool,
document: u32,

syntax: enum { proto2, proto3 } = .proto2,
imports: std.ArrayListUnmanaged(u32) = .{},

decls: std.MultiArrayList(Decl) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},
scratch: std.ArrayListUnmanaged(u32) = .{},

const ScratchState = struct {
    analyzer: *Analyzer,
    initial_scratch_len: u32,

    pub fn appendAndReset(state: ScratchState) std.mem.Allocator.Error!Children {
        const start = state.analyzer.extra.items.len;

        try state.analyzer.extra.appendSlice(state.analyzer.allocator, state.analyzer.scratch.items[state.initial_scratch_len..]);
        state.analyzer.scratch.items.len = state.initial_scratch_len;

        return Children{
            .start = @intCast(start),
            .end = @intCast(state.analyzer.extra.items.len),
        };
    }
};

fn saveScratch(analyzer: *Analyzer) ScratchState {
    return .{
        .analyzer = analyzer,
        .initial_scratch_len = @intCast(analyzer.scratch.items.len),
    };
}

pub const Children = packed struct(u64) {
    pub const none: Children = @bitCast(@as(u64, std.math.maxInt(u64)));
    start: u32,
    end: u32,
};

pub const Decl = struct {
    pub const Tag = enum(u8) {
        root,
        type,
        message_decl,
        message_field_decl,
        enum_decl,
        enum_value_decl,
    };

    pub const Extra = union(Tag) {
        pub const Root = extern struct {
            children: Children = Children.none,
        };

        pub const Type = extern struct {
            tag: enum(u8) { builtin, unresolved, resolved },
            payload: extern union {
                builtin: Tokenizer.Token.Tag,
                unresolved: u32,
                resolved: extern struct { document: u32, index: u32 },
            },
        };

        pub const MessageDecl = extern struct {
            parent: u32,
            name: u32,

            children: Children = Children.none,
        };

        pub const MessageFieldDecl = extern struct {
            parent: u32,
            name: u32,

            type: u32,
            field_number: u64,
        };

        pub const EnumDecl = extern struct {
            parent: u32,
            name: u32,

            children: Children = Children.none,
        };

        pub const EnumValueDecl = extern struct {
            parent: u32,
            name: u32,

            value: i64,
        };

        root: Root,
        type: Type,
        message_decl: MessageDecl,
        message_field_decl: MessageFieldDecl,
        enum_decl: EnumDecl,
        enum_value_decl: EnumValueDecl,
    };

    tag: Tag,
    extra: u32,
};

fn ExtraData(comptime tag: Decl.Tag) type {
    return std.meta.TagPayload(Decl.Extra, tag);
}

fn extraData(analyzer: *Analyzer, comptime tag: Decl.Tag, decl_index: u32) *align(1) ExtraData(tag) {
    const extra_index = analyzer.decls.items(.extra)[decl_index];
    return @alignCast(@ptrCast(
        analyzer.extra.items[extra_index..][0..comptime @divExact(@sizeOf(ExtraData(tag)), 4)],
    ));
}

fn appendDecl(analyzer: *Analyzer, comptime tag: Decl.Tag, data: ExtraData(tag)) std.mem.Allocator.Error!u32 {
    try analyzer.decls.append(analyzer.allocator, .{
        .tag = tag,
        .extra = @intCast(analyzer.extra.items.len),
    });
    try analyzer.extra.appendSlice(analyzer.allocator, &@as([
        @divExact(@sizeOf(ExtraData(tag)), 4)
    ]u32, @bitCast(data)));
    return @intCast(analyzer.decls.len - 1);
}

// AST Walking

pub const WalkError = std.mem.Allocator.Error || std.fmt.ParseIntError || error{Invalid};
pub fn walk(analyzer: *Analyzer, ast: *const Ast) WalkError!void {
    const allocator = analyzer.allocator;

    const state = analyzer.saveScratch();

    var syntax_already_found = false;
    var package_already_found = false;

    const this_decl = try analyzer.appendDecl(.root, .{});

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
            .message_decl => try analyzer.scratch.append(analyzer.allocator, try analyzer.walkMessageDecl(ast, this_decl, child)),
            .enum_decl => try analyzer.scratch.append(analyzer.allocator, try analyzer.walkEnumDecl(ast, this_decl, child)),
            else => continue,
        }
    }

    analyzer.extraData(.root, this_decl).children = try state.appendAndReset();

    if (!package_already_found)
        try analyzer.store.packages.documents.append(allocator, analyzer.document);
}

pub fn walkMessageDecl(
    analyzer: *Analyzer,
    ast: *const Ast,
    parent: u32,
    node: u32,
) WalkError!u32 {
    const allocator = analyzer.allocator;
    _ = allocator;
    std.debug.assert(ast.node_tags[node] == .message_decl);

    const state = analyzer.saveScratch();

    const name = ast.tokenSlice(ast.node_main_tokens[node]);
    const this_decl = try analyzer.appendDecl(.message_decl, .{
        .parent = parent,
        .name = try analyzer.string_pool.store(name),
    });

    const children = ast.getChildrenInExtra(node);
    for (children) |child| {
        try analyzer.scratch.append(analyzer.allocator, switch (ast.node_tags[child]) {
            .message_field_decl => try analyzer.walkMessageFieldDecl(ast, this_decl, child),
            .message_decl => try analyzer.walkMessageDecl(ast, this_decl, child),
            .enum_decl => try analyzer.walkEnumDecl(ast, this_decl, child),
            else => continue,
        });
    }

    analyzer.extraData(.message_decl, this_decl).children = try state.appendAndReset();
    return this_decl;
}

pub fn walkMessageFieldDecl(
    analyzer: *Analyzer,
    ast: *const Ast,
    parent: u32,
    node: u32,
) WalkError!u32 {
    const allocator = analyzer.allocator;
    _ = allocator;
    std.debug.assert(ast.node_tags[node] == .message_field_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);
    const data = ast.node_data[node].message_field_decl;

    return try analyzer.appendDecl(.message_field_decl, .{
        .parent = parent,
        .name = try analyzer.string_pool.store(name),

        .type = try analyzer.appendDecl(.type, switch (ast.node_tags[data.type_name_node]) {
            .builtin_type => Decl.Extra.Type{
                .tag = .builtin,
                .payload = .{
                    .builtin = ast.token_tags[ast.node_main_tokens[data.type_name_node]],
                },
            },
            .qualified_identifier => Decl.Extra.Type{
                .tag = .unresolved,
                .payload = .{
                    .unresolved = try analyzer.string_pool.store(ast.qualifiedIdentifierSlice(data.type_name_node)),
                },
            },
            else => unreachable,
        }),
        // TODO: Parse all int types properly
        .field_number = try std.fmt.parseUnsigned(u64, ast.tokenSlice(ast.node_main_tokens[node] + 2), 10),
    });
}

pub fn walkEnumDecl(
    analyzer: *Analyzer,
    ast: *const Ast,
    parent: u32,
    node: u32,
) WalkError!u32 {
    const allocator = analyzer.allocator;
    std.debug.assert(ast.node_tags[node] == .enum_decl);

    const state = analyzer.saveScratch();

    const name = ast.tokenSlice(ast.node_main_tokens[node]);

    const this_decl = try analyzer.appendDecl(.enum_decl, .{
        .parent = parent,
        .name = try analyzer.string_pool.store(name),
    });

    const children = ast.getChildrenInExtra(node);
    for (children) |child| {
        switch (ast.node_tags[child]) {
            .enum_value_decl => {
                try analyzer.scratch.append(allocator, try analyzer.walkEnumValueDecl(ast, parent, child));
            },
            else => {},
        }
    }

    analyzer.extraData(.enum_decl, this_decl).children = try state.appendAndReset();
    return this_decl;
}

pub fn walkEnumValueDecl(
    analyzer: *Analyzer,
    ast: *const Ast,
    parent: u32,
    node: u32,
) WalkError!u32 {
    std.debug.assert(ast.node_tags[node] == .enum_value_decl);

    const name = ast.tokenSlice(ast.node_main_tokens[node]);
    const data = ast.node_data[node].enum_value_decl;

    return try analyzer.appendDecl(.enum_value_decl, .{
        .parent = parent,
        .name = try analyzer.string_pool.store(name),

        // TODO: Parse all int types properly
        .value = @intFromEnum(ast.node_data[data.number_node].number_literal) * @as(i64, @intCast(try std.fmt.parseInt(u64, ast.tokenSlice(ast.node_main_tokens[data.number_node]), 0))),
    });
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
    _ = analyzer;
    // for (analyzer.top_level_decls.entries.items(.value)) |value| {
    //     switch (value.which) {
    //         .message => try analyzer.emitMessage(writer, value.index),
    //         .@"enum" => try analyzer.emitEnum(writer, value.index),
    //     }
    // }
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
    const field_types = message_field_decls_slice.items(.type);

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

    for (field_decls.entries.items(.value)) |field_decl| {
        try writer.print("{}: {s},\n", .{ std.zig.fmtId(field_names[field_decl]), field_types[field_decl] });
    }

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

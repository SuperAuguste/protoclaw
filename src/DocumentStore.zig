const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Parser = @import("Parser.zig");
const Ast = @import("Ast.zig");
const Analyzer = @import("Analyzer.zig");
const StringPool = @import("StringPool.zig");

const DocumentStore = @This();

pub const Document = struct {
    include_path: u32,
    import_path: []const u8,
    source: []const u8,

    ast: Ast,
    analyzer: Analyzer,
};

pub const Packages = struct {
    documents: std.ArrayListUnmanaged(u32) = .{},
    subpackages: PackageMap = .{},
};
pub const PackageMap = std.StringArrayHashMapUnmanaged(*Packages);

allocator: std.mem.Allocator,
string_pool: StringPool,
include_paths: std.ArrayListUnmanaged([]const u8) = .{},
documents: std.MultiArrayList(Document) = .{},
/// Used to resolve import
import_path_to_document: std.StringHashMapUnmanaged(u32) = .{},
packages: *Packages,

pub const AddIncludePathError =
    std.mem.Allocator.Error ||
    std.fs.Dir.OpenError ||
    std.fs.File.OpenError ||
    std.fs.File.ReadError ||
    std.fs.File.SeekError ||
    Parser.ParseError ||
    error{IncludePathConflict};

pub fn create(allocator: std.mem.Allocator) std.mem.Allocator.Error!*DocumentStore {
    var store = try allocator.create(DocumentStore);
    var packages = try allocator.create(Packages);
    packages.* = .{};
    store.* = .{ .allocator = allocator, .string_pool = .{ .allocator = allocator }, .packages = packages };
    return store;
}

pub fn addIncludePath(store: *DocumentStore, path: []const u8) AddIncludePathError!void {
    var dir = try std.fs.cwd().openIterableDir(path, .{});
    defer dir.close();

    try store.include_paths.append(store.allocator, path);

    var walker = try dir.walk(store.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".proto"))
            continue;

        const import_path = try store.allocator.dupe(u8, entry.path);
        if (std.fs.path.sep != '/') {
            std.mem.replaceScalar(u8, import_path, std.fs.path.sep, '/');
        }

        const gop = try store.import_path_to_document.getOrPut(store.allocator, import_path);
        if (gop.found_existing) {
            std.log.err("Include path conflict encountered while adding include path '{s}'! '{s}' already in import path mapping.", .{ path, import_path });
            return error.IncludePathConflict;
        }

        std.log.debug("Processing file {s}/{s}", .{ path, entry.path });

        const source = try entry.dir.readFileAlloc(store.allocator, entry.basename, std.math.maxInt(usize));

        var tokenizer = Tokenizer{};
        try tokenizer.tokenize(store.allocator, source);

        var parser = Parser.init(store.allocator, source, tokenizer.tokens.slice());
        const ast = parser.parse() catch |err| {
            const token = parser.token_index;
            const start = parser.token_starts[token];
            const end = parser.token_ends[token];

            std.log.err("{d}: {s}", .{ start, parser.source[start..end] });
            return err;
        };

        try store.documents.append(store.allocator, .{
            .include_path = @intCast(store.include_paths.items.len - 1),
            .import_path = import_path,
            .source = source,

            .ast = ast,
            .analyzer = .{
                .allocator = store.allocator,
                .store = store,
                .string_pool = &store.string_pool,
                .document = @intCast(store.documents.len),
            },
        });

        gop.value_ptr.* = @intCast(store.documents.len - 1);
    }
}

pub fn analyze(store: *DocumentStore) !void {
    var slice = store.documents.slice();
    const asts = slice.items(.ast);
    var analyzers = slice.items(.analyzer);

    for (asts, analyzers) |ast, *analyzer| {
        try analyzer.walk(&ast);
    }

    for (analyzers) |*analyzer| {
        try analyzer.analyze();
    }
}

pub fn emit(store: *DocumentStore, writer: anytype) !void {
    try writer.writeAll("const std = @import(\"std\");\n\n");
    try store.emitInternal(writer, store.packages);
}

fn emitInternal(store: *DocumentStore, writer: anytype, packages: *Packages) !void {
    const slice = packages.subpackages.entries.slice();
    const keys = slice.items(.key);
    const values = slice.items(.value);

    var doc_slice = store.documents.slice();
    var analyzers = doc_slice.items(.analyzer);

    for (keys, values) |key, value| {
        try writer.print("pub const {} = struct {{\n", .{std.zig.fmtId(key)});
        try store.emitInternal(writer, value);
        for (value.documents.items) |document| {
            try analyzers[document].emit(writer);
        }
        try writer.writeAll("};\n\n");
    }
}

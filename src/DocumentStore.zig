const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Parser = @import("Parser.zig");
const Ast = @import("Ast.zig");
const Analyzer = @import("Analyzer.zig");

const DocumentStore = @This();

const Document = struct {
    include_path: u32,
    import_path: []const u8,
    source: []const u8,

    ast: Ast,
    analyzer: Analyzer,
};

allocator: std.mem.Allocator,
include_paths: std.ArrayListUnmanaged([]const u8) = .{},
documents: std.MultiArrayList(Document) = .{},
/// Used to resolve import
import_path_to_document: std.StringHashMapUnmanaged(u32) = .{},

pub const AddIncludePathError =
    std.mem.Allocator.Error ||
    std.fs.Dir.OpenError ||
    std.fs.File.OpenError ||
    std.fs.File.ReadError ||
    std.fs.File.SeekError ||
    Parser.ParseError ||
    error{IncludePathConflict};

pub fn addIncludePath(store: *DocumentStore, path: []const u8) AddIncludePathError!void {
    var dir = try std.fs.cwd().openIterableDir(path, .{});
    defer dir.close();

    try store.include_paths.append(store.allocator, path);

    var walker = try dir.walk(store.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file)
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
}

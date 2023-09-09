const std = @import("std");
const Build = std.Build;
const Step = std.build.Step;
const DocumentStore = @import("../compiler/DocumentStore.zig");

const GenerateStep = @This();

pub const base_id: Step.Id = .custom;

step: Step,
name: []const u8,
includes: std.ArrayListUnmanaged(Build.LazyPath),
out: std.Build.LazyPath,
max_rss: usize,

store: *DocumentStore,

pub const Options = struct {
    name: []const u8,
    includes: []const Build.LazyPath,
    out: std.Build.LazyPath,
    max_rss: usize = 0,
};

pub fn create(owner: *std.Build, options: Options) *GenerateStep {
    const name = owner.fmt("compile protobuf {s}", .{options.name});

    var includes = std.ArrayListUnmanaged(Build.LazyPath).initCapacity(owner.allocator, options.includes.len) catch @panic("OOM");
    includes.appendSlice(owner.allocator, options.includes) catch @panic("OOM");

    const self = owner.allocator.create(GenerateStep) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = name,
            .owner = owner,
            .makeFn = make,
            .max_rss = options.max_rss,
        }),
        .name = name,
        .includes = includes,
        .out = options.out,
        .max_rss = options.max_rss,

        .store = DocumentStore.create(owner.allocator) catch @panic("OOM"),
    };
    return self;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    const owner = step.owner;
    const self = @fieldParentPtr(GenerateStep, "step", step);

    var store = self.store;
    const allocator = owner.allocator;

    for (self.includes.items) |lazy| {
        try store.addIncludePath(lazy.getPath2(owner, step));
    }

    try store.analyze();

    var list = std.ArrayList(u8).init(allocator);
    try store.emit(list.writer());

    const sentineled = try list.toOwnedSliceSentinel(0);
    defer allocator.free(sentineled);

    var ast = try std.zig.Ast.parse(allocator, sentineled, .zig);
    defer ast.deinit(allocator);

    const rendered = try ast.render(allocator);
    defer allocator.free(rendered);

    try std.fs.cwd().writeFile(self.out.getPath2(owner, step), rendered);

    prog_node.end();
}

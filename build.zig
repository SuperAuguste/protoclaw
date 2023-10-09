const std = @import("std");
const LazyPath = std.build.LazyPath;
const protoclaw = @import("src/lib.zig");

const examples = .{
    .{
        .name = "basic",
        .includes = .{"."},
        .out = "proto.zig",
    },
    .{
        .name = "scip",
        .includes = .{"."},
        .out = "scip.zig",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const protoclaw_module = b.addModule("protoclaw", .{
        .source_file = .{ .path = "src/lib.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "protoclaw",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Examples

    const test_messages_proto3_generate_step = protoclaw.GenerateStep.create(b, .{
        .name = "test_message_proto3",
        .includes = &.{ .{ .path = b.pathJoin(&.{"include"}) }, .{ .path = b.pathJoin(&.{"test"}) } },
        .out = .{ .path = b.pathJoin(&.{ "test", "test_message_proto3.zig" }) },
    });
    b.getInstallStep().dependOn(&test_messages_proto3_generate_step.step);

    inline for (examples) |example| {
        var includes: [example.includes.len]LazyPath = undefined;
        inline for (&includes, 0..) |*v, i| v.* = .{ .path = b.pathJoin(&.{ "examples", example.name, example.includes[i] }) };

        const example_generate_step = protoclaw.GenerateStep.create(b, .{
            .name = example.name,
            .includes = &includes,
            .out = .{ .path = b.pathJoin(&.{ "examples", example.name, example.out }) },
        });

        b.getInstallStep().dependOn(&example_generate_step.step);

        const example_exe = b.addExecutable(.{
            .name = "example-" ++ example.name,
            .root_source_file = .{ .path = "examples/" ++ example.name ++ "/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        example_exe.addModule("protoclaw", protoclaw_module);
        b.installArtifact(example_exe);

        const example_run_cmd = b.addRunArtifact(example_exe);
        example_run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            example_run_cmd.addArgs(args);
        }

        const run_example_step = b.step("run-example-" ++ example.name, "Run example " ++ example.name);
        run_example_step.dependOn(&example_run_cmd.step);
    }
}

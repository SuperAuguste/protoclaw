const std = @import("std");
const LazyPath = std.build.LazyPath;
const protoclaw = @import("src/lib.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const example_generate_step = protoclaw.GenerateStep.create(b, .{
        .name = "basic",
        .include = &.{
            .{ .path = "examples/basic" },
        },
        .out = .{ .path = "examples/basic/proto.zig" },
    });

    const example_step = b.step("example", "Run example");
    example_step.dependOn(&example_generate_step.step);
}

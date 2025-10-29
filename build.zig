const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("cronz", .{
        .root_source_file = b.path("src/cronz.zig"),
        .target = target,
        .optimize = optimize,
    });

    const regexp = b.dependency("regex", .{});
    module.addImport("regexp", regexp.module("regex"));

    const zdt = b.dependency("zdt", .{});
    module.addImport("zdt", zdt.module("zdt"));

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/cronz.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("cronz", module);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_exe_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

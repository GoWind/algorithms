const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const optimizeOption = b.standardOptimizeOption(.{});
    // exe artifact for recursive version
    const exe = b.addExecutable(.{
        .name = "avl-zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimizeOption,
    });
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });

    const perfInstrumentation = b.dependency("zig_mac_perf_events", .{});
    exe.addModule("perfLib", perfInstrumentation.module("perfLib"));

    // exe artifact for iterative version
    const iterableExe = b.addExecutable(.{
        .name = "avl-zig-iter",
        .root_source_file = .{ .path = "src/iter.zig" },
        .optimize = optimizeOption,
    });
    iterableExe.addModule("perfLib", perfInstrumentation.module("perfLib"));
    const run_cmd = b.addRunArtifact(exe);
    const run_iter_example = b.addRunArtifact(iterableExe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    run_step.dependOn(&run_iter_example.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    b.installArtifact(exe);
    b.installArtifact(iterableExe);
}

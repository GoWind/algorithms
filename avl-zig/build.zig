const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const optimizeOption = b.standardOptimizeOption(.{});
    _ = b.option(bool, "enable_perf_instrument", "instrument cpu perf counters");

    //Set up a struct to hold options passed during build calls (zig build --) to our code
    const buildOptions = b.addOptions();
    var enableInstrumentation = false;
    if (b.args) |args| {
        for (args) |arg| {
            if (std.mem.eql(u8, arg, "enable_perf_instrument")) {
                enableInstrumentation = true;
            }
        }
    }
    buildOptions.addOption(bool, "enable_perf_instrument", enableInstrumentation);
    // exe artifact for recursive version
    const exe = b.addExecutable(.{
        .name = "avl-zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimizeOption,
    });
    // @import("build_options") will provide the options passed during our build
    // to our code
    // this is expected to change in the future to exe.root_module.options in the future
    exe.addOptions("build_options", buildOptions);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });

    const perfInstrumentation = b.dependency("zig_mac_perf_events", .{});

    // @import("perfLib") will provide the perf library in our code
    exe.addModule("perfLib", perfInstrumentation.module("perfLib"));

    // exe artifact for iterative version
    const iterableExe = b.addExecutable(.{
        .name = "avl-zig-iter",
        .root_source_file = .{ .path = "src/iter.zig" },
        .optimize = optimizeOption,
    });
    iterableExe.addModule("perfLib", perfInstrumentation.module("perfLib"));

    // @import("build_options") will provide the options passed during our build
    // to our code
    // this is expected to change in the future to exe.root_module.options in the future
    iterableExe.addOptions("build_options", buildOptions);

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

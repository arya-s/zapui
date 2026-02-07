const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main zapui library module
    const zapui_mod = b.addModule("zapui", .{
        .root_source_file = b.path("src/zapui.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add system library paths for OpenGL headers
    zapui_mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

    // Library artifact (for linking)
    const lib = b.addLibrary(.{
        .name = "zapui",
        .root_module = zapui_mod,
    });
    b.installArtifact(lib);

    // Create a module for tests (without GL - just core types)
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/zapui.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Playground module
    const playground_mod = b.createModule(.{
        .root_source_file = b.path("playground/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    playground_mod.addImport("zapui", zapui_mod);

    // Playground executable for development testing
    const playground = b.addExecutable(.{
        .name = "playground",
        .root_module = playground_mod,
    });

    // Link system libraries for playground
    playground.linkSystemLibrary("GL");
    playground.linkSystemLibrary("glfw");
    playground.linkLibC();

    b.installArtifact(playground);

    const run_playground = b.addRunArtifact(playground);
    run_playground.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_playground.addArgs(args);
    }
    const run_step = b.step("run", "Run the playground");
    run_step.dependOn(&run_playground.step);
}

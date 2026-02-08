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
    // Add vendor directory for stb headers
    zapui_mod.addIncludePath(b.path("src"));

    // Compile stb_truetype
    zapui_mod.addCSourceFile(.{
        .file = b.path("src/vendor/stb_truetype.c"),
        .flags = &.{"-std=c99"},
    });
    zapui_mod.link_libc = true;

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
    test_mod.addIncludePath(b.path("src"));
    test_mod.addCSourceFile(.{
        .file = b.path("src/vendor/stb_truetype.c"),
        .flags = &.{"-std=c99"},
    });
    test_mod.link_libc = true;

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });
    lib_unit_tests.linkLibC();
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

    // Taffy demo
    const taffy_demo_mod = b.createModule(.{
        .root_source_file = b.path("examples/taffy_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    taffy_demo_mod.addImport("zapui", zapui_mod);

    const taffy_demo = b.addExecutable(.{
        .name = "taffy_demo",
        .root_module = taffy_demo_mod,
    });

    taffy_demo.linkSystemLibrary("GL");
    taffy_demo.linkSystemLibrary("glfw");
    taffy_demo.linkLibC();

    b.installArtifact(taffy_demo);

    const run_taffy_demo = b.addRunArtifact(taffy_demo);
    run_taffy_demo.step.dependOn(b.getInstallStep());
    const taffy_step = b.step("taffy-demo", "Run the Taffy layout demo");
    taffy_step.dependOn(&run_taffy_demo.step);

    // Taffy visual demo
    const taffy_visual_mod = b.createModule(.{
        .root_source_file = b.path("examples/taffy_visual.zig"),
        .target = target,
        .optimize = optimize,
    });
    taffy_visual_mod.addImport("zapui", zapui_mod);

    const taffy_visual = b.addExecutable(.{
        .name = "taffy_visual",
        .root_module = taffy_visual_mod,
    });

    taffy_visual.linkSystemLibrary("GL");
    taffy_visual.linkSystemLibrary("glfw");
    taffy_visual.linkLibC();

    b.installArtifact(taffy_visual);

    const run_taffy_visual = b.addRunArtifact(taffy_visual);
    run_taffy_visual.step.dependOn(b.getInstallStep());
    const taffy_visual_step = b.step("taffy-visual", "Run the Taffy visual demo");
    taffy_visual_step.dependOn(&run_taffy_visual.step);
}

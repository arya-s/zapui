const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get FreeType with libpng enabled for color emoji support
    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
        .@"enable-libpng" = true,
    });

    // Get zglfw (cross-platform GLFW)
    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    // Get zopengl (cross-platform OpenGL bindings)
    const zopengl_dep = b.dependency("zopengl", .{
        .target = target,
    });

    // Get zigwin32 (Win32 API bindings for Windows platform)
    const zigwin32_dep = b.dependency("zigwin32", .{});

    // Build HarfBuzz manually so we can share the freetype module (avoids module conflicts)
    const harfbuzz_upstream = b.dependency("harfbuzz", .{});
    const hb_lib = buildHarfbuzzLib(b, target, optimize, harfbuzz_upstream, freetype_dep);

    // Create HarfBuzz Zig wrapper module that shares our freetype module
    const harfbuzz_mod = b.addModule("harfbuzz", .{
        .root_source_file = b.path("pkg/harfbuzz/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "freetype", .module = freetype_dep.module("freetype") },
        },
    });
    // Add HarfBuzz include path for hb.h
    if (harfbuzz_upstream.builder.lazyDependency("harfbuzz", .{})) |upstream| {
        harfbuzz_mod.addIncludePath(upstream.path("src"));
    }
    // Add FreeType include path for ft2build.h (needed by hb-ft.h)
    if (freetype_dep.builder.lazyDependency("freetype", .{})) |ft_upstream| {
        harfbuzz_mod.addIncludePath(ft_upstream.path("include"));
    }
    const hb_options = b.addOptions();
    hb_options.addOption(bool, "coretext", false);
    hb_options.addOption(bool, "freetype", true);
    harfbuzz_mod.addOptions("build_options", hb_options);

    // Main zapui library module
    const zapui_mod = b.addModule("zapui", .{
        .root_source_file = b.path("src/zapui.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "freetype", .module = freetype_dep.module("freetype") },
            .{ .name = "harfbuzz", .module = harfbuzz_mod },
            .{ .name = "zglfw", .module = zglfw_dep.module("root") },
            .{ .name = "zopengl", .module = zopengl_dep.module("root") },
            .{ .name = "win32", .module = zigwin32_dep.module("win32") },
        },
    });

    zapui_mod.link_libc = true;

    // Library artifact (for linking)
    const lib = b.addLibrary(.{
        .name = "zapui",
        .root_module = zapui_mod,
    });

    // Link FreeType and HarfBuzz
    lib.linkLibrary(freetype_dep.artifact("freetype"));
    lib.linkLibrary(hb_lib);

    b.installArtifact(lib);

    // Create a module for tests (without GL - just core types)
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/zapui.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "freetype", .module = freetype_dep.module("freetype") },
            .{ .name = "harfbuzz", .module = harfbuzz_mod },
        },
    });
    test_mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    test_mod.link_libc = true;

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });
    lib_unit_tests.linkLibC();
    lib_unit_tests.linkLibrary(freetype_dep.artifact("freetype"));
    lib_unit_tests.linkLibrary(hb_lib);
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
    playground_mod.addImport("zglfw", zglfw_dep.module("root"));
    playground_mod.addImport("zopengl", zopengl_dep.module("root"));

    // Playground executable for development testing
    const playground = b.addExecutable(.{
        .name = "playground",
        .root_module = playground_mod,
    });

    // Link zglfw library
    playground.linkLibrary(zglfw_dep.artifact("glfw"));
    playground.linkLibC();
    playground.linkLibrary(freetype_dep.artifact("freetype"));
    playground.linkLibrary(hb_lib);

    b.installArtifact(playground);

    const run_playground = b.addRunArtifact(playground);
    run_playground.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_playground.addArgs(args);
    }
    const run_step = b.step("run", "Run the playground");
    run_step.dependOn(&run_playground.step);

    // Hello World example (GPUI port) - Win32 + D3D11
    const hello_world_mod = b.createModule(.{
        .root_source_file = b.path("examples/gpui_ports/hello_world/hello_world.zig"),
        .target = target,
        .optimize = optimize,
    });
    hello_world_mod.addImport("zapui", zapui_mod);
    hello_world_mod.addImport("freetype", freetype_dep.module("freetype"));

    const hello_world = b.addExecutable(.{
        .name = "hello_world",
        .root_module = hello_world_mod,
    });

    hello_world.linkLibC();
    hello_world.linkLibrary(freetype_dep.artifact("freetype"));
    hello_world.linkLibrary(hb_lib);

    b.installArtifact(hello_world);

    const hello_world_step = b.step("hello-world", "Build Hello World (Win32 + D3D11)");
    hello_world_step.dependOn(b.getInstallStep());

    // Shadow example (GPUI port) - Win32 + D3D11
    const shadow_mod = b.createModule(.{
        .root_source_file = b.path("examples/gpui_ports/shadow/shadow.zig"),
        .target = target,
        .optimize = optimize,
    });
    shadow_mod.addImport("zapui", zapui_mod);
    shadow_mod.addImport("freetype", freetype_dep.module("freetype"));

    const shadow = b.addExecutable(.{
        .name = "shadow",
        .root_module = shadow_mod,
    });

    shadow.linkLibC();
    shadow.linkLibrary(freetype_dep.artifact("freetype"));
    shadow.linkLibrary(hb_lib);

    b.installArtifact(shadow);

    const shadow_step = b.step("shadow", "Build Shadow example (Win32 + D3D11)");
    shadow_step.dependOn(b.getInstallStep());

    // Zaffy demo
    const zaffy_demo_mod = b.createModule(.{
        .root_source_file = b.path("examples/zaffy_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    zaffy_demo_mod.addImport("zapui", zapui_mod);
    zaffy_demo_mod.addImport("zglfw", zglfw_dep.module("root"));
    zaffy_demo_mod.addImport("zopengl", zopengl_dep.module("root"));

    const zaffy_demo = b.addExecutable(.{
        .name = "zaffy_demo",
        .root_module = zaffy_demo_mod,
    });

    zaffy_demo.linkLibrary(zglfw_dep.artifact("glfw"));
    zaffy_demo.linkLibC();
    zaffy_demo.linkLibrary(freetype_dep.artifact("freetype"));
    zaffy_demo.linkLibrary(hb_lib);

    b.installArtifact(zaffy_demo);

    const run_zaffy_demo = b.addRunArtifact(zaffy_demo);
    run_zaffy_demo.step.dependOn(b.getInstallStep());
    const zaffy_step = b.step("zaffy-demo", "Run the Zaffy layout demo");
    zaffy_step.dependOn(&run_zaffy_demo.step);

    // Zaffy visual demo
    const zaffy_visual_mod = b.createModule(.{
        .root_source_file = b.path("examples/zaffy_visual.zig"),
        .target = target,
        .optimize = optimize,
    });
    zaffy_visual_mod.addImport("zapui", zapui_mod);
    zaffy_visual_mod.addImport("zglfw", zglfw_dep.module("root"));
    zaffy_visual_mod.addImport("zopengl", zopengl_dep.module("root"));

    const zaffy_visual = b.addExecutable(.{
        .name = "zaffy_visual",
        .root_module = zaffy_visual_mod,
    });

    zaffy_visual.linkLibrary(zglfw_dep.artifact("glfw"));
    zaffy_visual.linkLibC();
    zaffy_visual.linkLibrary(freetype_dep.artifact("freetype"));
    zaffy_visual.linkLibrary(hb_lib);

    b.installArtifact(zaffy_visual);

    const run_zaffy_visual = b.addRunArtifact(zaffy_visual);
    run_zaffy_visual.step.dependOn(b.getInstallStep());
    const zaffy_visual_step = b.step("zaffy-visual", "Run the Zaffy visual demo");
    zaffy_visual_step.dependOn(&run_zaffy_visual.step);
}

/// Build HarfBuzz C++ library from source, linking against our shared FreeType
fn buildHarfbuzzLib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hb_dep: *std.Build.Dependency,
    ft_dep: *std.Build.Dependency,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "harfbuzz",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.linkLibC();
    lib.linkLibCpp();

    var flags: std.ArrayList([]const u8) = .empty;
    defer flags.deinit(b.allocator);
    flags.appendSlice(b.allocator, &.{
        "-DHAVE_STDBOOL_H",
        "-DHAVE_FREETYPE=1",
        "-DHAVE_FT_GET_VAR_BLEND_COORDINATES=1",
        "-DHAVE_FT_SET_VAR_BLEND_COORDINATES=1",
        "-DHAVE_FT_DONE_MM_VAR=1",
        "-DHAVE_FT_GET_TRANSFORM=1",
    }) catch @panic("OOM");

    if (target.result.os.tag != .windows) {
        flags.appendSlice(b.allocator, &.{
            "-DHAVE_UNISTD_H",
            "-DHAVE_SYS_MMAN_H",
            "-DHAVE_PTHREAD=1",
        }) catch @panic("OOM");
    }

    // Link our shared FreeType
    lib.linkLibrary(ft_dep.artifact("freetype"));

    // Compile HarfBuzz C++ source
    if (hb_dep.builder.lazyDependency("harfbuzz", .{})) |upstream| {
        lib.addIncludePath(upstream.path("src"));
        lib.addCSourceFile(.{
            .file = upstream.path("src/harfbuzz.cc"),
            .flags = flags.items,
        });
    }

    return lib;
}

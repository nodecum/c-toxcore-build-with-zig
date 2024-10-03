const std = @import("std");
const params = @import("src/params.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_toxcore_dep = b.dependency("c-toxcore", .{});

    const libsodium_dep = b.dependency(
        "libsodium",
        .{ .target = target, .optimize = optimize, .static = true, .shared = false },
    );
    const libsodium = libsodium_dep.artifact("sodium");
    //    const gtest_dep = b.dependency("gtest", .{ .target = target, .optimize = optimize });
    const cmp_dep = b.dependency("cmp", .{});

    // create file tree for c-toxcore
    const include_h_c = std.Build.Step.WriteFile.Directory.Options{ .include_extensions = &.{ ".h", ".c" } };
    const wf = b.addNamedWriteFiles("c-toxcore");
    const toxcore_dir = wf.addCopyDirectory(c_toxcore_dep.path("toxcore"), "toxcore", include_h_c);
    _ = wf.addCopyDirectory(c_toxcore_dep.path("toxencryptsave"), "toxencryptsave", include_h_c);
    _ = wf.addCopyDirectory(cmp_dep.path(""), "third_party/cmp", include_h_c);
    //_ = wf.addCopyFile(c_toxcore_dep.path("CMakeLists.txt"),"CMakeLists.txt");
    const root = wf.getDirectory();

    const lib = b.addStaticLibrary(.{
        .name = "c-toxcore",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib.addCSourceFiles(.{
        .root = root,
        .files = params.c_sources,
    });
    lib.addIncludePath(toxcore_dir);
    lib.installHeadersDirectory(toxcore_dir, "toxcore", .{ .exclude_extensions = &.{".c"} });
    lib.linkLibrary(libsodium);
    b.installArtifact(lib);

    // lib compilation depends on file tree
    lib.step.dependOn(&wf.step);

    // ----- build zig wrapper
    const tox_zig_step = b.step("tox_zig", "Build Zig wrappers around toxcore API");
    // translate-c the tox.h file
    const tox_h = toxcore_dir.path(b, "tox.h");
    const tox_zig = b.addTranslateC(.{
        .root_source_file = tox_h,
        .target = b.host,
        .optimize = optimize,
    });
    tox_zig.addIncludePath(toxcore_dir);
    tox_zig_step.dependOn(&tox_zig.step);
    tox_zig_step.dependOn(&b.addInstallFile(tox_zig.getOutput(), "tox.zig").step);

    const entrypoint = tox_zig.getOutput();

    // build cimgui as a module with the header file as the entrypoint
    const mod_c_toxcore = b.addModule("c-toxcore", .{
        .root_source_file = entrypoint,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod_c_toxcore.linkLibrary(lib);

    // we have to read the CMakeLists.txt file
    // to achieve this we copy the dependency to
    // tmp/CMakeLists.txt
    const CMakeLists_orig = c_toxcore_dep.path("CMakeLists.txt");
    const CMakeLists_install = b.addInstallFileWithDir(CMakeLists_orig, .{ .custom = "tmp" }, "CMakeLists.txt");

    const extract_build_params = b.addExecutable(.{
        .name = "extract_build_params",
        .root_source_file = b.path("src/extract_build_params.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(extract_build_params);
    const run_extract = b.addRunArtifact(extract_build_params);

    run_extract.addArg("--cmake-lists");
    run_extract.addArg("zig-out/tmp/CMakeLists.txt");
    run_extract.addArg("--params-zig");
    run_extract.addArg("src/params.zig");

    run_extract.step.dependOn(&CMakeLists_install.step);
    const run_step = b.step("update", "Update C sources");
    run_step.dependOn(&run_extract.step);
}

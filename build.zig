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

    const lib = b.addStaticLibrary(.{
        .name = "c-toxcore-build-with-zig",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    inline for (params.c_sources) |s| {
        if (std.mem.startsWith(u8, s, "third_party/cmp")) {
            const orig = cmp_dep.path(std.fs.path.basename(s));
            const install = b.addInstallFileWithDir(orig, .{ .custom = "tmp" }, s);
            lib.step.dependOn(&install.step);
        } else {
            const orig = c_toxcore_dep.path(s);
            const install = b.addInstallFileWithDir(orig, .{ .custom = "tmp" }, s);
            lib.step.dependOn(&install.step);
        }
        if (std.mem.endsWith(u8, s, ".c")) {
            lib.addCSourceFile(.{ .file = b.path("zig-out/tmp").path(b, s) });
        }
    }
    lib.addIncludePath(b.path("zig-out/tmp/toxcore"));
    lib.installHeadersDirectory(b.path("zig-out/tmp/toxcore"), "toxcore", .{ .exclude_extensions = &.{".c"} });
    lib.linkLibrary(libsodium);
    b.installArtifact(lib);

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
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_extract.step);
}

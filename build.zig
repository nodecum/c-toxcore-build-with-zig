const std = @import("std");
const params = @import("src/params.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_toxcore_dep = b.dependency("c-toxcore", .{
        //        .target = target,
        //        .optimize = optimize,
    });

    const libsodium_dep = b.dependency(
        "libsodium",
        .{ .target = target, .optimize = optimize, .static = true, .shared = false },
    );
    const libsodium = libsodium_dep.artifact("sodium");
    //    const gtest_dep = b.dependency("gtest", .{ .target = target, .optimize = optimize });
    const cmp_dep = b.dependency("cmp", .{});
    // we copy the third_party dependencies into the source tree
    // not an ideal solution but we need them there and git
    // submodule want work for zig dependency snapshots.
    //    const copy_files = b.addWriteFiles();
    //    _ = copy_files.addCopyFileToSource(
    //        .{ .dependency = .{ .dependency = cmp_dep, .sub_path = "cmp.c" } },
    //        "third_party/cmp/cmp.c",
    //    );
    //    _ = copy_files.addCopyFileToSource(
    //        .{ .dependency = .{ .dependency = cmp_dep, .sub_path = "cmp.h" } },
    //        "third_party/cmp/cmp.h",
    //    );

    const lib = b.addStaticLibrary(.{
        .name = "build-c-toxcore-with-zig",
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
    //lib.addIncludePath(curl_dep.path("include"));   // This declares intent for the library to be installed into the standard
    lib.installHeader(b.path("zig-out/tmp/toxcore/tox.h"), "tox.h");
    lib.installHeadersDirectory(b.path("zig-out/tmp/toxcore"), "toxcore", .{ .exclude_extensions = &.{".c"} });
    lib.linkLibrary(libsodium);
    b.installArtifact(lib);

    //lib.addCSourceFiles(.{ .files = params.c_sources });
    //lib.step.dependOn(&copy_files.step);

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
    //run_extract.step.dependOn(b.getInstallStep());
    lib.step.dependOn(&run_extract.step);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_extract.step);
}

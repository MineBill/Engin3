const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const tracy_client = b.addStaticLibrary(.{
        .name = "tracy",
        .target = target,
        .optimize = mode,
    });
    tracy_client.linkLibCpp();
    tracy_client.want_lto = false;
    tracy_client.addCSourceFiles(.{
        .files = &.{
            "tracy/public/TracyClient.cpp",
        }, 
        .flags = &.{
            "-DTRACY_ENABLE",
            "-fno-sanitize=undefined",
            "-D_WIN32_WINNT=0x601",
        }
    });

    if (target.query.os_tag == .windows) {
        tracy_client.linkSystemLibrary("dbghelp");
        tracy_client.linkSystemLibrary("ws2_32");
    }

    b.installArtifact(tracy_client);
}

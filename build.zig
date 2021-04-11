const std = @import("std");

const pkgs = struct {
    const tvg = std.build.Pkg{};
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const render = b.addExecutable("tvg-render", "src/tools/render.zig");
    render.setBuildMode(mode);
    render.setTarget(target);
    render.install();

    const dump = b.addExecutable("tvg-dump", "src/tools/dump.zig");
    dump.setBuildMode(mode);
    dump.setTarget(target);
    dump.install();

    const tvg_tests = b.addTest("src/lib/tvg.zig");

    const test_step = b.step("test", "Runs all tests");
    test_step.dependOn(&tvg_tests.step);
}

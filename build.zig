const std = @import("std");

const pkgs = struct {
    const tvg = std.build.Pkg{
        .name = "tvg",
        .path = "src/lib/tvg.zig",
    };
    const args = std.build.Pkg{
        .name = "args",
        .path = "lib/zig-args/args.zig",
    };
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const enable_dotnet = b.option(bool, "enable-dotnet", "Enables building the .NET based tools.") orelse false;

    if (enable_dotnet) {
        const svg2cs = b.addSystemCommand(&[_][]const u8{
            "mcs",
            "/out:zig-cache/bin/svg2tvg.exe",
            "src/tools/svg2tvg.cs",
        });
        b.getInstallStep().dependOn(&svg2cs.step);
    }

    const render = b.addExecutable("tvg-render", "src/tools/render.zig");
    render.setBuildMode(mode);
    render.setTarget(target);
    render.addPackage(pkgs.tvg);
    render.addPackage(pkgs.args);
    render.install();

    const text = b.addExecutable("tvg-text", "src/tools/text.zig");
    text.setBuildMode(mode);
    text.setTarget(target);
    text.addPackage(pkgs.tvg);
    text.addPackage(pkgs.args);
    text.install();

    const ground_truth_generator = b.addExecutable("ground-truth-generator", "src/data/ground-truth.zig");
    ground_truth_generator.setBuildMode(mode);
    ground_truth_generator.setTarget(target);
    ground_truth_generator.addPackage(pkgs.tvg);
    ground_truth_generator.install();

    const generate_ground_truth = ground_truth_generator.run();

    const gen_gt_step = b.step("generate", "Regenerates the ground truth data.");
    gen_gt_step.dependOn(&generate_ground_truth.step);

    const files = [_][]const u8{
        "app_menu.tvg", "shield.tvg", "shield-8.tvg", "workspace.tvg", "workspace_add.tvg", "feature-showcase.tvg",
    };
    inline for (files) |file| {
        const tvg_conversion = render.run();
        tvg_conversion.addArg(file);
        tvg_conversion.addArg("--output");
        tvg_conversion.addArg(file[0 .. file.len - 3] ++ "ppm");
        tvg_conversion.cwd = "examples";

        const tvgt_conversion = text.run();
        tvgt_conversion.addArg(file);
        tvgt_conversion.addArg("--output");
        tvgt_conversion.addArg(file[0 .. file.len - 3] ++ "tvgt");
        tvgt_conversion.cwd = "examples";

        const png_conversion = b.addSystemCommand(&[_][]const u8{
            "convert",
            "-strip",
            file[0 .. file.len - 3] ++ "ppm",
            file[0 .. file.len - 3] ++ "png",
        });
        png_conversion.cwd = "examples";
        png_conversion.step.dependOn(&tvg_conversion.step);

        gen_gt_step.dependOn(&tvgt_conversion.step);
        gen_gt_step.dependOn(&png_conversion.step);
    }

    const tvg_tests = b.addTest("src/lib/tvg.zig");
    tvg_tests.addPackage(std.build.Pkg{
        .name = "ground-truth",
        .path = "src/data/ground-truth.zig",
        .dependencies = &[_]std.build.Pkg{
            pkgs.tvg,
        },
    });

    const test_step = b.step("test", "Runs all tests");
    test_step.dependOn(&tvg_tests.step);
}

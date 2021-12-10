const std = @import("std");

const pkgs = struct {
    const tvg = std.build.Pkg{
        .name = "tvg",
        .path = .{ .path = "src/lib/tvg.zig" },
        .dependencies = &.{ptk},
    };
    const args = std.build.Pkg{
        .name = "args",
        .path = .{ .path = "vendor/zig-args/args.zig" },
    };
    const ptk = std.build.Pkg{
        .name = "ptk",
        .path = .{ .path = "vendor/parser-toolkit/src/main.zig" },
    };
};

pub fn build(b: *std.build.Builder) !void {
    const is_release = b.option(bool, "release", "Prepares a release build") orelse false;

    const target = b.standardTargetOptions(.{});
    const mode = if (is_release) .ReleaseSafe else b.standardReleaseOptions();

    const enable_dotnet = b.option(bool, "enable-dotnet", "Enables building the .NET based tools.") orelse false;
    if (enable_dotnet) {
        const svg2cs = b.addSystemCommand(&[_][]const u8{
            "csc",
            "/main:Application",
            "/debug",
            "/out:zig-out/bin/svg2tvg.exe",
            "/r:System.Drawing.dll",
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
    text.addPackage(pkgs.ptk);
    text.install();

    const ground_truth_generator = b.addExecutable("ground-truth-generator", "src/data/ground-truth.zig");
    ground_truth_generator.setBuildMode(mode);
    ground_truth_generator.setTarget(target);
    ground_truth_generator.addPackage(pkgs.tvg);
    if (!is_release) {
        ground_truth_generator.install();
    }

    const generate_ground_truth = ground_truth_generator.run();

    const gen_gt_step = b.step("generate", "Regenerates the ground truth data.");
    gen_gt_step.dependOn(&generate_ground_truth.step);

    const files = [_][]const u8{
        // "app_menu.tvg",  "workspace.tvg", "workspace_add.tvg", "feature-showcase.tvg", "arc-variants.tvg", ,
        "shield-16.tvg",  "shield-8.tvg",      "shield-32.tvg",
        "everything.tvg", "everything-32.tvg",
    };
    inline for (files) |file| {
        const tvg_conversion = render.run();
        tvg_conversion.addArg(file);
        tvg_conversion.addArg("--super-sampling");
        tvg_conversion.addArg("4"); // 16 times multisampling
        tvg_conversion.addArg("--output");
        tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
        tvg_conversion.cwd = "examples";

        const tvgt_conversion = text.run();
        tvgt_conversion.addArg(file);
        tvgt_conversion.addArg("--output");
        tvgt_conversion.addArg(file[0 .. file.len - 3] ++ "tvgt");
        tvgt_conversion.cwd = "examples";

        const png_conversion = b.addSystemCommand(&[_][]const u8{
            "convert",
            "-strip",
            file[0 .. file.len - 3] ++ "tga",
            file[0 .. file.len - 3] ++ "png",
        });
        png_conversion.cwd = "examples";
        png_conversion.step.dependOn(&tvg_conversion.step);

        gen_gt_step.dependOn(&tvgt_conversion.step);
        gen_gt_step.dependOn(&png_conversion.step);
    }
    {
        const tvg_tests = b.addTest("src/lib/tvg.zig");
        tvg_tests.addPackage(std.build.Pkg{
            .name = "ground-truth",
            .path = .{ .path = "src/data/ground-truth.zig" },
            .dependencies = &[_]std.build.Pkg{
                pkgs.tvg,
            },
        });

        const test_step = b.step("test", "Runs all tests");
        test_step.dependOn(&tvg_tests.step);
    }
    {
        const merge_covs = b.addSystemCommand(&[_][]const u8{
            "kcov",
            "--merge",
            b.pathFromRoot("kcov-output"),
            b.pathFromRoot("kcov-output"),
        });
        inline for (files) |file| {
            merge_covs.addArg(b.pathJoin(&[_][]const u8{ b.pathFromRoot("kcov-output"), file }));
        }

        const tvg_coverage = b.addTest("src/lib/tvg.zig");
        tvg_coverage.addPackage(std.build.Pkg{
            .name = "ground-truth",
            .path = .{ .path = "src/data/ground-truth.zig" },
            .dependencies = &[_]std.build.Pkg{
                pkgs.tvg,
            },
        });
        tvg_coverage.setExecCmd(&[_]?[]const u8{
            "kcov",
            "--exclude-path=~/software/zig-current",
            b.pathFromRoot("kcov-output"), // output dir for kcov
            null, // to get zig to use the --test-cmd-bin flag
        });

        const generator_coverage = b.addSystemCommand(&[_][]const u8{
            "kcov",
            "--exclude-path=~/software/zig-current",
            b.pathFromRoot("kcov-output"), // output dir for kcov
        });
        generator_coverage.addArtifactArg(ground_truth_generator);

        inline for (files) |file| {
            const tvg_conversion = b.addSystemCommand(&[_][]const u8{
                "kcov",
                "--exclude-path=~/software/zig-current",
                b.pathJoin(&[_][]const u8{ b.pathFromRoot("kcov-output"), file }), // output dir for kcov
            });
            tvg_conversion.addArtifactArg(render);
            tvg_conversion.addArg(file);
            tvg_conversion.addArg("--output");
            tvg_conversion.addArg(file[0 .. file.len - 3] ++ "tga");
            tvg_conversion.cwd = "examples";

            merge_covs.step.dependOn(&tvg_conversion.step);
        }

        merge_covs.step.dependOn(&tvg_coverage.step);
        merge_covs.step.dependOn(&generator_coverage.step);

        const coverage_step = b.step("coverage", "Generates ground truth and runs all tests with kcov");
        coverage_step.dependOn(&merge_covs.step);
    }
}

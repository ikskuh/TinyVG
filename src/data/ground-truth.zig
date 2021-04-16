const std = @import("std");
const tvg = @import("tvg");

pub fn main() !void {
    try std.fs.cwd().writeFile("examples/app_menu.tvg", &app_menu);
    try std.fs.cwd().writeFile("examples/workspace.tvg", &workspace);
    try std.fs.cwd().writeFile("examples/workspace_add.tvg", &workspace_add);
    try std.fs.cwd().writeFile("examples/shield.tvg", &shield);
    try std.fs.cwd().writeFile("examples/feature-showcase.tvg", &feature_showcase);
}

const builder = tvg.builder(.@"1/256");
const builder_16 = tvg.builder(.@"1/16");

const app_menu = blk: {
    @setEvalBranchQuota(10_000);

    break :blk builder.header(48, 48) ++
        builder.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("000000") catch unreachable,
    }) ++
        builder.fillPolygonFlat(4, 0) ++
        builder.point(6, 12) ++
        builder.point(42, 12) ++
        builder.point(42, 16) ++
        builder.point(6, 16) ++
        builder.fillPolygonFlat(4, 0) ++
        builder.point(6, 22) ++
        builder.point(42, 22) ++
        builder.point(42, 26) ++
        builder.point(6, 26) ++
        builder.fillPolygonFlat(4, 0) ++
        builder.point(6, 32) ++
        builder.point(42, 32) ++
        builder.point(42, 36) ++
        builder.point(6, 36) ++
        builder.end_of_document;
};

const workspace = blk: {
    @setEvalBranchQuota(10_000);

    break :blk builder.header(48, 48) ++
        builder.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("008751") catch unreachable,
        tvg.Color.fromString("83769c") catch unreachable,
        tvg.Color.fromString("1d2b53") catch unreachable,
    }) ++
        builder.fillRectanglesFlat(1, 0) ++
        builder.rectangle(6, 6, 16, 36) ++
        builder.fillRectanglesFlat(1, 1) ++
        builder.rectangle(26, 6, 16, 16) ++
        builder.fillRectanglesFlat(1, 2) ++
        builder.rectangle(26, 26, 16, 16) ++
        builder.end_of_document;
};

const workspace_add = blk: {
    @setEvalBranchQuota(10_000);

    break :blk builder.header(48, 48) ++
        builder.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("008751") catch unreachable,
        tvg.Color.fromString("83769c") catch unreachable,
        tvg.Color.fromString("ff004d") catch unreachable,
    }) ++
        builder.fillRectanglesFlat(1, 0) ++
        builder.rectangle(6, 6, 16, 36) ++
        builder.fillRectanglesFlat(1, 1) ++
        builder.rectangle(26, 6, 16, 16) ++
        builder.fillPathFlat(11, 2) ++
        builder.point(26, 32) ++
        builder.path.horiz(32) ++
        builder.path.vert(26) ++
        builder.path.horiz(36) ++
        builder.path.vert(32) ++
        builder.path.horiz(42) ++
        builder.path.vert(36) ++
        builder.path.horiz(36) ++
        builder.path.vert(42) ++
        builder.path.horiz(32) ++
        builder.path.vert(36) ++
        builder.path.horiz(26) ++
        builder.end_of_document;
};

const shield = blk: {
    @setEvalBranchQuota(10_000);
    break :blk builder.header(24, 24) ++
        builder.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("29adff") catch unreachable,
        tvg.Color.fromString("fff1e8") catch unreachable,
    }) ++
        builder.fillPathFlat(5, 0) ++
        builder.point(12, 1) ++ // M 12 1
        builder.path.line(3, 5) ++ // L 3 5
        builder.path.vert(11) ++ // V 11
        builder.path.bezier(3, 16.55, 6.84, 21.74, 12, 23) ++ // C 3     16.55 6.84 21.74 12 23
        builder.path.bezier(17.16, 21.74, 21, 16.55, 21, 11) ++ // C 17.16 21.74 21   16.55 21 11
        builder.path.vert(5) ++ // V 5
        builder.fillPathFlat(6, 1) ++
        builder.point(17.13, 17) ++ // M 12 1
        builder.path.bezier(15.92, 18.85, 14.11, 20.24, 12, 20.92) ++
        builder.path.bezier(9.89, 20.24, 8.08, 18.85, 6.87, 17) ++
        builder.path.bezier(6.53, 16.5, 6.24, 16, 6, 15.47) ++
        builder.path.bezier(6, 13.82, 8.71, 12.47, 12, 12.47) ++
        builder.path.bezier(15.29, 12.47, 18, 13.79, 18, 15.47) ++
        builder.path.bezier(17.76, 16, 17.47, 16.5, 17.13, 17) ++
        builder.fillPathFlat(4, 1) ++
        builder.point(12, 5) ++
        builder.path.bezier(13.5, 5, 15, 6.2, 15, 8) ++
        builder.path.bezier(15, 9.5, 13.8, 10.998, 12, 11) ++
        builder.path.bezier(10.5, 11, 9, 9.8, 9, 8) ++
        builder.path.bezier(9, 6.4, 10.2, 5, 12, 5) ++
        builder.end_of_document;
};

const feature_showcase = blk: {
    @setEvalBranchQuota(10_000);
    break :blk builder_16.header(1024, 1024) ++
        builder_16.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("e7a915") catch unreachable, // yellow
        tvg.Color.fromString("ff7800") catch unreachable, // orange
        tvg.Color.fromString("40ff00") catch unreachable, // green
    }) ++
        builder_16.fillRectanglesFlat(2, 0) ++
        builder_16.rectangle(16, 16, 64, 48) ++
        builder_16.rectangle(96, 16, 64, 48) ++
        builder_16.fillRectanglesGrad(2, .{ .linear = .{
        .point_0 = .{ .x = 32, .y = 80 },
        .point_1 = .{ .x = 144, .y = 128 },
        .color_0 = 1,
        .color_1 = 2,
    } }) ++
        builder_16.rectangle(16, 80, 64, 48) ++
        builder_16.rectangle(96, 80, 64, 48) ++
        builder_16.fillRectanglesGrad(2, .{ .radial = .{
        .point_0 = .{ .x = 80, .y = 144 },
        .point_1 = .{ .x = 48, .y = 176 },
        .color_0 = 1,
        .color_1 = 2,
    } }) ++
        builder_16.rectangle(16, 144, 64, 48) ++
        builder_16.rectangle(96, 144, 64, 48) ++
        builder_16.end_of_document;
};

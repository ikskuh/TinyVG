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

pub const app_menu = blk: {
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

pub const workspace = blk: {
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

pub const workspace_add = blk: {
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

pub const shield = blk: {
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

pub const feature_showcase = blk: {
    @setEvalBranchQuota(10_000);
    break :blk builder_16.header(1024, 1024) ++
        builder_16.colorTable(&[_]tvg.Color{
        tvg.Color.fromString("e7a915") catch unreachable, // 0 yellow
        tvg.Color.fromString("ff7800") catch unreachable, // 1 orange
        tvg.Color.fromString("40ff00") catch unreachable, // 2 green
        tvg.Color.fromString("ba004d") catch unreachable, // 3 reddish purple
        tvg.Color.fromString("62009e") catch unreachable, // 4 blueish purple
        tvg.Color.fromString("94e538") catch unreachable, // 5 grass green
    }) ++
        // FILL RECTANGLE
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
        // FILL POLYGON
        builder_16.fillPolygonFlat(7, 3) ++
        builder_16.point(192, 32) ++
        builder_16.point(208, 16) ++
        builder_16.point(240, 16) ++
        builder_16.point(256, 32) ++
        builder_16.point(256, 64) ++
        builder_16.point(224, 48) ++
        builder_16.point(192, 64) ++
        builder_16.fillPolygonGrad(7, .{ .linear = .{
        .point_0 = .{ .x = 224, .y = 80 },
        .point_1 = .{ .x = 224, .y = 128 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(192, 96) ++
        builder_16.point(208, 80) ++
        builder_16.point(240, 80) ++
        builder_16.point(256, 96) ++
        builder_16.point(256, 128) ++
        builder_16.point(224, 112) ++
        builder_16.point(192, 128) ++
        builder_16.fillPolygonGrad(7, .{ .radial = .{
        .point_0 = .{ .x = 224, .y = 144 },
        .point_1 = .{ .x = 224, .y = 192 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(192, 160) ++
        builder_16.point(208, 144) ++
        builder_16.point(240, 144) ++
        builder_16.point(256, 160) ++
        builder_16.point(256, 192) ++
        builder_16.point(224, 176) ++
        builder_16.point(192, 192) ++
        // FILL PATH
        builder_16.fillPathFlat(10, 5) ++
        builder_16.point(288, 64) ++
        builder_16.path.vert(32) ++
        builder_16.path.bezier(288, 24, 288, 16, 304, 16) ++
        builder_16.path.horiz(336) ++
        builder_16.path.bezier(352, 16, 352, 24, 352, 32) ++
        builder_16.path.vert(64) ++
        builder_16.path.line(336, 48) ++ // this should be an arc segment
        builder_16.path.line(320, 32) ++
        builder_16.path.line(312, 48) ++
        builder_16.path.line(304, 64) ++ // this should be an arc segment
        builder_16.path.close() ++
        builder_16.fillPathGrad(10, .{ .linear = .{
        .point_0 = .{ .x = 320, .y = 80 },
        .point_1 = .{ .x = 320, .y = 128 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(288, 64 + 64) ++
        builder_16.path.vert(64 + 32) ++
        builder_16.path.bezier(288, 64 + 24, 288, 64 + 16, 304, 64 + 16) ++
        builder_16.path.horiz(336) ++
        builder_16.path.bezier(352, 64 + 16, 352, 64 + 24, 352, 64 + 32) ++
        builder_16.path.vert(64 + 64) ++
        builder_16.path.line(336, 64 + 48) ++ // this should be an arc segment
        builder_16.path.line(320, 64 + 32) ++
        builder_16.path.line(312, 64 + 48) ++
        builder_16.path.line(304, 64 + 64) ++ // this should be an arc segment
        builder_16.path.close() ++
        builder_16.fillPathGrad(10, .{ .radial = .{
        .point_0 = .{ .x = 320, .y = 144 },
        .point_1 = .{ .x = 320, .y = 192 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(288, 128 + 64) ++
        builder_16.path.vert(128 + 32) ++
        builder_16.path.bezier(288, 128 + 24, 288, 128 + 16, 304, 128 + 16) ++
        builder_16.path.horiz(336) ++
        builder_16.path.bezier(352, 128 + 16, 352, 128 + 24, 352, 128 + 32) ++
        builder_16.path.vert(128 + 64) ++
        builder_16.path.line(336, 128 + 48) ++ // this should be an arc segment
        builder_16.path.line(320, 128 + 32) ++
        builder_16.path.line(312, 128 + 48) ++
        builder_16.path.line(304, 128 + 64) ++ // this should be an arc segment
        builder_16.path.close() ++
        // DRAW LINES
        builder_16.drawLinesFlat(4, 0.0, 1) ++
        builder_16.point(16 + 0, 224 + 0) ++ builder_16.point(16 + 64, 224 + 0) ++
        builder_16.point(16 + 0, 224 + 16) ++ builder_16.point(16 + 64, 224 + 16) ++
        builder_16.point(16 + 0, 224 + 32) ++ builder_16.point(16 + 64, 224 + 32) ++
        builder_16.point(16 + 0, 224 + 48) ++ builder_16.point(16 + 64, 224 + 48) ++
        builder_16.drawLinesGrad(4, 3.0, .{ .linear = .{
        .point_0 = .{ .x = 48, .y = 304 },
        .point_1 = .{ .x = 48, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(16 + 0, 304 + 0) ++ builder_16.point(16 + 64, 304 + 0) ++
        builder_16.point(16 + 0, 304 + 16) ++ builder_16.point(16 + 64, 304 + 16) ++
        builder_16.point(16 + 0, 304 + 32) ++ builder_16.point(16 + 64, 304 + 32) ++
        builder_16.point(16 + 0, 304 + 48) ++ builder_16.point(16 + 64, 304 + 48) ++
        builder_16.drawLinesGrad(4, 6.0, .{ .radial = .{
        .point_0 = .{ .x = 48, .y = 408 },
        .point_1 = .{ .x = 48, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(16 + 0, 384 + 0) ++ builder_16.point(16 + 64, 384 + 0) ++
        builder_16.point(16 + 0, 384 + 16) ++ builder_16.point(16 + 64, 384 + 16) ++
        builder_16.point(16 + 0, 384 + 32) ++ builder_16.point(16 + 64, 384 + 32) ++
        builder_16.point(16 + 0, 384 + 48) ++ builder_16.point(16 + 64, 384 + 48) ++
        // DRAW LINE STRIP
        builder_16.drawLineStripFlat(8, 3.0, 1) ++
        builder_16.point(96 + 0, 224 + 0) ++
        builder_16.point(96 + 64, 224 + 0) ++
        builder_16.point(96 + 64, 224 + 16) ++
        builder_16.point(96 + 0, 224 + 16) ++
        builder_16.point(96 + 0, 224 + 32) ++
        builder_16.point(96 + 64, 224 + 32) ++
        builder_16.point(96 + 64, 224 + 48) ++
        builder_16.point(96 + 0, 224 + 48) ++
        builder_16.drawLineStripGrad(8, 6.0, .{ .linear = .{
        .point_0 = .{ .x = 128, .y = 304 },
        .point_1 = .{ .x = 128, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(96 + 0, 304 + 0) ++
        builder_16.point(96 + 64, 304 + 0) ++
        builder_16.point(96 + 64, 304 + 16) ++
        builder_16.point(96 + 0, 304 + 16) ++
        builder_16.point(96 + 0, 304 + 32) ++
        builder_16.point(96 + 64, 304 + 32) ++
        builder_16.point(96 + 64, 304 + 48) ++
        builder_16.point(96 + 0, 304 + 48) ++
        builder_16.drawLineStripGrad(8, 0.0, .{ .radial = .{
        .point_0 = .{ .x = 128, .y = 408 },
        .point_1 = .{ .x = 128, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(96 + 0, 384 + 0) ++
        builder_16.point(96 + 64, 384 + 0) ++
        builder_16.point(96 + 64, 384 + 16) ++
        builder_16.point(96 + 0, 384 + 16) ++
        builder_16.point(96 + 0, 384 + 32) ++
        builder_16.point(96 + 64, 384 + 32) ++
        builder_16.point(96 + 64, 384 + 48) ++
        builder_16.point(96 + 0, 384 + 48) ++
        // DRAW LINE LOOP
        builder_16.drawLineLoopFlat(8, 6.0, 1) ++
        builder_16.point(176 + 0, 224 + 0) ++
        builder_16.point(176 + 64, 224 + 0) ++
        builder_16.point(176 + 64, 224 + 16) ++
        builder_16.point(176 + 16, 224 + 16) ++
        builder_16.point(176 + 16, 224 + 32) ++
        builder_16.point(176 + 64, 224 + 32) ++
        builder_16.point(176 + 64, 224 + 48) ++
        builder_16.point(176 + 0, 224 + 48) ++
        builder_16.drawLineLoopGrad(8, 0.0, .{ .linear = .{
        .point_0 = .{ .x = 208, .y = 304 },
        .point_1 = .{ .x = 208, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(176 + 0, 304 + 0) ++
        builder_16.point(176 + 64, 304 + 0) ++
        builder_16.point(176 + 64, 304 + 16) ++
        builder_16.point(176 + 16, 304 + 16) ++
        builder_16.point(176 + 16, 304 + 32) ++
        builder_16.point(176 + 64, 304 + 32) ++
        builder_16.point(176 + 64, 304 + 48) ++
        builder_16.point(176 + 0, 304 + 48) ++
        builder_16.drawLineLoopGrad(8, 3.0, .{ .radial = .{
        .point_0 = .{ .x = 208, .y = 408 },
        .point_1 = .{ .x = 208, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    } }) ++
        builder_16.point(176 + 0, 384 + 0) ++
        builder_16.point(176 + 64, 384 + 0) ++
        builder_16.point(176 + 64, 384 + 16) ++
        builder_16.point(176 + 16, 384 + 16) ++
        builder_16.point(176 + 16, 384 + 32) ++
        builder_16.point(176 + 64, 384 + 32) ++
        builder_16.point(176 + 64, 384 + 48) ++
        builder_16.point(176 + 0, 384 + 48) ++
        builder_16.end_of_document;
};

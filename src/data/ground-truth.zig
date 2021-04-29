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
        builder.fillRectangles(3, .flat, 0) ++
        builder.rectangle(6, 12, 36, 4) ++
        builder.rectangle(6, 22, 36, 4) ++
        builder.rectangle(6, 32, 36, 4) ++
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
        builder.fillRectangles(1, .flat, 0) ++
        builder.rectangle(6, 6, 16, 36) ++
        builder.fillRectangles(1, .flat, 1) ++
        builder.rectangle(26, 6, 16, 16) ++
        builder.fillRectangles(1, .flat, 2) ++
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
        builder.fillRectangles(1, .flat, 0) ++
        builder.rectangle(6, 6, 16, 36) ++
        builder.fillRectangles(1, .flat, 1) ++
        builder.rectangle(26, 6, 16, 16) ++
        builder.fillPath(11, .flat, 2) ++
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
        builder.fillPath(5, .flat, 0) ++
        builder.point(12, 1) ++ // M 12 1
        builder.path.line(3, 5) ++ // L 3 5
        builder.path.vert(11) ++ // V 11
        builder.path.bezier(3, 16.55, 6.84, 21.74, 12, 23) ++ // C 3     16.55 6.84 21.74 12 23
        builder.path.bezier(17.16, 21.74, 21, 16.55, 21, 11) ++ // C 17.16 21.74 21   16.55 21 11
        builder.path.vert(5) ++ // V 5
        builder.fillPath(6, .flat, 1) ++
        builder.point(17.13, 17) ++ // M 12 1
        builder.path.bezier(15.92, 18.85, 14.11, 20.24, 12, 20.92) ++
        builder.path.bezier(9.89, 20.24, 8.08, 18.85, 6.87, 17) ++
        builder.path.bezier(6.53, 16.5, 6.24, 16, 6, 15.47) ++
        builder.path.bezier(6, 13.82, 8.71, 12.47, 12, 12.47) ++
        builder.path.bezier(15.29, 12.47, 18, 13.79, 18, 15.47) ++
        builder.path.bezier(17.76, 16, 17.47, 16.5, 17.13, 17) ++
        builder.fillPath(4, .flat, 1) ++
        builder.point(12, 5) ++
        builder.path.bezier(13.5, 5, 15, 6.2, 15, 8) ++
        builder.path.bezier(15, 9.5, 13.8, 10.998, 12, 11) ++
        builder.path.bezier(10.5, 11, 9, 9.8, 9, 8) ++
        builder.path.bezier(9, 6.4, 10.2, 5, 12, 5) ++
        builder.end_of_document;
};

pub const feature_showcase = blk: {
    @setEvalBranchQuota(20_000);
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
        builder_16.fillRectangles(2, .flat, 0) ++
        builder_16.rectangle(16, 16, 64, 48) ++
        builder_16.rectangle(96, 16, 64, 48) ++
        builder_16.fillRectangles(2, .linear, .{
        .point_0 = .{ .x = 32, .y = 80 },
        .point_1 = .{ .x = 144, .y = 128 },
        .color_0 = 1,
        .color_1 = 2,
    }) ++
        builder_16.rectangle(16, 80, 64, 48) ++
        builder_16.rectangle(96, 80, 64, 48) ++
        builder_16.fillRectangles(2, .radial, .{
        .point_0 = .{ .x = 80, .y = 144 },
        .point_1 = .{ .x = 48, .y = 176 },
        .color_0 = 1,
        .color_1 = 2,
    }) ++
        builder_16.rectangle(16, 144, 64, 48) ++
        builder_16.rectangle(96, 144, 64, 48) ++
        // FILL POLYGON
        builder_16.fillPolygon(7, .flat, 3) ++
        builder_16.point(192, 32) ++
        builder_16.point(208, 16) ++
        builder_16.point(240, 16) ++
        builder_16.point(256, 32) ++
        builder_16.point(256, 64) ++
        builder_16.point(224, 48) ++
        builder_16.point(192, 64) ++
        builder_16.fillPolygon(7, .linear, .{
        .point_0 = .{ .x = 224, .y = 80 },
        .point_1 = .{ .x = 224, .y = 128 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(192, 96) ++
        builder_16.point(208, 80) ++
        builder_16.point(240, 80) ++
        builder_16.point(256, 96) ++
        builder_16.point(256, 128) ++
        builder_16.point(224, 112) ++
        builder_16.point(192, 128) ++
        builder_16.fillPolygon(7, .radial, .{
        .point_0 = .{ .x = 224, .y = 144 },
        .point_1 = .{ .x = 224, .y = 192 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(192, 160) ++
        builder_16.point(208, 144) ++
        builder_16.point(240, 144) ++
        builder_16.point(256, 160) ++
        builder_16.point(256, 192) ++
        builder_16.point(224, 176) ++
        builder_16.point(192, 192) ++
        // FILL PATH
        builder_16.fillPath(10, .flat, 5) ++
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
        builder_16.fillPath(10, .linear, .{
        .point_0 = .{ .x = 320, .y = 80 },
        .point_1 = .{ .x = 320, .y = 128 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
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
        builder_16.fillPath(10, .radial, .{
        .point_0 = .{ .x = 320, .y = 144 },
        .point_1 = .{ .x = 320, .y = 192 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
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
        builder_16.drawLines(4, 0.0, .flat, 1) ++
        builder_16.point(16 + 0, 224 + 0) ++ builder_16.point(16 + 64, 224 + 0) ++
        builder_16.point(16 + 0, 224 + 16) ++ builder_16.point(16 + 64, 224 + 16) ++
        builder_16.point(16 + 0, 224 + 32) ++ builder_16.point(16 + 64, 224 + 32) ++
        builder_16.point(16 + 0, 224 + 48) ++ builder_16.point(16 + 64, 224 + 48) ++
        builder_16.drawLines(4, 3.0, .linear, .{
        .point_0 = .{ .x = 48, .y = 304 },
        .point_1 = .{ .x = 48, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(16 + 0, 304 + 0) ++ builder_16.point(16 + 64, 304 + 0) ++
        builder_16.point(16 + 0, 304 + 16) ++ builder_16.point(16 + 64, 304 + 16) ++
        builder_16.point(16 + 0, 304 + 32) ++ builder_16.point(16 + 64, 304 + 32) ++
        builder_16.point(16 + 0, 304 + 48) ++ builder_16.point(16 + 64, 304 + 48) ++
        builder_16.drawLines(4, 6.0, .radial, .{
        .point_0 = .{ .x = 48, .y = 408 },
        .point_1 = .{ .x = 48, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(16 + 0, 384 + 0) ++ builder_16.point(16 + 64, 384 + 0) ++
        builder_16.point(16 + 0, 384 + 16) ++ builder_16.point(16 + 64, 384 + 16) ++
        builder_16.point(16 + 0, 384 + 32) ++ builder_16.point(16 + 64, 384 + 32) ++
        builder_16.point(16 + 0, 384 + 48) ++ builder_16.point(16 + 64, 384 + 48) ++
        // DRAW LINE STRIP
        builder_16.drawLineStrip(8, 3.0, .flat, 1) ++
        builder_16.point(96 + 0, 224 + 0) ++
        builder_16.point(96 + 64, 224 + 0) ++
        builder_16.point(96 + 64, 224 + 16) ++
        builder_16.point(96 + 0, 224 + 16) ++
        builder_16.point(96 + 0, 224 + 32) ++
        builder_16.point(96 + 64, 224 + 32) ++
        builder_16.point(96 + 64, 224 + 48) ++
        builder_16.point(96 + 0, 224 + 48) ++
        builder_16.drawLineStrip(8, 6.0, .linear, .{
        .point_0 = .{ .x = 128, .y = 304 },
        .point_1 = .{ .x = 128, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(96 + 0, 304 + 0) ++
        builder_16.point(96 + 64, 304 + 0) ++
        builder_16.point(96 + 64, 304 + 16) ++
        builder_16.point(96 + 0, 304 + 16) ++
        builder_16.point(96 + 0, 304 + 32) ++
        builder_16.point(96 + 64, 304 + 32) ++
        builder_16.point(96 + 64, 304 + 48) ++
        builder_16.point(96 + 0, 304 + 48) ++
        builder_16.drawLineStrip(8, 0.0, .radial, .{
        .point_0 = .{ .x = 128, .y = 408 },
        .point_1 = .{ .x = 128, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(96 + 0, 384 + 0) ++
        builder_16.point(96 + 64, 384 + 0) ++
        builder_16.point(96 + 64, 384 + 16) ++
        builder_16.point(96 + 0, 384 + 16) ++
        builder_16.point(96 + 0, 384 + 32) ++
        builder_16.point(96 + 64, 384 + 32) ++
        builder_16.point(96 + 64, 384 + 48) ++
        builder_16.point(96 + 0, 384 + 48) ++
        // DRAW LINE LOOP
        builder_16.drawLineLoop(8, 6.0, .flat, 1) ++
        builder_16.point(176 + 0, 224 + 0) ++
        builder_16.point(176 + 64, 224 + 0) ++
        builder_16.point(176 + 64, 224 + 16) ++
        builder_16.point(176 + 16, 224 + 16) ++
        builder_16.point(176 + 16, 224 + 32) ++
        builder_16.point(176 + 64, 224 + 32) ++
        builder_16.point(176 + 64, 224 + 48) ++
        builder_16.point(176 + 0, 224 + 48) ++
        builder_16.drawLineLoop(8, 0.0, .linear, .{
        .point_0 = .{ .x = 208, .y = 304 },
        .point_1 = .{ .x = 208, .y = 352 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(176 + 0, 304 + 0) ++
        builder_16.point(176 + 64, 304 + 0) ++
        builder_16.point(176 + 64, 304 + 16) ++
        builder_16.point(176 + 16, 304 + 16) ++
        builder_16.point(176 + 16, 304 + 32) ++
        builder_16.point(176 + 64, 304 + 32) ++
        builder_16.point(176 + 64, 304 + 48) ++
        builder_16.point(176 + 0, 304 + 48) ++
        builder_16.drawLineLoop(8, 3.0, .radial, .{
        .point_0 = .{ .x = 208, .y = 408 },
        .point_1 = .{ .x = 208, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(176 + 0, 384 + 0) ++
        builder_16.point(176 + 64, 384 + 0) ++
        builder_16.point(176 + 64, 384 + 16) ++
        builder_16.point(176 + 16, 384 + 16) ++
        builder_16.point(176 + 16, 384 + 32) ++
        builder_16.point(176 + 64, 384 + 32) ++
        builder_16.point(176 + 64, 384 + 48) ++
        builder_16.point(176 + 0, 384 + 48) ++
        // DRAW LINE PATH
        builder_16.drawPath(10, 0.0, .flat, 1) ++
        builder_16.point(256 + 0, 224 + 0) ++
        builder_16.path.horiz(256 + 48) ++
        builder_16.path.bezier(256 + 64, 224 + 0, 256 + 64, 224 + 16, 256 + 48, 224 + 16) ++
        builder_16.path.horiz(256 + 32) ++
        builder_16.path.line(256 + 16, 224 + 24) ++
        builder_16.path.line(256 + 32, 224 + 32) ++
        builder_16.path.line(256 + 64, 224 + 32) ++ // this is arc-ellipse later
        builder_16.path.line(256 + 48, 224 + 48) ++ // this is arc-circle later
        builder_16.path.horiz(256 + 16) ++
        builder_16.path.line(256 + 0, 224 + 32) ++ // this is arc-circle later
        builder_16.path.close() ++
        builder_16.drawPath(10, 6.0, .linear, .{
        .point_0 = .{ .x = 288, .y = 408 },
        .point_1 = .{ .x = 288, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(256 + 0, 304 + 0) ++
        builder_16.path.horiz(256 + 48) ++
        builder_16.path.bezier(256 + 64, 304 + 0, 256 + 64, 304 + 16, 256 + 48, 304 + 16) ++
        builder_16.path.horiz(256 + 32) ++
        builder_16.path.line(256 + 16, 304 + 24) ++
        builder_16.path.line(256 + 32, 304 + 32) ++
        builder_16.path.line(256 + 64, 304 + 32) ++ // this is arc-ellipse later
        builder_16.path.line(256 + 48, 304 + 48) ++ // this is arc-circle later
        builder_16.path.horiz(256 + 16) ++
        builder_16.path.line(256 + 0, 304 + 32) ++ // this is arc-circle later
        builder_16.path.close() ++
        builder_16.drawPath(10, 3.0, .radial, .{
        .point_0 = .{ .x = 288, .y = 408 },
        .point_1 = .{ .x = 288, .y = 432 },
        .color_0 = 3,
        .color_1 = 4,
    }) ++
        builder_16.point(256 + 0, 384 + 0) ++
        builder_16.path.horiz(256 + 48) ++
        builder_16.path.bezier(256 + 64, 384 + 0, 256 + 64, 384 + 16, 256 + 48, 384 + 16) ++
        builder_16.path.horiz(256 + 32) ++
        builder_16.path.line(256 + 16, 384 + 24) ++
        builder_16.path.line(256 + 32, 384 + 32) ++
        builder_16.path.line(256 + 64, 384 + 32) ++ // this is arc-ellipse later
        builder_16.path.line(256 + 48, 384 + 48) ++ // this is arc-circle later
        builder_16.path.horiz(256 + 16) ++
        builder_16.path.line(256 + 0, 384 + 32) ++ // this is arc-circle later
        builder_16.path.close() ++
        // Outline Fill Rectangle
        builder_16.outlineFillRectangles(1, 0.0, .flat, 0, .flat, 3) ++
        builder_16.rectangle(384, 16, 64, 48) ++
        builder_16.outlineFillRectangles(1, 1.0, .flat, 0, .linear, .{ .point_0 = .{ .x = 416, .y = 80 }, .point_1 = .{ .x = 416, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(384, 80, 64, 48) ++
        builder_16.outlineFillRectangles(1, 2.0, .flat, 0, .radial, .{ .point_0 = .{ .x = 416, .y = 168 }, .point_1 = .{ .x = 416, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(384, 144, 64, 48) ++
        builder_16.outlineFillRectangles(1, 3.0, .linear, .{ .point_0 = .{ .x = 496, .y = 16 }, .point_1 = .{ .x = 496, .y = 64 }, .color_0 = 1, .color_1 = 2 }, .flat, 3) ++
        builder_16.rectangle(464, 16, 64, 48) ++
        builder_16.outlineFillRectangles(1, 4.0, .linear, .{ .point_0 = .{ .x = 496, .y = 80 }, .point_1 = .{ .x = 496, .y = 128 }, .color_0 = 1, .color_1 = 2 }, .linear, .{ .point_0 = .{ .x = 496, .y = 80 }, .point_1 = .{ .x = 496, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(464, 80, 64, 48) ++
        builder_16.outlineFillRectangles(1, 5.0, .linear, .{ .point_0 = .{ .x = 496, .y = 144 }, .point_1 = .{ .x = 496, .y = 192 }, .color_0 = 1, .color_1 = 2 }, .radial, .{ .point_0 = .{ .x = 496, .y = 168 }, .point_1 = .{ .x = 496, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(464, 144, 64, 48) ++
        builder_16.outlineFillRectangles(1, 6.0, .radial, .{ .point_0 = .{ .x = 576, .y = 40 }, .point_1 = .{ .x = 576, .y = 88 }, .color_0 = 1, .color_1 = 2 }, .flat, 3) ++
        builder_16.rectangle(544, 16, 64, 48) ++
        builder_16.outlineFillRectangles(1, 7.0, .radial, .{ .point_0 = .{ .x = 576, .y = 104 }, .point_1 = .{ .x = 576, .y = 150 }, .color_0 = 1, .color_1 = 2 }, .linear, .{ .point_0 = .{ .x = 576, .y = 80 }, .point_1 = .{ .x = 576, .y = 128 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(544, 80, 64, 48) ++
        builder_16.outlineFillRectangles(1, 8.0, .radial, .{ .point_0 = .{ .x = 576, .y = 168 }, .point_1 = .{ .x = 576, .y = 216 }, .color_0 = 1, .color_1 = 2 }, .radial, .{ .point_0 = .{ .x = 576, .y = 168 }, .point_1 = .{ .x = 576, .y = 216 }, .color_0 = 3, .color_1 = 4 }) ++
        builder_16.rectangle(544, 144, 64, 48) ++
        // Outline Fill Polygon
        // TODO
        // PATH WITH ARC (ELLIPSE)
        builder_16.drawPath(3, 2.0, .flat, 1) ++
        builder_16.point(16 + 0, 464 + 0) ++
        builder_16.path.line(16 + 16, 464 + 16) ++
        builder_16.path.arc_ellipse(10, 15, 45, false, false, 16 + 48, 464 + 48) ++
        builder_16.path.line(16 + 64, 464 + 64) ++
        builder_16.drawPath(3, 2.0, .flat, 1) ++
        builder_16.point(96 + 0, 464 + 0) ++
        builder_16.path.line(96 + 16, 464 + 16) ++
        builder_16.path.arc_ellipse(10, 15, 45, false, true, 96 + 48, 464 + 48) ++
        builder_16.path.line(96 + 64, 464 + 64) ++
        builder_16.drawPath(3, 2.0, .flat, 1) ++
        builder_16.point(176 + 0, 464 + 0) ++
        builder_16.path.line(176 + 16, 464 + 16) ++
        builder_16.path.arc_ellipse(10, 15, 45, true, false, 176 + 48, 464 + 48) ++
        builder_16.path.line(176 + 64, 464 + 64) ++
        builder_16.drawPath(3, 2.0, .flat, 1) ++
        builder_16.point(256 + 0, 464 + 0) ++
        builder_16.path.line(256 + 16, 464 + 16) ++
        builder_16.path.arc_ellipse(10, 15, 45, true, true, 256 + 48, 464 + 48) ++
        builder_16.path.line(256 + 64, 464 + 64) ++
        builder_16.end_of_document;
};

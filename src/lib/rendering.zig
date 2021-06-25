const std = @import("std");
const tvg = @import("tvg.zig");
const parsing = tvg.parsing;

const Point = tvg.Point;
const Rectangle = tvg.Rectangle;
const Color = tvg.Color;
const Style = tvg.parsing.Style;

// TODO: Make these configurable
const circle_divs = 100;
const bezier_divs = 16;

pub fn isFramebuffer(comptime T: type) bool {
    const Framebuffer = if (@typeInfo(T) == .Pointer)
        std.meta.Child(T)
    else
        T;
    // @compileLog(
    //     T,
    //     Framebuffer,
    //     std.meta.trait.hasFn("setPixel")(Framebuffer),
    //     std.meta.trait.hasField("width")(Framebuffer),
    //     std.meta.trait.hasField("height")(Framebuffer),
    // );
    return std.meta.trait.hasFn("setPixel")(Framebuffer) and
        std.meta.trait.hasField("width")(Framebuffer) and
        std.meta.trait.hasField("height")(Framebuffer);
}

const IndexSlice = struct { offset: usize, len: usize };

/// Renders a command for TVG icon.
pub fn render(
    /// A struct that exports a single function `setPixel(x: isize, y: isize, color: [4]u8) void` as well as two fields width and height
    framebuffer: anytype,
    /// The parsed header of a TVG
    header: parsing.Header,
    /// The color lookup table
    color_table: []const tvg.Color,
    /// The command that should be executed.
    cmd: parsing.DrawCommand,
) !void {
    const temp_buffer_size = 4096;

    if (!comptime isFramebuffer(@TypeOf(framebuffer)))
        @compileError("framebuffer needs fields width, height and function setPixel!");
    const fb_width = @intToFloat(f32, framebuffer.width);
    const fb_height = @intToFloat(f32, framebuffer.height);
    // std.debug.print("render {}\n", .{cmd});

    var painter = Painter{
        .scale_x = fb_width / @intToFloat(f32, header.width),
        .scale_y = fb_height / @intToFloat(f32, header.height),
    };

    switch (cmd) {
        .fill_polygon => |data| {
            painter.fillPolygon(framebuffer, color_table, data.style, data.vertices);
        },
        .fill_rectangles => |data| {
            for (data.rectangles) |rect| {
                painter.fillRectangle(framebuffer, rect.x, rect.y, rect.width, rect.height, color_table, data.style);
            }
        },
        .fill_path => |data| {
            var point_store = FixedBufferList(Point, temp_buffer_size){};
            var slice_store = FixedBufferList(IndexSlice, 64){}; // known upper bound

            try renderPath(&point_store, &slice_store, data.path);

            var slices: [64][]const Point = undefined;
            for (slice_store.items()) |src, i| {
                slices[i] = point_store.items()[src.offset..][0..src.len];
            }

            painter.fillPolygonList(
                framebuffer,
                color_table,
                data.style,
                slices[0..slice_store.length],
                .even_odd,
            );
        },
        .draw_lines => |data| {
            for (data.lines) |line| {
                painter.drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, line);
            }
        },
        .draw_line_strip => |data| {
            for (data.vertices[1..]) |end, i| {
                const start = data.vertices[i]; // is actually [i-1], but we access the slice off-by-one!
                painter.drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                    .start = start,
                    .end = end,
                });
            }
        },
        .draw_line_loop => |data| {
            var start_index: usize = data.vertices.len - 1;
            for (data.vertices) |end, end_index| {
                const start = data.vertices[start_index];

                painter.drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                    .start = start,
                    .end = end,
                });
                start_index = end_index;
            }
        },
        .draw_line_path => |data| {
            var point_store = FixedBufferList(Point, temp_buffer_size){};
            var slice_store = FixedBufferList(IndexSlice, 64){}; // known upper bound

            try renderPath(&point_store, &slice_store, data.path);

            var slices: [64][]const Point = undefined;
            for (slice_store.items()) |src, i| {
                slices[i] = point_store.items()[src.offset..][0..src.len];
            }

            for (slices[0..slice_store.length]) |vertices| {
                for (vertices[1..]) |end, i| {
                    const start = vertices[i]; // is actually [i-1], but we access the slice off-by-one!
                    painter.drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                        .start = start,
                        .end = end,
                    });
                }
            }
        },
        .outline_fill_polygon => |data| {
            _ = data;
            @panic("outline_fill_polygon not implemented yet!");
        },
        .outline_fill_rectangles => |data| {
            for (data.rectangles) |rect| {
                painter.fillRectangle(framebuffer, rect.x, rect.y, rect.width, rect.height, color_table, data.fill_style);
                var tl = Point{ .x = rect.x, .y = rect.y };
                var tr = Point{ .x = rect.x + rect.width, .y = rect.y };
                var bl = Point{ .x = rect.x, .y = rect.y + rect.height };
                var br = Point{ .x = rect.x + rect.width, .y = rect.y + rect.height };
                painter.drawLine(framebuffer, color_table, data.line_style, data.line_width, data.line_width, .{ .start = tl, .end = tr });
                painter.drawLine(framebuffer, color_table, data.line_style, data.line_width, data.line_width, .{ .start = tr, .end = br });
                painter.drawLine(framebuffer, color_table, data.line_style, data.line_width, data.line_width, .{ .start = br, .end = bl });
                painter.drawLine(framebuffer, color_table, data.line_style, data.line_width, data.line_width, .{ .start = bl, .end = tl });
            }
        },
        .outline_fill_path => |data| {
            _ = data;
            @panic("outline_fill_path not implemented yet!");
        },
    }
}

pub fn renderPath(point_list: anytype, slice_list: anytype, path: tvg.parsing.Path) !void {
    const Helper = struct {
        list: @TypeOf(point_list),
        last: Point,
        count: usize,

        fn append(self: *@This(), pt: Point) !void {
            // Discard when point is in the vicinity of the last point (same pixel)
            const delta = 0.25;
            if (std.math.approxEqAbs(f32, pt.x, self.last.x, delta) and std.math.approxEqAbs(f32, pt.y, self.last.y, delta))
                return;

            try self.list.append(pt);
            self.last = pt;
            self.count += 1;
        }

        fn back(self: @This()) Point {
            return self.last;
        }
    };

    var point_store = Helper{
        .list = point_list,
        .last = undefined,
        .count = 0,
    };

    for (path.segments) |segment| {
        const start_index = point_store.count;

        try point_store.append(segment.start);

        for (segment.commands) |node| {
            switch (node) {
                .line => |pt| try point_store.append(pt.data),
                .horiz => |x| try point_store.append(Point{ .x = x.data, .y = point_store.back().y }),
                .vert => |y| try point_store.append(Point{ .x = point_store.back().x, .y = y.data }),
                .bezier => |bezier| {
                    var previous = point_store.back();

                    const oct0_x = [4]f32{ previous.x, bezier.data.c0.x, bezier.data.c1.x, bezier.data.p1.x };
                    const oct0_y = [4]f32{ previous.y, bezier.data.c0.y, bezier.data.c1.y, bezier.data.p1.y };

                    var i: usize = 1;
                    while (i < bezier_divs) : (i += 1) {
                        const f = @intToFloat(f32, i) / @intToFloat(f32, bezier_divs);

                        const x = lerpAndReduceToOne(4, oct0_x, f);
                        const y = lerpAndReduceToOne(4, oct0_y, f);

                        try point_store.append(Point{ .x = x, .y = y });
                    }

                    try point_store.append(bezier.data.p1);
                },
                .quadratic_bezier => |bezier| {
                    var previous = point_store.back();

                    const oct0_x = [3]f32{ previous.x, bezier.data.c.x, bezier.data.p1.x };
                    const oct0_y = [3]f32{ previous.y, bezier.data.c.y, bezier.data.p1.y };

                    var i: usize = 1;
                    while (i < bezier_divs) : (i += 1) {
                        const f = @intToFloat(f32, i) / @intToFloat(f32, bezier_divs);

                        const x = lerpAndReduceToOne(3, oct0_x, f);
                        const y = lerpAndReduceToOne(3, oct0_y, f);

                        try point_store.append(Point{ .x = x, .y = y });
                    }

                    try point_store.append(bezier.data.p1);
                },
                // /home/felix/projects/forks/svg-curve-lib/src/js/svg-curve-lib.js
                .arc_circle => |circle| {
                    try renderCircle(
                        &point_store,
                        point_store.back(),
                        circle.data.target,
                        circle.data.radius,
                        circle.data.large_arc,
                        circle.data.sweep,
                    );
                },
                .arc_ellipse => |ellipse| {
                    try renderEllipse(
                        &point_store,
                        point_store.back(),
                        ellipse.data.target,
                        ellipse.data.radius_x,
                        ellipse.data.radius_y,
                        ellipse.data.rotation,
                        ellipse.data.large_arc,
                        ellipse.data.sweep,
                    );
                },
                .close => {
                    // if (node_index != (nodes.len - 1)) {
                    //     // .close must be last!
                    //     return error.InvalidData;
                    // }
                    try point_store.append(segment.start);
                },
            }
        }
        const end_index = point_store.count;

        if (end_index > start_index) {
            try slice_list.append(IndexSlice{
                .offset = start_index,
                .len = end_index - start_index,
            });
        }
    }
}

fn toRadians(a: f32) f32 {
    return std.math.pi / 180.0 * a;
}

const cos = std.math.cos;
const sin = std.math.sin;
const sqrt = std.math.sqrt;
const abs = std.math.fabs;

pub fn renderEllipse(
    point_list: anytype,
    p0: Point,
    p1: Point,
    radius_x: f32,
    radius_y: f32,
    rotation: f32,
    large_arc: bool,
    turn_left: bool,
) !void {
    const radius_min = distance(p0, p1) / 2.0;
    const radius_lim = std.math.min(std.math.fabs(radius_x), std.math.fabs(radius_y));

    const up_scale = if (radius_lim < radius_min)
        radius_min / radius_lim
    else
        1.0;

    // std.log.warn("{d} {d} {d}, {d} => {d}", .{ radius_x, radius_y, radius_lim, radius_min, up_scale });

    const ratio = radius_x / radius_y;
    const rot = rotationMat(toRadians(rotation - 90));
    const transform = [2][2]f32{
        .{ rot[0][0] / up_scale, rot[0][1] / up_scale },
        .{ rot[1][0] / up_scale * ratio, rot[1][1] / up_scale * ratio },
    };
    const transform_back = [2][2]f32{
        .{ rot[1][1] * up_scale, -rot[0][1] / ratio * up_scale },
        .{ -rot[1][0] * up_scale, rot[0][0] / ratio * up_scale },
    };

    var tmp = FixedBufferList(Point, circle_divs){};
    renderCircle(&tmp, applyMat(transform, p0), applyMat(transform, p1), radius_x * up_scale, large_arc, turn_left) catch unreachable; // buffer is correctly sized

    for (tmp.buffer) |p| {
        try point_list.append(applyMat(transform_back, p));
    }
}

fn renderCircle(
    point_list: anytype,
    p0: Point,
    p1: Point,
    r: f32,
    large_arc: bool,
    turn_left: bool,
) !void {
    // Whether the center should be to the left of the vector from p0 to p1
    const left_side = (turn_left and large_arc) or (!turn_left and !large_arc);

    const delta = scale(sub(p1, p0), 0.5);
    const midpoint = add(p0, delta);

    // Vector from midpoint to center, but incorrect length
    const radius_vec = if (left_side) Point{ .x = -delta.y, .y = delta.x } else Point{ .x = delta.y, .y = -delta.x };
    const len_squared = length2(radius_vec);
    if (len_squared - 0.03 > r * r or r < 0) {
        std.log.err("{d} > {d}", .{ std.math.sqrt(len_squared), std.math.sqrt(r * r) });
        return error.InvalidRadius;
    }

    const to_center = scale(radius_vec, sqrt(r * r / len_squared - 1));
    const center = add(midpoint, to_center);

    const angle = std.math.asin(sqrt(len_squared) / r) * 2;
    const arc = if (large_arc) (std.math.tau - angle) else angle;
    const step_mat = rotationMat((if (turn_left) -arc else arc) / circle_divs);

    var pos = sub(p0, center);
    var i: usize = 0;
    while (i < circle_divs - 1) : (i += 1) {
        pos = applyMat(step_mat, pos);
        const point = add(pos, center);

        try point_list.append(point);
    }

    try point_list.append(p1);
}

fn rotationMat(angle: f32) [2][2]f32 {
    const s = sin(angle);
    const c = cos(angle);
    return .{
        .{ c, -s },
        .{ s, c },
    };
}

fn applyMat(mat: [2][2]f32, p: Point) Point {
    return .{
        .x = p.x * mat[0][0] + p.y * mat[0][1],
        .y = p.x * mat[1][0] + p.y * mat[1][1],
    };
}

fn pointFromInts(x: i16, y: i16) Point {
    return Point{ .x = @intToFloat(f32, x) + 0.5, .y = @intToFloat(f32, y) + 0.5 };
}

fn pointToInts(point: Point) struct { x: i16, y: i16 } {
    return .{
        .x = @floatToInt(i16, std.math.round(point.x)),
        .y = @floatToInt(i16, std.math.round(point.y)),
    };
}

fn xy(x: f32, y: f32) Point {
    return Point{ .x = x, .y = y };
}

test "point conversion" {
    const TestData = struct { point: Point, x: i16, y: i16 };

    const pt2int = [_]TestData{
        .{ .point = xy(0, 0), .x = 0, .y = 0 },
        .{ .point = xy(1, 0), .x = 1, .y = 0 },
        .{ .point = xy(2, 0), .x = 2, .y = 0 },
        .{ .point = xy(0, 1), .x = 0, .y = 1 },
        .{ .point = xy(0, 2), .x = 0, .y = 2 },
        .{ .point = xy(1, 3), .x = 1, .y = 3 },
        .{ .point = xy(2, 4), .x = 2, .y = 4 },
    };
    const int2pt = [_]TestData{
        .{ .point = xy(0, 0), .x = 0, .y = 0 },
        .{ .point = xy(1, 0), .x = 1, .y = 0 },
        .{ .point = xy(2, 0), .x = 2, .y = 0 },
        .{ .point = xy(0, 1), .x = 0, .y = 1 },
        .{ .point = xy(0, 2), .x = 0, .y = 2 },
        .{ .point = xy(1, 3), .x = 1, .y = 3 },
        .{ .point = xy(2, 4), .x = 2, .y = 4 },
    };
    for (pt2int) |data| {
        const ints = pointToInts(data.point);
        //std.debug.print("{d} {d} => {d} {d}\n", .{
        //    data.point.x, data.point.y,
        //    ints.x,       ints.y,
        //});
        std.testing.expectEqual(data.x, ints.x);
        std.testing.expectEqual(data.y, ints.y);
    }
    for (int2pt) |data| {
        const pt = pointFromInts(data.x, data.y);
        std.testing.expectApproxEqAbs(@as(f32, 0.0), distance(pt, data.point), sqrt(2.0) / 2.0);
    }
}

fn add(a: Point, b: Point) Point {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}

fn sub(p1: Point, p2: Point) Point {
    return Point{ .x = p1.x - p2.x, .y = p1.y - p2.y };
}

fn dot(p1: Point, p2: Point) f32 {
    return p1.x * p2.x + p1.y * p2.y;
}

fn scale(a: Point, s: f32) Point {
    return .{ .x = a.x * s, .y = a.y * s };
}

fn length2(p: Point) f32 {
    return dot(p, p);
}

fn length(p: Point) f32 {
    return sqrt(length2(p));
}

fn distance(p1: Point, p2: Point) f32 {
    return length(sub(p1, p2));
}

fn getProjectedPointOnLine(v1: Point, v2: Point, p: Point) Point {
    var l1 = sub(v2, v1);
    var l2 = sub(p, v1);
    var proj = dot(l1, l2) / length2(l1);

    return add(v1, scale(l1, proj));
}

fn sampleStlye(color_table: []const Color, style: Style, x: i16, y: i16) Color {
    return switch (style) {
        .flat => |index| color_table[index],
        .linear => |grad| blk: {
            const c0 = color_table[grad.color_0];
            const c1 = color_table[grad.color_1];

            const p0 = grad.point_0;
            const p1 = grad.point_1;
            const pt = pointFromInts(x, y);

            const direction = sub(p1, p0);
            const delta_pt = sub(pt, p0);

            const dot_0 = dot(direction, delta_pt);
            if (dot_0 <= 0.0)
                break :blk c0;

            const dot_1 = dot(direction, sub(pt, p1));
            if (dot_1 >= 0.0)
                break :blk c1;

            const len_grad = length(direction);

            const pos_grad = length(getProjectedPointOnLine(
                Point{ .x = 0, .y = 0 },
                direction,
                delta_pt,
            ));

            break :blk lerp_sRGB(c0, c1, pos_grad / len_grad);
        },
        .radial => |grad| blk: {
            const dist_max = distance(grad.point_0, grad.point_1);
            const dist_is = distance(grad.point_0, pointFromInts(x, y));

            const c0 = color_table[grad.color_0];
            const c1 = color_table[grad.color_1];

            break :blk lerp_sRGB(c0, c1, dist_is / dist_max);
        },
    };
}

const Painter = struct {
    scale_x: f32,
    scale_y: f32,

    fn fillPolygon(self: Painter, framebuffer: anytype, color_table: []const Color, style: Style, points: []const Point) void {
        fillPolygonList(self, framebuffer, color_table, style, &[_][]const Point{points}, .nonzero);
    }

    const FillRule = enum { even_odd, nonzero };
    fn fillPolygonList(self: Painter, framebuffer: anytype, color_table: []const Color, style: Style, points_lists: []const []const Point, rule: FillRule) void {
        std.debug.assert(points_lists.len > 0);

        var min_x: i16 = std.math.maxInt(i16);
        var min_y: i16 = std.math.maxInt(i16);
        var max_x: i16 = std.math.minInt(i16);
        var max_y: i16 = std.math.minInt(i16);

        for (points_lists) |points| {
            // std.debug.assert(points.len >= 3);
            for (points) |pt| {
                min_x = std.math.min(min_x, @floatToInt(i16, std.math.floor(self.scale_x * pt.x)));
                min_y = std.math.min(min_y, @floatToInt(i16, std.math.floor(self.scale_y * pt.y)));
                max_x = std.math.max(max_x, @floatToInt(i16, std.math.ceil(self.scale_x * pt.x)));
                max_y = std.math.max(max_y, @floatToInt(i16, std.math.ceil(self.scale_y * pt.y)));
            }
        }

        // limit to valid screen area
        min_x = std.math.max(min_x, 0);
        min_y = std.math.max(min_y, 0);

        max_x = std.math.min(max_x, @intCast(i16, framebuffer.width - 1));
        max_y = std.math.min(max_y, @intCast(i16, framebuffer.height - 1));

        var y: i16 = min_y;
        while (y <= max_y) : (y += 1) {
            var x: i16 = min_x;
            while (x <= max_x) : (x += 1) {

                // compute "center" of the pixel
                var p = pointFromInts(x, y);
                p.x /= self.scale_x;
                p.y /= self.scale_y;

                var inside_count: usize = 0;
                for (points_lists) |points| {
                    if (points.len < 2) continue;
                    var inside = false;

                    // free after https://stackoverflow.com/a/17490923

                    var j = points.len - 1;
                    for (points) |p0, i| {
                        defer j = i;
                        const p1 = points[j];

                        if ((p0.y > p.y) != (p1.y > p.y) and p.x < (p1.x - p0.x) * (p.y - p0.y) / (p1.y - p0.y) + p0.x) {
                            inside = !inside;
                        }
                    }
                    if (inside) {
                        inside_count += 1;
                    }
                }
                const set = switch (rule) {
                    .nonzero => (inside_count > 0),
                    .even_odd => (inside_count % 2) == 1,
                };
                if (set) {
                    framebuffer.setPixel(x, y, sampleStlye(color_table, style, x, y).toArray());
                }
            }
        }
    }

    fn fillRectangle(self: Painter, framebuffer: anytype, x: f32, y: f32, width: f32, height: f32, color_table: []const Color, style: Style) void {
        const xlimit = @floatToInt(i16, std.math.ceil(self.scale_x * (x + width)));
        const ylimit = @floatToInt(i16, std.math.ceil(self.scale_y * (y + height)));

        var py = @floatToInt(i16, std.math.floor(self.scale_y * y));
        while (py < ylimit) : (py += 1) {
            var px = @floatToInt(i16, std.math.floor(self.scale_x * x));
            while (px < xlimit) : (px += 1) {
                framebuffer.setPixel(px, py, sampleStlye(color_table, style, px, py).toArray());
            }
        }
    }

    fn drawLine(self: Painter, framebuffer: anytype, color_table: []const Color, style: Style, width_start: f32, width_end: f32, line: tvg.Line) void {
        const len_fract = distance(line.start, line.end);

        const num_dots = @floatToInt(usize, std.math.ceil(len_fract));

        if (num_dots == 0)
            return;

        var i: usize = 0;
        while (i <= num_dots) : (i += 1) {
            const f = @intToFloat(f32, i) / @intToFloat(f32, num_dots);

            const pos = Point{
                .x = lerp(line.start.x, line.end.x, f),
                .y = lerp(line.start.y, line.end.y, f),
            };
            const width = lerp(width_start, width_end, f);

            self.drawCircle(
                framebuffer,
                color_table,
                style,
                pos,
                width / 2.0, // circle uses radius, we use width/diameter
            );
        }
    }

    fn drawCircle(self: Painter, framebuffer: anytype, color_table: []const Color, style: Style, location: Point, radius: f32) void {
        if (radius < 0)
            return;

        const left = @floatToInt(i16, std.math.floor(self.scale_x * (location.x - radius) - 0.5));
        const right = @floatToInt(i16, std.math.ceil(self.scale_y * (location.x + radius) + 0.5));

        const top = @floatToInt(i16, std.math.floor(self.scale_x * (location.y - radius) - 0.5));
        const bottom = @floatToInt(i16, std.math.ceil(self.scale_y * (location.y + radius) + 0.5));

        const r2 = radius * radius;
        if (r2 > 0.77) {
            var y: i16 = top;
            while (y <= bottom) : (y += 1) {
                var x: i16 = left;
                while (x <= right) : (x += 1) {
                    const pt = pointFromInts(x, y);
                    var delta = sub(pt, location);
                    delta.x /= self.scale_x;
                    delta.y /= self.scale_y;
                    const dist = length2(delta);
                    if (dist <= r2)
                        framebuffer.setPixel(x, y, sampleStlye(color_table, style, x, y).toArray());
                }
            }
        } else {
            const pt = pointToInts(location);
            framebuffer.setPixel(pt.x, pt.y, sampleStlye(color_table, style, pt.x, pt.y).toArray());
        }
    }
};

const sRGB_gamma = 2.2;

fn gamma2linear(v: f32) u8 {
    std.debug.assert(v >= 0 and v <= 1);
    return @floatToInt(u8, 255.0 * std.math.pow(f32, v, 1.0 / sRGB_gamma));
}

fn linear2gamma(v: u8) f32 {
    return std.math.pow(f32, @intToFloat(f32, v) / 255.0, sRGB_gamma);
}

fn lerp_sRGB(c0: Color, c1: Color, f_unchecked: f32) Color {
    const f = std.math.clamp(f_unchecked, 0, 1);
    return Color{
        .r = gamma2linear(lerp(linear2gamma(c0.r), linear2gamma(c1.r), f)),
        .g = gamma2linear(lerp(linear2gamma(c0.g), linear2gamma(c1.g), f)),
        .b = gamma2linear(lerp(linear2gamma(c0.b), linear2gamma(c1.b), f)),
        .a = @floatToInt(u8, lerp(@intToFloat(f32, c0.a), @intToFloat(f32, c0.a), f)),
    };
}

fn lerp(a: f32, b: f32, x: f32) f32 {
    return a + (b - a) * x;
}

fn lerpAndReduce(comptime n: comptime_int, vals: [n]f32, f: f32) [n - 1]f32 {
    var result: [n - 1]f32 = undefined;
    for (result) |*r, i| {
        r.* = lerp(vals[i + 0], vals[i + 1], f);
    }
    return result;
}

fn lerpAndReduceToOne(comptime n: comptime_int, vals: [n]f32, f: f32) f32 {
    if (n == 1) {
        return vals[0];
    } else {
        return lerpAndReduceToOne(n - 1, lerpAndReduce(n, vals, f), f);
    }
}

pub fn FixedBufferList(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        buffer: [N]T = undefined,
        length: usize = 0,

        pub fn append(self: *Self, value: T) !void {
            if (self.length == N)
                return error.OutOfMemory;
            self.buffer[self.length] = value;
            self.length += 1;
        }

        pub fn popBack(self: Self) ?T {
            if (self.length == 0)
                return null;
            self.length -= 1;
            return self.buffer[self.length];
        }

        pub fn itemsMut(self: *Self) []T {
            return self.buffer[0..self.length];
        }

        pub fn items(self: Self) []const T {
            return self.buffer[0..self.length];
        }

        pub fn front(self: Self) ?T {
            if (self.length == 0)
                return null;
            return self.buffer[0];
        }

        pub fn back(self: Self) ?T {
            if (self.length == 0)
                return null;
            return self.buffer[self.length - 1];
        }
    };
}

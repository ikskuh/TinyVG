const std = @import("std");
const tvg = @import("tvg.zig");
const parsing = tvg.parsing;

const Point = tvg.Point;
const Rectangle = tvg.Rectangle;
const Color = tvg.Color;
const Style = tvg.parsing.Style;

pub fn isFramebuffer(comptime T: type) bool {
    const Framebuffer = if (@typeInfo(T) == .Pointer)
        std.meta.Child(T)
    else
        @TypeOf(T);
    return std.meta.trait.hasFn("setPixel")(Framebuffer) and
        std.meta.trait.hasField("width")(Framebuffer) and
        std.meta.trait.hasField("height")(Framebuffer);
}

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
    if (!comptime isFramebuffer(@TypeOf(framebuffer)))
        @compileError("framebuffer needs fields width, height and function setPixel!");
    // std.debug.print("render {}\n", .{cmd});
    switch (cmd) {
        .fill_polygon => |data| {
            fillPolygon(framebuffer, color_table, data.style, data.vertices);
        },
        .fill_rectangles => |data| {
            for (data.rectangles) |rect| {
                fillRectangle(framebuffer, rect.x, rect.y, rect.width, rect.height, color_table, data.style);
            }
        },
        .fill_path => |data| {
            var point_store = FixedBufferList(Point, 256){};

            try point_store.append(data.start);
            try renderPath(&point_store, data.path);

            fillPolygon(framebuffer, color_table, data.style, point_store.items());
        },
        .draw_lines => |data| {
            for (data.lines) |line| {
                drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, line);
            }
        },
        .draw_line_strip => |data| {
            for (data.vertices[1..]) |end, i| {
                const start = data.vertices[i]; // is actually [i-1], but we access the slice off-by-one!
                drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                    .start = start,
                    .end = end,
                });
            }
        },
        .draw_line_loop => |data| {
            var start_index: usize = data.vertices.len - 1;
            for (data.vertices) |end, end_index| {
                const start = data.vertices[start_index];

                drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                    .start = start,
                    .end = end,
                });
                start_index = end_index;
            }
        },
        .draw_line_path => |data| {
            var point_store = FixedBufferList(Point, 256){};

            try point_store.append(data.start);
            try renderPath(&point_store, data.path);

            const vertices = point_store.items();

            for (vertices[1..]) |end, i| {
                const start = vertices[i]; // is actually [i-1], but we access the slice off-by-one!
                drawLine(framebuffer, color_table, data.style, data.line_width, data.line_width, .{
                    .start = start,
                    .end = end,
                });
            }
        },
    }
}

fn renderPath(point_store: anytype, nodes: []const tvg.parsing.PathNode) !void {
    for (nodes) |node, node_index| {
        switch (node) {
            .line => |pt| try point_store.append(pt),
            .horiz => |x| try point_store.append(Point{ .x = x, .y = point_store.back().?.y }),
            .vert => |y| try point_store.append(Point{ .x = point_store.back().?.x, .y = y }),
            .bezier => |bezier| {
                var previous = point_store.back().?;

                const oct0_x = [4]f32{ previous.x, bezier.c0.x, bezier.c1.x, bezier.p1.x };
                const oct0_y = [4]f32{ previous.y, bezier.c0.y, bezier.c1.y, bezier.p1.y };

                // always 16 subdivs
                const divs: usize = 16;
                var i: usize = 1;
                while (i < divs) : (i += 1) {
                    const f = @intToFloat(f32, i) / @intToFloat(f32, divs);

                    const x = lerpAndReduceToOne(4, oct0_x, f);
                    const y = lerpAndReduceToOne(4, oct0_y, f);

                    const current = Point{ .x = x, .y = y };

                    if (std.math.approxEqAbs(f32, previous.x, current.x, 0.5) and std.math.approxEqAbs(f32, previous.y, current.y, 0.5))
                        continue;
                    try point_store.append(current);
                }

                try point_store.append(bezier.p1);
            },
            .arc_circle => @panic("arc not implemented yet!"),
            .arc_ellipse => @panic("arc not implemented yet!"),
            .close => {
                if (node_index != (nodes.len - 1)) {
                    // .close must be last!
                    return error.InvalidData;
                }
                try point_store.append(point_store.front().?);
            },
        }
    }
}

fn pointFromInts(x: i16, y: i16) Point {
    return Point{ .x = @intToFloat(f32, x) + 0.5, .y = @intToFloat(f32, y) + 0.5 };
}

fn distance2(p1: Point, p2: Point) f32 {
    const dx = p1.x - p2.x;
    const dy = p1.y - p2.y;
    return dx * dx + dy * dy;
}

fn distance(p1: Point, p2: Point) f32 {
    return std.math.sqrt(distance2(p1, p2));
}

fn dot(p1: Point, p2: Point) f32 {
    return p1.x * p2.x + p1.y * p2.y;
}

fn sub(p1: Point, p2: Point) Point {
    return Point{ .x = p1.x - p2.x, .y = p1.y - p2.y };
}

fn length(p: Point) f32 {
    return std.math.sqrt(p.x * p.x + p.y * p.y);
}

fn getProjectedPointOnLine(v1: Point, v2: Point, p: Point) Point {
    // get dot product of e1, e2
    var e1 = sub(v2, v1); // (v2.x - v1.x, v2.y - v1.y);
    var e2 = sub(p, v1); // (p.x - v1.x, p.y - v1.y);
    var valDp = dot(e1, e2);
    // get length of vectors
    var lenLineE1 = std.math.sqrt(e1.x * e1.x + e1.y * e1.y);
    var lenLineE2 = std.math.sqrt(e2.x * e2.x + e2.y * e2.y);
    var cos = valDp / (lenLineE1 * lenLineE2);
    // length of v1P'
    var projLenOfLine = cos * lenLineE2;
    return Point{
        .x = (v1.x + (projLenOfLine * e1.x) / lenLineE1),
        .y = (v1.y + (projLenOfLine * e1.y) / lenLineE1),
    };
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

fn fillPolygon(framebuffer: anytype, color_table: []const Color, style: Style, points: []const Point) void {
    std.debug.assert(points.len >= 3);

    var min_x: i16 = std.math.maxInt(i16);
    var min_y: i16 = std.math.maxInt(i16);
    var max_x: i16 = std.math.minInt(i16);
    var max_y: i16 = std.math.minInt(i16);

    for (points) |pt| {
        min_x = std.math.min(min_x, @floatToInt(i16, std.math.floor(pt.x)));
        min_y = std.math.min(min_y, @floatToInt(i16, std.math.floor(pt.y)));
        max_x = std.math.max(max_x, @floatToInt(i16, std.math.ceil(pt.x)));
        max_y = std.math.max(max_y, @floatToInt(i16, std.math.ceil(pt.y)));
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
            var inside = false;

            // compute "center" of the pixel
            const p = pointFromInts(x, y);

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
                framebuffer.setPixel(x, y, sampleStlye(color_table, style, x, y).toArray());
            }
        }
    }
}

fn fillRectangle(framebuffer: anytype, x: f32, y: f32, width: f32, height: f32, color_table: []const Color, style: Style) void {
    const xlimit = @floatToInt(i16, std.math.ceil(x + width));
    const ylimit = @floatToInt(i16, std.math.ceil(y + height));

    var py = @floatToInt(i16, std.math.floor(y));
    while (py < ylimit) : (py += 1) {
        var px = @floatToInt(i16, std.math.floor(x));
        while (px < xlimit) : (px += 1) {
            framebuffer.setPixel(px, py, sampleStlye(color_table, style, px, py).toArray());
        }
    }
}

fn drawLine(framebuffer: anytype, color_table: []const Color, style: Style, width_start: f32, width_end: f32, line: tvg.Line) void {
    const len_fract = distance(line.start, line.end);

    const num_dots = @floatToInt(usize, std.math.ceil(len_fract));

    if (num_dots == 0)
        return;

    // std.debug.print("draw line with len={d}, dots={d}\n", .{ len_fract, num_dots });

    var i: usize = 0;
    while (i <= num_dots) : (i += 1) {
        const f = @intToFloat(f32, i) / @intToFloat(f32, num_dots);

        const pos = Point{
            .x = lerp(line.start.x, line.end.x, f),
            .y = lerp(line.start.y, line.end.y, f),
        };
        const width = lerp(width_start, width_end, f);

        // std.debug.print("{d}\t{d} {d}\t{d}\n", .{ f, pos.x, pos.y, width });

        drawCircle(
            framebuffer,
            color_table,
            style,
            pos,
            width / 2.0, // circle uses radius, we use width/diameter
        );
    }
}

fn drawCircle(framebuffer: anytype, color_table: []const Color, style: Style, location: Point, radius: f32) void {
    if (radius < 0)
        return;
    const left = @floatToInt(i16, std.math.floor(location.x - radius));
    const right = @floatToInt(i16, std.math.ceil(location.x + radius));

    const top = @floatToInt(i16, std.math.floor(location.y - radius));
    const bottom = @floatToInt(i16, std.math.ceil(location.y + radius));

    const r2 = radius * radius;
    if (r2 > 0.77) {
        var y: i16 = top;
        while (y <= bottom) : (y += 1) {
            var x: i16 = left;
            while (x <= right) : (x += 1) {
                const pt = pointFromInts(x, y);
                const dist = distance2(pt, location);
                if (dist <= r2)
                    framebuffer.setPixel(x, y, sampleStlye(color_table, style, x, y).toArray());
            }
        }
    } else {
        const x = @floatToInt(i16, location.x);
        const y = @floatToInt(i16, location.y);
        framebuffer.setPixel(x, y, sampleStlye(color_table, style, x, y).toArray());
    }
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

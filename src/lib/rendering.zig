const std = @import("std");
const tvg = @import("tvg.zig");
const parsing = tvg.parsing;

const Point = tvg.Point;
const Rectangle = tvg.Rectangle;
const Color = tvg.Color;

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

    switch (cmd) {
        .fill_polygon => |data| {
            fillPolygon(framebuffer, color_table[data.style.flat], data.vertices);
        },
        .fill_rectangles => |data| {
            for (data.rectangles) |rect| {
                fillRectangle(framebuffer, rect.x, rect.y, rect.width, rect.height, color_table[data.style.flat]);
            }
        },
        .fill_path => |data| {
            var point_store = FixedBufferList(Point, 256){};

            try point_store.append(data.start);
            try renderPath(&point_store, data.path);

            fillPolygon(framebuffer, color_table[data.style.flat], point_store.items());
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

// const Scaler = struct {
//     const Self = @This();

//     scale_x: f32,
//     scale_y: f32,
//     unit_scale: Scale,

//     fn mapX(self: Self, unit: Unit) i16 {
//         return round(self.mapX_f32(unit));
//     }

//     fn mapY(self: Self, unit: Unit) i16 {
//         return round(self.mapY_f32(unit));
//     }

//     fn mapX_f32(self: Self, unit: Unit) f32 {
//         return self.scale_x * unit.toFloat(self.unit_scale);
//     }

//     fn mapY_f32(self: Self, unit: Unit) f32 {
//         return self.scale_y * unit.toFloat(self.unit_scale);
//     }

//     fn round(f: f32) i16 {
//         return @floatToInt(i16, std.math.round(f));
//     }
// };

pub fn fillPolygon(framebuffer: anytype, color: Color, points: []const Point) void {
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
            const p = Point{ .x = @intToFloat(f32, x) + 0.5, .y = @intToFloat(f32, y) + 0.5 };

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
                framebuffer.setPixel(x, y, color.toArray());
            }
        }
    }
}

pub fn fillRectangle(framebuffer: anytype, x: f32, y: f32, width: f32, height: f32, color: Color) void {
    const xlimit = @floatToInt(isize, std.math.ceil(x + width));
    const ylimit = @floatToInt(isize, std.math.ceil(y + height));

    var py = @floatToInt(isize, std.math.floor(y));
    while (py < ylimit) : (py += 1) {
        var px = @floatToInt(isize, std.math.floor(x));
        while (px < xlimit) : (px += 1) {
            framebuffer.setPixel(px, py, color.toArray());
        }
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

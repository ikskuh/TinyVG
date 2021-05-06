const std = @import("std");
const tvg = @import("tvg.zig");

pub const CoordinateRange = enum { default, reduced };

pub const Header = struct {
    version: u8,
    scale: tvg.Scale,
    custom_color_space: bool,
    coordinate_range: CoordinateRange,
    width: u16,
    height: u16,
};

const Point = tvg.Point;
const Rectangle = tvg.Rectangle;
const Line = tvg.Line;

pub const Path = struct {
    segments: []Segment,

    pub const Segment = struct {
        start: Point,
        commands: []Node,
    };

    pub const Node = union(enum) {
        const Self = @This();

        line: NodeData(Point),
        horiz: NodeData(f32),
        vert: NodeData(f32),
        bezier: NodeData(Bezier),
        arc_circle: NodeData(ArcCircle),
        arc_ellipse: NodeData(ArcEllipse),
        close: NodeData(void),
        quadratic_bezier: NodeData(QuadraticBezier),

        fn NodeData(comptime Payload: type) type {
            return struct {
                line_width: ?f32,
                data: Payload,

                fn init(
                    line_width: ?f32,
                    data: Payload,
                ) @This() {
                    return .{ .line_width = line_width, .data = data };
                }
            };
        }

        pub const ArcCircle = struct {
            radius: f32,
            large_arc: bool,
            sweep: bool,
            target: Point,
        };

        pub const ArcEllipse = struct {
            radius_x: f32,
            radius_y: f32,
            rotation: f32,
            large_arc: bool,
            sweep: bool,
            target: Point,
        };

        pub const Bezier = struct {
            c0: Point,
            c1: Point,
            p1: Point,
        };

        pub const QuadraticBezier = struct {
            c: Point,
            p1: Point,
        };

        const Type = packed enum(u3) {
            line = 0, // x,y
            horiz = 1, // x
            vert = 2, // y
            bezier = 3, // c0x,c0y,c1x,c1y,x,y
            arc_circ = 4, //r,x,y
            arc_ellipse = 5, // rx,ry,x,y
            close = 6,
            quad_bezier = 7,
        };
    };
};

pub const DrawCommand = union(enum) {
    fill_polygon: FillPolygon,
    fill_rectangles: FillRectangles,
    fill_path: FillPath,
    draw_lines: DrawLines,
    draw_line_loop: DrawLineSegments,
    draw_line_strip: DrawLineSegments,
    draw_line_path: DrawPath,

    outline_fill_polygon: OutlineFillPolygon,
    outline_fill_rectangles: OutlineFillRectangles,
    outline_fill_path: OutlineFillPath,

    pub const FillPolygon = struct {
        style: Style,
        vertices: []Point,
    };

    pub const FillRectangles = struct {
        style: Style,
        rectangles: []Rectangle,
    };

    pub const FillPath = struct {
        style: Style,
        path: Path,
    };

    pub const OutlineFillPolygon = struct {
        fill_style: Style,
        line_style: Style,
        line_width: f32,
        vertices: []Point,
    };

    pub const OutlineFillRectangles = struct {
        fill_style: Style,
        line_style: Style,
        line_width: f32,
        rectangles: []Rectangle,
    };

    pub const OutlineFillPath = struct {
        fill_style: Style,
        line_style: Style,
        line_width: f32,
        path: Path,
    };

    pub const DrawLines = struct {
        style: Style,
        line_width: f32,
        lines: []Line,
    };

    pub const DrawLineSegments = struct {
        style: Style,
        line_width: f32,
        vertices: []Point,
    };

    pub const DrawPath = struct {
        style: Style,
        line_width: f32,
        path: Path,
    };
};

const StyleType = enum(u2) {
    flat = 0,
    linear = 1,
    radial = 2,
};

pub const Style = union(StyleType) {
    const Self = @This();

    flat: u32, // color index
    linear: Gradient,
    radial: Gradient,
};

const Gradient = struct {
    const Self = @This();

    point_0: Point,
    point_1: Point,
    color_0: u32,
    color_1: u32,
};

pub fn Parser(comptime Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        allocator: *std.mem.Allocator,
        temp_buffer: std.ArrayList(u8),
        end_of_document: bool = false,

        header: Header,
        color_table: []tvg.Color,

        pub fn init(allocator: *std.mem.Allocator, reader: Reader) !Self {
            var actual_magic_number: [2]u8 = undefined;
            reader.readNoEof(&actual_magic_number) catch return error.InvalidData;
            if (!std.mem.eql(u8, &actual_magic_number, &tvg.magic_number))
                return error.InvalidData;

            const version = reader.readByte() catch return error.InvalidData;
            var header: Header = undefined;
            var color_table: []tvg.Color = undefined;

            switch (version) {
                1 => {
                    const ScaleAndFlags = packed struct {
                        scale: u4,
                        custom_color_space: bool,
                        reduced_coordinate_space: bool,
                        padding: u2,
                    };

                    const scale_and_flags = @bitCast(ScaleAndFlags, try reader.readByte());
                    // if (scale_and_flags.scale > 8)
                    //     return error.InvalidData;
                    if (scale_and_flags.padding != 0)
                        return error.InvalidData;

                    const scale = @intToEnum(tvg.Scale, scale_and_flags.scale);

                    const width: u16 = if (scale_and_flags.reduced_coordinate_space)
                        mapZeroToMax(try reader.readByte())
                    else
                        try reader.readIntLittle(u16);
                    const height: u16 = if (scale_and_flags.reduced_coordinate_space)
                        mapZeroToMax(try reader.readByte())
                    else
                        try reader.readIntLittle(u16);

                    const color_count = reader.readIntLittle(u16) catch return error.InvalidData;

                    color_table = try allocator.alloc(tvg.Color, color_count);
                    errdefer allocator.free(color_table);

                    for (color_table) |*c| {
                        c.* = tvg.Color{
                            .r = try reader.readByte(),
                            .g = try reader.readByte(),
                            .b = try reader.readByte(),
                            .a = try reader.readByte(),
                        };
                    }

                    header = Header{
                        .version = version,
                        .scale = scale,
                        .width = width,
                        .height = height,
                        .custom_color_space = scale_and_flags.custom_color_space,
                        .coordinate_range = if (scale_and_flags.reduced_coordinate_space)
                            CoordinateRange.reduced
                        else
                            CoordinateRange.default,
                    };
                },
                else => return error.UnsupportedVersion,
            }

            return Self{
                .allocator = allocator,
                .reader = reader,
                .temp_buffer = std.ArrayList(u8).init(allocator),

                .header = header,
                .color_table = color_table,
            };
        }

        pub fn deinit(self: *Self) void {
            self.temp_buffer.deinit();
            self.allocator.free(self.color_table);
            self.* = undefined;
        }

        fn setTempStorage(self: *Self, comptime T: type, length: usize) ![]T {
            try self.temp_buffer.resize(@sizeOf(T) * length);

            var items = @alignCast(@alignOf(T), std.mem.bytesAsSlice(T, self.temp_buffer.items));
            std.debug.assert(items.len == length);
            return items;
        }

        fn setDualTempStorage(
            self: *Self,
            comptime T1: type,
            length1: usize,
            comptime T2: type,
            length2: usize,
        ) !struct { first: []T1, second: []T2 } {
            const offset_second_buffer = std.mem.alignForward(@sizeOf(T1) * length1, @alignOf(T2));
            try self.temp_buffer.resize(offset_second_buffer + @sizeOf(T2) * length2);

            var result = .{
                .first = @alignCast(@alignOf(T1), std.mem.bytesAsSlice(T1, self.temp_buffer.items[0..offset_second_buffer])),
                .second = @alignCast(@alignOf(T2), std.mem.bytesAsSlice(T2, self.temp_buffer.items[offset_second_buffer..])),
            };

            std.debug.assert(result.first.len == length1);
            std.debug.assert(result.second.len == length2);
            return result;
        }

        pub fn next(self: *Self) !?DrawCommand {
            if (self.end_of_document)
                return null;
            const command_byte = try self.reader.readByte();
            return switch (@intToEnum(tvg.format.Command, command_byte)) {
                .end_of_document => {
                    self.end_of_document = true;
                    return null;
                },
                .fill_polygon => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());

                    const vertex_count = count_and_grad.getCount();
                    if (vertex_count < 2) return error.InvalidData;

                    const style = try self.readStyle(try count_and_grad.getStyleType());

                    var vertices = try self.setTempStorage(Point, vertex_count);
                    for (vertices) |*pt| {
                        pt.x = try self.readUnit();
                        pt.y = try self.readUnit();
                    }

                    break :blk DrawCommand{
                        .fill_polygon = DrawCommand.FillPolygon{
                            .style = style,
                            .vertices = vertices,
                        },
                    };
                },
                .fill_rectangles => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const rectangle_count = count_and_grad.getCount();

                    var rectangles = try self.setTempStorage(Rectangle, rectangle_count);
                    for (rectangles) |*rect| {
                        rect.x = try self.readUnit();
                        rect.y = try self.readUnit();
                        rect.width = try self.readUnit();
                        rect.height = try self.readUnit();
                        if (rect.width <= 0 or rect.height <= 0)
                            return error.InvalidFormat;
                    }

                    break :blk DrawCommand{
                        .fill_rectangles = DrawCommand.FillRectangles{
                            .style = style,
                            .rectangles = rectangles,
                        },
                    };
                },
                .fill_path => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const segment_count = count_and_grad.getCount();

                    var path = try self.readPath(segment_count);

                    break :blk DrawCommand{
                        .fill_path = DrawCommand.FillPath{
                            .style = style,
                            .path = path,
                        },
                    };
                },
                .draw_lines => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const line_count = count_and_grad.getCount();

                    const line_width = try self.readUnit();

                    var lines = try self.setTempStorage(Line, line_count);
                    for (lines) |*line| {
                        line.start.x = try self.readUnit();
                        line.start.y = try self.readUnit();
                        line.end.x = try self.readUnit();
                        line.end.y = try self.readUnit();
                    }

                    break :blk DrawCommand{
                        .draw_lines = DrawCommand.DrawLines{
                            .style = style,
                            .line_width = line_width,
                            .lines = lines,
                        },
                    };
                },
                .draw_line_loop => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const point_count = count_and_grad.getCount() + 1;

                    const line_width = try self.readUnit();

                    var points = try self.setTempStorage(Point, point_count);
                    for (points) |*point| {
                        point.x = try self.readUnit();
                        point.y = try self.readUnit();
                    }

                    break :blk DrawCommand{
                        .draw_line_loop = DrawCommand.DrawLineSegments{
                            .style = style,
                            .line_width = line_width,
                            .vertices = points,
                        },
                    };
                },
                .draw_line_strip => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const point_count = count_and_grad.getCount() + 1;

                    const line_width = try self.readUnit();

                    var points = try self.setTempStorage(Point, point_count);
                    for (points) |*point| {
                        point.x = try self.readUnit();
                        point.y = try self.readUnit();
                    }

                    break :blk DrawCommand{
                        .draw_line_strip = DrawCommand.DrawLineSegments{
                            .style = style,
                            .line_width = line_width,
                            .vertices = points,
                        },
                    };
                },
                .draw_line_path => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const style = try self.readStyle(try count_and_grad.getStyleType());
                    const segment_count = count_and_grad.getCount();

                    const line_width = try self.readUnit();

                    const path = try self.readPath(segment_count);

                    break :blk DrawCommand{
                        .draw_line_path = DrawCommand.DrawPath{
                            .style = style,
                            .line_width = line_width,
                            .path = path,
                        },
                    };
                },
                .outline_fill_polygon => @panic("parsing outline_fill_polygon not implemented yet!"),
                .outline_fill_rectangles => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try self.readByte());
                    const line_style_dat = try self.readByte();

                    const line_style = try self.readStyle(try convertStyleType(@truncate(u2, line_style_dat)));
                    const fill_style = try self.readStyle(try count_and_grad.getStyleType());

                    const line_width = try self.readUnit();

                    const rectangle_count = count_and_grad.getCount();

                    var rectangles = try self.setTempStorage(Rectangle, rectangle_count);
                    for (rectangles) |*rect| {
                        rect.x = try self.readUnit();
                        rect.y = try self.readUnit();
                        rect.width = try self.readUnit();
                        rect.height = try self.readUnit();
                        if (rect.width <= 0 or rect.height <= 0)
                            return error.InvalidFormat;
                    }

                    break :blk DrawCommand{
                        .outline_fill_rectangles = DrawCommand.OutlineFillRectangles{
                            .fill_style = fill_style,
                            .line_style = line_style,
                            .line_width = line_width,
                            .rectangles = rectangles,
                        },
                    };
                },
                .outline_fill_path => @panic("parsing outline_fill_path not implemented yet!"),
                _ => return error.InvalidData,
            };
        }

        fn readPath(self: *Self, segment_count: usize) !Path {
            var segment_lengths: [64]usize = undefined;
            std.debug.assert(segment_count <= segment_lengths.len);

            var total_node_count: usize = 0;

            {
                var i: usize = 0;
                while (i < segment_count) : (i += 1) {
                    segment_lengths[i] = try self.readUInt();
                    total_node_count += segment_lengths[i];
                    // std.log.debug("node[{}]: {}", .{ i, segment_lengths[i] });
                }
            }

            // std.log.debug("total: {}", .{total_node_count});

            const buffers = try self.setDualTempStorage(
                Path.Segment,
                segment_count,
                Path.Node,
                total_node_count,
            );

            var segment_start: usize = 0;
            for (buffers.first) |*segment, i| {
                const segment_len = segment_lengths[i];

                segment.start.x = try self.readUnit();
                segment.start.y = try self.readUnit();

                segment.commands = buffers.second[segment_start..][0..segment_len];
                for (segment.commands) |*node| {
                    node.* = try self.readNode();
                }

                segment_start += segment_len;
            }
            std.debug.assert(buffers.first.len == segment_count);
            std.debug.assert(segment_start == total_node_count);

            return Path{
                .segments = buffers.first,
            };
        }

        fn readNode(self: Self) !Path.Node {
            const Tag = packed struct {
                type: Path.Node.Type,
                padding0: u1 = 0,
                has_line_width: bool,
                padding1: u3 = 0,
            };
            const tag = @bitCast(Tag, try self.readByte());

            var line_width: ?f32 = if (tag.has_line_width)
                try self.readUnit()
            else
                null;

            const PathNode = Path.Node;

            return switch (tag.type) {
                .line => PathNode{ .line = PathNode.NodeData(Point).init(line_width, .{
                    .x = try self.readUnit(),
                    .y = try self.readUnit(),
                }) },
                .horiz => PathNode{ .horiz = PathNode.NodeData(f32).init(line_width, try self.readUnit()) },
                .vert => PathNode{ .vert = PathNode.NodeData(f32).init(line_width, try self.readUnit()) },
                .bezier => PathNode{ .bezier = PathNode.NodeData(PathNode.Bezier).init(line_width, PathNode.Bezier{
                    .c0 = Point{
                        .x = try self.readUnit(),
                        .y = try self.readUnit(),
                    },
                    .c1 = Point{
                        .x = try self.readUnit(),
                        .y = try self.readUnit(),
                    },
                    .p1 = Point{
                        .x = try self.readUnit(),
                        .y = try self.readUnit(),
                    },
                }) },
                .arc_circ => blk: {
                    var flags = try self.readByte();
                    break :blk PathNode{ .arc_circle = PathNode.NodeData(PathNode.ArcCircle).init(line_width, PathNode.ArcCircle{
                        .radius = try self.readUnit(),
                        .large_arc = (flags & 1) != 0,
                        .sweep = (flags & 2) != 0,
                        .target = Point{
                            .x = try self.readUnit(),
                            .y = try self.readUnit(),
                        },
                    }) };
                },
                .arc_ellipse => blk: {
                    var flags = try self.readByte();
                    break :blk PathNode{ .arc_ellipse = PathNode.NodeData(PathNode.ArcEllipse).init(line_width, PathNode.ArcEllipse{
                        .radius_x = try self.readUnit(),
                        .radius_y = try self.readUnit(),
                        .rotation = try self.readUnit(),
                        .large_arc = (flags & 1) != 0,
                        .sweep = (flags & 2) != 0,
                        .target = Point{
                            .x = try self.readUnit(),
                            .y = try self.readUnit(),
                        },
                    }) };
                },
                .close => PathNode{ .close = PathNode.NodeData(void).init(line_width, {}) },
                .quad_bezier => PathNode{ .quadratic_bezier = PathNode.NodeData(PathNode.QuadraticBezier).init(line_width, PathNode.QuadraticBezier{
                    .c = Point{
                        .x = try self.readUnit(),
                        .y = try self.readUnit(),
                    },
                    .p1 = Point{
                        .x = try self.readUnit(),
                        .y = try self.readUnit(),
                    },
                }) },
            };
        }

        fn readStyle(self: Self, kind: StyleType) !Style {
            return switch (kind) {
                .flat => Style{ .flat = try self.readUInt() },
                .linear => Style{ .linear = try self.readGradient() },
                .radial => Style{ .radial = try self.readGradient() },
            };
        }

        fn readGradient(self: Self) !Gradient {
            var grad: Gradient = undefined;
            grad.point_0 = Point{
                .x = try self.readUnit(),
                .y = try self.readUnit(),
            };
            grad.point_1 = Point{
                .x = try self.readUnit(),
                .y = try self.readUnit(),
            };
            grad.color_0 = try self.readUInt();
            grad.color_1 = try self.readUInt();
            return grad;
        }

        fn readUInt(self: Self) error{InvalidData}!u32 {
            var byte_count: u8 = 0;
            var result: u32 = 0;
            while (true) {
                const byte = self.reader.readByte() catch return error.InvalidData;
                // check for too long *and* out of range in a single check
                if (byte_count == 4 and (byte & 0xF0) != 0)
                    return error.InvalidData;
                const val = @as(u32, (byte & 0x7F)) << @intCast(u5, (7 * byte_count));
                result |= val;
                if ((byte & 0x80) == 0)
                    break;
                byte_count += 1;
                std.debug.assert(byte_count <= 5);
            }
            return result;
        }

        fn readUnit(self: Self) !f32 {
            switch (self.header.coordinate_range) {
                .reduced => return @intToEnum(tvg.Unit, try self.reader.readIntLittle(i8)).toFloat(self.header.scale),
                .default => return @intToEnum(tvg.Unit, try self.reader.readIntLittle(i16)).toFloat(self.header.scale),
            }
        }

        fn readByte(self: Self) !u8 {
            return try self.reader.readByte();
        }

        fn readU16(self: Self) !u16 {
            return try self.reader.readIntLittle(u16);
        }
    };
}

const CountAndStyleTag = packed struct {
    const Self = @This();
    raw_count: u6,
    style_kind: u2,

    pub fn getCount(self: Self) usize {
        if (self.raw_count == 0)
            return self.raw_count -% 1;
        return self.raw_count;
    }

    pub fn getStyleType(self: Self) !StyleType {
        return convertStyleType(self.style_kind);
    }
};

fn convertStyleType(value: u2) !StyleType {
    return switch (value) {
        @enumToInt(StyleType.flat) => StyleType.flat,
        @enumToInt(StyleType.linear) => StyleType.linear,
        @enumToInt(StyleType.radial) => StyleType.radial,
        else => error.InvalidData,
    };
}

fn MapZeroToMax(comptime T: type) type {
    const info = @typeInfo(T).Int;
    return std.meta.Int(.unsigned, info.bits + 1);
}
fn mapZeroToMax(value: anytype) MapZeroToMax(@TypeOf(value)) {
    return if (value == 0)
        std.math.maxInt(@TypeOf(value)) + 1
    else
        value;
}

test "mapZeroToMax" {
    std.testing.expectEqual(@as(u9, 256), mapZeroToMax(@as(u8, 0)));
    std.testing.expectEqual(@as(u17, 65536), mapZeroToMax(@as(u16, 0)));
}

// test "readUInt" {
//     const T = struct {
//         fn run(seq: []const u8) !u32 {
//             var stream = std.io.fixedBufferStream(seq);
//             return try readUInt(stream.reader());
//         }
//     };

//     std.testing.expectEqual(@as(u32, 0x00), try T.run(&[_]u8{0x00}));
//     std.testing.expectEqual(@as(u32, 0x40), try T.run(&[_]u8{0x40}));
//     std.testing.expectEqual(@as(u32, 0x80), try T.run(&[_]u8{ 0x80, 0x01 }));
//     std.testing.expectEqual(@as(u32, 0x100000), try T.run(&[_]u8{ 0x80, 0x80, 0x40 }));
//     std.testing.expectEqual(@as(u32, 0x8000_0000), try T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x08 }));
//     std.testing.expectError(error.InvalidData, T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x10 })); // out of range
//     std.testing.expectError(error.InvalidData, T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x10 })); // too long
// }

test "coverage test" {
    const source = &@import("ground-truth").feature_showcase;

    var stream = std.io.fixedBufferStream(@as([]const u8, source));

    var parser = try Parser(@TypeOf(stream).Reader).init(std.testing.allocator, stream.reader());
    defer parser.deinit();

    while (try parser.next()) |node| {
        _ = node;
    }
}

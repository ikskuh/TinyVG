const std = @import("std");
const tvg = @import("tvg.zig");

pub const Header = struct {
    version: u8,
    scale: tvg.Scale,
    custom_color_space: bool,
    width: f32,
    height: f32,
};

const Point = tvg.Point;
const Rectangle = tvg.Rectangle;

pub const DrawCommand = union(enum) {
    fill_polygon: FillPolygon,
    fill_rectangles: FillRectangles,
    fill_path: FillPath,

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
        start: Point,
        path: []PathNode,
    };
};

pub const PathNode = union(enum) {
    const Self = @This();

    line: Point,
    horiz: f32,
    vert: f32,
    bezier: Bezier,
    arc_circle,
    arc_ellipse,
    close,

    pub const Bezier = struct {
        c0: Point,
        c1: Point,
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
        reserved = 7,
    };

    const Tag = packed struct {
        type: Type,
        padding0: u1 = 0,
        has_line_width: bool,
        padding1: u3 = 0,
    };

    fn read(scale: tvg.Scale, reader: anytype) !Self {
        const tag = @bitCast(Tag, try readByte(reader));

        var line_width: ?f32 = if (tag.has_line_width)
            try readUnit(scale, reader)
        else
            null;

        return switch (tag.type) {
            .line => Self{ .line = .{
                .x = try readUnit(scale, reader),
                .y = try readUnit(scale, reader),
            } },
            .horiz => Self{ .horiz = try readUnit(scale, reader) },
            .vert => Self{ .vert = try readUnit(scale, reader) },
            .bezier => Self{ .bezier = Bezier{
                .c0 = Point{
                    .x = try readUnit(scale, reader),
                    .y = try readUnit(scale, reader),
                },
                .c1 = Point{
                    .x = try readUnit(scale, reader),
                    .y = try readUnit(scale, reader),
                },
                .p1 = Point{
                    .x = try readUnit(scale, reader),
                    .y = try readUnit(scale, reader),
                },
            } },
            .arc_circ => @panic("todo"),
            .arc_ellipse => @panic("todo"),
            .close => .close,
            .reserved => return error.InvalidData,
        };
    }
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

    fn read(reader: anytype, scale: tvg.Scale, kind: StyleType) !Self {
        return switch (kind) {
            .flat => Style{ .flat = try readUInt(reader) },
            .linear => Style{ .linear = try Gradient.loadFromStream(scale, reader) },
            .radial => Style{ .radial = try Gradient.loadFromStream(scale, reader) },
        };
    }
};

const Gradient = struct {
    const Self = @This();

    point_0: Point,
    point_1: Point,
    color_0: u32,
    color_1: u32,

    fn loadFromStream(scale: tvg.Scale, reader: anytype) !Self {
        var grad: Gradient = undefined;
        grad.point_0 = Point{
            .x = try readUnit(scale, reader),
            .y = try readUnit(scale, reader),
        };
        grad.point_1 = Point{
            .x = try readUnit(scale, reader),
            .y = try readUnit(scale, reader),
        };
        grad.color_0 = try readUInt(reader);
        grad.color_1 = try readUInt(reader);
        return grad;
    }
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
                        padding: u3,
                    };

                    const scale_and_flags = @bitCast(ScaleAndFlags, try readByte(reader));
                    if (scale_and_flags.scale > 8)
                        return error.InvalidData;

                    const scale = @intToEnum(tvg.Scale, scale_and_flags.scale);

                    const width = try readUnit(scale, reader);
                    const height = try readUnit(scale, reader);

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

        pub fn deinit(self: *Self) !void {
            self.temp_buffer.deinit();
            self.* = undefined;
        }

        fn setTempStorage(self: *Self, comptime T: type, length: usize) ![]T {
            try self.temp_buffer.resize(@sizeOf(T) * length);

            var items = @alignCast(@alignOf(T), std.mem.bytesAsSlice(T, self.temp_buffer.items));
            std.debug.assert(items.len == length);
            return items;
        }

        pub fn next(self: *Self) !?DrawCommand {
            if (self.end_of_document)
                return null;
            const command_byte = try self.reader.readByte();
            return switch (@intToEnum(Command, command_byte)) {
                .end_of_document => {
                    self.end_of_document = true;
                    return null;
                },
                .fill_polygon => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try readByte(self.reader));

                    const vertex_count = count_and_grad.getCount();
                    if (vertex_count < 2) return error.InvalidData;

                    const style = try Style.read(self.reader, self.header.scale, try count_and_grad.getStyleType());

                    var vertices = try self.setTempStorage(Point, vertex_count);
                    for (vertices) |*pt| {
                        pt.x = try readUnit(self.header.scale, self.reader);
                        pt.y = try readUnit(self.header.scale, self.reader);
                    }

                    break :blk DrawCommand{
                        .fill_polygon = DrawCommand.FillPolygon{
                            .style = style,
                            .vertices = vertices,
                        },
                    };
                },
                .fill_rectangle => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try readByte(self.reader));
                    const style = try Style.read(self.reader, self.header.scale, try count_and_grad.getStyleType());
                    const rectangle_count = count_and_grad.getCount();

                    var rectangles = try self.setTempStorage(Rectangle, rectangle_count);
                    for (rectangles) |*rect| {
                        rect.x = try readUnit(self.header.scale, self.reader);
                        rect.y = try readUnit(self.header.scale, self.reader);
                        rect.width = try readUnit(self.header.scale, self.reader);
                        rect.height = try readUnit(self.header.scale, self.reader);
                    }

                    break :blk DrawCommand{
                        .fill_rectangles = DrawCommand.FillRectangles{
                            .style = style,
                            .rectangles = rectangles,
                        },
                    };
                },
                .fill_path => blk: {
                    const count_and_grad = @bitCast(CountAndStyleTag, try readByte(self.reader));
                    const style = try Style.read(self.reader, self.header.scale, try count_and_grad.getStyleType());
                    const path_length = count_and_grad.getCount();

                    const start_x = try readUnit(self.header.scale, self.reader);
                    const start_y = try readUnit(self.header.scale, self.reader);

                    var path = try self.setTempStorage(PathNode, path_length);
                    for (path) |*node| {
                        node.* = try PathNode.read(self.header.scale, self.reader);
                    }

                    break :blk DrawCommand{
                        .fill_path = DrawCommand.FillPath{
                            .style = style,
                            .start = Point{
                                .x = start_x,
                                .y = start_y,
                            },
                            .path = path,
                        },
                    };
                },
                _ => return error.InvalidData,
            };
        }
    };
}

const Command = enum(u8) {
    end_of_document = 0,
    fill_polygon = 1,
    fill_rectangle = 2,
    fill_path = 3,
    _,
};

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
        return switch (self.style_kind) {
            @enumToInt(StyleType.flat) => StyleType.flat,
            @enumToInt(StyleType.linear) => StyleType.linear,
            @enumToInt(StyleType.radial) => StyleType.radial,
            else => error.InvalidData,
        };
    }
};

fn readUInt(reader: anytype) error{InvalidData}!u32 {
    var byte_count: u8 = 0;
    var result: u32 = 0;
    while (true) {
        const byte = reader.readByte() catch return error.InvalidData;
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

fn readUnit(scale: tvg.Scale, reader: anytype) !f32 {
    return @intToEnum(tvg.Unit, try reader.readIntLittle(i16)).toFloat(scale);
}

fn readByte(reader: anytype) !u8 {
    return reader.readByte();
}

test "readUInt" {
    const T = struct {
        fn run(seq: []const u8) !u32 {
            var stream = std.io.fixedBufferStream(seq);
            return try readUInt(stream.reader());
        }
    };

    std.testing.expectEqual(@as(u32, 0x00), try T.run(&[_]u8{0x00}));
    std.testing.expectEqual(@as(u32, 0x40), try T.run(&[_]u8{0x40}));
    std.testing.expectEqual(@as(u32, 0x80), try T.run(&[_]u8{ 0x80, 0x01 }));
    std.testing.expectEqual(@as(u32, 0x100000), try T.run(&[_]u8{ 0x80, 0x80, 0x40 }));
    std.testing.expectEqual(@as(u32, 0x8000_0000), try T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x08 }));
    std.testing.expectError(error.InvalidData, T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x10 })); // out of range
    std.testing.expectError(error.InvalidData, T.run(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x10 })); // too long
}

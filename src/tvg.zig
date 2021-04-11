const std = @import("std");
const painterz = @import("painterz");

/// This is the TVG magic number which recognizes the icon format.
/// Magic numbers might seem unnecessary, but they will be the first
/// guard in line against bad input and prevent unnecessary cycles
/// to detect those.
pub const magic_number = [2]u8{ 0x72, 0x56 };

/// This is the latest TVG version supported by this library.
pub const current_version = 1;

const DrawIconError = error{
    /// The icon data does not contain valid data. This is only triggered when
    /// the library can actually determine that the data is bad. Not every bad
    /// data might trigger that error, but when it's certain that the data is
    /// bad (invalid magic, version, enumerations, ...) this error is returned.
    InvalidData,
    /// The version number of the TVG icon is not supported by this library.
    InvalidVersion,
};

/// A scalable fixed-point number.
pub const Unit = enum(i16) {
    const Self = @This();

    _,

    pub fn init(scale: u4, value: f32) Self {
        return @intToEnum(Self, @floatToInt(i16, value * @intToFloat(f32, @as(u16, 1) << scale) + 0.5));
    }

    pub fn raw(self: Self) i16 {
        return @enumToInt(self);
    }

    pub fn toFloat(self: Self, scale: u4) f32 {
        return @intToFloat(f32, @enumToInt(self)) / @intToFloat(f32, @as(u16, 1) << scale);
    }

    pub fn toInt(self: Self, scale: u4) i16 {
        const factor = @as(i16, 1) << scale;
        return @divFloor(@enumToInt(self) + (@divExact(factor, 2)), factor);
    }

    pub fn toUnsignedInt(self: Self, scale: u4) !u15 {
        const i = toInt(self, scale);
        if (i < 0)
            return error.InvalidData;
        return @intCast(u15, i);
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

fn readByte(reader: anytype) error{InvalidData}!u8 {
    return reader.readByte() catch return error.InvalidData;
}

fn readUnit(reader: anytype) error{InvalidData}!Unit {
    return @intToEnum(Unit, reader.readIntLittle(i16) catch return error.InvalidData);
}

/// this is a convenient "readNoEof" without allocation
fn readSlice(stream: *std.io.FixedBufferStream([]const u8), comptime T: type, len: usize) error{InvalidData}![]align(1) const T {
    const byte_len = @sizeOf(T) * len;
    const buffer = stream.buffer[stream.pos..];
    stream.seekBy(@intCast(i64, byte_len)) catch return error.InvalidData;
    var slice = std.mem.bytesAsSlice(T, buffer[0..byte_len]);
    std.debug.assert(slice.len == len);
    return slice;
}

const Point = struct {
    x: i16,
    y: i16,
};

pub const Color = extern struct {
    const Self = @This();

    r: u8,
    g: u8,
    b: u8,
    a: u8,

    fn lerp(lhs: Self, rhs: Self, factor: f32) Self {
        const l = struct {
            fn l(a: u8, b: u8, c: f32) u8 {
                return @floatToInt(u8, @intToFloat(f32, a) + (@intToFloat(b) - @intToFloat(a)) * std.math.clamp(c, 0, 1));
            }
        }.l;

        return Self{
            .r = l(lhs.r, rhs.r, factor),
            .g = l(lhs.g, rhs.g, factor),
            .b = l(lhs.b, rhs.b, factor),
            .a = l(lhs.a, rhs.a, factor),
        };
    }

    pub fn fromString(str: []const u8) !Self {
        return switch (str.len) {
            6 => Self{
                .r = try std.fmt.parseInt(u8, str[0..2], 16),
                .g = try std.fmt.parseInt(u8, str[2..4], 16),
                .b = try std.fmt.parseInt(u8, str[4..6], 16),
                .a = 0xFF,
            },
            else => error.InvalidFormat,
        };
    }
};

const Gradient = struct {
    const Self = @This();

    x0: Unit,
    y0: Unit,
    x1: Unit,
    y1: Unit,
    c0: u32,
    c1: u32,

    fn sampleLinear(self: Self, x: Unit, y: Unit) Color {
        @panic("todo");
    }

    fn sampleRadial(self: Self, x: Unit, y: Unit) Color {
        @panic("todo");
    }

    fn loadFromStream(reader: anytype) error{InvalidData}!Self {
        var grad: Gradient = undefined;
        grad.x0 = try readUnit(reader);
        grad.y0 = try readUnit(reader);
        grad.x1 = try readUnit(reader);
        grad.y1 = try readUnit(reader);
        grad.c0 = try readUInt(reader);
        grad.c1 = try readUInt(reader);
        return grad;
    }
};

const StyleType = enum(u2) {
    flat = 0,
    linear = 1,
    radial = 2,
};

const Style = union(StyleType) {
    const Self = @This();

    flat: u32, // color
    linear: Gradient,
    radial: Gradient,

    fn sample(self: Self, color_lut: []const Color, x: Unit, y: Unit) Color {
        return switch (self) {
            .flat => |index| color_lut[index],
            .linear => |grad| grad.sampleLinear(color_lut, x, y),
            .radial => |grad| grad.sampleRadial(color_lut, x, y),
        };
    }

    fn read(reader: anytype, kind: StyleType) !Self {
        return switch (kind) {
            .flat => Style{ .flat = try readUInt(reader) },
            .linear => Style{ .linear = try Gradient.loadFromStream(reader) },
            .radial => Style{ .radial = try Gradient.loadFromStream(reader) },
        };
    }
};

const Node = struct {
    const Self = @This();

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

    const Data = union(Type) {
        line: struct { x: Unit, y: Unit },
        horiz: Unit,
        vert: Unit,
        bezier: struct {
            c0x: Unit,
            c0y: Unit,
            c1x: Unit,
            c1y: Unit,
            p1x: Unit,
            p1y: Unit,
        },
        arc_circ: struct {
            radius: Unit,
            x: Unit,
            y: Unit,
        },
        arc_ellipse: struct {
            radius_x: Unit,
            radius_y: Unit,
            x: Unit,
            y: Unit,
        },
        close,
        reserved,
    };

    line_width: ?Unit = null,
    data: Data,

    fn read(reader: anytype) !Self {
        const tag = @bitCast(Node.Tag, try readByte(reader));

        var node = Node{ .data = undefined };

        if (tag.has_line_width) {
            node.line_width = try readUnit(reader);
        }

        node.data = switch (tag.type) {
            .line => Data{ .line = .{
                .x = try readUnit(reader),
                .y = try readUnit(reader),
            } },
            .horiz => Data{ .horiz = try readUnit(reader) },
            .vert => Data{ .vert = try readUnit(reader) },
            .bezier => Data{ .bezier = .{
                .c0x = try readUnit(reader),
                .c0y = try readUnit(reader),
                .c1x = try readUnit(reader),
                .c1y = try readUnit(reader),
                .p1x = try readUnit(reader),
                .p1y = try readUnit(reader),
            } },
            .arc_circ => Data{ .arc_circ = .{
                .radius = try readUnit(reader),
                .x = try readUnit(reader),
                .y = try readUnit(reader),
            } },
            .arc_ellipse => Data{ .arc_ellipse = .{
                .radius_x = try readUnit(reader),
                .radius_y = try readUnit(reader),
                .x = try readUnit(reader),
                .y = try readUnit(reader),
            } },
            .close => .close,
            .reserved => return error.InvalidData,
        };

        return node;
    }
};

const Scaler = struct {
    const Self = @This();

    scale_x: f32,
    scale_y: f32,
    unit_scale: u4,

    fn mapX(self: Self, unit: Unit) i16 {
        return round(self.mapX_f32(unit));
    }

    fn mapY(self: Self, unit: Unit) i16 {
        return round(self.mapY_f32(unit));
    }

    fn mapX_f32(self: Self, unit: Unit) f32 {
        return self.scale_x * unit.toFloat(self.unit_scale);
    }

    fn mapY_f32(self: Self, unit: Unit) f32 {
        return self.scale_y * unit.toFloat(self.unit_scale);
    }

    fn round(f: f32) i16 {
        return @floatToInt(i16, std.math.round(f));
    }
};

/// 
/// Draws a TVG icon
pub fn drawIcon(
    canvas: anytype,
    target_x: isize,
    target_y: isize,
    target_width: usize,
    target_height: usize,
    comptime TargetColor: type,
    comptime createColor: fn (r: u8, g: u8, b: u8, a: u8) TargetColor,
    icon: []const u8,
) DrawIconError!void {
    var stream = std.io.fixedBufferStream(icon);
    var reader = stream.reader();

    var actual_magic_number: [2]u8 = undefined;
    reader.readNoEof(&actual_magic_number) catch return error.InvalidData;
    if (!std.mem.eql(u8, &actual_magic_number, &magic_number))
        return error.InvalidData;

    const version = reader.readByte() catch return error.InvalidData;
    switch (version) {
        1 => {
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

            const ScaleAndFlags = packed struct {
                scale: u4,
                custom_color_space: bool,
                padding: u3,
            };

            const scale_and_flags = @bitCast(ScaleAndFlags, try readByte(reader));
            if (scale_and_flags.scale > 8)
                return error.InvalidData;

            const width: Unit = try readUnit(reader);
            const height: Unit = try readUnit(reader);

            const custom_color_space = scale_and_flags.custom_color_space;

            var scaler = Scaler{
                .unit_scale = @truncate(u4, scale_and_flags.scale),
                .scale_x = undefined,
                .scale_y = undefined,
            };
            scaler.scale_x = @intToFloat(f32, target_width) / width.toFloat(scaler.unit_scale);
            scaler.scale_y = @intToFloat(f32, target_height) / height.toFloat(scaler.unit_scale);

            if (width.raw() <= 0) return error.InvalidData;
            if (height.raw() <= 0) return error.InvalidData;

            const color_count = reader.readIntLittle(u16) catch return error.InvalidData;

            // this is a convenient "readNoEof" without allocation
            const color_table = try readSlice(&stream, Color, color_count);

            command_loop: while (true) {
                const command_byte = reader.readByte() catch return error.InvalidData;
                switch (@intToEnum(Command, command_byte)) {
                    .end_of_document => break :command_loop,
                    .fill_polygon => {
                        const count_and_grad = @bitCast(CountAndStyleTag, try readByte(reader));

                        const vertex_count = count_and_grad.getCount();
                        if (vertex_count < 2) return error.InvalidData;

                        const style = try Style.read(reader, try count_and_grad.getStyleType());

                        const vertices = try readSlice(&stream, Unit, 2 * vertex_count);

                        var points: [64]Point = undefined;
                        for (points[0..vertex_count]) |*pt, i| {
                            pt.x = scaler.mapX(vertices[2 * i + 0]);
                            pt.y = scaler.mapY(vertices[2 * i + 1]);
                        }

                        switch (style) {
                            .flat => |color_index| {
                                canvas.fillPolygon(target_x, target_y, createColor(
                                    color_table[color_index].r,
                                    color_table[color_index].g,
                                    color_table[color_index].b,
                                    color_table[color_index].a,
                                ), Point, points[0..vertex_count]);
                            },
                            else => std.debug.panic("style {s} not implemented yet!", .{std.meta.tagName(style)}),
                        }
                    },
                    .fill_rectangle => {
                        const count_and_grad = @bitCast(CountAndStyleTag, try readByte(reader));
                        const style = try Style.read(reader, try count_and_grad.getStyleType());
                        const rectangle_count = count_and_grad.getCount();

                        const Rectangle = packed struct {
                            x: Unit,
                            y: Unit,
                            width: Unit,
                            height: Unit,
                        };

                        comptime {
                            if (@sizeOf(Rectangle) != 8)
                                @compileError("");
                        }

                        const rectangles = try readSlice(&stream, Rectangle, rectangle_count);
                        for (rectangles) |rect| {
                            if (@enumToInt(rect.width) <= 0) return error.InvalidData;
                            if (@enumToInt(rect.height) <= 0) return error.InvalidData;
                        }

                        switch (style) {
                            .flat => |color_index| {
                                const color = createColor(
                                    color_table[color_index].r,
                                    color_table[color_index].g,
                                    color_table[color_index].b,
                                    color_table[color_index].a,
                                );
                                for (rectangles) |rect| {
                                    canvas.fillRectangle(
                                        target_x + scaler.mapX(rect.x),
                                        target_y + scaler.mapY(rect.y),
                                        @intCast(u15, scaler.mapX(rect.width)),
                                        @intCast(u15, scaler.mapY(rect.height)),
                                        color,
                                    );
                                }
                            },
                            else => std.debug.panic("style {s} not implemented yet!", .{std.meta.tagName(style)}),
                        }
                    },
                    .fill_path => {
                        const count_and_grad = @bitCast(CountAndStyleTag, try readByte(reader));
                        const style = try Style.read(reader, try count_and_grad.getStyleType());
                        const path_length = count_and_grad.getCount();

                        var node_store: [64]Node = undefined;
                        var point_store = FixedBufferList(Point, 256){};

                        if (path_length > node_store.len) @panic("Path too long, fix implementation!");

                        const start_x = try readUnit(reader);
                        const start_y = try readUnit(reader);

                        var nodes: []Node = node_store[0..path_length];
                        for (nodes) |*node| {
                            node.* = try Node.read(reader);
                        }

                        point_store.append(Point{
                            .x = scaler.mapX(start_x),
                            .y = scaler.mapY(start_y),
                        }) catch @panic("point store too small");

                        // render path to polygon
                        for (nodes) |node, node_index| {
                            switch (node.data) {
                                .line => |pt| point_store.append(Point{ .x = scaler.mapX(pt.x), .y = scaler.mapY(pt.y) }) catch @panic(""),
                                .horiz => |x| point_store.append(Point{ .x = scaler.mapX(x), .y = point_store.back().?.y }) catch @panic(""),
                                .vert => |y| point_store.append(Point{ .x = point_store.back().?.x, .y = scaler.mapY(y) }) catch @panic(""),
                                .bezier => |bezier| {
                                    var previous = point_store.back().?;

                                    const oct0_x = [4]f32{ @intToFloat(f32, previous.x), scaler.mapX_f32(bezier.c0x), scaler.mapX_f32(bezier.c1x), scaler.mapX_f32(bezier.p1x) };
                                    const oct0_y = [4]f32{ @intToFloat(f32, previous.y), scaler.mapY_f32(bezier.c0y), scaler.mapY_f32(bezier.c1y), scaler.mapY_f32(bezier.p1y) };

                                    // always 16 subdivs
                                    const divs: usize = 16;
                                    var i: usize = 1;
                                    while (i < divs) : (i += 1) {
                                        const f = @intToFloat(f32, i) / @intToFloat(f32, divs);

                                        const x = lerpAndReduceToOne(4, oct0_x, f);
                                        const y = lerpAndReduceToOne(4, oct0_y, f);

                                        const current = Point{
                                            .x = Scaler.round(x),
                                            .y = Scaler.round(y),
                                        };

                                        if (std.meta.eql(previous, current))
                                            continue;
                                        point_store.append(current) catch @panic("");
                                    }

                                    point_store.append(Point{
                                        .x = scaler.mapX(bezier.p1x),
                                        .y = scaler.mapY(bezier.p1y),
                                    }) catch @panic("");
                                },
                                .arc_circ => @panic("bezier not implemented yet!"),
                                .arc_ellipse => @panic("bezier not implemented yet!"),
                                .close => {
                                    if (node_index != (nodes.len - 1)) {
                                        // .close must be last!
                                        return error.InvalidData;
                                    }
                                    point_store.append(point_store.front().?) catch @panic("");
                                },
                                .reserved => unreachable,
                            }
                        }

                        // for (point_store.items()) |pt, i| {
                        //     std.debug.print("[{}] = {}\n", .{ i, pt });
                        // }

                        switch (style) {
                            .flat => |color_index| {
                                canvas.fillPolygon(target_x, target_y, createColor(
                                    color_table[color_index].r,
                                    color_table[color_index].g,
                                    color_table[color_index].b,
                                    color_table[color_index].a,
                                ), Point, point_store.items());
                            },
                            else => std.debug.panic("style {s} not implemented yet!", .{std.meta.tagName(style)}),
                        }
                    },
                    _ => return error.InvalidData,
                }
            }
        },
        else => return error.InvalidVersion,
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

// brainstorming

// path nodes (u3)
//   line x,y
//   horiz x
//   vert y
//   bezier c0x,c0y,c1x,c1y,x,y
//   arc_circ r,x,y
//   arc_ellipse rx,ry,x,y
//   close
// flags:
//   [ ] has line width (prepend)

// primitive types (both fill and outline)
// - rectangle
// - circle
// - circle sector
// - polygon
// - path
// primitive types (other)
// - line strip
// - lines

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

pub const builder = @import("builder.zig").create;

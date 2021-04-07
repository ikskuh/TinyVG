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

    pub fn raw(self: Self) i16 {
        return @enumToInt(self);
    }

    pub fn toFloat(self: Self, scale: u4) f32 {
        return @intToFloat(f32, @enumToInt(self)) / @intToFloat(@as(u16, 1) << scale);
    }

    pub fn toInt(self: Self, scale: u4) i16 {
        const factor = @as(i16, 1) << scale;
        return @divFloor(@enumToInt(self) + (@divExact(factor, 2)), factor);
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

const Color = extern struct {
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
};

const GradientType = enum(u2) {
    flat = 0,
    linear = 1,
    radial = 2,
    _,
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

    fn loadFromStream(stream: anytype) error{InvalidData}!Self {
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

const Style = union(enum) {
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
                _,
            };

            const scale_raw = reader.readByte() catch return error.InvalidData;
            if (scale_raw > 8)
                return error.InvalidData;
            const scale = @truncate(u4, scale_raw);
            const width: Unit = try readUnit(reader);
            const height: Unit = try readUnit(reader);

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
                        const count_and_grad = reader.readByte() catch return error.InvalidData;

                        const vertex_count = @intCast(u6, count_and_grad & 0x3F);
                        if (vertex_count < 2) return error.InvalidData;

                        const gradient = @intToEnum(GradientType, @intCast(u2, count_and_grad >> 6));
                        switch (gradient) {
                            .flat, .linear, .radial => {},
                            _ => return error.InvalidData,
                        }

                        var style: Style = if (gradient == .flat) blk: {
                            const color = try readUInt(reader);
                            break :blk Style{ .flat = color };
                        } else blk: {
                            var grad = try Gradient.loadFromStream(reader);
                            break :blk switch (gradient) {
                                .flat => unreachable,
                                .linear => Style{ .linear = grad },
                                .radial => Style{ .radial = grad },
                                _ => unreachable,
                            };
                        };

                        const vertices = try readSlice(&stream, Unit, 2 * vertex_count);

                        var points: [64]Point = undefined;
                        for (points[0..vertex_count]) |*pt, i| {
                            pt.x = vertices[2 * i + 0].toInt(scale);
                            pt.y = vertices[2 * i + 1].toInt(scale);
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
                    _ => return error.InvalidData,
                }
            }
        },
        else => return error.InvalidVersion,
    }
}

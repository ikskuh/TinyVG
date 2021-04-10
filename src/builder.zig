const std = @import("std");

const tvg = @import("tvg.zig");

pub const Scale = enum(u4) {
    const Self = @This();

    @"1/1" = 0,
    @"1/2" = 1,
    @"1/4" = 2,
    @"1/8" = 3,
    @"1/16" = 4,
    @"1/32" = 5,
    @"1/64" = 6,
    @"1/128" = 7,
    @"1/256" = 8,

    pub fn map(self: Self, value: f32) tvg.Unit {
        return tvg.Unit.init(@enumToInt(self), value);
    }
};

fn JoinLength(comptime T: type) comptime_int {
    const info = @typeInfo(T);

    var len: usize = 0;
    inline for (info.Struct.fields) |fld| {
        len += @typeInfo(fld.field_type).Array.len;
    }
    return len;
}

fn join(list: anytype) [JoinLength(@TypeOf(list))]u8 {
    const T = @TypeOf(list);
    const info = @typeInfo(T);

    var array = [1]u8{0x55} ** JoinLength(T);

    comptime var offset: usize = 0;
    inline for (info.Struct.fields) |fld, i| {
        const len = @typeInfo(fld.field_type).Array.len;

        std.mem.copy(u8, array[offset .. offset + len], &list[i]);
        offset += len;
    }

    return array;
}

fn writeU16(buf: *[2]u8, value: u16) void {
    buf[0] = @truncate(u8, value >> 0);
    buf[1] = @truncate(u8, value >> 8);
}

pub fn create(comptime scale: Scale) type {
    return struct {
        pub fn unit(value: f32) [2]u8 {
            var buf: [2]u8 = undefined;
            writeU16(&buf, @bitCast(u16, scale.map(value).raw()));
            return buf;
        }

        pub fn byte(val: u8) [1]u8 {
            return [1]u8{val};
        }

        pub fn point(x: f32, y: f32) [4]u8 {
            return join(.{ unit(x), unit(y) });
        }

        pub fn header(width: f32, height: f32) [8]u8 {
            return join(.{
                tvg.magic_number,
                byte(tvg.current_version),
                byte(@enumToInt(scale)),
                unit(width),
                unit(height),
            });
        }

        pub fn colorTable(comptime colors: []const tvg.Color) [2 + 4 * colors.len]u8 {
            var buf: [2 + 4 * colors.len]u8 = undefined;
            std.mem.set(u8, &buf, 0x55);
            writeU16(buf[0..2], @intCast(u16, colors.len));
            for (colors) |c, i| {
                buf[2 + 4 * i + 0] = c.r;
                buf[2 + 4 * i + 1] = c.g;
                buf[2 + 4 * i + 2] = c.b;
                buf[2 + 4 * i + 3] = c.a;
            }
            return buf;
        }

        pub fn fillPathFlat(num_items: u6, color: u7) [3]u8 {
            return join(.{ byte(3), byte(num_items), byte(color) });
        }

        pub const path = struct {
            pub fn line(x: f32, y: f32) [5]u8 {
                return join(.{ byte(0), point(x, y) });
            }

            pub fn horiz(x: f32) [3]u8 {
                return join(.{ byte(1), unit(x) });
            }

            pub fn vert(y: f32) [3]u8 {
                return join(.{ byte(2), unit(y) });
            }

            pub fn bezier(c0x: f32, c0y: f32, c1x: f32, c1y: f32, p1x: f32, p1y: f32) [13]u8 {
                return join(.{ byte(3), point(c0x, c0y), point(c1x, c1y), point(p1x, p1y) });
            }

            pub fn arc_circ() [N]u8 {
                return byte(4);
            }

            pub fn arc_ellipse() [N]u8 {
                return byte(5);
            }

            pub fn close() [1]u8 {
                return byte(6);
            }
        };

        pub const end_of_document = [1]u8{0x00};
    };
}

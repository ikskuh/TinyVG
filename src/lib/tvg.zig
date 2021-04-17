const std = @import("std");
const painterz = @import("painterz");

/// This is the TVG magic number which recognizes the icon format.
/// Magic numbers might seem unnecessary, but they will be the first
/// guard in line against bad input and prevent unnecessary cycles
/// to detect those.
pub const magic_number = [2]u8{ 0x72, 0x56 };

/// This is the latest TVG version supported by this library.
pub const current_version = 1;

// submodules

/// A generic module that provides functions for assembling TVG graphics at comptime or
/// runtime.
pub const builder = @import("builder.zig").create;

/// Module that provides a generic purpose TVG parser. This parser exports all data as
/// pre-scaled `f32` values.
pub const parsing = @import("parsing.zig");

/// A TVG software renderer based on the parsing module. Takes a parser stream as input.
pub const rendering = @import("rendering.zig");

/// Contains common TVG constants
pub const format = @import("format.zig");

/// Returns a stream of TVG commands as well as the document header.
/// - `allocator` is used to allocate temporary data like the current set of vertices for *FillPolygon*. This can be a fixed-buffer allocator.
/// - `reader` is a generic stream that provides the TVG byte data.
pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !parsing.Parser(@TypeOf(reader)) {
    return try parsing.Parser(@TypeOf(reader)).init(allocator, reader);
}

comptime {
    if (std.builtin.is_test) {
        _ = @import("builder.zig"); // import file for tests
        _ = parsing;
        _ = rendering;
    }
}

/// A TVG scale value. Defines the scale for all units inside a graphic.
/// The scale is defined by the number of decimal bits in a `i16`, thus scaling
/// can be trivially implemented by shifting the integers right by the scale bits.
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

    pub fn map(self: Self, value: f32) Unit {
        return Unit.init(self, value);
    }

    pub fn getShiftBits(self: Self) u4 {
        return @enumToInt(self);
    }

    pub fn getScaleFactor(self: Self) u15 {
        return @as(u15, 1) << self.getShiftBits();
    }
};

/// A scalable fixed-point number.
pub const Unit = enum(i16) {
    const Self = @This();

    _,

    pub fn init(scale: Scale, value: f32) Self {
        return @intToEnum(Self, @floatToInt(i16, value * @intToFloat(f32, scale.getScaleFactor()) + 0.5));
    }

    pub fn raw(self: Self) i16 {
        return @enumToInt(self);
    }

    pub fn toFloat(self: Self, scale: Scale) f32 {
        return @intToFloat(f32, @enumToInt(self)) / @intToFloat(f32, scale.getScaleFactor());
    }

    pub fn toInt(self: Self, scale: Scale) i16 {
        const factor = scale.getScaleFactor();
        return @divFloor(@enumToInt(self) + (@divExact(factor, 2)), factor);
    }

    pub fn toUnsignedInt(self: Self, scale: Scale) !u15 {
        const i = toInt(self, scale);
        if (i < 0)
            return error.InvalidData;
        return @intCast(u15, i);
    }
};

pub const Color = extern struct {
    const Self = @This();

    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn toArray(self: Self) [4]u8 {
        return [4]u8{
            self.r,
            self.g,
            self.b,
            self.a,
        };
    }

    pub fn lerp(lhs: Self, rhs: Self, factor: f32) Self {
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

pub const Point = struct {
    x: f32,
    y: f32,
};

pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Line = struct {
    start: Point,
    end: Point,
};

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

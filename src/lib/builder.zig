const std = @import("std");
const tvg = @import("tvg.zig");

pub fn builder(writer: anytype) Builder(@TypeOf(writer)) {
    return .{ .writer = writer };
}

pub fn Builder(comptime Writer: type) type {
    return struct {
        const Self = @This();

        pub const Error = Writer.Error || error{OutOfRange};

        writer: Writer,
        state: State = .initial,

        scale: tvg.Scale = undefined,
        range: tvg.Range = undefined,
        color_encoding: tvg.ColorEncoding = undefined,

        pub fn writeHeader(self: *Self, width: u32, height: u32, scale: tvg.Scale, color_encoding: tvg.ColorEncoding, range: tvg.Range) Error!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .initial);

            try self.writer.writeAll(&[_]u8{
                0x72, 0x56, // magic
                tvg.current_version, // version
                @enumToInt(scale) | (@as(u8, @enumToInt(color_encoding)) << 4) | (@as(u8, @enumToInt(range)) << 6),
            });
            switch (range) {
                .reduced => {
                    const rwidth = mapSizeToType(u8, width) catch return error.OutOfRange;
                    const rheight = mapSizeToType(u8, height) catch return error.OutOfRange;

                    try self.writer.writeIntLittle(u8, rwidth);
                    try self.writer.writeIntLittle(u8, rheight);
                },

                .default => {
                    const rwidth = mapSizeToType(u16, width) catch return error.OutOfRange;
                    const rheight = mapSizeToType(u16, height) catch return error.OutOfRange;

                    try self.writer.writeIntLittle(u16, rwidth);
                    try self.writer.writeIntLittle(u16, rheight);
                },

                .enhanced => {
                    try self.writer.writeIntLittle(u32, width);
                    try self.writer.writeIntLittle(u32, height);
                },
            }

            self.color_encoding = color_encoding;
            self.scale = scale;
            self.range = range;

            self.state = .color_table;
        }

        pub fn writeColorTable(self: *Self, colors: []const tvg.Color) (error{UnsupportedColorEncoding} || Error)!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .color_table);

            const count = std.math.cast(u32, colors.len) catch return error.OutOfRange;
            try self.writeUint(count);

            switch (self.color_encoding) {
                .u565 => for (colors) |c| {
                    const rgb8 = c.toRgba8();

                    const value: u16 =
                        (@as(u16, ((rgb8[0] >> 3) & 0x1F)) << 0) |
                        (@as(u16, ((rgb8[1] >> 2) & 0x2F)) << 5) |
                        (@as(u16, ((rgb8[2] >> 3) & 0x1F)) << 11);

                    try self.writer.writeIntLittle(u16, value);
                },

                .u8888 => for (colors) |c| {
                    var rgba = c.toRgba8();
                    try self.writer.writeIntLittle(u8, rgba[0]);
                    try self.writer.writeIntLittle(u8, rgba[1]);
                    try self.writer.writeIntLittle(u8, rgba[2]);
                    try self.writer.writeIntLittle(u8, rgba[3]);
                },
                .f32 => for (colors) |c| {
                    try self.writer.writeIntLittle(u32, @bitCast(u32, c.r));
                    try self.writer.writeIntLittle(u32, @bitCast(u32, c.g));
                    try self.writer.writeIntLittle(u32, @bitCast(u32, c.b));
                    try self.writer.writeIntLittle(u32, @bitCast(u32, c.a));
                },

                .custom => return error.UnsupportedColorEncoding,
            }

            self.state = .body;
        }

        pub fn writeCustomColorTable(self: *Self) (error{UnsupportedColorEncoding} || Error)!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .color_table);

            if (self.color_encoding != .custom) {
                return error.UnsupportedColorEncoding;
            }

            self.state = .body;
        }

        pub fn writeFillPolygon(self: *Self, style: tvg.Style, points: []const tvg.Point) Error!void {
            const count = try mapToU6(points.len);

            try self.writeCommand(.fill_polygon);
            try self.writeStyleTypeAndCount(style, count);
            try self.writeStyle(style);

            for (points) |pt| {
                try self.writePoint(pt);
            }
        }

        pub fn writeFillRectangles(self: *Self, style: tvg.Style, rectangles: []const tvg.Rectangle) Error!void {
            const rectangle_count = try mapToU6(rectangles.len);

            try self.writeCommand(.fill_rectangles);
            try self.writeStyleTypeAndCount(style, rectangle_count);
            try self.writeStyle(style);

            for (rectangles) |rect| {
                try self.writeRectangle(rect);
            }
        }

        pub fn writeDrawLines(self: *Self, style: tvg.Style, line_width: f32, lines: []const tvg.Line) Error!void {
            const count = try mapToU6(lines.len);

            try self.writeCommand(.draw_lines);
            try self.writeStyleTypeAndCount(style, count);
            try self.writeStyle(style);
            try self.writeUnit(line_width);

            for (lines) |line| {
                try self.writePoint(line.start);
                try self.writePoint(line.end);
            }
        }

        pub fn writeDrawLineLoop(self: *Self, style: tvg.Style, line_width: f32, points: []const tvg.Point) Error!void {
            const count = try mapToU6(points.len - 1);

            try self.writeCommand(.draw_line_loop);
            try self.writeStyleTypeAndCount(style, count);
            try self.writeStyle(style);
            try self.writeUnit(line_width);

            for (points) |pt| {
                try self.writePoint(pt);
            }
        }

        pub fn writeDrawLineStrip(self: *Self, style: tvg.Style, line_width: f32, points: []const tvg.Point) Error!void {
            const count = try mapToU6(points.len - 1);

            try self.writeCommand(.draw_line_strip);
            try self.writeStyleTypeAndCount(style, count);
            try self.writeStyle(style);
            try self.writeUnit(line_width);

            for (points) |pt| {
                try self.writePoint(pt);
            }
        }

        pub fn writeOutlineFillPolygon(self: *Self, fill_style: tvg.Style, line_style: tvg.Style, line_width: f32, points: []const tvg.Point) Error!void {
            const count = try mapToU6(points.len);

            try self.writeCommand(.outline_fill_polygon);
            try self.writeStyleTypeAndCount(fill_style, count);
            try self.writer.writeByte(@enumToInt(std.meta.activeTag(line_style)));
            try self.writeStyle(line_style);
            try self.writeStyle(fill_style);
            try self.writeUnit(line_width);

            for (points) |pt| {
                try self.writePoint(pt);
            }
        }

        pub fn writeOutlineFillRectangles(self: *Self, fill_style: tvg.Style, line_style: tvg.Style, line_width: f32, rectangles: []const tvg.Rectangle) Error!void {
            const rectangle_count = try mapToU6(rectangles.len);

            try self.writeCommand(.outline_fill_rectangles);
            try self.writeStyleTypeAndCount(fill_style, rectangle_count);

            try self.writer.writeByte(@enumToInt(std.meta.activeTag(line_style)));
            try self.writeStyle(line_style);
            try self.writeStyle(fill_style);
            try self.writeUnit(line_width);

            for (rectangles) |rect| {
                try self.writeRectangle(rect);
            }
        }

        pub fn writeFillPath(self: *Self, style: tvg.Style, path: []const tvg.Path.Segment) Error!void {
            const segment_count = try validatePath(path);

            try self.writeCommand(.fill_path);
            try self.writeStyleTypeAndCount(style, segment_count);
            try self.writeStyle(style);

            try self.writePath(path);
        }

        pub fn writeDrawPath(self: *Self, style: tvg.Style, line_width: f32, path: []const tvg.Path.Segment) Error!void {
            const segment_count = try validatePath(path);

            try self.writeCommand(.draw_line_path);
            try self.writeStyleTypeAndCount(style, segment_count);
            try self.writeStyle(style);

            try self.writeUnit(line_width);

            try self.writePath(path);
        }

        pub fn writeOutlineFillPath(self: *Self, fill_style: tvg.Style, line_style: tvg.Style, line_width: f32, path: []const tvg.Path.Segment) Error!void {
            const segment_count = try validatePath(path);

            try self.writeCommand(.outline_fill_path);
            try self.writeStyleTypeAndCount(fill_style, segment_count);

            try self.writer.writeByte(@enumToInt(std.meta.activeTag(line_style)));

            try self.writeStyle(line_style);
            try self.writeStyle(fill_style);
            try self.writeUnit(line_width);

            try self.writePath(path);
        }

        pub fn writeEndOfFile(self: *Self) Error!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .body);

            try self.writer.writeByte(@enumToInt(tvg.format.Command.end_of_document));

            self.state = .end_of_file;
        }

        fn validatePath(segments: []const tvg.Path.Segment) Error!StyleCount {
            const segment_count = try mapToU6(segments.len);
            for (segments) |segment| {
                _ = std.math.cast(u32, segment.commands.len) catch return error.OutOfRange;
            }
            return segment_count;
        }

        fn writeCommand(self: *Self, cmd: tvg.format.Command) Error!void {
            try self.writer.writeByte(@enumToInt(cmd));
        }

        /// Encodes a 6 bit count as well as a 2 bit style type.
        fn writeStyleTypeAndCount(self: *Self, style: tvg.StyleType, mapped_count: StyleCount) !void {
            const data = (@as(u8, @enumToInt(style)) << 6) | @enumToInt(mapped_count);
            try self.writer.writeByte(data);
        }

        /// Writes a Style without encoding the type. This must be done via a second channel.
        fn writeStyle(self: *Self, style: tvg.Style) Error!void {
            return switch (style) {
                .flat => |value| try self.writeUint(value),
                .linear, .radial => |grad| {
                    try self.writePoint(grad.point_0);
                    try self.writePoint(grad.point_1);
                    try self.writeUint(grad.color_0);
                    try self.writeUint(grad.color_1);
                },
            };
        }

        fn writePath(self: *Self, path: []const tvg.Path.Segment) !void {
            std.debug.assert(path.len > 0);
            std.debug.assert(path.len <= 64);
            for (path) |item| {
                try self.writeUint(@intCast(u32, item.commands.len));
            }
            for (path) |item| {
                try self.writePoint(item.start);
                for (item.commands) |node| {
                    const kind: u8 = @enumToInt(std.meta.activeTag(node));

                    const line_width = switch (node) {
                        .line => |data| data.line_width,
                        .horiz => |data| data.line_width,
                        .vert => |data| data.line_width,
                        .bezier => |data| data.line_width,
                        .arc_circle => |data| data.line_width,
                        .arc_ellipse => |data| data.line_width,
                        .close => |data| data.line_width,
                        .quadratic_bezier => |data| data.line_width,
                    };

                    const tag: u8 = kind |
                        if (line_width != null) @as(u8, 0x10) else 0;

                    try self.writer.writeByte(tag);
                    if (line_width) |width| {
                        try self.writeUnit(width);
                    }

                    switch (node) {
                        .line => |data| try self.writePoint(data.data),
                        .horiz => |data| try self.writeUnit(data.data),
                        .vert => |data| try self.writeUnit(data.data),
                        .bezier => |data| {
                            try self.writePoint(data.data.c0);
                            try self.writePoint(data.data.c1);
                            try self.writePoint(data.data.p1);
                        },
                        .arc_circle => |data| {
                            const flags: u8 = 0 |
                                (@as(u8, @boolToInt(data.data.sweep)) << 1) |
                                (@as(u8, @boolToInt(data.data.large_arc)) << 0);
                            try self.writer.writeByte(flags);
                            try self.writeUnit(data.data.radius);
                            try self.writePoint(data.data.target);
                        },
                        .arc_ellipse => |data| {
                            const flags: u8 = 0 |
                                (@as(u8, @boolToInt(data.data.sweep)) << 1) |
                                (@as(u8, @boolToInt(data.data.large_arc)) << 0);
                            try self.writer.writeByte(flags);
                            try self.writeUnit(data.data.radius_x);
                            try self.writeUnit(data.data.radius_y);
                            try self.writeUnit(data.data.rotation);
                            try self.writePoint(data.data.target);
                        },
                        .quadratic_bezier => |data| {
                            try self.writePoint(data.data.c);
                            try self.writePoint(data.data.p1);
                        },
                        .close => {},
                    }
                }
            }
        }

        fn writeUint(self: *Self, value: u32) Error!void {
            var iter = value;
            while (iter >= 0x80) {
                try self.writer.writeByte(@as(u8, 0x80) | @truncate(u7, iter));
                iter >>= 7;
            }
            try self.writer.writeByte(@truncate(u7, iter));
        }

        fn writeUnit(self: *Self, value: f32) Error!void {
            const val = self.scale.map(value).raw();
            switch (self.range) {
                .reduced => {
                    const reduced_val = std.math.cast(i8, val) catch return error.OutOfRange;
                    try self.writer.writeIntLittle(i8, reduced_val);
                },
                .default => {
                    const reduced_val = std.math.cast(i16, val) catch return error.OutOfRange;
                    try self.writer.writeIntLittle(i16, reduced_val);
                },
                .enhanced => {
                    try self.writer.writeIntLittle(i32, val);
                },
            }
        }

        fn writePoint(self: *Self, point: tvg.Point) Error!void {
            try self.writeUnit(point.x);
            try self.writeUnit(point.y);
        }

        fn writeRectangle(self: *Self, rect: tvg.Rectangle) Error!void {
            try self.writeUnit(rect.x);
            try self.writeUnit(rect.y);
            try self.writeUnit(rect.width);
            try self.writeUnit(rect.height);
        }

        const State = enum {
            initial,
            color_table,
            body,
            end_of_file,
            faulted,
        };
    };
}

fn mapSizeToType(comptime Dest: type, value: u32) error{OutOfRange}!Dest {
    if (value == 0 or value > std.math.maxInt(Dest) + 1) return error.OutOfRange;
    if (value == std.math.maxInt(Dest))
        return 0;
    return @intCast(Dest, value);
}

fn mapToU6(value: usize) error{OutOfRange}!StyleCount {
    if (value == 0 or value > 0x20) return error.OutOfRange;
    if (value == 0x40)
        return @intToEnum(StyleCount, 0);
    return @intToEnum(StyleCount, @intCast(u6, value));
}

const StyleCount = enum(u6) {
    // 0 = 64, everything else is equivalent
    _,
};

const ground_truth = @import("ground-truth");

test "encode shield (default range, scale 1/256)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(24, 24, .@"1/256", .default);
    try ground_truth.renderShield(&writer);
}

test "encode shield (reduced range, scale 1/4)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(24, 24, .@"1/4", .reduced);
    try ground_truth.renderShield(&writer);
}

test "encode app_menu (default range, scale 1/256)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(48, 48, .@"1/256", .default);
    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("000000"),
    });
    try writer.writeFillRectangles(tvg.Style{ .flat = 0 }, &[_]tvg.Rectangle{
        tvg.rectangle(6, 12, 36, 4),
        tvg.rectangle(6, 22, 36, 4),
        tvg.rectangle(6, 32, 36, 4),
    });
    try writer.writeEndOfFile();
}

test "encode workspace (default range, scale 1/256)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(48, 48, .@"1/256", .default);
    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("008751"),
        try tvg.Color.fromString("83769c"),
        try tvg.Color.fromString("1d2b53"),
    });

    try writer.writeFillRectangles(tvg.Style{ .flat = 0 }, &[_]tvg.Rectangle{tvg.rectangle(6, 6, 16, 36)});
    try writer.writeFillRectangles(tvg.Style{ .flat = 1 }, &[_]tvg.Rectangle{tvg.rectangle(26, 6, 16, 16)});
    try writer.writeFillRectangles(tvg.Style{ .flat = 2 }, &[_]tvg.Rectangle{tvg.rectangle(26, 26, 16, 16)});
    try writer.writeEndOfFile();
}

test "encode workspace_add (default range, scale 1/256)" {
    const Node = tvg.Path.Node;

    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(48, 48, .@"1/256", .default);
    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("008751"),
        try tvg.Color.fromString("83769c"),
        try tvg.Color.fromString("ff004d"),
    });

    try writer.writeFillRectangles(tvg.Style{ .flat = 0 }, &[_]tvg.Rectangle{tvg.rectangle(6, 6, 16, 36)});
    try writer.writeFillRectangles(tvg.Style{ .flat = 1 }, &[_]tvg.Rectangle{tvg.rectangle(26, 6, 16, 16)});

    try writer.writeFillPath(tvg.Style{ .flat = 2 }, &[_]tvg.Path.Segment{
        tvg.Path.Segment{
            .start = tvg.point(26, 32),
            .commands = &[_]Node{
                Node{ .horiz = .{ .data = 32 } },
                Node{ .vert = .{ .data = 26 } },
                Node{ .horiz = .{ .data = 36 } },
                Node{ .vert = .{ .data = 32 } },
                Node{ .horiz = .{ .data = 42 } },
                Node{ .vert = .{ .data = 36 } },
                Node{ .horiz = .{ .data = 36 } },
                Node{ .vert = .{ .data = 42 } },
                Node{ .horiz = .{ .data = 32 } },
                Node{ .vert = .{ .data = 36 } },
                Node{ .horiz = .{ .data = 26 } },
            },
        },
    });

    try writer.writeEndOfFile();
}

test "encode arc_variants (default range, scale 1/256)" {
    const Node = tvg.Path.Node;

    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(92, 92, .@"1/256", .default);
    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("40ff00"),
    });

    try writer.writeFillPath(tvg.Style{ .flat = 0 }, &[_]tvg.Path.Segment{
        tvg.Path.Segment{
            .start = tvg.point(48, 32),
            .commands = &[_]Node{
                Node{ .horiz = .{ .data = 64 } },
                Node{ .arc_ellipse = .{ .data = .{ .radius_x = 18.5, .radius_y = 18.5, .rotation = 0, .large_arc = false, .sweep = true, .target = tvg.point(80, 48) } } },
                Node{ .vert = .{ .data = 64 } },
                Node{ .arc_ellipse = .{ .data = .{ .radius_x = 18.5, .radius_y = 18.5, .rotation = 0, .large_arc = false, .sweep = false, .target = tvg.point(64, 80) } } },
                Node{ .horiz = .{ .data = 48 } },
                Node{ .arc_ellipse = .{ .data = .{ .radius_x = 18.5, .radius_y = 18.5, .rotation = 0, .large_arc = true, .sweep = true, .target = tvg.point(32, 64) } } },
                Node{ .vert = .{ .data = 64 } },
                Node{ .arc_ellipse = .{ .data = .{ .radius_x = 18.5, .radius_y = 18.5, .rotation = 0, .large_arc = true, .sweep = false, .target = tvg.point(48, 32) } } },
            },
        },
    });

    try writer.writeEndOfFile();
}

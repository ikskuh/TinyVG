const std = @import("std");
const tvg = @import("tvg.zig");

pub fn builder(writer: anytype) Builder(@TypeOf(writer)) {
    return .{ .writer = writer };
}

pub fn Builder(comptime Writer: type) type {
    return struct {
        const Self = @This();

        const Error = Writer.Error || error{OutOfRange};

        writer: Writer,
        state: State = .initial,

        scale: tvg.Scale = undefined,
        range: tvg.Range = undefined,

        pub fn writeHeader(self: *Self, width: u16, height: u16, scale: tvg.Scale, range: tvg.Range) Error!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .initial);

            try self.writer.writeAll(&[_]u8{
                0x72, 0x56, // magic
                tvg.current_version, // version
                @enumToInt(scale) | (if (range == .reduced) @as(u8, 0x20) else 0),
            });
            switch (range) {
                .reduced => {
                    const rwidth = mapSizeToByte(width) catch return error.OutOfRange;
                    const rheight = mapSizeToByte(height) catch return error.OutOfRange;

                    try self.writer.writeIntLittle(u8, rwidth);
                    try self.writer.writeIntLittle(u8, rheight);
                },
                .default => {
                    try self.writer.writeIntLittle(u16, width);
                    try self.writer.writeIntLittle(u16, height);
                },
            }

            self.scale = scale;
            self.range = range;

            self.state = .color_table;
        }

        pub fn writeColorTable(self: *Self, colors: []const tvg.Color) Error!void {
            errdefer self.state = .faulted;
            std.debug.assert(self.state == .color_table);

            const count = std.math.cast(u16, colors.len) catch return error.OutOfRange;

            try self.writer.writeIntLittle(u16, count);
            for (colors) |c| {
                try self.writer.writeAll(&[_]u8{ c.r, c.g, c.b, c.a });
            }

            self.state = .body;
        }

        pub fn writeFillPolygon(self: *Self) Error!void {
            _ = self;
            @panic("fillPolygon not implemented yet!");
        }
        pub fn writeFillRectangles(self: *Self) Error!void {
            _ = self;
            @panic("fillRectangles not implemented yet!");
        }
        pub fn writeDrawLines(self: *Self) Error!void {
            _ = self;
            @panic("drawLines not implemented yet!");
        }
        pub fn writeDrawLineLoop(self: *Self) Error!void {
            _ = self;
            @panic("drawLineLoop not implemented yet!");
        }
        pub fn writeDrawLineStrip(self: *Self) Error!void {
            _ = self;
            @panic("drawLineStrip not implemented yet!");
        }
        pub fn writeOutlineFillPolygon(self: *Self) Error!void {
            _ = self;
            @panic("outlineFillPolygon not implemented yet!");
        }
        pub fn writeOutlineFillRectangles(self: *Self) Error!void {
            _ = self;
            @panic("outlineFillRectangles not implemented yet!");
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

            try self.writeCommand(.draw_path);
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
                        if (line_width != null) @as(u8, 0x40) else 0;

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
            const val = @bitCast(u16, self.scale.map(value).raw());
            switch (self.range) {
                .reduced => {
                    const reduced_val = std.math.cast(u8, val) catch return error.OutOfRange;
                    try self.writer.writeIntLittle(u8, reduced_val);
                },
                .default => {
                    try self.writer.writeIntLittle(u16, val);
                },
            }
        }

        fn writePoint(self: *Self, point: tvg.Point) Error!void {
            try self.writeUnit(point.x);
            try self.writeUnit(point.y);
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

fn mapSizeToByte(value: u16) error{OutOfRange}!u8 {
    if (value == 0 or value > 0x100) return error.OutOfRange;
    if (value == 0x100)
        return 0;
    return @intCast(u8, value);
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

fn renderTestShield(writer: *Builder(std.io.FixedBufferStream([]u8).Writer)) !void {
    const Node = tvg.Path.Node;

    // header is already written here

    try writer.writeColorTable(&[_]tvg.Color{
        try tvg.Color.fromString("29adff"),
        try tvg.Color.fromString("fff1e8"),
    });

    try writer.writeFillPath(
        tvg.Style{ .flat = 0 },
        &[_]tvg.Path.Segment{
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 12, .y = 1 },
                .commands = &[_]Node{
                    Node{ .line = .{ .data = tvg.point(3, 5) } },
                    Node{ .vert = .{ .data = 11 } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(3, 16.55), .c1 = tvg.point(6.84, 21.74), .p1 = tvg.point(12, 23) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(17.16, 21.74), .c1 = tvg.point(21, 16.55), .p1 = tvg.point(21, 11) } } },
                    Node{ .vert = .{ .data = 5 } },
                },
            },
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 17.13, .y = 17 },
                .commands = &[_]Node{
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15.92, 18.85), .c1 = tvg.point(14.11, 20.24), .p1 = tvg.point(12, 20.92) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(9.89, 20.24), .c1 = tvg.point(8.08, 18.85), .p1 = tvg.point(6.87, 17) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(6.53, 16.5), .c1 = tvg.point(6.24, 16), .p1 = tvg.point(6, 15.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(6, 13.82), .c1 = tvg.point(8.71, 12.47), .p1 = tvg.point(12, 12.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15.29, 12.47), .c1 = tvg.point(18, 13.79), .p1 = tvg.point(18, 15.47) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(17.76, 16), .c1 = tvg.point(17.47, 16.5), .p1 = tvg.point(17.13, 17) } } },
                },
            },
            tvg.Path.Segment{
                .start = tvg.Point{ .x = 12, .y = 5 },
                .commands = &[_]Node{
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(13.5, 5), .c1 = tvg.point(15, 6.2), .p1 = tvg.point(15, 8) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(15, 9.5), .c1 = tvg.point(13.8, 10.998), .p1 = tvg.point(12, 11) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(10.5, 11), .c1 = tvg.point(9, 9.8), .p1 = tvg.point(9, 8) } } },
                    Node{ .bezier = .{ .data = Node.Bezier{ .c0 = tvg.point(9, 6.4), .c1 = tvg.point(10.2, 5), .p1 = tvg.point(12, 5) } } },
                },
            },
        },
    );

    try writer.writeEndOfFile();
}

const ground_truth = @import("ground-truth");

test "render shield (default range, scale 1/256)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(24, 24, .@"1/256", .default);
    try renderTestShield(&writer);

    try std.testing.expectEqualSlices(u8, &ground_truth.shield, stream.getWritten());
}

test "render shield (reduced range, scale 1/4)" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var writer = builder(stream.writer());
    try writer.writeHeader(24, 24, .@"1/4", .reduced);
    try renderTestShield(&writer);

    try std.testing.expectEqualSlices(u8, &ground_truth.shield_8, stream.getWritten());
}

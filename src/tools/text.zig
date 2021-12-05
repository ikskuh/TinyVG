const std = @import("std");
const tvg = @import("tvg");
const ptk = @import("ptk");
const args = @import("args");

fn printUsage(stream: anytype) !void {
    try stream.writeAll(
        \\tvg-text [-I <fmt>] [-O <fmt>] [-o <output>] <input>
        \\
        \\Converts tvg related files between different formats. Only supports a single input and output file.
        \\
        \\Options:
        \\  <input>                     defines the input file, performs auto detection of the format if -I is not specified. Use - for stdin.
        \\  -h, --help                  prints this text.
        \\  -I, --input-format  <fmt>   sets the format of the input file.
        \\  -O, --output-format <fmt>   sets the format of the output file.
        \\  -o, --output <file>         sets the output file, or use - for stdout. performs auto detection of the format if -O is not specified.
        \\
        \\Support formats:
        \\  tvg  - Tiny vector graphics, binary representation.
        \\  tvgt - Tiny vector graphics, text representation.
        \\  svg  - Scalable vector graphics. Only usable for output, use svg2tvgt to convert to tvg text format.
        \\
    );
}

const CliOptions = struct {
    help: bool = false,

    @"input-format": ?Format = null,
    @"output-format": ?Format = null,

    output: ?[]const u8 = null,

    pub const shorthands = .{
        .o = "output",
        .h = "help",
        .I = "input-format",
        .O = "output-format",
    };
};

const Format = enum {
    tvg,
    tvgt,
    svg,
};

fn detectFormat(ext: []const u8) ?Format {
    return if (std.mem.eql(u8, ext, ".tvg"))
        Format.tvg
    else if (std.mem.eql(u8, ext, ".tvgt"))
        Format.tvgt
    else if (std.mem.eql(u8, ext, ".svg"))
        Format.svg
    else
        null;
}

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const cli = args.parseForCurrentProcess(CliOptions, allocator, .print) catch return 1;
    defer cli.deinit();

    // const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (cli.options.help) {
        try printUsage(stdout);
        return 0;
    }

    if (cli.positionals.len != 1) {
        try stderr.writeAll("Expected exactly one positional argument!\n");
        try printUsage(stderr);
        return 1;
    }

    const input_file = cli.positionals[0];
    const input_ext = std.fs.path.extension(input_file);
    const input_format = cli.options.@"input-format" orelse
        detectFormat(input_ext) orelse {
        try stderr.print("Could not auto-detect the input format for extension {s}\n", .{input_ext});
        return 1;
    };

    const output_file = cli.options.output orelse blk: {
        if (cli.options.@"output-format" == null) {
            try stderr.print("Could not auto-detect the input format for extension {s}\n", .{input_ext});
            return 1;
        }
        const dest_ext: []const u8 = switch (cli.options.@"output-format".?) {
            .svg => ".svg",
            .tvg => ".tvg",
            .tvgt => ".tvgt",
        };
        break :blk try std.mem.join(allocator, "", &[_][]const u8{
            input_file[0 .. input_file.len - input_ext.len],
            dest_ext,
        });
    };
    const output_ext = std.fs.path.extension(output_file);
    const output_format = cli.options.@"output-format" orelse
        detectFormat(output_ext) orelse {
        try stderr.print("Could not auto-detect the output format for extension {s}\n", .{output_ext});
        return 1;
    };

    var intermediary_tvg = std.ArrayList(u8).init(allocator);
    defer intermediary_tvg.deinit();

    var input_stream = try FileOrStream.openRead(std.fs.cwd(), input_file);
    defer input_stream.close();

    switch (input_format) {
        .tvg => {
            const buffer = try input_stream.file.readToEndAlloc(allocator, 1 << 24);

            intermediary_tvg.deinit();
            intermediary_tvg = std.ArrayList(u8).fromOwnedSlice(allocator, buffer);
        },

        .tvgt => {
            // TODO: Implement TVGT parsing
        },

        .svg => {
            try stderr.print("This tool cannot convert from SVG files. Use svg2tvg to convert the SVG to TVG textual representation.\n", .{});
            return 1;
        },
    }

    // Conversion process:
    //
    // Read the input file and directly convert it to TVG (binary).
    // After that, write the output file via the TVG decoder.

    // std.log.err("input:  {s} {s}", .{ input_file, @tagName(input_format) });
    // std.log.err("output: {s} {s}", .{ output_file, @tagName(output_format) });

    {

        // Parse file header before creating the output file
        var stream = std.io.fixedBufferStream(intermediary_tvg.items);
        var parser = try tvg.parse(allocator, stream.reader());
        defer parser.deinit();

        // Open/create the output file after the TVG header was valid
        var output_stream = try FileOrStream.openWrite(std.fs.cwd(), output_file);
        defer output_stream.close();

        switch (output_format) {
            .tvg => {
                try output_stream.writer().writeAll(intermediary_tvg.items);
            },
            .tvgt => {
                try renderTvgText(std.io.FixedBufferStream([]u8).Reader, output_stream.writer(), &parser);
            },
            .svg => {
                // TODO: Implement SVG rendering
            },
        }
    }
    return 0;
}

const FileOrStream = struct {
    file: std.fs.File,
    close_stream: bool,

    fn openRead(dir: std.fs.Dir, path: []const u8) !FileOrStream {
        if (std.mem.eql(u8, path, "-")) {
            return FileOrStream{
                .file = std.io.getStdIn(),
                .close_stream = false,
            };
        }
        return FileOrStream{
            .file = try dir.openFile(path, .{}),
            .close_stream = true,
        };
    }

    fn openWrite(dir: std.fs.Dir, path: []const u8) !FileOrStream {
        if (std.mem.eql(u8, path, "-")) {
            return FileOrStream{
                .file = std.io.getStdOut(),
                .close_stream = false,
            };
        }
        return FileOrStream{
            .file = try dir.createFile(path, .{}),
            .close_stream = true,
        };
    }

    fn reader(self: *FileOrStream) std.fs.File.Reader {
        return self.file.reader();
    }

    fn writer(self: *FileOrStream) std.fs.File.Writer {
        return self.file.writer();
    }

    fn close(self: *FileOrStream) void {
        if (self.close_stream) {
            self.file.close();
        }
        self.* = undefined;
    }
};

fn renderTvgText(comptime Reader: type, writer: anytype, parser: *tvg.parsing.Parser(Reader)) !void {
    try writer.print("(tvg {d}\n", .{parser.header.version});
    try writer.print("  ({d} {d} {s} {s} {s})\n", .{
        parser.header.width,
        parser.header.height,
        @tagName(parser.header.scale),
        @tagName(parser.header.color_encoding),
        @tagName(parser.header.coordinate_range),
    });

    try writer.writeAll("  (\n");
    for (parser.color_table) |color| {
        if (color.a != 1.0) {
            try writer.print("    ({d:.3} {d:.3} {d:.3} {d:.3})\n", .{
                color.r, color.g, color.b, color.a,
            });
        } else {
            try writer.print("    ({d:.3} {d:.3} {d:.3})\n", .{
                color.r, color.g, color.b,
            });
        }
    }
    try writer.writeAll("  )\n");

    try writer.writeAll("  (\n");
    while (try parser.next()) |command| {
        try writer.print("     (\n       {s}", .{std.meta.tagName(command)});
        switch (command) {
            .fill_rectangles => |data| {
                try renderStyle("\n       ", writer, data.style);
                try renderRectangles("\n       ", writer, data.rectangles);
            },

            .outline_fill_rectangles => |data| {
                try renderStyle("\n       ", writer, data.fill_style);
                try renderStyle("\n       ", writer, data.line_style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderRectangles("\n       ", writer, data.rectangles);
            },

            .draw_lines => |data| {
                try renderStyle("\n       ", writer, data.style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderLines("\n       ", writer, data.lines);
            },

            .draw_line_loop => |data| {
                try renderStyle("\n       ", writer, data.style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderPoints("\n       ", writer, data.vertices);
            },

            .draw_line_strip => |data| {
                try renderStyle("\n       ", writer, data.style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderPoints("\n       ", writer, data.vertices);
            },

            .fill_polygon => |data| {
                try renderStyle("\n       ", writer, data.style);
                try renderPoints("\n       ", writer, data.vertices);
            },

            .outline_fill_polygon => |data| {
                try renderStyle("\n       ", writer, data.fill_style);
                try renderStyle("\n       ", writer, data.line_style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderPoints("\n       ", writer, data.vertices);
            },

            .draw_line_path => |data| {
                try renderStyle("\n       ", writer, data.style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderPath("\n       ", writer, data.path);
            },

            .fill_path => |data| {
                try renderStyle("\n       ", writer, data.style);
                try renderPath("\n       ", writer, data.path);
            },

            .outline_fill_path => |data| {
                try renderStyle("\n       ", writer, data.fill_style);
                try renderStyle("\n       ", writer, data.line_style);
                try writer.print("\n       {d}", .{data.line_width});
                try renderPath("\n       ", writer, data.path);
            },
        }
        try writer.writeAll("\n     )\n");
    }
    try writer.writeAll("  )\n");

    try writer.writeAll(")\n");
}

fn renderRectangles(line_prefix: []const u8, writer: anytype, rects: []const tvg.Rectangle) !void {
    try writer.print("{s}(", .{line_prefix});
    for (rects) |r| {
        try writer.print("{s}  ({d} {d} {d} {d})", .{
            line_prefix, r.x, r.y, r.width, r.height,
        });
    }
    try writer.print("{s})", .{line_prefix});
}

fn renderLines(line_prefix: []const u8, writer: anytype, lines: []const tvg.Line) !void {
    try writer.print("{s}(", .{line_prefix});
    for (lines) |l| {
        try writer.print("{s}  (({d} {d}) ({d} {d}))", .{
            line_prefix, l.start.x, l.start.y, l.end.x, l.end.y,
        });
    }
    try writer.print("{s})", .{line_prefix});
}

fn renderPoints(line_prefix: []const u8, writer: anytype, point: []const tvg.Point) !void {
    try writer.print("{s}(", .{line_prefix});
    for (point) |p| {
        try writer.print("{s}  ({d} {d})", .{
            line_prefix, p.x, p.y,
        });
    }
    try writer.print("{s})", .{line_prefix});
}

fn renderPath(line_prefix: []const u8, writer: anytype, path: tvg.Path) !void {
    try writer.print("{s}(", .{line_prefix});
    for (path.segments) |segment| {
        try writer.print("{s}  ({d} {d}){s}  (", .{ line_prefix, segment.start.x, segment.start.y, line_prefix });
        for (segment.commands) |node| {
            try writer.print("{s}    ", .{line_prefix});
            try renderPathNode(writer, node);
        }
        try writer.print("{s}  )", .{line_prefix});
    }
    try writer.print("{s})", .{line_prefix});
}

fn renderPathNode(writer: anytype, node: tvg.Path.Node) !void {
    switch (node) {
        .line => |line| try writer.print("(line {d} {d})", .{ line.data.x, line.data.y }),
        .horiz => |horiz| try writer.print("(horiz {d})", .{horiz.data}),
        .vert => |vert| try writer.print("(vert {d})", .{vert.data}),
        .bezier => |bezier| try writer.print("(bezier ({d} {d}) ({d} {d}) ({d} {d}))", .{
            bezier.data.c0.x,
            bezier.data.c0.y,
            bezier.data.c1.x,
            bezier.data.c1.y,
            bezier.data.p1.x,
            bezier.data.p1.y,
        }),
        .quadratic_bezier => |bezier| try writer.print("(quad-bezier ({d} {d}) ({d} {d}))", .{
            bezier.data.c.x,
            bezier.data.c.y,
            bezier.data.p1.x,
            bezier.data.p1.y,
        }),
        .arc_circle => |arc_circle| try writer.print("(arc-circle {d}, {}, {}, ({d} {d}))", .{
            arc_circle.data.radius,
            arc_circle.data.large_arc,
            arc_circle.data.sweep,
            arc_circle.data.target.x,
            arc_circle.data.target.y,
        }),
        .arc_ellipse => |arc_ellipse| try writer.print("(arc-ellipse {d}, {d}, {d}, {}, {}, ({d} {d}))", .{
            arc_ellipse.data.radius_x,
            arc_ellipse.data.radius_y,
            arc_ellipse.data.rotation,
            arc_ellipse.data.large_arc,
            arc_ellipse.data.sweep,
            arc_ellipse.data.target.x,
            arc_ellipse.data.target.y,
        }),
        .close => try writer.writeAll("(close)"),
    }
}

fn renderStyle(line_prefix: []const u8, writer: anytype, style: tvg.Style) !void {
    switch (style) {
        .flat => |color| try writer.print("{s}(flat {d})", .{ line_prefix, color }),
        .linear, .radial => |grad| {
            try writer.print("{s}({s} ({d} {d}) ({d} {d}) {d} {d} )", .{
                line_prefix,
                std.meta.tagName(style),
                grad.point_0.x,
                grad.point_0.y,
                grad.point_1.x,
                grad.point_1.y,
                grad.color_0,
                grad.color_1,
            });
        },
    }
}

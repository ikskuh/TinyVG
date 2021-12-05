const std = @import("std");
const tvg = @import("tvg");
const ptk = @import("ptk");
const args = @import("args");

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

    const read_stdin = std.mem.eql(u8, cli.positionals[0], "-");
    const write_stdout = if (cli.options.output) |o|
        std.mem.eql(u8, o, "-")
    else
        false;

    if (read_stdin and cli.options.output == null) {
        try stderr.writeAll("Requires --output file name set when reading from stdin!\n");
        try printUsage(stderr);
        return 1;
    }

    var source_file: std.fs.File = if (read_stdin)
        std.io.getStdIn()
    else
        try std.fs.cwd().openFile(cli.positionals[0], .{});
    defer if (!read_stdin)
        source_file.close();

    // Parse file header before creating the output file

    var parser = try tvg.parse(allocator, source_file.reader());
    defer parser.deinit();

    // Open/create the output file after the TVG header was valid

    var dest_file: std.fs.File = if (write_stdout)
        std.io.getStdIn()
    else blk: {
        var out_name = cli.options.output orelse try std.mem.concat(allocator, u8, &[_][]const u8{
            cli.positionals[0][0..(cli.positionals[0].len - std.fs.path.extension(cli.positionals[0]).len)],
            ".tvgt",
        });

        break :blk try std.fs.cwd().createFile(out_name, .{});
    };
    defer if (!read_stdin)
        dest_file.close();

    // Start rendering the file output

    try renderTvgText(dest_file.writer(), &parser);

    return 0;
}

fn renderTvgText(writer: anytype, parser: *tvg.parsing.Parser(std.fs.File.Reader)) !void {
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

const CliOptions = struct {
    help: bool = false,

    output: ?[]const u8 = null,

    pub const shorthands = .{
        .o = "output",
        .h = "help",
    };
};

fn printUsage(stream: anytype) !void {
    try stream.writeAll(
        \\tvg-render [-o file] source.tvg
        \\
    );
}

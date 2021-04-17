const std = @import("std");
const tvg = @import("tvg");
const args = @import("args");

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const cli = args.parseForCurrentProcess(CliOptions, allocator) catch return 1;
    defer cli.deinit();

    const stdin = std.io.getStdIn().reader();
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
            ".ppm",
        });

        break :blk try std.fs.cwd().createFile(out_name, .{});
    };
    defer if (!read_stdin)
        dest_file.close();

    // Start rendering the file output

    var writer = dest_file.writer();

    try writer.writeAll("(tvg\n");
    try writer.print("  ({d} {d} {d} {d})\n", .{
        parser.header.version,
        @as(u16, 1) << @enumToInt(parser.header.scale),
        parser.header.width,
        parser.header.height,
    });

    try writer.writeAll("  (\n");
    for (parser.color_table) |color| {
        if (color.a != 0xFF) {
            try writer.print("    ({} {} {} {})\n", .{
                color.r, color.g, color.b, color.a,
            });
        } else {
            try writer.print("    ({} {} {})\n", .{
                color.r, color.g, color.b,
            });
        }
    }
    try writer.writeAll("  )\n");

    try writer.writeAll("  (\n");
    while (try parser.next()) |command| {
        switch (command) {
            .fill_path => |path| {
                try writer.writeAll("     (\n       fill_path\n       ");
                try renderStyle(writer, path.style);
                try writer.writeAll("\n       (");
                for (path.path) |node| {
                    try writer.writeAll("\n         (");
                    switch (node) {
                        .line => |line| try writer.print("line {d} {d}", .{ line.x, line.y }),
                        .horiz => |horiz| try writer.print("horiz {d}", .{horiz}),
                        .vert => |vert| try writer.print("vert {d}", .{vert}),
                        .bezier => |bezier| try writer.print("bezier ({d} {d}) ({d} {d}) ({d} {d})", .{
                            bezier.c0.x,
                            bezier.c0.y,
                            bezier.c1.x,
                            bezier.c1.y,
                            bezier.p1.x,
                            bezier.p1.y,
                        }),
                        .arc_circle => |arc_circle| try writer.print("arc-circle", .{}),
                        .arc_ellipse => |arc_ellipse| try writer.print("arc-ellipse", .{}),
                        .close => try writer.writeAll("close"),
                    }
                    try writer.writeAll(")");
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .fill_polygon => |polygon| {
                try writer.writeAll("     (\n       fill_polygon\n       ");
                try renderStyle(writer, polygon.style);
                try writer.writeAll("\n       (");
                for (polygon.vertices) |verts| {
                    try writer.print("\n         ({d} {d})", .{
                        verts.x, verts.y,
                    });
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .fill_rectangles => |rects| {
                try writer.writeAll("     (\n       fill_rectangles\n       ");
                try renderStyle(writer, rects.style);
                try writer.writeAll("\n       (");
                for (rects.rectangles) |r| {
                    try writer.print("\n         ({d} {d} {d} {d})", .{
                        r.x, r.y, r.width, r.height,
                    });
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .draw_lines => |data| {
                try writer.writeAll("     (\n       draw_lines\n       ");
                try renderStyle(writer, data.style);
                try writer.print("\n       {d}\n       (", .{data.line_width});
                for (data.lines) |l| {
                    try writer.print("\n         (({d} {d}) ({d} {d}))", .{
                        l.start.x, l.start.y, l.end.x, l.end.y,
                    });
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .draw_line_strip => |data| {
                try writer.writeAll("     (\n       draw_line_strip\n       ");
                try renderStyle(writer, data.style);
                try writer.print("\n       {d}\n       (", .{data.line_width});
                for (data.vertices) |p| {
                    try writer.print("\n         ({d} {d})", .{
                        p.x, p.y,
                    });
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .draw_line_loop => |data| {
                try writer.writeAll("     (\n       draw_line_loop\n       ");
                try renderStyle(writer, data.style);
                try writer.print("\n       {d}\n       (", .{data.line_width});
                for (data.vertices) |p| {
                    try writer.print("\n         ({d} {d})", .{
                        p.x, p.y,
                    });
                }
                try writer.writeAll("\n       )\n     )\n");
            },
            .draw_line_path => |data| {
                try writer.writeAll("     (\n       draw_line_path\n       ");
                try renderStyle(writer, data.style);
                try writer.print("\n       {d}\n       (", .{data.line_width});
                for (data.path) |node| {
                    try writer.writeAll("\n         (");
                    switch (node) {
                        .line => |line| try writer.print("line {d} {d}", .{ line.x, line.y }),
                        .horiz => |horiz| try writer.print("horiz {d}", .{horiz}),
                        .vert => |vert| try writer.print("vert {d}", .{vert}),
                        .bezier => |bezier| try writer.print("bezier ({d} {d}) ({d} {d}) ({d} {d})", .{
                            bezier.c0.x,
                            bezier.c0.y,
                            bezier.c1.x,
                            bezier.c1.y,
                            bezier.p1.x,
                            bezier.p1.y,
                        }),
                        .arc_circle => |arc_circle| try writer.print("arc-circle", .{}),
                        .arc_ellipse => |arc_ellipse| try writer.print("arc-ellipse", .{}),
                        .close => try writer.writeAll("close"),
                    }
                    try writer.writeAll(")");
                }
                try writer.writeAll("\n       )\n     )\n");
            },
        }
    }
    try writer.writeAll("  )\n");

    try writer.writeAll(")\n");

    return 0;
}

fn renderStyle(writer: anytype, style: tvg.parsing.Style) !void {
    switch (style) {
        .flat => |color| try writer.print("(flat {d})", .{color}),
        .linear, .radial => |grad| {
            try writer.print("({s} ({d} {d}) ({d} {d}) {d} {d} )", .{
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

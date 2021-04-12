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
    try writer.print("  ({d} {d} {d})\n", .{
        parser.header.version,
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
                try writer.writeAll("\n     )\n");
            },
            .fill_polygon => |polygon| {
                try writer.writeAll("     (\n       fill_polygon\n       ");
                try renderStyle(writer, polygon.style);
                try writer.writeAll("\n     )\n");
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
        }
    }
    try writer.writeAll("  )\n");

    try writer.writeAll(")\n");

    return 0;
}

fn renderStyle(writer: anytype, style: tvg.parsing.Style) !void {
    switch (style) {
        .flat => |color| try writer.print("(flat {d})", .{color}),
        .linear, .radial => {
            try writer.print("({s} ", .{std.meta.tagName(style)});
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

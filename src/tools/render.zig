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

    var icon_buffer = try source_file.readToEndAlloc(allocator, 1 << 20);
    defer allocator.free(icon_buffer);

    var geometry = cli.options.geometry orelse Geometry{
        .width = 256,
        .height = 256,
    };

    const pixel_count = @as(usize, geometry.width) * @as(usize, geometry.height);

    var backing_buffer = try allocator.alloc(u8, ImgFormat.bytesRequired(pixel_count));
    defer allocator.free(backing_buffer);

    var slice = ImgFormat.init(backing_buffer, pixel_count);
    {
        const color: u24 = cli.options.background.toInt();

        var i: usize = 0;
        while (i < slice.int_count) : (i += 1) {
            slice.set(i, color);
        }
    }

    try tvg.drawIcon(
        &Framebuffer{
            .slice = slice,
            .stride = geometry.width,
            .width = geometry.width,
            .height = geometry.height,
        },
        icon_buffer,
    );

    {
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

        var writer = dest_file.writer();
        try writer.print("P6 {} {} 255\n", .{ geometry.width, geometry.height });
        try writer.writeAll(backing_buffer[0 .. 3 * pixel_count]);
    }

    return 0;
}

const Framebuffer = struct {
    const Self = @This();

    // private API

    slice: ImgFormat,
    stride: usize,

    // public API

    width: usize,
    height: usize,

    pub fn setPixel(self: *Self, x: isize, y: isize, color: [4]u8) void {
        const offset = (std.math.cast(usize, y) catch return) * self.stride + (std.math.cast(usize, x) catch return);
        // std.debug.print("{} {} => {any}\n", .{ x, y, color });
        self.slice.set(offset, (Color{ .r = color[0], .g = color[1], .b = color[2] }).toInt());
    }
};

const ImgFormat = std.PackedIntSliceEndian(u24, .Little);

const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn parse(str: []const u8) !Color {
        switch (str.len) {
            3 => {
                const r = try std.fmt.parseInt(u8, str[0..1], 16);
                const g = try std.fmt.parseInt(u8, str[0..1], 16);
                const b = try std.fmt.parseInt(u8, str[0..1], 16);
                return Color{
                    .r = r | r << 4,
                    .g = g | g << 4,
                    .b = b | b << 4,
                };
            },

            6 => {
                const r = try std.fmt.parseInt(u8, str[0..2], 16);
                const g = try std.fmt.parseInt(u8, str[2..4], 16);
                const b = try std.fmt.parseInt(u8, str[4..6], 16);
                return Color{
                    .r = r | r << 4,
                    .g = g | g << 4,
                    .b = b | b << 4,
                };
            },
            else => return error.InvalidColor,
        }
    }

    pub fn toInt(self: Color) u24 {
        return @as(u24, self.r) | (@as(u24, self.g) << 8) | (@as(u24, self.b) << 16);
    }
};

const CliOptions = struct {
    help: bool = false,

    output: ?[]const u8 = null,

    geometry: ?Geometry = null,

    background: Color = Color{ .r = 0xAA, .g = 0xAA, .b = 0xAA },

    pub const shorthands = .{
        .o = "output",
        .g = "geometry",
        .h = "help",
        .b = "background",
    };
};

const Geometry = struct {
    const Self = @This();

    width: u16,
    height: u16,

    pub fn parse(str: []const u8) !Self {
        if (std.mem.indexOfScalar(u8, str, 'x')) |index| {
            return Geometry{
                .width = try std.fmt.parseInt(u16, str[0..index], 10),
                .height = try std.fmt.parseInt(u16, str[index + 1 ..], 10),
            };
        } else {
            const v = try std.fmt.parseInt(u16, str, 10);
            return Geometry{
                .width = v,
                .height = v,
            };
        }
    }
};

fn printUsage(stream: anytype) !void {
    try stream.writeAll(
        \\tvg-render [-o file] [-g geometry] source.tvg
        \\
    );
}

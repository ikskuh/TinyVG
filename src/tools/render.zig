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

    var parser = try tvg.parse(allocator, source_file.reader());
    defer parser.deinit();

    var geometry = cli.options.geometry orelse Geometry{
        .width = parser.header.width,
        .height = parser.header.height,
    };

    const pixel_count = @as(usize, geometry.width) * @as(usize, geometry.height);

    var image_buffer = try allocator.alloc(Color, pixel_count);
    defer allocator.free(image_buffer);

    for (image_buffer) |*c| {
        c.* = cli.options.background;
    }

    var fb = Framebuffer{
        .slice = image_buffer,
        .stride = geometry.width,
        .width = geometry.width,
        .height = geometry.height,
    };
    while (try parser.next()) |cmd| {
        try tvg.rendering.render(&fb, parser.header, parser.color_table, cmd);
    }

    {
        var dest_file: std.fs.File = if (write_stdout)
            std.io.getStdIn()
        else blk: {
            var out_name = cli.options.output orelse try std.mem.concat(allocator, u8, &[_][]const u8{
                cli.positionals[0][0..(cli.positionals[0].len - std.fs.path.extension(cli.positionals[0]).len)],
                ".tga",
            });

            break :blk try std.fs.cwd().createFile(out_name, .{});
        };
        defer if (!read_stdin)
            dest_file.close();

        var writer = dest_file.writer();
        try dumpTga(writer, geometry.width, geometry.height, image_buffer);
    }

    return 0;
}

fn dumpTga(src_writer: anytype, width: u16, height: u16, pixels: []const Color) !void {
    var buffered_writer = std.io.bufferedWriter(src_writer);
    var writer = buffered_writer.writer();

    std.debug.assert(pixels.len == @as(u32, width) * height);

    const image_id = "Hello, TGA!";

    try writer.writeIntLittle(u8, @intCast(u8, image_id.len));
    try writer.writeIntLittle(u8, 0); // color map type = no color map
    try writer.writeIntLittle(u8, 2); // image type = uncompressed true-color image
    // color map spec
    try writer.writeIntLittle(u16, 0); // first index
    try writer.writeIntLittle(u16, 0); // length
    try writer.writeIntLittle(u8, 0); // number of bits per pixel
    // image spec
    try writer.writeIntLittle(u16, 0); // x origin
    try writer.writeIntLittle(u16, 0); // y origin
    try writer.writeIntLittle(u16, width); // width
    try writer.writeIntLittle(u16, height); // height
    try writer.writeIntLittle(u8, 32); // bits per pixel
    try writer.writeIntLittle(u8, 8 | 0x20); // 0…3 => alpha channel depth = 8, 4…7 => direction=top left

    try writer.writeAll(image_id);
    try writer.writeAll(""); // color map data \o/
    try writer.writeAll(std.mem.sliceAsBytes(pixels));

    try buffered_writer.flush();
}

const Framebuffer = struct {
    const Self = @This();

    // private API

    slice: []Color,
    stride: usize,

    // public API

    width: usize,
    height: usize,

    pub fn setPixel(self: *Self, x: isize, y: isize, color: [4]u8) void {
        const offset = (std.math.cast(usize, y) catch return) * self.stride + (std.math.cast(usize, x) catch return);

        const dst = self.slice[offset];
        self.slice[offset] = Color{
            .r = lerp(dst.r, color[0], color[3]),
            .g = lerp(dst.g, color[1], color[3]),
            .b = lerp(dst.b, color[2], color[3]),
            .a = lerp(dst.a, color[3], color[3]),
        };
    }

    fn lerp(c0: u8, c1: u8, a: u8) u8 {
        const f0 = @intToFloat(f32, c0);
        const f1 = @intToFloat(f32, c1);
        return @floatToInt(u8, f0 + (f1 - f0) * @intToFloat(f32, a) / 255.0);
    }
};

const Color = extern struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8 = 0xFF,

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
};

const CliOptions = struct {
    help: bool = false,

    output: ?[]const u8 = null,

    geometry: ?Geometry = null,

    background: Color = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0x00 },

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

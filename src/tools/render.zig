const std = @import("std");
const tvg = @import("tvg");
const args = @import("args");

fn printUsage(stream: anytype) !void {
    try stream.writeAll(
        \\tvg-render [-o file] [-g geometry] [-a] [--super-sampling <scale>] source.tvg
        \\
    );
}

const CliOptions = struct {
    help: bool = false,

    output: ?[]const u8 = null,

    geometry: ?Geometry = null,

    background: Color = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 },

    @"anti-alias": bool = false,
    @"super-sampling": ?u32 = null,

    pub const shorthands = .{
        .o = "output",
        .g = "geometry",
        .h = "help",
        .b = "background",
        .a = "anti-alias",
    };
};

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

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

    var parser = try tvg.parse(allocator, source_file.reader());
    defer parser.deinit();

    const default_geometry = Geometry{
        .width = try std.math.cast(u16, parser.header.width),
        .height = try std.math.cast(u16, parser.header.height),
    };

    var image_geometry = cli.options.geometry orelse default_geometry;

    var super_scale: u32 = 1;

    if (cli.options.@"anti-alias") {
        super_scale = 8;
    }
    if (cli.options.@"super-sampling") |scaling| {
        if (scaling == 0 or scaling > 32) {
            try stderr.writeAll("Superscaling is only allowed for scales between 1 and 32.\n");
            return 1;
        }
        super_scale = scaling;
    }

    // Render TVG with super-scaling

    var render_geometry = Geometry{
        .width = super_scale * image_geometry.width,
        .height = super_scale * image_geometry.height,
    };

    const render_pixel_count = @as(usize, render_geometry.width) * @as(usize, render_geometry.height);

    var render_buffer = try allocator.alloc(Color, render_pixel_count);
    defer allocator.free(render_buffer);

    for (render_buffer) |*c| {
        c.* = cli.options.background;
    }

    var fb = Framebuffer{
        .slice = render_buffer,
        .stride = render_geometry.width,
        .scale = super_scale,
        .width = render_geometry.width,
        .height = render_geometry.height,
    };
    while (try parser.next()) |cmd| {
        try tvg.rendering.render(&fb, parser.header, parser.color_table, cmd);
    }

    const image_pixel_count = @as(usize, image_geometry.width) * @as(usize, image_geometry.height);

    var image_buffer = try allocator.alloc(Color, image_pixel_count);
    defer allocator.free(image_buffer);

    for (image_buffer) |*pixel, i| {
        const x = i % image_geometry.width;
        const y = i / image_geometry.width;

        // stores premultiplied rgb + linear alpha
        // premultiplication is necessary as
        // (1,1,1,50%) over (0,0,0,0%) must result in (1,1,1,25%) and not (0.5,0.5,0.5,25%).
        // This will only happen if we fully ignore the fraction of transparent colors in the final result.
        // The average must also be computed in linear space, as we would get invalid color blending otherwise.
        var color = std.mem.zeroes([4]f32);

        var dy: usize = 0;
        while (dy < super_scale) : (dy += 1) {
            var dx: usize = 0;
            while (dx < super_scale) : (dx += 1) {
                const sx = x * super_scale + dx;
                const sy = y * super_scale + dy;

                const src_color = render_buffer[sy * render_geometry.width + sx];

                const a = @intToFloat(f32, src_color.a) / 255.0;

                // Create premultiplied linear colors
                color[0] += a * mapToLinear(src_color.r);
                color[1] += a * mapToLinear(src_color.g);
                color[2] += a * mapToLinear(src_color.b);
                color[3] += a;
            }
        }

        // Compute average
        for (color) |*chan| {
            chan.* = chan.* / @intToFloat(f32, super_scale * super_scale);
        }

        const final_a = color[3];

        if (final_a > 0.0) {
            pixel.* = Color{
                // unmultiply the alpha and apply the gamma
                .r = mapToGamma(color[0] / final_a),
                .g = mapToGamma(color[1] / final_a),
                .b = mapToGamma(color[2] / final_a),
                .a = @floatToInt(u8, 255.0 * color[3]),
            };
        } else {
            pixel.* = Color{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 0x00 };
        }
    }

    {
        var file = try std.fs.cwd().createFile("/tmp/test.tga", .{});
        defer file.close();

        const width = try std.math.cast(u16, render_geometry.width);
        const height = try std.math.cast(u16, render_geometry.height);

        try dumpTga(file.writer(), width, height, render_buffer);
    }

    {
        const width = try std.math.cast(u16, image_geometry.width);
        const height = try std.math.cast(u16, image_geometry.height);

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
        try dumpTga(writer, width, height, image_buffer);
    }

    return 0;
}

const gamma = 2.2;

fn mapToLinear(val: u8) f32 {
    return std.math.pow(f32, @intToFloat(f32, val) / 255.0, gamma);
}

fn mapToGamma(val: f32) u8 {
    return @floatToInt(u8, 255.0 * std.math.pow(f32, val, 1.0 / gamma));
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
    scale: usize,
    width: usize,
    height: usize,

    pub fn setPixel(self: *Self, x: isize, y: isize, color: [4]u8) void {
        if (x < 0 or y < 0)
            return;
        if (x >= self.width or y >= self.height)
            return;
        const offset = (std.math.cast(usize, y) catch return) * self.stride + (std.math.cast(usize, x) catch return);

        const destination_pixel = &self.slice[offset];

        const src_color = Color{
            .r = color[0],
            .g = color[1],
            .b = color[2],
            .a = color[3],
        };
        const dst_color = destination_pixel.*;

        if (src_color.a == 0) {
            return;
        }
        if (src_color.a == 255) {
            destination_pixel.* = src_color;
            return;
        }

        // src over dst
        //   a over b

        const src_alpha = @intToFloat(f32, src_color.a) / 255.0;
        const dst_alpha = @intToFloat(f32, dst_color.a) / 255.0;

        const fin_alpha = src_alpha + (1.0 - src_alpha) * dst_alpha;

        destination_pixel.* = Color{
            .r = lerp(src_color.r, dst_color.r, src_alpha, dst_alpha, fin_alpha),
            .g = lerp(src_color.g, dst_color.g, src_alpha, dst_alpha, fin_alpha),
            .b = lerp(src_color.b, dst_color.b, src_alpha, dst_alpha, fin_alpha),
            .a = @floatToInt(u8, 255.0 * fin_alpha),
        };
    }

    fn lerp(src: u8, dst: u8, src_alpha: f32, dst_alpha: f32, fin_alpha: f32) u8 {
        const src_val = mapToLinear(src);
        const dst_val = mapToLinear(dst);

        const value = (1.0 / fin_alpha) * (src_alpha * src_val + (1.0 - src_alpha) * dst_alpha * dst_val);

        return mapToGamma(value);
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
                    .r = r,
                    .g = g,
                    .b = b,
                };
            },
            else => return error.InvalidColor,
        }
    }
};

const Geometry = struct {
    const Self = @This();

    width: u32,
    height: u32,

    pub fn parse(str: []const u8) !Self {
        if (std.mem.indexOfScalar(u8, str, 'x')) |index| {
            return Geometry{
                .width = try std.fmt.parseInt(u32, str[0..index], 10),
                .height = try std.fmt.parseInt(u32, str[index + 1 ..], 10),
            };
        } else {
            const v = try std.fmt.parseInt(u32, str, 10);
            return Geometry{
                .width = v,
                .height = v,
            };
        }
    }
};

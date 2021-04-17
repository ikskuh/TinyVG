const std = @import("std");

pub const Command = enum(u8) {
    end_of_document = 0,

    fill_polygon = 1,
    fill_rectangles = 2,
    fill_path = 3,

    draw_lines = 4,
    draw_line_loop = 5,
    draw_line_strip = 6,
    draw_line_path = 7,

    outline_fill_polygon = 8,
    outline_fill_rectangles = 9,
    outline_fill_path = 10,

    _,
};

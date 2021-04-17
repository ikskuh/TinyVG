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
    _,
};

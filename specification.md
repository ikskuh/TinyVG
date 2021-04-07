# Tiny Vector Graphics (Specification)

**Comment:** This specification uses a Zig style type notation to document.

## Common Notation

The offset notation uses either hexadecimal (0x00) or hexadecimal with bit offset (0x00:3). The same is true for sizes, which uses 0x00:3 to denote that only 3 bit are used. The offset notation also uses `+0x00` to note items that are not relative to the file start, but to a certain context dependent entity.

## Common Header
 
Each *TVG* file starts with the same 3-byte header, which has the following fields:

| Offset | Size | Name      | Type    | Value       |
|--------|------|-----------|---------|-------------|
| 0x00   |    2 | `magic`   | `[2]u8` | 0x72, 0x56  |
| 0x02   |    1 | `version` | `u8`    | *see below* |

`version` must be one of the valid versions listed below. They have no major/minor listing and just start with version 1.

*TVG* uses little endian integers if not stated otherwise as most machines nowadays use little endian data.

## Common data types

This section explains common data types used in the *TVG* format.

### `uint`
A variadic sized unsigned integer. The encoding is a sequence of bytes where the lower 7 bit encode a little endian number and the upper bit determines if there is another byte following. If the bit is 1, another byte is following and the byte value is shifted left by 7 bit per byte. If the bit is 0, it's the end of the sequence.

The maximum legal number of bits encoded with this technique are 32, so 5 bytes.

Examples:
```zig
{ 0x00 }             => 0x00
{ 0x40 }             => 0x40
{ 0x80, 0x01 }       => 0x80
{ 0x80, 0x80, 0x40 } => 0x100000
```

### `sint`
A variadic sized signed integer. This follows the same encoding scheme as the `uint`, but uses a swizzle encoding which moves the sign bit to the last bit and inverts the bits when the sign bit is set. This means that values are encoded in the following sequence:

> 0, -1, 1, -2, 2, -3, 3, ...

With this encoding, we can still keep small numbers in low bytes. This example code shows how to encode/decode such a number in Zig:

```zig
pub fn encode(n: i32) u32 {
    const v = (n << 1) ^ (n >> 31);
    return @bitCast(u32, v);
}

pub fn decode(u: u32) i32 {
    const n = @bitCast(i32, u);
    return (n << 1) ^ (n >> 31);
}
```

### `unit`
A graphics-dependent fixed-point decimal number, encoded as a 16 bit signed two's complement integer with the last N bits being the decimal places.
A `scale` value for the graphic will determine the number of decimal places.

### `Gradient`

A two-point gradient that is either linear or radial.

`grad_point_0_x` and `grad_point_0_y` form the first point, `grad_point_1_x` and `grad_point_1_y` form the second point.

The gradient has the color `grad_point_0_c` at the first point, the color `grad_point_1_c` at the second point and interpolates linearly between the two colors.

```zig
grad_point_0_x: unit,
grad_point_0_y: unit,
grad_point_1_x: unit,
grad_point_1_y: unit,
grad_point_0_c: uint,
grad_point_1_c: uint,
```

## Version 1

### Full Header

This is the full header for version 1 of *TVG*:

| Offset | Size | Name           | Type    | Value                               |
|--------|------|----------------|---------|-------------------------------------|
| 0x00   |    2 | `magic`        | `[2]u8` | `0x72`, `0x56`                      |
| 0x02   |    1 | `version`      | `u8`    | `1`                                 |
| 0x03:0 |  0:4 | `scale`        | `u4`    | *see below*                         |
| 0x03:4 |  0:4 | *unused*       | `u4`    | *must be 0*                         |
| 0x04   |    2 | `width`        | `unit`  | Width of the graphic in units.      |
| 0x06   |    2 | `height`       | `unit`  | Height of the graphic in units.     |
| 0x08   |    2 | `color_count`  | `u16`   | number of colors in the color table |

`scale` is a value between 0 and 8 defining the number of bits used as decimal places.
It defines how to convert units (16 bit integers) to pixels in the final image, allowing
sub-pixel precision of vector data. 0 means that no bits are used (thus 1 unit is 1 pixel),
and 8 means that 8 bits are used as decimal places (thus 256 units is 1 pixel).

`width` and `height` must both be larger than 0. Negative values or zero is not allowed.

After this header, there are `color_count` entries into a color table, each entry consists of four `u8` values.
The values are *red*, *green*, *blue*, *transparency* (often called *alpha*). So a table with 3 entries looks like this:

```zig
red0, green0, blue0, alpha0, // color 0
red1, green1, blue1, alpha1, // color 1
red2, green2, blue2, alpha2, // color 2
```

After the color table, a list of variable-size commands follow. Each command starts with a single byte denoting the type of that entry. The types are documented in the following chapters.

### `command=0` End of document

This command will mark the end of the command list. No commands must be read after the encounter of a 0 command.

### `command=1` Fill polygon

This command will fill a N vertex polygon with 2 < N < 64 vertices. Vertices only have a position and the polygon will be filled either
with a single color or a gradient.

| Offset  | Size | Name           | Type    | Value                                              |
|---------|------|----------------|---------|----------------------------------------------------|
| +0x00:0 |  0:7 | `vertex_count` | `u6`    | Number of vertices in the polygon.                 |
| +0x00:6 |  0:2 | `gradient`     | `u2`    | If > 0, uses a gradient instead of a solid color.  |

**if `gradient` is not 0, the following header applies:**

| Offset     | Size  | Name             | Type    | Value                                              |
|------------|-------|------------------|---------|----------------------------------------------------|
| +0x00:0    |  0:6  | `vertex_count`   | `u6`    | Number of vertices in the polygon.                 |
| +0x00:6    |  0:2  | `gradient`       | `u2`    | If > 0, uses a gradient instead of a solid color.  |
| +0x01      |    2  | `grad_point_0_x` | `unit`  | Gradient Point 0, x coordinate                     |
| +0x03      |    2  | `grad_point_0_y` | `unit`  | Gradient Point 0, y coordinate                     |
| +0x05      |    2  | `grad_point_1_x` | `unit`  | Gradient Point 1, x coordinate                     |
| +0x07      |    2  | `grad_point_1_y` | `unit`  | Gradient Point 1, y coordinate                     |
| +0x09      | *var* | `grad_point_0_c` | `uint`  | Gradient Point 0, color index                      |
| *changing* | *var* | `grad_point_1_c` | `uint`  | Gradient Point 1, color index                      |

The `grad_point_0_x` and `grad_point_0_y` fields define the position of the first gradient point.
`grad_point_1_x` and `grad_point_1_y` define the position of the second gradient point. Colors will either be
be linearly (`gradient=1`) or radially (`gradient=2`) interpolated between the first and the second point.
For radial interpolation, the second point defines the radius for the gradient.

The colors of the two points are defined by the index `grad_point_0_c` and `grad_point_1_c` in the color table.

**else, if `gradient` is 0, the following header applies:**

| Offset     | Size  | Name             | Type    | Value                                              |
|------------|-------|------------------|---------|----------------------------------------------------|
| +0x00:0    |  0:6  | `vertex_count`   | `u7`    | Number of vertices in the polygon.                 |
| +0x00:6    |  0:2  | `gradient`       | `u2`    | If > 0, uses a gradient instead of a solid color.  |
| +0x01      | *var* | `color`          | `uint`  | Color index of the fill color                      |

The `color` field defines which color this polygon has. The color is selected from the color table.

**after the header**, the `vertex_count` vertices are listed. Each vertex consists of two `unit` values, defining x and y coordinate:

| Offset     | Size  | Name             | Type    | Value                                              |
|------------|-------|------------------|---------|----------------------------------------------------|
| +0x00      |    2  | `vertex.x`       | `unit`  | x coordinate of the vertex                         |
| +0x01      |    2  | `vertex.y`       | `unit`  | y coordinate of the vertex                         |

### `command=2` Draw line list

This command draws a list of disjoint lines.

```zig
struct {
    line_count: u6,
    use_gradient: u2,
    line_width: unit,
    if(gradient > 0) {
        gradient: Gradient,
    } else {
        color: uint,
    },
    lines: [line_count]struct {
        x0: unit,
        y0: unit,
        x1: unit,
        y1: unit,
    },
}
```

`line_count` defines how many lines there are in the list. `line_count=0` is mapped to 64 as 0 lines would have no information and the command could be removed. `use_gradient > 0` defines that a `gradient` is used. `use_gradient = 1` means a linear gradient is used, `use_gradient = 2` is a radial one.
When `use_gradient` is 0, a flat `color` is used for shading the lines. `line_width` defines the line width in units. Lines always have rounded ends

`lines` contains pairs of points for each line in the list.

### `command=3` Draw line strip

This command draws a list of connected lines. A line is defined by the first and second point, the next line is defined by the second and third point and so on. This allows very compact drawing of connected lines.

```zig
struct {
    line_count: u6,
    use_gradient: u2,
    line_width: unit,
    if(gradient > 0) {
        gradient: Gradient,
    } else {
        color: uint,
    },
    vertices: [line_count + 1]struct {
        x: unit,
        y: unit,
    },
}
```

The parameters for *Draw line strip* are the same as for *Draw line list*, except for `vertices` which will define all points of the list strip.


### `command=4` Draw line loop

This command is the same as *Draw line strip*, but the last and first vertex are connected to each other. This means that only
closed loops can be drawn with this command.

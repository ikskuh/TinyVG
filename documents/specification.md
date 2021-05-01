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

### `Point`

A point in euclidean space.

```zig
struct {
    x: unit,
    y: unit,
};
```

### `Gradient`

A two-point gradient that is either linear or radial.

`point_0` is the first point, `point_1` is the second point.

The gradient has the color `color_0` at the first point, the color `color_1` at the second point and interpolates between the two colors.

```zig
struct {
    point_0: Point,
    point_1: Point,
    color_0: uint,
    color_1: uint,
}
```

For *linear* gradients, the gradient will interpolate everything on a line between `point_0` and `point_1`.

For *radial* gradients, the interpolation will be done based on the distance to `point_0`. The interpolation will take `color_0` if the distance is zero and `color_1` if the distance is larger or equal to the distance between `point_0` and `point_1`.

### `Style`

This defines a style structure based on a given `type` parameter.

```zig
struct(type: u2) {
    if(type == 0) {
        flat_color: uint,
    } else if(type == 1 or type == 2) {
        gradient: Gradient,
    } else {
        unreachable;
    }
}
```

A style with `type=0` is just a flat color defined by the index into the color table, `type=2` is a linear gradient, `type=3` is a radial gradient.

## Version 1

### Full Header

This is the full header for version 1 of *TVG*:

```zig
struct {
    magic: [2]u8 = .{ 0x72, 0x56 },
    version: u8  = 1,
    scale: u4, 
    custom_color_space: bool,
    padding: u3 = 0,
    width: u16,
    height: u16,
    color_count: u16,
}
```

`scale` is a value between 0 and 8 defining the number of bits used as decimal places.
It defines how to convert units (16 bit integers) to pixels in the final image, allowing
sub-pixel precision of vector data. 0 means that no bits are used (thus 1 unit is 1 pixel),
and 8 means that 8 bits are used as decimal places (thus 256 units is 1 pixel).

`width` and `height` must both be larger than 0 and define the size of the vector graphic.

After this header, there are `color_count` entries into a color table, each entry consists of four byte.

If `custom_color_space` is 0, the colors are encoded with [sRGB](https://en.wikipedia.org/wiki/SRGB) color values and a linear transparency:
```zig
struct {
    red: u8,
    green: u8,
    blue: u8,
    transparency: u8,
}   
```
`transparency` is also often `alpha`. 

If `custom_color_space` is one, these four bytes have a implementation defined meaning and might use any kind of color encoding. When this flag is set, the file is explicitly marked as non-standard and should be rejected by any conforming renderer that doesn't provide means to have configurable color parsing.

So a table with 3 entries looks like this:

```zig
c0_0, c0_1, c0_2, c0_3, // color 0
c1_0, c1_1, c1_2, c1_3, // color 1
c2_0, c2_1, c2_2, c2_3, // color 2
```

After the color table, a list of variable-size commands follow. Each command starts with a single byte denoting the type of that entry. The types are documented in the following chapters.

### `command=0` End of document

This command will mark the end of the command list. No commands must be read after the encounter of a 0 command.

### `command=1` Fill polygon

This command will fill a N vertex polygon with 2 < N < 64 vertices. Vertices only have a position and the polygon will be filled either
with the given style.

```zig
struct {
    vertex_count: u6, // Number of vertices in the polygon.
    style_type: u2,   
    style: Style(style_type),
    vertices: [vertex_count]Point,
}
```

### `command=2` Fill rectangle

This command will fill one or several rectangles with the given style.

```zig
struct {
    rectangle_count: u6,
    style_type: u2,
    style: Style(style_type),
    rectangles: [rectangle_count] struct {
        x: unit,
        y: unit,
        width: unit,
        height: unit,
    },
}
```

### `command=3` Fill path

This command will fill a complex path structure with the given style.

```zig
struct {
    node_count: u6,
    style_type: u2,
    style: Style(style_type),
    start: Point,
    nodes: [node_count]Node,
}
```

`style` defines how the area enclosed by the path is filled. `start` is the first vertex of the path.

After the *Fill path* header, `node_count` path elements will follow. These have the following semantics and encoding:

Each path node will start with a single byte defining the type and some flags for each node:

```zig
struct {
    type: enum(u3) {
        line = 0,
        horiz = 1,
        vert = 2,
        bezier = 3,
        arc_circ = 4,
        arc_ellipse = 5,
        close = 6,
    },
    padding0: u1 = 0,
    has_line_width: bool,
    padding1: u3 = 0,
}
```

`type` defines what data the rest of the node contains and how to render it. `has_line_width` is only relevant for drawing line paths, not filled paths. When `has_line_width` is set, the header is followed by a `unit` that defines the positive line width that is used for rendering.

Drawing the path starts at `start` and each node uses the end of the previous node to start drawing.

#### `line=0` Line

```zig
struct {
    x: unit,
    y: unit,
}
```

Draws a line to (`x`,`y`).

#### `horiz=1` Horizontal Line

```zig
struct {
    x: unit,
}
```

Draws a horizontal line to the `x` coordinate. `y` will stay the same.

#### `vert=2` Vertical line

```zig
struct {
    y: unit,
}
```

Draws a vertical line to the `y` coordinate. `x` will stay the same.

#### `bezier=3` Cubic bezier curve

```zig
struct {
    c0: Point,
    c1: Point,
    p1: Point,
}
```

Draws a cubic bezier curve from the current point to `p1`. `c0` and `c1` will be the control points for the starting point and `p1`.

#### `arc_circ=4` Arc segment (circle)

> TODO: Properly specify arc drawing

```zig
struct {
    big_segment: bool,
    turn_left: bool,
    padding: u6 = 0,
    radius: unit,
    point: Point,
}
```

Draws a circle segment from the current location to `point`. The radius of the circle is given by (positive) `radius`.

When `big_segment` is 1, the arc segment will use the variant that is longer, otherwise, the shorter arc segment will be drawn.

By default, the arc segment will take a right turn when going from the current location to `point`: `current ⌢ point`

If `turn_left` is set, the turn direction is switched and the arc will take a left turn: `current ⌣ point`


#### `arc_ellipse=5` Arc segment (ellipse)

```zig
struct {
    big_segment: bool,
    turn_left: bool,
    padding: u6 = 0,
    radius_x: unit,
    radius_y: unit,
    point: Point,
}
```

Draws a segment of an ellipse from the current location to `point`. The size of the ellipse is given by (positive) `radius_x` for radius on the major axis and (positive) `radius_y` for the radius on the minor axis.

`big_segment` and `turn_left` have the same meaning as for *Arc segment (circle)*

#### `close=6` Close the path

This command will close the path by drawing a straight line to `start`. This command **must** be the last one in a node sequence
and will be ignored in case of a *Fill path* command.

### `command=4` Draw lines

```zig
struct {
    line_count: u6,
    style_type: u2,
    style: Style(style_type),
    line_width: unit,
    lines: [line_count] struct { p0: Point, p1: Point },
}
```

### `command=5` Draw line loop

```zig
struct {
    line_count: u6,
    style_type: u2,
    style: Style(style_type),
    line_width: unit,
    vertices: [1 + line_count]Point,
}
```

### `command=6` Draw line strip

```zig
struct {
    line_count: u6,
    style_type: u2,
    style: Style(style_type),
    line_width: unit,
    vertices: [1 + line_count]Point,
}
```

### `command=7` Draw line path

```zig
struct {
    node_count: u6,
    style_type: u2,
    style: Style(style_type),
    line_width: unit,
    start: Point,
    nodes: [node_count]Node,
}
```

### `command=8` Outline fill polygon

```zig
struct {
    vertex_count: u6, // Number of vertices in the polygon.
    fill_style_type: u2,   
    line_style_type: u2,
    padding: u6,
    line_style: Style(line_style_type),
    fill_style: Style(fill_style_type),
    line_width: unit,
    vertices: [vertex_count]Point,
}
```

### `command=9` Outline fill rectangles

```zig
struct {
    rectangle_count: u6,
    fill_style_type: u2,
    line_style_type: u2,
    padding: u6,
    line_style: Style(line_style_type),
    fill_style: Style(fill_style_type),
    line_width: unit,
    rectangles: [rectangle_count] struct {
        x: unit,
        y: unit,
        width: unit,
        height: unit,
    },
}
```

### `command=10` Outline fill path

```zig
struct {
    node_count: u6,
    fill_style_type: u2,
    line_style_type: u2,
    padding: u6,
    line_style: Style(line_style_type),
    fill_style: Style(fill_style_type),
    line_width: unit,
    start: Point,
    nodes: [node_count]Node,
}
```

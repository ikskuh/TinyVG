meta:
  id: tvg
  endian: le
  bit-endian: le
seq:
  - id: magic
    contents: [0x72, 0x56]
  - id: version
    size: 1
  - id: scale
    type: b4
    enum: scale
  - id: color_space
    type: b2
    enum: color_space
  - id: coordinate_range
    type: b2
    enum: coordinate_range
  - id: width
    type:
      switch-on: coordinate_range
      cases:
        'coordinate_range::reduced': u1
        'coordinate_range::default': u2
        'coordinate_range::extended': u4
  - id: height
    type:
      switch-on: coordinate_range
      cases:
        'coordinate_range::reduced': u1
        'coordinate_range::default': u2
        'coordinate_range::extended': u4
  - id: color_count
    type: uint
  - id: commands
    type: command
    repeat: until
    repeat-until: (_.id == command::end_of_document)

types:
  void: {}
  uint:
    seq:
      - type: u2
  point:
    seq:
      - id: x
        type: unit
      - id: y
        type: unit
  size:
    seq:
      - id: width
        type: unit
      - id: height
        type: unit
  rectangle:
    seq:
      - id: position
        type: point
      - id: size
        type: size
  unit:
    seq:
      - id: value
        type:
          switch-on: _root.coordinate_range
          cases:
            'coordinate_range::reduced': u1
            'coordinate_range::default': u2
            'coordinate_range::extended': u4
  gradient:
    seq:
      - id: point_0
        type: point
      - id: point_1
        type: point
      - id: color_0
        type: uint
      - id: color_1
        type: uint
  command:
    seq:
      - id: id
        type: u2
        enum: command
      - id: data
        type: 
          switch-on: id
          cases:
            'command::end_of_document': void
            'command::fill_polygon': fill_polygon
            'command::fill_rectangles': fill_rectangles
            'command::fill_path': fill_path
            'command::draw_lines': draw_lines
            'command::draw_line_loop': draw_line_loop
            'command::draw_line_strip': draw_line_strip
            'command::draw_line_path': draw_line_path
            'command::outline_fill_polygon': outline_fill_polygon
            'command::outline_fill_rectangles': outline_fill_rectangles
            'command::outline_fill_path': outline_fill_path
  fill_polygon:
    seq:
      - type: u2
  fill_rectangles:
    seq:
      - id: count
        type: b6
      - id: style_type
        type: b2
        enum: style
      - id: style
        type:
          switch-on: style_type
          cases:
            'style::flat': uint
            'style::linear': gradient
            'style::radial': gradient
      - id: rectangles
        type: rectangle
        repeat: expr
        repeat-expr: count
  fill_path:
    seq:
      - type: u2
  draw_lines:
    seq:
      - type: u2
  draw_line_loop:
    seq:
      - type: u2
  draw_line_strip:
    seq:
      - type: u2
  draw_line_path:
    seq:
      - type: u2
  outline_fill_polygon:
    seq:
      - type: u2
  outline_fill_rectangles:
    seq:
      - type: u2
  outline_fill_path:
    seq:
      - type: u2

  

enums:
  style:
    0: "flat"
    1: "linear"
    2: "radial"
  command:
    0: "end_of_document"
    1: "fill_polygon"
    2: "fill_rectangles"
    3: "fill_path"
    4: "draw_lines"
    5: "draw_line_loop"
    6: "draw_line_strip"
    7: "draw_line_path"
    8: "outline_fill_polygon"
    9: "outline_fill_rectangles"
    10: "outline_fill_path"
  scale:
    0: "scale_1_1"
    1: "scale_1_2"
    2: "scale_1_4"
    3: "scale_1_8"
    4: "scale_1_16"
    5: "scale_1_32"
    6: "scale_1_64"
    7: "scale_1_128"
    8: "scale_1_256"
    9: "scale_1_512"
    10: "scale_1_1024"
    11: "scale_1_2048"
    12: "scale_1_4096"
    13: "scale_1_8192"
    14: "scale_1_16384"
    15: "scale_1_32768"
  color_space:
    0: "srgb_8"
    1: "adobe_rgb_10"
    2: "rgb_565"
    3: "custom"
  coordinate_range:
    0: "reduced"
    1: "default"
    2: "extended"
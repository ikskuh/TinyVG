# menu.tvg

**SVG:** (341 byte) ![](menu.svg)

**PNG:** (321 byte) ![](menu.png)

**TVG:** (72 byte)

```zig
// Header:
0x72, 0x56, // magic number
0x01,       // version
8,          // scale (1/256)
0, 48,      // width (48 pixels)
0, 48,      // height (48 pixels)
1,  0,      // number of colors (1)

// Color table:
0x00, 0x00, 0x00, 0xFF, // color 0 = black

// Command list:
0x01,         // fill_polygon
0x04,         // 3 vertices, flat style
0x00,         // color=0
0, 6, 0, 12,  // vtx 0
0, 42, 0, 12, // vtx 1
0, 42, 0, 16, // vtx 2
0, 6, 0, 16,  // vtx 3

0x01,         // fill_polygon
0x04,         // 3 vertices, flat style
0x00,         // color=0
0, 6, 0, 22,  // vtx 0
0, 42, 0, 22, // vtx 1
0, 42, 0, 26, // vtx 2
0, 6, 0, 26,  // vtx 3

0x01,         // fill_polygon
0x04,         // 3 vertices, flat style
0x00,         // color=0
0, 6, 0, 32,  // vtx 0
0, 42, 0, 32, // vtx 1
0, 42, 0, 36, // vtx 2
0, 6, 0, 36,  // vtx 3

0x00,         // end_of_document
```
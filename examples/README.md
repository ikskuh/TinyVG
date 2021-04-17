# Example Files

## `app_menu.tvg` ()

![](app_menu.png)

| File Type | Size (Bytes) | Size (Relative) |
|-----------|--------------|-----------------|
| TVG       | 72  | 100%            |
| PNG       | 86  | 119% |

<details>
<summary>Textual Representation</summary>

```
(tvg
  (1 256 48 48)
  (
    (0 0 0)
  )
  (
     (
       fill_polygon
       (flat 0)
       (
         (6 12)
         (42 12)
         (42 16)
         (6 16)
       )
     )
     (
       fill_polygon
       (flat 0)
       (
         (6 22)
         (42 22)
         (42 26)
         (6 26)
       )
     )
     (
       fill_polygon
       (flat 0)
       (
         (6 32)
         (42 32)
         (42 36)
         (6 36)
       )
     )
  )
)
```
</details>

## `feature-showcase.tvg` ()

![](feature-showcase.png)

| File Type | Size (Bytes) | Size (Relative) |
|-----------|--------------|-----------------|
| TVG       | 1247  | 100%            |
| PNG       | 26567  | 2130% |

<details>
<summary>Textual Representation</summary>

```
(tvg
  (1 16 1024 1024)
  (
    (231 169 21)
    (255 120 0)
    (64 255 0)
    (186 0 77)
    (98 0 158)
    (148 229 56)
  )
  (
     (
       fill_rectangles
       (flat 0)
       (
         (16 16 64 48)
         (96 16 64 48)
       )
     )
     (
       fill_rectangles
       (linear (32 80) (144 128) 1 2 )
       (
         (16 80 64 48)
         (96 80 64 48)
       )
     )
     (
       fill_rectangles
       (radial (80 144) (48 176) 1 2 )
       (
         (16 144 64 48)
         (96 144 64 48)
       )
     )
     (
       fill_polygon
       (flat 3)
       (
         (192 32)
         (208 16)
         (240 16)
         (256 32)
         (256 64)
         (224 48)
         (192 64)
       )
     )
     (
       fill_polygon
       (linear (224 80) (224 128) 3 4 )
       (
         (192 96)
         (208 80)
         (240 80)
         (256 96)
         (256 128)
         (224 112)
         (192 128)
       )
     )
     (
       fill_polygon
       (radial (224 144) (224 192) 3 4 )
       (
         (192 160)
         (208 144)
         (240 144)
         (256 160)
         (256 192)
         (224 176)
         (192 192)
       )
     )
     (
       fill_path
       (flat 5)
       (
         (vert 32)
         (bezier (288 24) (288 16) (304 16))
         (horiz 336)
         (bezier (352 16) (352 24) (352 32))
         (vert 64)
         (line 336 48)
         (line 320 32)
         (line 312 48)
         (line 304 64)
         (close)
       )
     )
     (
       fill_path
       (linear (320 80) (320 128) 3 4 )
       (
         (vert 96)
         (bezier (288 88) (288 80) (304 80))
         (horiz 336)
         (bezier (352 80) (352 88) (352 96))
         (vert 128)
         (line 336 112)
         (line 320 96)
         (line 312 112)
         (line 304 128)
         (close)
       )
     )
     (
       fill_path
       (radial (320 144) (320 192) 3 4 )
       (
         (vert 160)
         (bezier (288 152) (288 144) (304 144))
         (horiz 336)
         (bezier (352 144) (352 152) (352 160))
         (vert 192)
         (line 336 176)
         (line 320 160)
         (line 312 176)
         (line 304 192)
         (close)
       )
     )
     (
       draw_lines
       (flat 1)
       0
       (
         ((16 224) (80 224))
         ((16 240) (80 240))
         ((16 256) (80 256))
         ((16 272) (80 272))
       )
     )
     (
       draw_lines
       (linear (48 304) (48 352) 3 4 )
       3
       (
         ((16 304) (80 304))
         ((16 320) (80 320))
         ((16 336) (80 336))
         ((16 352) (80 352))
       )
     )
     (
       draw_lines
       (radial (48 408) (48 432) 3 4 )
       6
       (
         ((16 384) (80 384))
         ((16 400) (80 400))
         ((16 416) (80 416))
         ((16 432) (80 432))
       )
     )
     (
       draw_line_strip
       (flat 1)
       3
       (
         (96 224)
         (160 224)
         (160 240)
         (96 240)
         (96 256)
         (160 256)
         (160 272)
         (96 272)
       )
     )
     (
       draw_line_strip
       (linear (128 304) (128 352) 3 4 )
       6
       (
         (96 304)
         (160 304)
         (160 320)
         (96 320)
         (96 336)
         (160 336)
         (160 352)
         (96 352)
       )
     )
     (
       draw_line_strip
       (radial (128 408) (128 432) 3 4 )
       0
       (
         (96 384)
         (160 384)
         (160 400)
         (96 400)
         (96 416)
         (160 416)
         (160 432)
         (96 432)
       )
     )
     (
       draw_line_loop
       (flat 1)
       6
       (
         (176 224)
         (240 224)
         (240 240)
         (192 240)
         (192 256)
         (240 256)
         (240 272)
         (176 272)
       )
     )
     (
       draw_line_loop
       (linear (208 304) (208 352) 3 4 )
       0
       (
         (176 304)
         (240 304)
         (240 320)
         (192 320)
         (192 336)
         (240 336)
         (240 352)
         (176 352)
       )
     )
     (
       draw_line_loop
       (radial (208 408) (208 432) 3 4 )
       3
       (
         (176 384)
         (240 384)
         (240 400)
         (192 400)
         (192 416)
         (240 416)
         (240 432)
         (176 432)
       )
     )
     (
       draw_line_path
       (flat 1)
       0
       (
         (horiz 304)
         (bezier (320 224) (320 240) (304 240))
         (horiz 288)
         (line 272 248)
         (line 288 256)
         (line 320 256)
         (line 304 272)
         (horiz 272)
         (line 256 256)
         (close)
       )
     )
     (
       draw_line_path
       (linear (288 408) (288 432) 3 4 )
       6
       (
         (horiz 304)
         (bezier (320 304) (320 320) (304 320))
         (horiz 288)
         (line 272 328)
         (line 288 336)
         (line 320 336)
         (line 304 352)
         (horiz 272)
         (line 256 336)
         (close)
       )
     )
     (
       draw_line_path
       (radial (288 408) (288 432) 3 4 )
       3
       (
         (horiz 304)
         (bezier (320 384) (320 400) (304 400))
         (horiz 288)
         (line 272 408)
         (line 288 416)
         (line 320 416)
         (line 304 432)
         (horiz 272)
         (line 256 416)
         (close)
       )
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
     (
       outline_fill_rectangles
     )
  )
)
```
</details>

## `shield.tvg` ()

![](shield.png)

| File Type | Size (Bytes) | Size (Relative) |
|-----------|--------------|-----------------|
| TVG       | 207  | 100%            |
| PNG       | 169  | 81% |

<details>
<summary>Textual Representation</summary>

```
(tvg
  (1 256 24 24)
  (
    (41 173 255)
    (255 241 232)
  )
  (
     (
       fill_path
       (flat 0)
       (
         (line 3 5)
         (vert 11)
         (bezier (3 16.55078125) (6.83984375 21.73828125) (12 23))
         (bezier (17.16015625 21.73828125) (21 16.55078125) (21 11))
         (vert 5)
       )
     )
     (
       fill_path
       (flat 1)
       (
         (bezier (15.921875 18.8515625) (14.109375 20.23828125) (12 20.921875))
         (bezier (9.890625 20.23828125) (8.078125 18.8515625) (6.87109375 17))
         (bezier (6.53125 16.5) (6.23828125 16) (6 15.46875))
         (bezier (6 13.8203125) (8.7109375 12.46875) (12 12.46875))
         (bezier (15.2890625 12.46875) (18 13.7890625) (18 15.46875))
         (bezier (17.76171875 16) (17.46875 16.5) (17.12890625 17))
       )
     )
     (
       fill_path
       (flat 1)
       (
         (bezier (13.5 5) (15 6.19921875) (15 8))
         (bezier (15 9.5) (13.80078125 10.99609375) (12 11))
         (bezier (10.5 11) (9 9.80078125) (9 8))
         (bezier (9 6.3984375) (10.19921875 5) (12 5))
       )
     )
  )
)
```
</details>

## `workspace_add.tvg` ()

![](workspace_add.png)

| File Type | Size (Bytes) | Size (Relative) |
|-----------|--------------|-----------------|
| TVG       | 85  | 100%            |
| PNG       | 126  | 148% |

<details>
<summary>Textual Representation</summary>

```
(tvg
  (1 256 48 48)
  (
    (0 135 81)
    (131 118 156)
    (255 0 77)
  )
  (
     (
       fill_rectangles
       (flat 0)
       (
         (6 6 16 36)
       )
     )
     (
       fill_rectangles
       (flat 1)
       (
         (26 6 16 16)
       )
     )
     (
       fill_path
       (flat 2)
       (
         (horiz 32)
         (vert 26)
         (horiz 36)
         (vert 32)
         (horiz 42)
         (vert 36)
         (horiz 36)
         (vert 42)
         (horiz 32)
         (vert 36)
         (horiz 26)
       )
     )
  )
)
```
</details>

## `workspace.tvg` ()

![](workspace.png)

| File Type | Size (Bytes) | Size (Relative) |
|-----------|--------------|-----------------|
| TVG       | 56  | 100%            |
| PNG       | 120  | 214% |

<details>
<summary>Textual Representation</summary>

```
(tvg
  (1 256 48 48)
  (
    (0 135 81)
    (131 118 156)
    (29 43 83)
  )
  (
     (
       fill_rectangles
       (flat 0)
       (
         (6 6 16 36)
       )
     )
     (
       fill_rectangles
       (flat 1)
       (
         (26 6 16 16)
       )
     )
     (
       fill_rectangles
       (flat 2)
       (
         (26 26 16 16)
       )
     )
  )
)
```
</details>


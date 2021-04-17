# TVG Text Format

This document is an auxiliary document side-by-side to the TVG specification to allow a non-binary represenation of TVG files.

This format is meant for debugging/development and is not required to be implemented by conforming implementations.

## Example

```lisp
(tvg
  ( ; header information
    1 ; version
    128 ; virtual canvas width 
    128 ; virtual canvas height
  )
  ( ; color table
    (0 0 0)
    (255 255 0)
    (0 0 0 128)
  )
  ; all other elements are now elements of graphic
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
      (6, 32)
      (42, 32)
      (42, 36)
      (6, 36)
    )
  ) 
)
```
# Tiny Vector Graphics (Specification)

**Abstract:** The tiny vector graphics format is a binary file format that encodes a list of vector graphic primitives.

## Intruction

### Why a new format

SVG is the status quo widespread vector format. Every program can kinda use it and can probably render it right. The problem is that SVG is a horribly large specification, it is based on XML and provides not only vector graphics, but also a full suite for animation and JavaScript scripting. Implementing a new SVG renderer from scratch is a tremendous amount of work, and it is hard to get it done right.

Quoting the [german Wikipedia](https://de.wikipedia.org/wiki/Scalable_Vector_Graphics):

> 🇩🇪 Praktisch alle relevanten Webbrowser können einen Großteil des Sprachumfangs darstellen.  
> 🇺🇸 Virtually all relevant web browsers can display a large part of the language range.

The use of XML bloats the files by a huge magnitude and doesn't provide a efficient encoding, thus a lot of websites and applications ship files that are not encoded optimally. Also SVG allows several ways of achieving the same thing, and can be seen more as a intermediate format for editing as for final encoding.

TVG was created to adress most of these problems, trying to achieve a balance between flexibility and file size, while keeping file size as the more important priority.

### Features

- Binary encoding
- Support of the most common 2D vector primitives
  - Paths
  - Polygons
  - Rectangles
  - Lines
- 3 different fill styles
  - Flat color
  - Linear 2-point gradient
  - Radial 2-point gradient

## Format

TVG files are roughly structured like this:

![Stack of Blocks](graphics/overview.svg)

Files are made up of a header, followed by a color lookup table and a sequence of commands terminated by a _end of file_ command.

## Header

## Color Table

## Commands

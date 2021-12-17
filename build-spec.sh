#!/bin/bash

exec markdown-pdf \
  --paper-format A4 \
  --paper-orientation portrait \
  --out "$1"  \
  --cwd documents \
  --runnings-path documents/helper/runnings.js \
  --css-path documents/helper/style.css \
  documents/specification.md
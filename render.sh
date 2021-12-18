#!/bin/bash

set -e

# lcmark -o specification.body.tex -t latex -c 0 -u ../specification.md 

pandoc \
  -f gfm \
  -t latex \
  --metadata-file=info.yaml \
  -s \
  --table-of-contents \
  --resource-path=.. \
  ../specification.md \
  --include-in-header=table.header.tex \
  -o specification.pdf

# sed -i 's/\.svg\}/.pdf}/g' specification.body.tex

# cat preamble.tex specification.body.tex postamble.tex > specification.tex

# xelatex  specification.tex
# xelatex  specification.tex
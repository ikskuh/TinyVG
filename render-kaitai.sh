#!/bin/bash
set -e 
kaitai-struct-compiler --target graphviz --outdir dev-thingies/ documents/tvg.ksy
dot -Tsvg dev-thingies/tvg.dot -o dev-thingies/tvg.svg
dot -Tpng dev-thingies/tvg.dot -o dev-thingies/tvg.png
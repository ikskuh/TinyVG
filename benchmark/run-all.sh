#!/bin/bash


ROOT="$(realpath $(dirname $(realpath $0)))"

"${ROOT}/benchmark-folder.sh" "${ROOT}/../website/benchmark/freesvg.csv" ~/projects/datasets/vectors/freesvg.org/ /tmp/benchmark/freesvg/
"${ROOT}/benchmark-folder.sh" "${ROOT}/../website/benchmark/zig.csv" ~/projects/datasets/vectors/zig-logo/ /tmp/benchmark/zig/
"${ROOT}/benchmark-folder.sh" "${ROOT}/../website/benchmark/w3c.csv" ~/projects/datasets/vectors/w3c/ /tmp/benchmark/w3c/
"${ROOT}/benchmark-folder.sh" "${ROOT}/../website/benchmark/papirus.csv" ~/projects/datasets/vectors/papirus/ /tmp/benchmark/papirus/ 1000
"${ROOT}/benchmark-folder.sh" "${ROOT}/../website/benchmark/material-design.csv" ~/projects/datasets/vectors/material-design/ /tmp/benchmark/material-design/ 1000
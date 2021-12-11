#!/bin/bash

# This script performs a basic benchmark to compare SVG and TVG
#
# $1 is the SVG file that will be rendered to TVG, then back to SVG

set -eo pipefail

function write_log()
{
  echo "$@" >&2
}

function panic()
{
  write_log "$@"
  exit 1
}

ROOT="$(realpath $(dirname $(realpath $0)))"
PATH="${ROOT}/../src/tools/svg2tvg/bin/Debug/net5.0/linux-x64:${ROOT}/../zig-out/bin:${PATH}"
WORKDIR=/tmp/tvg-benchmark

which convert tvg-text svgo svg2tvgt tvg-render > /dev/null

[ -f "$1" ] || panic "file not found!"

rm -rf "${WORKDIR}}"
mkdir -p "${WORKDIR}"

cp "$1" "${WORKDIR}/input.svg"

svgo --quiet --config "${ROOT}/svgo.config.js" "${WORKDIR}/input.svg" >&2

# WARNING: This invokes inkscape and is ultimatively slow
# convert -background none "${WORKDIR}/input.svg" "${WORKDIR}/input.png"

svg2tvgt --strict "${WORKDIR}/input.svg" --output "${WORKDIR}/output.tvgt"

tvg-text "${WORKDIR}/output.tvgt" --output "${WORKDIR}/output.tvg"

tvg-text "${WORKDIR}/output.tvg" --output "${WORKDIR}/output.svg"
svgo --quiet --config "${ROOT}/svgo.config.js" "${WORKDIR}/output.svg" >&2

tvg-render "${WORKDIR}/output.tvg" --output "${WORKDIR}/output.tga" --super-sampling 4
convert "${WORKDIR}/output.tga" "${WORKDIR}/output.png"

# compare -similarity-threshold 0.5 "${WORKDIR}/input.png" "${WORKDIR}/output.png" "${WORKDIR}/diff.png"

SVG_SIZE=$(cat "${WORKDIR}/input.svg" | wc -c)
TVG_SIZE=$(cat "${WORKDIR}/output.tvg" | wc -c)

echo -e "$1\t${SVG_SIZE}\t${TVG_SIZE}"
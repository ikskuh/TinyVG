#!/bin/bash

set -eo pipefail

DST="$1"
DIR="$2"
OUT="$3"
LIMIT="$4"
ROOT="$(realpath $(dirname $(realpath $0)))"

[ ! -e "${DST}" ] || [ -f "${DST}" ]

if [ ! -z "${LIMIT}" ]; then
  LIMIT=$((${LIMIT} + 0))
fi

if [ -z "${DIR}" ]; then
  DIR="."
fi

[ -d "${DIR}" ]

DIR=$(realpath "${DIR}")

if [ ! -z "${OUT}" ]; then

  if [ ! -e "${OUT}" ]; then
    mkdir -p "${OUT}"
  fi

  if [ -d "${OUT}" ]; then
    rm -rf ${OUT}/*
    cp "${ROOT}/index.htm.head" "${OUT}/index.htm"
  fi
fi

echo "Searching ${DIR}"

echo -e "Path\tSVG Size\tTVG Size" > "${DST}"

OIFS="$IFS"
IFS=$'\n'
for file in $(find "${DIR}" -name "*.svg"); do

  echo -n "Converting ${file} ..."

  if "${ROOT}/bench-from-svg.sh" "$file" >> "${DST}" ; then
    if [ ! -z "${OUT}" ]; then
      RELPATH="$(realpath "--relative-to=${DIR}" "${file}")"
      DIRNAME="img/$(dirname "${RELPATH}")"

      mkdir -p "${OUT}/${DIRNAME}"

      cp "/tmp/tvg-benchmark/input.svg" "${OUT}/img/${RELPATH}"
      cp "/tmp/tvg-benchmark/output.svg" "${OUT}/img/${RELPATH%.svg}.ref.svg"
      cp "/tmp/tvg-benchmark/output.png" "${OUT}/img/${RELPATH%.svg}.png"

      SVG_SIZE="$(cat "/tmp/tvg-benchmark/input.svg" | wc -c)"
      TVG_SIZE="$(cat "/tmp/tvg-benchmark/output.tvg" | wc -c)"

      echo -n "<tr><td><code>${RELPATH}</code></td>" >> "${OUT}/index.htm" # File Name
      echo -n "<td>${SVG_SIZE}</td>" >> "${OUT}/index.htm" # SVG Size
      echo -n "<td>${TVG_SIZE}</td>" >> "${OUT}/index.htm" # TVG Size
      echo -n "<td>$((100 * ${TVG_SIZE} / ${SVG_SIZE}))%</td>" >> "${OUT}/index.htm" # TVG/SVG Ratio
      echo -n "<td><img loading=\"lazy\" src=\"img/${RELPATH}\"></td>" >> "${OUT}/index.htm" # SVG original
      echo -n "<td><img loading=\"lazy\" src=\"img/${RELPATH%.svg}.png\"></td>" >> "${OUT}/index.htm" # TVG render
      echo    "<td><img loading=\"lazy\" src=\"img/${RELPATH%.svg}.ref.svg\"></td></tr>" >> "${OUT}/index.htm" # TVG reference svg

    fi
    echo -e "\b\b\bSUCCESS"
  else
    echo -e "\b\b\bFAILED"
  fi

  if [ ! -z "${LIMIT}" ]; then
    if [ $(cat "${DST}" | wc -l) -ge $((${LIMIT} + 1)) ]; then
      break 
    fi
  fi

done

if [ ! -z "${OUT}" ]; then
  cat "${ROOT}/index.htm.foot" >> "${OUT}/index.htm"
fi
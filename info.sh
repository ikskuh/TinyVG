#!/bin/bash

zig build generate

for file in examples/*.tvg ; do
  SIZE_TVG="$(wc -c "${file}" | awk '{ print $1 }')"
  SIZE_PNG="$(wc -c "${file%.*}.png" | awk '{ print $1 }')"
  echo "${file} has size ${SIZE_TVG}, which are $(( (100 * ${SIZE_TVG} ) / ${SIZE_PNG} ))% of ${SIZE_PNG}"
done
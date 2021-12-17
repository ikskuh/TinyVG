#!/bin/bash

set -e

function uxf2svg() 
{
  umlet -action=convert -format=svg -filename=$1  -output=$2
}

for file in *.uxf ; do
  uxf2svg "${file}" "${file%.*}.svg"
done
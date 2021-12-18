#!/bin/bash

set -e

rm -rf sdk-release
mkdir sdk-release

cp documents/sdk-readme.txt sdk-release/README.txt

echo "Prepare examples..."
mkdir -p sdk-release/examples/{code,graphics}
cp examples/native/usage.c sdk-release/examples/code/usage.c
cp examples/web/index.htm sdk-release/examples/code/polyfill.htm

cp design/logo.tvg                sdk-release/examples/graphics/tinyvg.tvg
cp examples/tinyvg/everything.tvg sdk-release/examples/graphics/feature-test.tvg
cp website/img/shield.tvg         sdk-release/examples/graphics/shield.tvg
cp website/img/tiger.tvg          sdk-release/examples/graphics/tiger.tvg
cp website/img/flowchart.tvg      sdk-release/examples/graphics/flowchart.tvg
cp website/img/comic.tvg          sdk-release/examples/graphics/comic.tvg
cp website/img/chart.tvg          sdk-release/examples/graphics/chart.tvg
cp website/img/app-icon.tvg       sdk-release/examples/graphics/app-icon.tvg

echo "Prepare Zig package"
mkdir -p sdk-release/zig/
cp -r vendor/parser-toolkit/src sdk-release/zig/ptk
cp -r src/lib/* sdk-release/zig

echo "Build native libraries"
zig build -Drelease -Dlibs=false -Dheaders=true  -Dtools=false --prefix sdk-release/native install
zig build -Drelease -Dlibs=true  -Dheaders=false -Dtools=true  --prefix sdk-release/native/x86_64-windows -Dtarget=x86_64-windows install
zig build -Drelease -Dlibs=true  -Dheaders=false -Dtools=true  --prefix sdk-release/native/x86_64-macos   -Dtarget=x86_64-macos   install
zig build -Drelease -Dlibs=true  -Dheaders=false -Dtools=true  --prefix sdk-release/native/x86_64-linux   -Dtarget=x86_64-linux   install
zig build -Drelease -Dlibs=true  -Dheaders=false -Dtools=true  --prefix sdk-release/native/aarch64-macos  -Dtarget=x86_64-macos   install
zig build -Drelease -Dlibs=true  -Dheaders=false -Dtools=true  --prefix sdk-release/native/aarch64-linux  -Dtarget=x86_64-linux   install

# patch the dll files
mv sdk-release/native/x86_64-windows/lib/tinyvg{.dll,}.dll
mv sdk-release/native/x86_64-windows/lib/tinyvg{.dll,}.pdb

echo "Build wasm polyfill"
zig build -Drelease -Dlibs=false -Dheaders=false -Dtools=false -Dpolyfill --prefix sdk-release/
mv sdk-release/{www,js}

echo "Build specification"
./build-spec.sh sdk-release/specification.pdf

echo "Build dotnet tooling"

make -C src/tools/svg2tvg/ publish
cp -r src/tools/svg2tvg/release/win-x64/*      sdk-release/native/x86_64-windows/bin/
cp -r src/tools/svg2tvg/release/linux-x64/*    sdk-release/native/x86_64-linux/bin/
cp -r src/tools/svg2tvg/release/osx-x64/*      sdk-release/native/x86_64-macos/bin/
cp -r src/tools/svg2tvg/release/linux-arm64/*  sdk-release/native/aarch64-linux/bin/

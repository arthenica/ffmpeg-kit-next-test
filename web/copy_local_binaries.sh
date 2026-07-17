#!/usr/bin/env bash
#
# Copies the locally built FFmpegKitNext web (wasm) output into this test app so
# it can be served as static files. Sample assets are owned by this web app and
# are not copied from another platform.
#
#   ./copy_local_binaries.sh [path-to-ffmpeg-kit-next]
#
# Default source repo is ../../ffmpeg-kit-next relative to this script.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kit_repo="${1:-${script_dir}/../../ffmpeg-kit-next}"

bundle_root="${kit_repo}/prebuilt/bundle-web-wasm32/ffmpeg-kit-next"
bundle_lib="${bundle_root}/lib"
bundle_binding="${bundle_root}/dist"

if [[ ! -d "${bundle_lib}" ]]; then
  echo "error: web bundle not found at ${bundle_lib}" >&2
  echo "       build it first: (cd ${kit_repo} && ./nix-web.sh -p web-wasm32-emscripten)" >&2
  exit 1
fi

echo "Copying web library from ${bundle_lib}"
rm -rf "${script_dir:?}/lib"
mkdir -p "${script_dir}/lib"
# The main module (.js/.wasm) plus every side module (.so) it loads at runtime.
cp -f "${bundle_lib}"/libffmpegkit.js "${script_dir}/lib/"
cp -f "${bundle_lib}"/libffmpegkit.wasm "${script_dir}/lib/"
if [[ -f "${bundle_lib}/libffmpegkit.so" ]]; then
  cp -f "${bundle_lib}"/*.so "${script_dir}/lib/"
fi

echo "Copying JS binding layer from ${bundle_binding}"
# dist/ and lib/ are kept siblings so the worker's ../lib import resolves, exactly
# as in the bundle. This is the shipped package; the app consumes it, never edits it.
rm -rf "${script_dir:?}/dist"
mkdir -p "${script_dir}/dist/src"
cp -f "${bundle_binding}"/*.js "${bundle_binding}"/*.d.ts "${bundle_root}"/package.json "${script_dir}/dist/"
cp -f "${bundle_binding}"/src/*.js "${script_dir}/dist/src/"

echo "Done. Serve with:  node server.mjs"

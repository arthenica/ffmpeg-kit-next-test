#!/bin/bash

export BASEDIR="$(pwd)"

BUNDLE_PREFIX="${BASEDIR}/../../ffmpeg-kit-next/prebuilt/bundle-apple-xcframework-ios-"
shopt -s nullglob
BUNDLE_DIRS=("${BUNDLE_PREFIX}"*/)

if [ "${#BUNDLE_DIRS[@]}" -eq 0 ]; then
    printf 'Error: no bundle folders matching %s*\n' "$BUNDLE_PREFIX" >&2
    exit 1
fi
if [ "${#BUNDLE_DIRS[@]}" -gt 1 ]; then
    printf 'Warning: found %s bundle folders matching %s*; using first: %s\n' \
        "${#BUNDLE_DIRS[@]}" "$BUNDLE_PREFIX" "${BUNDLE_DIRS[0]}" >&2
fi

cd "${BASEDIR}/../ipados" || exit 1
rm -rf *.framework || exit 1
rm -rf *.xcframework || exit 1
find "${BUNDLE_DIRS[0]}" -name "*.xcframework" -exec cp -R {} . \; || exit 1

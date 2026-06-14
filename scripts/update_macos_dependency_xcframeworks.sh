#!/bin/bash

export BASEDIR="$(pwd)"

cd ${BASEDIR}/../macos || exit 1
rm -rf *.xcframework || exit 1
rm -rf *.framework || exit 1
find ${BASEDIR}/../../ffmpeg-kit-next/prebuilt/bundle-apple-xcframework-macos-10.15 -name "*.xcframework" -exec cp -R {} . \; || exit 1

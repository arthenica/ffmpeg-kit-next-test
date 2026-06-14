#!/bin/bash

export BASEDIR="$(pwd)"

cd ${BASEDIR}/../tvos || exit 1
rm -rf *.framework || exit 1
rm -rf *.xcframework || exit 1
find ${BASEDIR}/../../ffmpeg-kit-next/prebuilt/bundle-apple-xcframework-tvos-11.0 -name "*.xcframework" -exec cp -R {} . \; || exit 1

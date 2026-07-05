#!/bin/bash

export BASEDIR="$(pwd)"

cd ${BASEDIR}/../ipados || exit 1
rm -rf *.framework || exit 1
rm -rf *.xcframework || exit 1
find ${BASEDIR}/../../ffmpeg-kit-next/prebuilt/bundle-apple-xcframework-ios-12.1 -name "*.xcframework" -exec cp -R {} . \; || exit 1

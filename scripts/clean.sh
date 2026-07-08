#!/bin/bash

CURRENT_WORKING_DIRECTORY="$(pwd)"

rm -rf ../android/.gradle
rm -rf ../android/build/
rm -rf ../android/test-app-java/build/
rm -rf ../android/test-app-kotlin/build/
rm -rf ../android/test-app-native/build/

rm -rf ../ios/*.framework
rm -rf ../ios/*.xcframework

rm -rf ../ipados/*.framework
rm -rf ../ipados/*.xcframework

rm -rf ../macos/*.framework
rm -rf ../macos/*.xcframework

rm -rf ../tvos/*.framework
rm -rf ../tvos/*.xcframework

rm -rf ../visionos/*.framework
rm -rf ../visionos/*.xcframework

rm -rf ../linux/build

cd ../flutter/test-app-podspec && ./clean.sh
cd "$CURRENT_WORKING_DIRECTORY"

cd ../flutter/test-app-spm && ./clean.sh
cd "$CURRENT_WORKING_DIRECTORY"

cd ../react-native && ./clean.sh
cd "$CURRENT_WORKING_DIRECTORY"

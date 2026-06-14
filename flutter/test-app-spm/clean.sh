#!/bin/bash

flutter clean
rm -rf build 
rm -rf ios/.symlinks
rm -rf ios/Pods
rm -rf ios/Flutter/App.framework
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/flutter_assets
rm -rf macos/.symlinks
rm -rf macos/Pods
rm -rf macos/Flutter/App.framework
rm -rf macos/Flutter/Flutter.framework
rm -rf macos/Flutter/flutter_assets
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
rm -rf /Library/Developer/Xcode/DerivedData/Runner-*

rm -rf android/.gradle
rm -rf .dart_tool
rm -rf .packages
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies
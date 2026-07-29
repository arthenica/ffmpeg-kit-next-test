# FFmpegKitNext Flutter Test Applications

The `flutter` folder contains two Flutter test applications for integrating `FFmpegKitNext`.

Flutter encourages Swift Package Manager for Apple platform dependencies, and the SPM test app follows that flow.
Projects can still use `FFmpegKitNext` without Swift Package Manager, so this repository also includes a CocoaPods
test app. Both applications consume the same local `ffmpeg_kit_next_flutter` plugin; they only differ in the Apple
dependency integration path.

## Test Apps

- [CocoaPods test application](test-app-podspec)
- [Swift Package Manager test application](test-app-spm)

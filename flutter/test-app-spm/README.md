# FFmpegKitNext Flutter Test Application (Swift Package Manager)

This Flutter test application consumes the local `ffmpeg_kit_next_flutter` plugin. On Apple platforms it is prepared
for Flutter's Swift Package Manager flow.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/963876c6-eb7f-4432-a647-821877ae2cc8)

## Add FFmpegKitNext to a Flutter App

`ffmpeg_kit_next_flutter` is consumed from a local path dependency, not from `pub.dev`.

```yaml
dependencies:
  ffmpeg_kit_next_flutter:
    path: ../ffmpeg-kit-next/flutter/flutter
```

Adjust the path to match the location of `ffmpeg-kit-next` relative to your Flutter application.

For Android, the plugin contains a local Maven repository under `android/libs-maven`. Gradle does not inherit
repositories from dependencies, so declare that repository in the app's project-level `android/build.gradle`:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        def ffmpegKitProject = rootProject.findProject(":ffmpeg_kit_next_flutter")
        if (ffmpegKitProject != null) {
            maven {
                url "${ffmpegKitProject.projectDir}/libs-maven"
            }
        }
    }
}
```

Keep this in `android/build.gradle`, not in `settings.gradle` dependency resolution. For iOS, iPadOS and macOS, the
plugin's `Package.swift` references the copied `xcframeworks` as binary targets when Swift Package Manager is enabled;
the sibling podspec remains the CocoaPods fallback.

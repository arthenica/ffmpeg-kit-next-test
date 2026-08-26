# FFmpegKitNext React Native Test Application (TypeScript)

The `react-native/tsx` folder contains a React Native test application, written in TypeScript, that consumes the local
`ffmpeg-kit-next-react-native` package. A [JavaScript version](../js) of the same application is also available.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/6715f84d-3a93-43d1-9f74-5fd4097a23c6)

## Add FFmpegKitNext to a React Native App

`ffmpeg-kit-next-react-native` is consumed from a local package path, not from the npm registry.

```sh
yarn add file:../ffmpeg-kit-next/react-native
```

Or with npm:

```sh
npm install ../ffmpeg-kit-next/react-native
```

Adjust the path to match the location of `ffmpeg-kit-next` relative to your application.

For Android, the plugin contains a local Maven repository under `android/libs-maven`. Gradle does not inherit
repositories from dependencies, so declare that repository in the app's `android/build.gradle`:

```groovy
allprojects {
    repositories {
        def ffmpegKitProject = rootProject.findProject(":ffmpeg-kit-next-react-native")
        if (ffmpegKitProject != null) {
            maven {
                url "${ffmpegKitProject.projectDir}/libs-maven"
            }
        }
    }
}
```

React Native autolinking adds the package to Android and iOS. iOS and iPadOS use the vendored `xcframeworks` declared
by the package podspec, so no extra CocoaPods source or explicit `pod` line is needed.

## TypeScript Notes

The application entry point is `index.tsx`, not the `index.js` React Native assumes by default. Both release bundlers
are pointed at it explicitly: `entryFile` in `android/app/build.gradle` and `ENTRY_FILE` in `ios/.xcode.env`.

The `ios` and `android` scripts type-check first and only build/launch if it passes
(`yarn typecheck && react-native run-ios`), so build and run with `yarn ios` / `yarn android` to gate every run on a
clean type check. While the type check fails for the reason described below, these scripts stop before installing
anything. Invoking `yarn react-native run-ios` directly bypasses the script and does not type-check.

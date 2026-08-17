# FFmpegKitNext Test

Test applications for [FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next).

- `Android` under the [android](android) folder
- `Flutter` under the [flutter](flutter) folder
- `iOS` under the [ios](ios) folder
- `iPadOS` under the [ipados](ipados) folder
- `Linux` under the [linux](linux) folder
- `macOS` under the [macos](macos) folder
- `React Native` under the [react-native](react-native) folder
- `tvOS` under the [tvos](tvos) folder
- `visionOS` under the [visionos](visionos) folder
- `Web` under the [web](web) folder
- `Windows` under the [windows](windows) folder

The platform README files describe how an application adds the already-built local `FFmpegKitNext` package or binary
artifacts. They do not duplicate API usage examples.

The test applications cover command execution, video encoding, accessing https urls, encoding audio, burning subtitles,
video stabilisation, pipe operations, concurrent command execution and using ffkit protocols. Platform support differs
where the operating system or runtime does not provide an equivalent capability.

Android test applications (including Flutter and React Native apps running on Android) also include the ffkitsaf
protocol under the FFKit Protocols page to demonstrate how SAF URIs can be used with `FFmpegKitNext`.

The `Linux` and `Windows` test applications have no embedded video player. Both instead offer a PLAY button on the
tabs that produce video, which opens the encoded file in the default system player in an external window.

### Versions

Released test applications are tagged with the `ffmpeg-kit-next` release they depend on. The development branch may
target a newer version before a release tag is created.

|  Platform | FFmpegKit Version |                                        Tag                                        |
| :----: |:-----------------:|:---------------------------------------------------------------------------------:|
|   Android<br>Flutter<br>iOS<br>iPadOS<br>Linux<br>macOS<br>React Native<br>tvOS<br>visionOS<br>Web    |       8.1.1       |  [8.1.1](https://github.com/arthenica/ffmpeg-kit-next-test/tree/v8.1.1)   |
|   Android<br>Flutter<br>iOS<br>Linux<br>macOS<br>React Native<br>tvOS    |       8.1.0       |  [8.1.0](https://github.com/arthenica/ffmpeg-kit-next-test/tree/v8.1.0)   |
|   Android<br>Flutter<br>iOS<br>Linux<br>macOS<br>React Native<br>tvOS    |       7.1.0       |  [7.1.0](https://github.com/arthenica/ffmpeg-kit-next-test/tree/v7.1.0)   |
|   Android<br>Flutter<br>iOS<br>Linux<br>macOS<br>React Native<br>tvOS    |       6.1.1       |  [6.1.1](https://github.com/arthenica/ffmpeg-kit-next-test/tree/v6.1.1)   |
|   Android<br>Flutter<br>iOS<br>Linux<br>macOS<br>React Native<br>tvOS    |       6.1.0       |  [6.1.0](https://github.com/arthenica/ffmpeg-kit-next-test/tree/v6.1.0)   |

### License

`FFmpegKitNext Test` repository is licensed under the [MIT License](https://opensource.org/licenses/MIT), fonts used by
the applications are licensed under the [SIL Open Font License](https://opensource.org/licenses/OFL-1.1), other 
digital assets are published in the public domain.

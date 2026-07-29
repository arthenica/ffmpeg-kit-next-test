# FFmpegKitNext visionOS Test Applications

The `visionos` folder contains Objective-C and Swift test applications that consume local `FFmpegKitNext` visionOS
artifacts.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/6f7c85f4-0737-4a3a-a81e-ea32cef9ac26)

## Add FFmpegKitNext to a visionOS App

This assumes the visionOS package, `xcframeworks` or framework bundles already exist locally.

### Swift Package Manager

Use this option for Xcode projects that can consume a local package.

1. In Xcode, select `File` -> `Add Package Dependencies`.
2. Choose `Add Local...`.
3. Select the generated package folder, for example:

   ```text
   prebuilt/bundle-apple-xcframework-visionos-1.0/
   ```

4. Add the `ffmpeg-kit` package product to the visionOS app target.

The generated `Package.swift` references the local `xcframeworks` by relative path, so keep the package folder together
with the frameworks it was created for. The generated Swift package uses Swift tools 5.9 for visionOS support.

### Manual xcframework Integration

Add every generated `xcframework` to the app target:

```text
ffmpegkit.xcframework
libavcodec.xcframework
libavdevice.xcframework
libavfilter.xcframework
libavformat.xcframework
libavutil.xcframework
libswresample.xcframework
libswscale.xcframework
```

In `General` -> `Frameworks, Libraries and Embedded Content`, set the generated `xcframeworks` to `Embed & Sign` for
the final app target. If the frameworks are not copied into the Xcode project, make sure `Framework Search Paths`
points to the generated output folder.

### Manual framework Integration

If you use generated `.framework` bundles instead of `xcframeworks`, add all generated frameworks from the visionOS
output folder, not only `ffmpegkit.framework`. Embed and sign them for app targets.

Add a Run Script phase after `Embed Frameworks`:

```bash
${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/ffmpegkit.framework/strip-frameworks.sh
```

### System Libraries

Always link `ffmpegkit` together with the generated FFmpeg libraries listed above. Depending on the options enabled in
the local artifacts, Xcode may also need Apple frameworks or system libraries such as `AudioToolbox`, `VideoToolbox`,
`libbz2`, `libiconv` and `libz`.

Do not mix frameworks from different builds, deployment targets or enabled-library sets.

## Test Apps

- `test-app-objc`
- `test-app-swift`

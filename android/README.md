# FFmpegKitNext Android Test Applications

The `android` folder contains Java, Kotlin and native Android test applications that consume a local
`FFmpegKitNext` Android AAR.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/3950f5f7-dba2-479d-8cf3-e0c936678854)

## Add FFmpegKitNext to an Android App

This assumes the Android AAR has already been produced as a local Maven repository. Add that repository to the
application's `settings.gradle`:

```groovy
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven {
            url "<path-to-ffmpeg-kit-next>/prebuilt/bundle-android-aar-24-maven"
        }
    }
}
```

Then add the Android package to the app module:

```groovy
dependencies {
    implementation "com.arthenica:ffmpeg-kit-next:9.0.0"
}
```

When the local Maven repository is used, the generated POM resolves `smart-exception-java` transitively. If you add
`ffmpeg-kit-next.aar` manually instead of using the Maven repository, also add:

```groovy
implementation "com.arthenica:smart-exception-java:0.2.1"
```

For a native Android application, enable `prefab true` in the app module so CMake can consume the native headers and
libraries exported by the AAR. Keep `abiFilters` aligned with the ABIs included in your local AAR.

## Test Apps

- `test-app-java`
- `test-app-kotlin`
- `test-app-native`

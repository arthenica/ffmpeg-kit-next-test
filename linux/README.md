# FFmpegKitNext Linux

The `linux` folder contains a GTK-based Linux test application that consumes a local `FFmpegKitNext` Linux bundle.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/e0b51c25-b141-403d-8907-0e99872e660d)

## Add FFmpegKitNext to a Linux App

This assumes the Linux headers, shared libraries and `pkg-config` file already exist in a local bundle such as:

```text
<path-to-ffmpeg-kit-next>/prebuilt/bundle-linux/ffmpeg-kit-next
```

Point `pkg-config` at the bundle before configuring your application:

```sh
export PKG_CONFIG_PATH="<path-to-bundle>/pkgconfig:${PKG_CONFIG_PATH}"
```

Then consume the package from CMake:

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG_KIT REQUIRED IMPORTED_TARGET ffmpeg-kit-next=8.1.1)
target_link_libraries(<your-target> PRIVATE PkgConfig::FFMPEG_KIT)
```

At runtime, make sure the dynamic loader can find the FFmpegKitNext shared libraries. Use an install location known to
the loader, an rpath in your application, or an application launcher that sets `LD_LIBRARY_PATH` to the bundle's `lib`
directory.

## Video Playback

This app has no embedded player. The Video, Subtitle, Vid.Stab and Pipe tabs have a **PLAY** button that hands the
encoded file to whatever application the desktop has registered for it, in an external window. The button is disabled
until an output file has been produced.

## Test App Prerequisites

- `cmake` > 3.7
- C++ compiler with C++11 support
- `libgtkmm-3.0-dev` > 3.0

## Run This Test App

1. Configure the app with the local bundle path. `FFMPEG_KIT_BUNDLE_PATH` is the path where the local
   `ffmpeg-kit-next` Linux bundle exists.

    ```shell
    mkdir build
    cd build
    cmake -DFFMPEG_KIT_BUNDLE_PATH=/home/taner/Projects/ffmpeg-kit-next/prebuilt/bundle-linux/ffmpeg-kit-next ..
    ```

2. Run `make` to build and install the test app.

    ```shell
    make
    make install
    ```

3. Execute `ffmpeg-kit-linux-test-app.sh` from the `bin` directory.

    ```shell
    ./ffmpeg-kit-linux-test-app.sh
    ```

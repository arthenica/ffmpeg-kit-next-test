# FFmpegKitNext Linux

<img src="https://github.com/arthenica/ffmpeg-kit-next-test/blob/main/docs/assets/linux.gif" width="640">

Test application that depends on a local `ffmpeg-kit-next` build.

#### Prerequisites
- `cmake` > 3.7
- C++ compiler with C++11 support
- `libgtkmm-3.0-dev` > 3.0

#### Building

1. Use `cmake` to configure to build. 

  - `FFMPEG_KIT_BUNDLE_PATH` is the path where the local `ffmpeg-kit-next` Linux bundle exists

    ```shell
    mkdir build
    cd build
    cmake -DFFMPEG_KIT_BUNDLE_PATH=/home/taner/Projects/ffmpeg-kit-next/prebuilt/bundle-linux/ffmpeg-kit-next ..
    ```

2. Run `make` to build and/or to install the library.

    ```shell
    make
    make install
    ```

#### Running

1. Execute `ffmpeg-kit-linux-test-app.sh` from the `bin` directory after installing the app via `make install`.

    ```shell
    ./ffmpeg-kit-linux-test-app.sh
    ```

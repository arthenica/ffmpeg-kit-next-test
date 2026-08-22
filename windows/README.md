# FFmpegKitNext Windows Test Applications

The `windows` folder contains `MinGW-w64` and `MSVC` test applications that consume a local `FFmpegKitNext` Windows
bundle. Both are built from one set of sources, once per ABI, under `mingw-abi/` and `msvc-abi/`.

## Demo

<br/>

[![Test Application]](https://github.com/user-attachments/assets/760cbb7e-62c0-47e4-a7ce-65bccbe8275e)

## Add FFmpegKitNext to a Windows App

This assumes the Windows headers, import libraries, DLLs and package files already exist in a local bundle such as:

```text
<path-to-ffmpeg-kit-next>/prebuilt/bundle-windows/ffmpeg-kit-next
```

### MinGW-w64

Point `pkg-config` at the bundle, then consume the package from CMake:

```sh
export PKG_CONFIG_PATH="<path-to-bundle>/lib/pkgconfig:${PKG_CONFIG_PATH}"
```

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG_KIT REQUIRED IMPORTED_TARGET ffmpeg-kit-next=9.0.0)
target_link_libraries(<your-target> PRIVATE PkgConfig::FFMPEG_KIT)
```

### MSVC

Point CMake at the bundle root and use the package config it ships:

```cmake
list(APPEND CMAKE_PREFIX_PATH "<path-to-bundle>")
find_package(ffmpeg-kit-next 9.0.0 REQUIRED CONFIG)
target_link_libraries(<your-target> PRIVATE ffmpeg-kit-next::ffmpegkit)
```

At runtime, copy the bundle's `bin/*.dll` next to your executable or add the bundle `bin` directory to `PATH`.

## Test App Prerequisites

### MinGW-w64

Build from an MSYS2 MinGW shell matching the environment used to build the library (`CLANGARM64` on an `arm64` host).

- `cmake` >= 3.10
- C++ compiler with C++17 support

```bash
pacman -S ${MINGW_PACKAGE_PREFIX}-toolchain ${MINGW_PACKAGE_PREFIX}-cmake ${MINGW_PACKAGE_PREFIX}-pkgconf
```

### MSVC

Build from a plain Windows shell.

- `cmake` > 3.20, the native Windows build
- Visual Studio 2022, or Visual Studio Build Tools 2022 with the **Desktop development with C++** workload

## Run This Test App

`FFMPEG_KIT_BUNDLE_PATH` is the path where the local `ffmpeg-kit-next` Windows bundle exists. Each ABI configures into
its own build directory. Launch through the generated launcher rather than the bare `.exe`; it puts the required DLLs on
`PATH` first.

### MinGW-w64

```shell
cd mingw-abi
mkdir build && cd build
cmake -DFFMPEG_KIT_BUNDLE_PATH=/f/Projects/ffmpeg-kit-next/prebuilt/bundle-windows/ffmpeg-kit-next ..
cmake --build .
cmake --install .
```

Run `./bin/ffmpeg-kit-next-windows-test-app.sh` from the MSYS2 shell, or `bin/ffmpeg-kit-next-windows-test-app.cmd` from
`cmd.exe` or Explorer.

### MSVC

```powershell
cd msvc-abi
mkdir build; cd build
cmake -G "Visual Studio 17 2022" -A x64 -DFFMPEG_KIT_BUNDLE_PATH=F:/Projects/ffmpeg-kit-next/prebuilt/bundle-windows/ffmpeg-kit-next ..
cmake --build . --config Release
cmake --install . --config Release
```

On an `arm64` host use `-A ARM64`. Run `ffmpeg-kit-next-windows-test-app.cmd` from the `bin` directory.

## Test Apps

- `mingw-abi`
- `msvc-abi`

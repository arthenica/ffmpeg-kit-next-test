cmake_minimum_required(VERSION 3.20)
project(ffmpeg-kit-next-windows-test VERSION 9.0.0)

# MSVC ABI build of the Windows test application.
#
# FFmpegKitNext is located through the CMake package config the bundle ships in
# lib/cmake/ffmpeg-kit-next. That is the natural mechanism here: the imported
# target resolves lib/ffmpegkit.lib, the MSVC format import library, which
# link.exe understands. The bundle's pkg-config file cannot be used because its
# "Libs: -L${libdir} -lffmpegkit" line is GNU linker syntax; the MinGW build
# uses it instead, see ../mingw-abi/CMakeLists.txt.
#
# Both builds consume the same bundle and the same DLLs. Only the import library
# and the discovery mechanism differ.
#
# Everything after the discovery below is shared with the MinGW build.

if(NOT MSVC)
    message(FATAL_ERROR "This directory builds the MSVC ABI. Configure with a Visual Studio generator (or clang-cl), or use ../mingw-abi for MinGW-w64.")
endif()

set(FFMPEG_KIT_BUNDLE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/../../ffmpeg-kit-next/prebuilt/bundle-windows/ffmpeg-kit-next"
    CACHE PATH "Path to the ffmpeg-kit Windows bundle")

# Windows keeps the import libraries in lib and the runtime DLLs in bin. The
# loader searches PATH for the DLLs, so bin is what the launcher prepends.
set(FFMPEG_KIT_BINARY_PATH "${FFMPEG_KIT_BUNDLE_PATH}/bin")

# find_package searches <prefix>/lib/cmake/<name> among other places, so the
# bundle root is the right prefix to hand it.
list(APPEND CMAKE_PREFIX_PATH "${FFMPEG_KIT_BUNDLE_PATH}")
find_package(ffmpeg-kit-next 9.0.0 REQUIRED CONFIG)

set(FFMPEG_KIT_TARGET ffmpeg-kit-next::ffmpegkit)

# MSVC links the C++ runtime the app is built against from the Visual C++
# redistributable, which is installed system wide rather than living in a
# prefix the launcher could add to PATH. Nothing extra to prepend.
set(EXTRA_RUNTIME_BIN "")

include(${CMAKE_CURRENT_SOURCE_DIR}/../common.cmake)

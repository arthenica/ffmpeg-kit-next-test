# 3.10 rather than 3.7: common.cmake pins CMAKE_CXX_STANDARD to 17, which CMake
# only understands from 3.8 onwards.
cmake_minimum_required(VERSION 3.10)
project(ffmpeg-kit-next-windows-test VERSION 8.1.1)

# MinGW-w64 build of the Windows test application.
#
# FFmpegKitNext is located through its pkg-config file. That is the natural
# mechanism here: the .pc file declares "Libs: -L${libdir} -lffmpegkit", which is
# GNU linker syntax, and -lffmpegkit resolves lib/libffmpegkit.dll.a. The MSVC
# build cannot use it for exactly that reason and uses the CMake package config
# instead, see ../msvc-abi/CMakeLists.txt.
#
# Everything after the discovery below is shared with the MSVC build.

if(MSVC)
    message(FATAL_ERROR "This directory builds the MinGW-w64 ABI. Configure ../msvc-abi with a Visual Studio or clang-cl toolchain instead.")
endif()

set(FFMPEG_KIT_BUNDLE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/../../ffmpeg-kit-next/prebuilt/bundle-windows/ffmpeg-kit-next"
    CACHE PATH "Path to the ffmpeg-kit Windows bundle")

# Windows keeps the import libraries (.dll.a) in lib and the runtime DLLs in bin.
# The loader searches PATH for the DLLs, so bin is what the launchers prepend.
set(FFMPEG_KIT_BINARY_PATH "${FFMPEG_KIT_BUNDLE_PATH}/bin")
set(FFMPEG_KIT_PKG_CONFIG_PATH "${FFMPEG_KIT_BUNDLE_PATH}/lib/pkgconfig")

# The pkgconf that CMake finds under clangarm64/mingw64/ucrt64 is a NATIVE
# Windows binary. It does not understand the MSYS2 "/home", "/f", ... mounts: a
# leading "/" is resolved against the current drive root, so a POSIX pkgconfig
# path silently points at the wrong place and the package is "not found". The
# library build writes the .pc prefix in native form (cygpath -m); the search
# path has to be given in the same form. Convert it here.
#
# Native paths carry drive letters, so ";" -- not ":" -- separates entries.
find_program(CYGPATH_FOR_PKGCONFIG cygpath)
if(CYGPATH_FOR_PKGCONFIG)
    execute_process(COMMAND "${CYGPATH_FOR_PKGCONFIG}" -m "${FFMPEG_KIT_PKG_CONFIG_PATH}"
                    OUTPUT_VARIABLE FFMPEG_KIT_PKG_CONFIG_PATH_NATIVE
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
else()
    set(FFMPEG_KIT_PKG_CONFIG_PATH_NATIVE "${FFMPEG_KIT_PKG_CONFIG_PATH}")
endif()

if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
    set(ENV{PKG_CONFIG_PATH} "${FFMPEG_KIT_PKG_CONFIG_PATH_NATIVE};$ENV{PKG_CONFIG_PATH}")
else()
    set(ENV{PKG_CONFIG_PATH} "${FFMPEG_KIT_PKG_CONFIG_PATH_NATIVE}")
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG_KIT REQUIRED IMPORTED_TARGET ffmpeg-kit-next=8.1.1)

set(FFMPEG_KIT_TARGET PkgConfig::FFMPEG_KIT)

# MINGW_PREFIX is exported by every MSYS2 MinGW shell (/clangarm64, /mingw64, ...).
# Its bin directory holds the compiler runtime DLLs the app is linked against
# (libwinpthread, and libc++/libunwind or libstdc++/libgcc depending on the
# environment), so the generated launcher puts it on PATH.
if(DEFINED ENV{MINGW_PREFIX} AND NOT "$ENV{MINGW_PREFIX}" STREQUAL "")
    set(EXTRA_RUNTIME_BIN "$ENV{MINGW_PREFIX}/bin")
else()
    message(WARNING "MINGW_PREFIX is not set. Configure from an MSYS2 MinGW shell, otherwise the generated .cmd launcher will not find the compiler runtime DLLs.")
    set(EXTRA_RUNTIME_BIN "")
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/../common.cmake)

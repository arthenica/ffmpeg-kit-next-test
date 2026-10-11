cmake_minimum_required(VERSION 3.22.1)

project("native-test" LANGUAGES C)

# Provided by the ffmpeg-kit-next AAR through its prefab payload.
# Requires the AAR to publish a prefab package named "ffmpeg-kit-next"
# exposing (at least) the modules linked below. AGP adds the AAR's prefab
# directory to CMAKE_FIND_ROOT_PATH when android.buildFeatures.prefab = true,
# so no explicit path is needed here.
find_package(ffmpeg-kit-next REQUIRED CONFIG)

add_library(native-test SHARED native-test.c)

# Align both load segments and the RELRO boundary on 64-bit Android devices.
if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "x86_64")
    target_link_options(native-test PRIVATE
            "-Wl,-z,max-page-size=16384"
            "-Wl,-z,common-page-size=16384")
endif()

find_library(log-lib log)

target_link_libraries(native-test
        ffmpeg-kit-next::avformat
        ffmpeg-kit-next::avcodec
        ffmpeg-kit-next::avfilter
        ffmpeg-kit-next::avdevice
        ffmpeg-kit-next::avutil
        ${log-lib})

cmake_minimum_required(VERSION 3.7)
project(ffmpeg-kit-next-linux-test VERSION 6.1.1)

include(CTest)
enable_testing()

set(FFMPEG_KIT_BUNDLE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/../../ffmpeg-kit-next/prebuilt/bundle-linux/ffmpeg-kit-next"
    CACHE PATH "Path to the ffmpeg-kit Linux bundle")
set(FFMPEG_KIT_LIBRARY_PATH "${FFMPEG_KIT_BUNDLE_PATH}/lib")
set(FFMPEG_KIT_PKG_CONFIG_PATH "${FFMPEG_KIT_BUNDLE_PATH}/pkgconfig")

if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
    set(ENV{PKG_CONFIG_PATH} "${FFMPEG_KIT_PKG_CONFIG_PATH}:$ENV{PKG_CONFIG_PATH}")
else()
    set(ENV{PKG_CONFIG_PATH} "${FFMPEG_KIT_PKG_CONFIG_PATH}")
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG_KIT REQUIRED IMPORTED_TARGET ffmpeg-kit-next=6.1.1)
pkg_check_modules(GTKMM REQUIRED IMPORTED_TARGET gtkmm-3.0>=3.0)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/data/ffmpeg-kit-next-linux-test-app.sh.in ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-linux-test-app.sh @ONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/data/com.arthenica.ffmpegkitnext.test.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/data/com.arthenica.ffmpegkitnext.test.desktop @ONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/src/Application.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/Application.h @ONLY)

list(APPEND APP_SOURCES
    "src/Application.cpp"
    "src/Application.h"
    "src/AudioTab.cpp"
    "src/AudioTab.h"
    "src/CommandTab.cpp"
    "src/CommandTab.h"
    "src/Constants.h"
    "src/ConcurrentExecutionTab.cpp"
    "src/ConcurrentExecutionTab.h"
    "src/FFKitProtocolsTab.cpp"
    "src/FFKitProtocolsTab.h"
    "src/FFmpegKitTest.cpp"
    "src/FFmpegKitTest.h"
    "src/HttpsTab.cpp"
    "src/HttpsTab.h"
    "src/main.cpp"
    "src/MediaInformationParserTest.cpp"
    "src/MediaInformationParserTest.h"
    "src/OtherTab.cpp"
    "src/OtherTab.h"
    "src/PipeTab.cpp"
    "src/PipeTab.h"
    "src/Popup.cpp"
    "src/Popup.h"
    "src/ProgressDialog.cpp"
    "src/ProgressDialog.h"
    "src/SubtitleTab.cpp"
    "src/SubtitleTab.h"
    "src/Util.cpp"
    "src/Util.h"
    "src/Video.cpp"
    "src/Video.h"
    "src/VideoTab.cpp"
    "src/VideoTab.h"
    "src/VidStabTab.cpp"
    "src/VidStabTab.h"
)

add_executable(ffmpeg-kit-next-linux-test ${APP_SOURCES})
set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "ffmpeg-kit-next-linux-test-app")
target_link_libraries(${PROJECT_NAME} PUBLIC PkgConfig::FFMPEG_KIT)
target_link_libraries(${PROJECT_NAME} PUBLIC PkgConfig::GTKMM)
target_link_libraries(${PROJECT_NAME} PUBLIC pthread)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)

install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)
install (DIRECTORY data/fonts DESTINATION share)
install (DIRECTORY data/icons DESTINATION share)
install (DIRECTORY data/images DESTINATION share)
install (DIRECTORY data/subtitles DESTINATION share)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-linux-test-app.sh DESTINATION bin PERMISSIONS OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_WRITE WORLD_READ)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/data/com.arthenica.ffmpegkitnext.test.desktop DESTINATION share/applications)

# uninstall target (CMake does not provide one out of the box)
if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

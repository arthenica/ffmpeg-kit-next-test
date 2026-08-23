# Shared definition of the Windows test application.
#
# The two ABI directories (mingw-abi, msvc-abi) each locate FFmpegKitNext in the
# way that is native to their toolchain and then include this file. Everything
# below is toolchain neutral so that the two builds cannot drift apart: they
# compile the same sources, embed the same resources and install the same data.
#
# Each includer must set, before including:
#
#   FFMPEG_KIT_TARGET        the imported target to link against
#   FFMPEG_KIT_BINARY_PATH   the bundle bin directory holding the runtime DLLs
#
# and may set:
#
#   EXTRA_RUNTIME_BIN        a directory holding compiler runtime DLLs, added to
#                            PATH by the generated launcher. Empty when the
#                            toolchain has no redistributable of its own.

if(NOT DEFINED FFMPEG_KIT_TARGET)
    message(FATAL_ERROR "FFMPEG_KIT_TARGET must be set before including common.cmake")
endif()
if(NOT DEFINED FFMPEG_KIT_BINARY_PATH)
    message(FATAL_ERROR "FFMPEG_KIT_BINARY_PATH must be set before including common.cmake")
endif()

# Resolved once here rather than in each includer, so that every path below is
# absolute and independent of which ABI directory CMake was pointed at.
set(APP_ROOT "${CMAKE_CURRENT_LIST_DIR}")
set(APP_SOURCE_DIR "${APP_ROOT}/src")
set(APP_DATA_DIR "${APP_ROOT}/data")

include(CTest)
enable_testing()

if(NOT WIN32)
    message(FATAL_ERROR "This test application targets Windows.")
endif()

# The resource script embeds the application manifest and the icon. Handled by
# windres under MinGW-w64 and by rc.exe under MSVC; CMake picks the right one.
enable_language(RC)

# Pinned rather than left to the compiler default. GCC 11+ defaults to gnu++17
# while MSVC defaults to C++14, and an unpinned standard would mean the two ABI
# builds compile the same sources under different language rules.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The two launchers need the same directories in different forms: the .cmd runs
# under cmd.exe and needs native Windows paths, the .sh runs under the MSYS2
# shell and needs POSIX paths. cygpath is the only reliable converter, so ask it
# for both rather than guessing from the value CMake was given. Outside MSYS2
# (an MSVC build from a plain Windows shell) cygpath does not exist and there is
# no POSIX form to produce, so fall back to CMake's own conversion.
find_program(CYGPATH_EXECUTABLE cygpath)

function(ffmpegkit_path_forms INPUT_PATH NATIVE_VARIABLE POSIX_VARIABLE)
    if(CYGPATH_EXECUTABLE)
        execute_process(COMMAND "${CYGPATH_EXECUTABLE}" -w "${INPUT_PATH}"
                        OUTPUT_VARIABLE NATIVE_FORM OUTPUT_STRIP_TRAILING_WHITESPACE)
        execute_process(COMMAND "${CYGPATH_EXECUTABLE}" -u "${INPUT_PATH}"
                        OUTPUT_VARIABLE POSIX_FORM OUTPUT_STRIP_TRAILING_WHITESPACE)
    else()
        file(TO_NATIVE_PATH "${INPUT_PATH}" NATIVE_FORM)
        set(POSIX_FORM "${INPUT_PATH}")
    endif()
    set(${NATIVE_VARIABLE} "${NATIVE_FORM}" PARENT_SCOPE)
    set(${POSIX_VARIABLE} "${POSIX_FORM}" PARENT_SCOPE)
endfunction()

ffmpegkit_path_forms("${FFMPEG_KIT_BINARY_PATH}" FFMPEG_KIT_BINARY_PATH_NATIVE FFMPEG_KIT_BINARY_PATH_POSIX)

if(DEFINED EXTRA_RUNTIME_BIN AND NOT "${EXTRA_RUNTIME_BIN}" STREQUAL "")
    ffmpegkit_path_forms("${EXTRA_RUNTIME_BIN}" EXTRA_RUNTIME_BIN_NATIVE EXTRA_RUNTIME_BIN_POSIX)
else()
    set(EXTRA_RUNTIME_BIN_NATIVE "")
    set(EXTRA_RUNTIME_BIN_POSIX "")
endif()

configure_file(${APP_DATA_DIR}/ffmpeg-kit-next-windows-test-app.cmd.in
               ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-windows-test-app.cmd @ONLY)

# The .sh launcher only makes sense from an MSYS2 shell, which is also the only
# place a POSIX form of the bundle path exists.
if(CYGPATH_EXECUTABLE)
    configure_file(${APP_DATA_DIR}/ffmpeg-kit-next-windows-test-app.sh.in
                   ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-windows-test-app.sh @ONLY)
endif()

# Generated into the build tree rather than next to the sources. The two ABI
# builds configure this header with different install prefixes, and a single
# copy inside src/ would mean whichever configured last wins for both.
configure_file(${APP_SOURCE_DIR}/Application.h.in
               ${CMAKE_CURRENT_BINARY_DIR}/generated/Application.h @ONLY)

list(APPEND APP_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/generated/Application.h"
    "${APP_SOURCE_DIR}/Application.cpp"
    "${APP_SOURCE_DIR}/AudioTab.cpp"
    "${APP_SOURCE_DIR}/AudioTab.h"
    "${APP_SOURCE_DIR}/CommandTab.cpp"
    "${APP_SOURCE_DIR}/CommandTab.h"
    "${APP_SOURCE_DIR}/Constants.h"
    "${APP_SOURCE_DIR}/ConcurrentExecutionTab.cpp"
    "${APP_SOURCE_DIR}/ConcurrentExecutionTab.h"
    "${APP_SOURCE_DIR}/FFKitProtocolsTab.cpp"
    "${APP_SOURCE_DIR}/FFKitProtocolsTab.h"
    "${APP_SOURCE_DIR}/FFmpegKitTest.cpp"
    "${APP_SOURCE_DIR}/FFmpegKitTest.h"
    "${APP_SOURCE_DIR}/HttpsTab.cpp"
    "${APP_SOURCE_DIR}/HttpsTab.h"
    "${APP_SOURCE_DIR}/main.cpp"
    "${APP_SOURCE_DIR}/MediaInformationParserTest.cpp"
    "${APP_SOURCE_DIR}/MediaInformationParserTest.h"
    "${APP_SOURCE_DIR}/OtherTab.cpp"
    "${APP_SOURCE_DIR}/OtherTab.h"
    "${APP_SOURCE_DIR}/Popup.cpp"
    "${APP_SOURCE_DIR}/Popup.h"
    "${APP_SOURCE_DIR}/ProgressDialog.cpp"
    "${APP_SOURCE_DIR}/ProgressDialog.h"
    "${APP_SOURCE_DIR}/resource.rc"
    "${APP_SOURCE_DIR}/SubtitleTab.cpp"
    "${APP_SOURCE_DIR}/SubtitleTab.h"
    "${APP_SOURCE_DIR}/Tab.cpp"
    "${APP_SOURCE_DIR}/Tab.h"
    "${APP_SOURCE_DIR}/Theme.h"
    "${APP_SOURCE_DIR}/Util.cpp"
    "${APP_SOURCE_DIR}/Util.h"
    "${APP_SOURCE_DIR}/Video.cpp"
    "${APP_SOURCE_DIR}/Video.h"
    "${APP_SOURCE_DIR}/VideoTab.cpp"
    "${APP_SOURCE_DIR}/VideoTab.h"
    "${APP_SOURCE_DIR}/VidStabTab.cpp"
    "${APP_SOURCE_DIR}/VidStabTab.h"
    "${APP_SOURCE_DIR}/Win32Ui.cpp"
    "${APP_SOURCE_DIR}/Win32Ui.h"
)

# Deliberately NOT a WIN32 (GUI subsystem) executable. Every tab reports progress
# on stdout and the unit tests run on the console before the window opens, so the
# app is built for the console subsystem to keep that output visible.
add_executable(${PROJECT_NAME} ${APP_SOURCES})
# Emit the exe into the same bin/ directory as the generated launchers. The
# launchers start "%~dp0<exe>" / "./<exe>", i.e. they expect the exe next to
# themselves. That is the install layout; matching it in the build tree too lets
# the launcher run straight from build/bin without installing first.
set_target_properties(${PROJECT_NAME} PROPERTIES
    OUTPUT_NAME "ffmpeg-kit-next-windows-test-app"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")

# Multi-config generators append the configuration name to
# RUNTIME_OUTPUT_DIRECTORY, which would put the exe in bin/Release while the
# launchers sit in bin. Pinning the per-config directories keeps the exe next to
# them, matching the install layout and the single-config generators MinGW uses.
# CMAKE_CONFIGURATION_TYPES is empty on those, so this is a no-op there.
foreach(_config ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER "${_config}" _config_upper)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY_${_config_upper} "${CMAKE_CURRENT_BINARY_DIR}/bin")
endforeach()
unset(_config_upper)

# src for the hand written headers, generated for Application.h.
target_include_directories(${PROJECT_NAME} PRIVATE
    "${APP_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/generated")

target_link_libraries(${PROJECT_NAME} PRIVATE ${FFMPEG_KIT_TARGET})

# The application calls the wide (...W) Win32 API exclusively and passes resource
# macros such as IDC_ARROW to it. Those macros (MAKEINTRESOURCE) resolve to the
# ANSI form unless UNICODE is defined, which then fails to match the LPCWSTR the
# W functions expect. _UNICODE does the same for the C runtime's TCHAR mapping.
# Neither MinGW-w64 nor a command-line MSVC build defines these by default, so set
# them for every toolchain.
target_compile_definitions(${PROJECT_NAME} PRIVATE UNICODE _UNICODE)

# comctl32 provides the tab control, comdlg32 the open dialog, shell32
# ShellExecuteW and SHGetKnownFolderPath, ole32 CoTaskMemFree, gdi32 the font.
target_link_libraries(${PROJECT_NAME} PRIVATE comctl32 comdlg32 shell32 ole32 gdi32 user32)

if(MSVC)
    # The sources are UTF-8 without a BOM. Without /utf-8 MSVC reads them in the
    # active code page, which is not UTF-8 on most machines.
    target_compile_options(${PROJECT_NAME} PRIVATE /utf-8)
    # The app calls the portable C library (fopen, sscanf) that MSVC deprecates
    # in favour of its _s variants. The warnings are noise here.
    target_compile_definitions(${PROJECT_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
    # resource.rc already embeds data/app.manifest as RT_MANIFEST id 1, and
    # link.exe embeds a generated one at the same id unless told not to. The
    # duplicate makes cvtres fail with CVT1100. MinGW's ld generates none of its
    # own, so only MSVC needs this and both ABIs keep the same manifest.
    target_link_options(${PROJECT_NAME} PRIVATE /MANIFEST:NO)
else()
    # MinGW-w64 needs winpthread for the std::thread/std::mutex machinery that
    # libstdc++ and libc++ are built against. MSVC has no equivalent.
    target_link_libraries(${PROJECT_NAME} PRIVATE pthread)
endif()

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)

install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION bin)
install(DIRECTORY ${APP_DATA_DIR}/cacert DESTINATION share)
install(DIRECTORY ${APP_DATA_DIR}/fonts DESTINATION share)
install(DIRECTORY ${APP_DATA_DIR}/icons DESTINATION share)
install(DIRECTORY ${APP_DATA_DIR}/images DESTINATION share)
install(DIRECTORY ${APP_DATA_DIR}/subtitles DESTINATION share)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-windows-test-app.cmd DESTINATION bin)
if(CYGPATH_EXECUTABLE)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/bin/ffmpeg-kit-next-windows-test-app.sh DESTINATION bin
            PERMISSIONS OWNER_WRITE OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_WRITE WORLD_READ)
endif()

# Install the FFmpegKitNext runtime DLLs next to the executable. Windows resolves
# a DLL from the executable's own directory first, so an installed app runs
# without the bundle bin directory being on PATH.
install(DIRECTORY ${FFMPEG_KIT_BINARY_PATH}/ DESTINATION bin FILES_MATCHING PATTERN "*.dll")

# uninstall target (CMake does not provide one out of the box)
if(NOT TARGET uninstall)
    configure_file(
        "${APP_ROOT}/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

/*
 * Copyright (c) 2022, 2026 Taner Sener
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef FFMPEG_KIT_TEST_UTIL_H
#define FFMPEG_KIT_TEST_UTIL_H

#include <string>
#include <windows.h>

namespace ffmpegkittest {

    class Util {
        public:
            /**
             * Normalizes a Windows path for use as a plain FFmpeg argument.
             *
             * Windows APIs hand back backslash separated paths (SHGetKnownFolderPath
             * returns C:\Users\...\AppData\Local). FFmpeg accepts forward slashes on
             * Windows and they survive every layer in between without escaping, so
             * every path is converted once here rather than at each use.
             *
             * The drive letter colon needs NO escaping in this position: FFmpeg's
             * url_find_protocol() recognises a DOS path and does not mistake "C:" for
             * a protocol name.
             */
            static std::string toCommandPath(const std::string& path);

            /**
             * Escapes a Windows path for use INSIDE a filter graph option value, such
             * as subtitles=filename=... or drawtext=fontfile=...
             *
             * libavfilter splits filter options on ':', so an unescaped drive letter
             * colon makes it read the value as "C" and treat the rest of the path as
             * unknown options. Surrounding the value in single quotes does not help:
             * FFmpegKitConfig::parseArguments() consumes unescaped quotes before the
             * string ever reaches libavfilter.
             */
            static std::string toFilterPath(const std::string& path);

            /**
             * Opens a file with whatever application Windows has registered for it,
             * in an external window.
             *
             * This app has no embedded player. Handing the file to the shell keeps
             * the FFmpegKitNext DLLs the only media stack in the process: an embedded
             * player would either pull in a second FFmpeg (GStreamer, mpv) whose
             * decoders say nothing about whether this build works, or an HWND video
             * overlay layered over the tab page.
             *
             * Returns false when no application could be launched. The caller is
             * expected to tell the user where the file is in that case.
             */
            static bool openInSystemPlayer(const std::string& path, HWND parentWindow);

            /**
             * Shows the standard open dialog filtered to images and reads the chosen
             * file. Returns false when the user cancels or the file cannot be read.
             */
            static bool chooseImageFile(HWND parentWindow, std::string& outPath);
    };

}

#endif // FFMPEG_KIT_TEST_UTIL_H

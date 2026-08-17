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

#include "Util.h"
#include "Win32Ui.h"

#include <algorithm>
#include <commdlg.h>
#include <iostream>
#include <shellapi.h>

std::string ffmpegkittest::Util::toCommandPath(const std::string& path) {
    std::string commandPath = path;
    std::replace(commandPath.begin(), commandPath.end(), '\\', '/');
    return commandPath;
}

std::string ffmpegkittest::Util::toFilterPath(const std::string& path) {
    const std::string commandPath = toCommandPath(path);

    std::string filterPath;
    filterPath.reserve(commandPath.size() + 4);

    for (const char character : commandPath) {
        if (character == ':') {
            // A path used inside a filter option value (e.g. subtitles=filename=,
            // drawtext=fontfile=, vidstabdetect=result=) passes through two
            // avfilter unescaping passes: once for the filtergraph description and
            // once for the per-filter option list. Each pass consumes one
            // backslash, so the drive-letter colon needs two backslashes ("C\\:")
            // to leave a literal colon in the final value. A single backslash is
            // swallowed by the filtergraph pass, and the bare colon then splits
            // the value ("No option name near ...").
            filterPath += "\\\\";
        }
        filterPath += character;
    }

    return filterPath;
}

bool ffmpegkittest::Util::openInSystemPlayer(const std::string& path, HWND parentWindow) {
    // ShellExecuteW resolves the registered handler straight from the registry.
    // Its success codes are the historical "greater than 32" convention.
    const std::wstring widePath = ffmpegkittest::ui::toWide(path);
    const HINSTANCE result = ShellExecuteW(parentWindow, L"open", widePath.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
    const INT_PTR code = reinterpret_cast<INT_PTR>(result);

    if (code <= 32) {
        std::cout << "Failed to open " << path << " in the system player. ShellExecute returned " << code << "." << std::endl;
        return false;
    }

    std::cout << "Opened " << path << " in the system player." << std::endl;
    return true;
}

bool ffmpegkittest::Util::chooseImageFile(HWND parentWindow, std::string& outPath) {
    wchar_t fileName[MAX_PATH];
    fileName[0] = L'\0';

    OPENFILENAMEW openFileName;
    ZeroMemory(&openFileName, sizeof(openFileName));
    openFileName.lStructSize = sizeof(openFileName);
    openFileName.hwndOwner = parentWindow;
    openFileName.lpstrFilter = L"Images\0*.jpg;*.jpeg;*.png\0All Files\0*.*\0";
    openFileName.lpstrFile = fileName;
    openFileName.nMaxFile = MAX_PATH;
    openFileName.lpstrTitle = L"Select an image";
    openFileName.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;

    if (!GetOpenFileNameW(&openFileName)) {
        return false;
    }

    outPath = ffmpegkittest::ui::toUtf8(fileName);
    return true;
}

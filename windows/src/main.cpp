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

#include "Application.h"
#include "FFmpegKitTest.h"
#include "MediaInformationParserTest.h"

#include <FFmpegKitConfig.h>

#include <clocale>
#include <commctrl.h>
#include <iostream>
#include <objbase.h>
#include <windows.h>

/*
 * Built for the console subsystem rather than the GUI subsystem, so main() is
 * the entry point rather than WinMain(). Every tab reports progress on stdout
 * and the unit tests below run before the window opens, so keeping a console
 * attached is what makes those readable.
 */
int main(int argc, char** argv) {
    // Required before creating the tab control, and what activates the version 6
    // common controls the application manifest requests.
    INITCOMMONCONTROLSEX controls;
    controls.dwSize = sizeof(controls);
    controls.dwICC = ICC_TAB_CLASSES | ICC_STANDARD_CLASSES | ICC_PROGRESS_CLASS;
    InitCommonControlsEx(&controls);

    // SHGetKnownFolderPath and the shell open dialog both need COM on this thread.
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // FFmpeg parses numbers with the C locale.
    setlocale(LC_ALL, "C");

    // RUN UNIT TESTS BEFORE STARTING THE APPLICATION
    testMediaInformationJsonParser();
    testFFmpegKit();

    int exitCode = 1;

    {
        ffmpegkittest::Application application;
        if (application.create()) {
            exitCode = application.run();
        }
    }

    ffmpegkit::FFmpegKitConfig::disableRedirection();
    CoUninitialize();
    return exitCode;
}

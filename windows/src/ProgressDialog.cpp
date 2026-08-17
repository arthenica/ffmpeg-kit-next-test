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

#include "ProgressDialog.h"

#include <commctrl.h>

namespace {

    const wchar_t* ProgressDialogClassName = L"FFmpegKitNextTestProgressDialog";
    bool windowClassRegistered = false;

    // The client size and content border the Linux dialog asks for, so the two
    // apps put up a window of the same shape.
    constexpr int DialogWidth = 300;
    constexpr int DialogHeight = 60;
    constexpr int ContentMargin = 10;
    constexpr int ProgressBarHeight = 20;

    constexpr int ProgressMinimum = 0;
    constexpr int ProgressMaximum = 100;
}

ffmpegkittest::ProgressDialog::~ProgressDialog() {
    hide();
}

void ffmpegkittest::ProgressDialog::registerWindowClass() {
    if (windowClassRegistered) {
        return;
    }

    WNDCLASSEXW windowClass;
    ZeroMemory(&windowClass, sizeof(windowClass));
    windowClass.cbSize = sizeof(windowClass);
    windowClass.lpfnWndProc = &ProgressDialog::windowProcedure;
    windowClass.hInstance = GetModuleHandleW(nullptr);
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE + 1);
    windowClass.lpszClassName = ProgressDialogClassName;

    RegisterClassExW(&windowClass);
    windowClassRegistered = true;
}

void ffmpegkittest::ProgressDialog::show(HWND parentWindow) {
    if (hwnd != nullptr) {
        return;
    }

    registerWindowClass();

    // WS_CAPTION without WS_SYSMENU gives a title bar with no close button. The
    // window belongs to the session that opened it, so there is nothing sensible
    // for the user to close it with.
    const DWORD style = WS_POPUP | WS_CAPTION;
    const DWORD exStyle = WS_EX_DLGMODALFRAME;

    RECT bounds = {0, 0, DialogWidth, DialogHeight};
    AdjustWindowRectEx(&bounds, style, FALSE, exStyle);
    const int width = bounds.right - bounds.left;
    const int height = bounds.bottom - bounds.top;

    int left = CW_USEDEFAULT;
    int top = CW_USEDEFAULT;
    RECT parentBounds;
    if (parentWindow != nullptr && GetWindowRect(parentWindow, &parentBounds)) {
        left = parentBounds.left + (((parentBounds.right - parentBounds.left) - width) / 2);
        top = parentBounds.top + (((parentBounds.bottom - parentBounds.top) - height) / 2);
    }

    // Passing the parent as the owner keeps this window above the application
    // and out of the taskbar without disabling anything.
    hwnd = CreateWindowExW(exStyle, ProgressDialogClassName, L"", style,
                           left, top, width, height,
                           parentWindow, nullptr, GetModuleHandleW(nullptr), nullptr);

    if (hwnd == nullptr) {
        return;
    }

    progressBar = CreateWindowExW(
        0, PROGRESS_CLASS, nullptr, WS_CHILD | WS_VISIBLE,
        ContentMargin, (DialogHeight - ProgressBarHeight) / 2,
        DialogWidth - (ContentMargin * 2), ProgressBarHeight,
        hwnd, nullptr, GetModuleHandleW(nullptr), nullptr);

    if (progressBar != nullptr) {
        SendMessageW(progressBar, PBM_SETRANGE32, static_cast<WPARAM>(ProgressMinimum),
                     static_cast<LPARAM>(ProgressMaximum));
        SendMessageW(progressBar, PBM_SETPOS, static_cast<WPARAM>(ProgressMinimum), 0);
    }

    ShowWindow(hwnd, SW_SHOWNORMAL);
    UpdateWindow(hwnd);
}

void ffmpegkittest::ProgressDialog::update(double percentage) {
    if (progressBar == nullptr) {
        return;
    }

    // The callers report how far through the session they are as a percentage,
    // which is what the bar's range was set to.
    int position = static_cast<int>(percentage + 0.5);
    if (position < ProgressMinimum) {
        position = ProgressMinimum;
    } else if (position > ProgressMaximum) {
        position = ProgressMaximum;
    }

    SendMessageW(progressBar, PBM_SETPOS, static_cast<WPARAM>(position), 0);
}

void ffmpegkittest::ProgressDialog::hide() {
    if (hwnd == nullptr) {
        return;
    }

    // Windows destroys an owned window along with its owner, so by the time the
    // destructor runs at shutdown the handle may already be gone.
    if (IsWindow(hwnd)) {
        // Destroying the owner takes the child with it, so the bar handle is
        // only cleared rather than destroyed separately.
        DestroyWindow(hwnd);
    }

    hwnd = nullptr;
    progressBar = nullptr;
}

LRESULT CALLBACK ffmpegkittest::ProgressDialog::windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_CLOSE:
        // Swallowed so that Alt+F4 cannot leave a session running with no window
        // reporting it. The dialog closes when the session that opened it ends.
        return 0;

    default:
        break;
    }

    return DefWindowProcW(window, message, wParam, lParam);
}

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

#include "Tab.h"
#include "Theme.h"
#include "Win32Ui.h"

namespace {
    const wchar_t* TabWindowClassName = L"FFmpegKitNextTestTab";
    bool windowClassRegistered = false;

    /** Cached for the process lifetime, the same way ui::defaultFont() is. */
    HBRUSH outputBackgroundBrush() {
        static HBRUSH brush = CreateSolidBrush(ffmpegkittest::theme::OutputBackground);
        return brush;
    }

    HBRUSH editBackgroundBrush() {
        static HBRUSH brush = CreateSolidBrush(ffmpegkittest::theme::EditBackground);
        return brush;
    }

    /** True for both the editable fields and the read-only output panes. */
    bool isEditControl(HWND control) {
        wchar_t className[8];
        if (GetClassNameW(control, className, ARRAYSIZE(className)) == 0) {
            return false;
        }
        return lstrcmpiW(className, L"Edit") == 0;
    }

    /**
     * True for the read-only multi-line edits ui::createOutput() builds.
     *
     * A read-only edit sends WM_CTLCOLORSTATIC rather than WM_CTLCOLOREDIT, so
     * the output panes and the labels arrive at the same handler and have to be
     * told apart before they can be coloured differently. The style is checked
     * instead of the control id because every tab numbers its own controls.
     */
    bool isOutputPane(HWND control) {
        if (!isEditControl(control)) {
            return false;
        }

        const LONG style = static_cast<LONG>(GetWindowLongPtrW(control, GWL_STYLE));
        return (style & ES_MULTILINE) != 0 && (style & ES_READONLY) != 0;
    }

    /**
     * The palette border colour of an edit control, if it takes one.
     *
     * The edits dropped WS_EX_CLIENTEDGE so that the orange and blue borders the
     * other test apps draw could replace the themed sunken edge.
     */
    bool borderColorFor(HWND control, COLORREF& color) {
        if (!isEditControl(control)) {
            return false;
        }

        color = isOutputPane(control) ? ffmpegkittest::theme::OutputBorder
                                      : ffmpegkittest::theme::EditBorder;
        return true;
    }

    /**
     * Draws the borders around the edit controls of one tab page.
     *
     * The controls no longer own a border, so each frame goes in the one pixel
     * ring just outside the control. That ring belongs to the page rather than
     * the child, so WS_CLIPCHILDREN does not clip it away.
     */
    void paintChildBorders(HWND parent, HDC deviceContext) {
        for (HWND child = GetWindow(parent, GW_CHILD); child != nullptr;
             child = GetWindow(child, GW_HWNDNEXT)) {

            COLORREF color = 0;
            if (!borderColorFor(child, color)) {
                continue;
            }

            RECT bounds;
            GetWindowRect(child, &bounds);
            MapWindowPoints(nullptr, parent, reinterpret_cast<POINT*>(&bounds), 2);
            InflateRect(&bounds, 1, 1);

            HBRUSH brush = CreateSolidBrush(color);
            FrameRect(deviceContext, &bounds, brush);
            DeleteObject(brush);
        }
    }
}

ffmpegkittest::Tab::~Tab() {
}

void ffmpegkittest::Tab::registerWindowClass() {
    if (windowClassRegistered) {
        return;
    }

    WNDCLASSEXW windowClass;
    ZeroMemory(&windowClass, sizeof(windowClass));
    windowClass.cbSize = sizeof(windowClass);

    // The layout centres controls on the page width, so every control moves when
    // the page is resized. Without these the system would only invalidate the
    // strip a resize exposes and leave the moved controls unpainted.
    windowClass.style = CS_HREDRAW | CS_VREDRAW;
    windowClass.lpfnWndProc = &Tab::windowProcedure;
    windowClass.hInstance = GetModuleHandleW(nullptr);
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);

    // COLOR_BTNFACE is the tab page background, so child controls blend into the
    // tab control instead of sitting on a white rectangle.
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE + 1);
    windowClass.lpszClassName = TabWindowClassName;

    RegisterClassExW(&windowClass);
    windowClassRegistered = true;
}

HWND ffmpegkittest::Tab::create(HWND parent) {
    registerWindowClass();

    parentWindow = parent;

    hwnd = CreateWindowExW(
        WS_EX_CONTROLPARENT, TabWindowClassName, L"", WS_CHILD | WS_CLIPCHILDREN,
        0, 0, 0, 0, parent, nullptr, GetModuleHandleW(nullptr), this);

    return hwnd;
}

void ffmpegkittest::Tab::setBounds(const RECT& bounds) {
    if (hwnd == nullptr) {
        return;
    }

    MoveWindow(hwnd, bounds.left, bounds.top,
               bounds.right - bounds.left, bounds.bottom - bounds.top, TRUE);
}

void ffmpegkittest::Tab::setVisible(const bool visible) {
    if (hwnd != nullptr) {
        ShowWindow(hwnd, visible ? SW_SHOW : SW_HIDE);
    }
}

void ffmpegkittest::Tab::post(std::function<void()> work) {
    if (hwnd == nullptr) {
        return;
    }

    auto* heapWork = new std::function<void()>(std::move(work));
    if (!PostMessageW(hwnd, WM_FFKIT_INVOKE, 0, reinterpret_cast<LPARAM>(heapWork))) {
        // The queue is gone; running it here would touch controls from the wrong
        // thread, so the work is dropped rather than executed unsafely.
        delete heapWork;
    }
}

LRESULT CALLBACK ffmpegkittest::Tab::windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    Tab* tab = reinterpret_cast<Tab*>(GetWindowLongPtrW(window, GWLP_USERDATA));

    switch (message) {
    case WM_NCCREATE: {
        auto* createStruct = reinterpret_cast<CREATESTRUCTW*>(lParam);
        tab = static_cast<Tab*>(createStruct->lpCreateParams);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(tab));
        if (tab != nullptr) {
            tab->hwnd = window;
        }
        break;
    }

    case WM_CREATE:
        if (tab != nullptr) {
            tab->onCreate();
        }
        return 0;

    case WM_SIZE:
        if (tab != nullptr) {
            tab->onLayout(LOWORD(lParam), HIWORD(lParam));

            // The borders are painted around where the controls used to be, so
            // the page is repainted once they have been moved.
            //
            // RDW_ALLCHILDREN matters as much as the invalidation itself:
            // InvalidateRect stops at this window and never reaches the
            // controls. The owner drawn buttons paint only through WM_DRAWITEM
            // and the edits gave up WS_EX_CLIENTEDGE, so neither has any
            // painting of its own to fall back on, and both would stay blank
            // after a resize until something else, such as the mouse passing
            // over them, invalidated them.
            RedrawWindow(window, nullptr, nullptr,
                         RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);
        }
        return 0;

    case WM_COMMAND:
        if (tab != nullptr) {
            tab->onCommand(LOWORD(wParam), HIWORD(wParam));
        }
        return 0;

    case WM_FFKIT_INVOKE: {
        auto* heapWork = reinterpret_cast<std::function<void()>*>(lParam);
        if (heapWork != nullptr) {
            (*heapWork)();
            delete heapWork;
        }
        return 0;
    }

    case WM_PAINT: {
        // The page background arrives from the window class brush by way of
        // WM_ERASEBKGND, so this only adds the borders around the edits.
        PAINTSTRUCT paint;
        HDC deviceContext = BeginPaint(window, &paint);
        paintChildBorders(window, deviceContext);
        EndPaint(window, &paint);
        return 0;
    }

    case WM_DRAWITEM: {
        // Sent to the parent of an owner drawn control, so this one handler
        // paints the buttons and combo boxes of every tab.
        auto* item = reinterpret_cast<DRAWITEMSTRUCT*>(lParam);
        if (item != nullptr && ui::drawOwnerDrawnControl(*item)) {
            return TRUE;
        }
        break;
    }

    case WM_MEASUREITEM: {
        auto* item = reinterpret_cast<MEASUREITEMSTRUCT*>(lParam);
        if (item != nullptr && ui::measureOwnerDrawnControl(*item)) {
            return TRUE;
        }
        break;
    }

    case WM_CTLCOLORSTATIC: {
        auto deviceContext = reinterpret_cast<HDC>(wParam);

        if (isOutputPane(reinterpret_cast<HWND>(lParam))) {
            // The log pane carries the shared yellow panel colour. The brush is
            // returned so the control fills the part of its client area the text
            // does not cover, which is most of it before a run produces output.
            SetBkColor(deviceContext, theme::OutputBackground);
            SetTextColor(deviceContext, theme::OutputText);
            return reinterpret_cast<LRESULT>(outputBackgroundBrush());
        }

        // Labels paint their own background by default, which shows as a grey
        // block against the tab page. Making them transparent keeps the page
        // uniform.
        SetBkMode(deviceContext, TRANSPARENT);
        return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_BTNFACE));
    }

    case WM_CTLCOLOREDIT: {
        // The editable fields. Windows already paints them white under a light
        // theme, so this is mostly about pinning them to the palette the other
        // test apps use rather than letting the system theme decide.
        auto deviceContext = reinterpret_cast<HDC>(wParam);
        SetBkColor(deviceContext, theme::EditBackground);
        SetTextColor(deviceContext, theme::EditText);
        return reinterpret_cast<LRESULT>(editBackgroundBrush());
    }

    default:
        break;
    }

    return DefWindowProcW(window, message, wParam, lParam);
}

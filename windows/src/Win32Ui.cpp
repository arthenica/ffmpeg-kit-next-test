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

#include "Win32Ui.h"
#include "Theme.h"

#include <commctrl.h>

namespace {

    /** The row height of an owner drawn combo box, in the raw pixels the layout works in. */
    constexpr int ComboBoxItemHeight = 20;

    /** Padding between the left edge of a combo box row and its text. */
    constexpr int ComboBoxTextPadding = 8;

    /** Corner radius of a button, matching border-radius: 5px on Linux and 6dp on Android. */
    constexpr int CornerRadius = 5;

    /**
     * Space between the border painted around an edit control and its text.
     *
     * The controls dropped WS_EX_CLIENTEDGE so the palette border could replace
     * the themed sunken edge, and with it went the inset the edge provided.
     */
    constexpr int EditTextMargin = 4;

    void applyEditMargins(HWND control) {
        if (control != nullptr) {
            SendMessageW(control, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN,
                         MAKELPARAM(EditTextMargin, EditTextMargin));
        }
    }

    void fillRectangle(HDC deviceContext, const RECT& bounds, COLORREF color) {
        HBRUSH brush = CreateSolidBrush(color);
        FillRect(deviceContext, &bounds, brush);
        DeleteObject(brush);
    }

    void frameRectangle(HDC deviceContext, const RECT& bounds, COLORREF color) {
        HBRUSH brush = CreateSolidBrush(color);
        FrameRect(deviceContext, &bounds, brush);
        DeleteObject(brush);
    }

    /**
     * Fills and outlines a rounded rectangle in one pass.
     *
     * RoundRect leaves the pixels outside the curve untouched, so the caller has
     * to erase the rectangle first or the square corners of the previous state
     * stay behind when a button is pressed and released.
     */
    void roundedRectangle(HDC deviceContext, const RECT& bounds, COLORREF fill, COLORREF border) {
        HBRUSH brush = CreateSolidBrush(fill);
        HPEN pen = CreatePen(PS_SOLID, 1, border);
        HGDIOBJ previousBrush = SelectObject(deviceContext, brush);
        HGDIOBJ previousPen = SelectObject(deviceContext, pen);

        // The last two arguments are the width and height of the ellipse the
        // corners are cut from, so they are twice the radius that ends up drawn.
        RoundRect(deviceContext, bounds.left, bounds.top, bounds.right, bounds.bottom,
                  CornerRadius * 2, CornerRadius * 2);

        SelectObject(deviceContext, previousBrush);
        SelectObject(deviceContext, previousPen);
        DeleteObject(brush);
        DeleteObject(pen);
    }

    void drawOwnerDrawnButton(const DRAWITEMSTRUCT& item) {
        const bool disabled = (item.itemState & ODS_DISABLED) != 0;
        const bool pressed = (item.itemState & ODS_SELECTED) != 0;

        COLORREF fill = ffmpegkittest::theme::ButtonBackground;
        COLORREF border = ffmpegkittest::theme::ButtonBorder;
        COLORREF captionColor = ffmpegkittest::theme::ButtonText;

        if (disabled) {
            fill = ffmpegkittest::theme::ButtonBackgroundDisabled;
            border = ffmpegkittest::theme::ButtonBorderDisabled;
            captionColor = ffmpegkittest::theme::ButtonTextDisabled;
        } else if (pressed) {
            fill = ffmpegkittest::theme::ButtonBackgroundPressed;
        }

        // Erase to the tab page colour first so the corners the curve leaves out
        // show the page rather than whatever the previous state painted there.
        FillRect(item.hDC, &item.rcItem, GetSysColorBrush(COLOR_BTNFACE));
        roundedRectangle(item.hDC, item.rcItem, fill, border);

        wchar_t caption[128];
        const int length = GetWindowTextW(item.hwndItem, caption, ARRAYSIZE(caption));

        // The font is selected explicitly rather than relying on whatever the
        // system left in the device context.
        HFONT previousFont = static_cast<HFONT>(SelectObject(item.hDC, ffmpegkittest::ui::defaultFont()));
        SetBkMode(item.hDC, TRANSPARENT);
        SetTextColor(item.hDC, captionColor);

        RECT textBounds = item.rcItem;
        DrawTextW(item.hDC, caption, length, &textBounds,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

        SelectObject(item.hDC, previousFont);

        if ((item.itemState & ODS_FOCUS) != 0 && !disabled) {
            RECT focusBounds = item.rcItem;
            InflateRect(&focusBounds, -3, -3);
            DrawFocusRect(item.hDC, &focusBounds);
        }
    }

    void drawOwnerDrawnComboBox(const DRAWITEMSTRUCT& item) {
        // Both the closed face and the rows of the open list arrive here. The
        // drop down arrow is painted by the theme on top of the closed face, so
        // it keeps the system look whatever this draws underneath.
        const bool highlighted = (item.itemState & ODS_SELECTED) != 0;

        fillRectangle(item.hDC, item.rcItem,
                      highlighted ? ffmpegkittest::theme::ComboBoxHighlight
                                  : ffmpegkittest::theme::ComboBoxBackground);

        // Sent with no item while the control is still empty.
        if (item.itemID == static_cast<UINT>(-1)) {
            return;
        }

        const int length = static_cast<int>(SendMessageW(item.hwndItem, CB_GETLBTEXTLEN, item.itemID, 0));
        if (length <= 0) {
            return;
        }

        std::wstring text(static_cast<size_t>(length) + 1, L'\0');
        SendMessageW(item.hwndItem, CB_GETLBTEXT, item.itemID, reinterpret_cast<LPARAM>(&text[0]));

        HFONT previousFont = static_cast<HFONT>(SelectObject(item.hDC, ffmpegkittest::ui::defaultFont()));
        SetBkMode(item.hDC, TRANSPARENT);
        SetTextColor(item.hDC, ffmpegkittest::theme::ComboBoxText);

        RECT textBounds = item.rcItem;
        textBounds.left += ComboBoxTextPadding;
        DrawTextW(item.hDC, text.c_str(), length, &textBounds,
                  DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

        SelectObject(item.hDC, previousFont);

        if ((item.itemState & (ODS_FOCUS | ODS_COMBOBOXEDIT)) == (ODS_FOCUS | ODS_COMBOBOXEDIT)) {
            RECT focusBounds = item.rcItem;
            DrawFocusRect(item.hDC, &focusBounds);
        }
    }


    HWND createControl(HWND parent, const wchar_t* className, const wchar_t* text,
                       DWORD style, DWORD exStyle, int controlId) {
        HWND control = CreateWindowExW(
            exStyle, className, text, WS_CHILD | WS_VISIBLE | style,
            0, 0, 0, 0, parent, reinterpret_cast<HMENU>(static_cast<INT_PTR>(controlId)),
            reinterpret_cast<HINSTANCE>(GetWindowLongPtrW(parent, GWLP_HINSTANCE)), nullptr);

        if (control != nullptr) {
            SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(ffmpegkittest::ui::defaultFont()), TRUE);
        }

        return control;
    }

    /** EDIT controls need CRLF; FFmpeg log messages use bare LF. */
    std::wstring toEditLineEndings(const std::wstring& text) {
        std::wstring converted;
        converted.reserve(text.size());

        for (size_t i = 0; i < text.size(); i++) {
            const wchar_t character = text[i];
            if (character == L'\n' && (i == 0 || text[i - 1] != L'\r')) {
                // Lone '\n' (Unix line ending) -> '\r\n'.
                converted += L"\r\n";
            } else if (character == L'\r' && (i + 1 >= text.size() || text[i + 1] != L'\n')) {
                // Lone '\r' -> '\r\n'. FFmpeg terminates its progress/statistics
                // lines ("frame=... fps=...") with a bare carriage return so they
                // overwrite in place on a terminal. A Win32 EDIT control only
                // breaks a line on '\r\n', so without this every such line would
                // collapse onto one line.
                converted += L"\r\n";
            } else {
                converted += character;
            }
        }

        return converted;
    }
}

HFONT ffmpegkittest::ui::defaultFont() {
    // Cached for the process lifetime. Taken from the current theme rather than
    // hard coded so the app follows the user's font and DPI settings.
    static HFONT font = nullptr;

    if (font == nullptr) {
        NONCLIENTMETRICSW metrics;
        metrics.cbSize = sizeof(metrics);
        if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0)) {
            font = CreateFontIndirectW(&metrics.lfMessageFont);
        }
        if (font == nullptr) {
            font = static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
        }
    }

    return font;
}

HFONT ffmpegkittest::ui::headerFont() {
    // Cached for the process lifetime, like defaultFont(), and derived from it so
    // the header still follows the user's font and DPI settings.
    static HFONT font = nullptr;

    if (font == nullptr) {
        NONCLIENTMETRICSW metrics;
        metrics.cbSize = sizeof(metrics);
        if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0)) {
            LOGFONTW logFont = metrics.lfMessageFont;

            // The web header is 18px against a 15px body. Scaling rather than
            // fixing a point size keeps that relationship whatever the shell
            // font is. lfHeight is negative, so this enlarges it.
            logFont.lfHeight = MulDiv(logFont.lfHeight, 4, 3);
            logFont.lfWeight = FW_SEMIBOLD;
            logFont.lfQuality = CLEARTYPE_NATURAL_QUALITY;
            font = CreateFontIndirectW(&logFont);
        }
        if (font == nullptr) {
            font = defaultFont();
        }
    }

    return font;
}

std::wstring ffmpegkittest::ui::toWide(const std::string& text) {
    if (text.empty()) {
        return std::wstring();
    }

    const int length = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
    if (length <= 0) {
        return std::wstring();
    }

    std::wstring wide(static_cast<size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), &wide[0], length);
    return wide;
}

std::string ffmpegkittest::ui::toUtf8(const std::wstring& text) {
    if (text.empty()) {
        return std::string();
    }

    const int length = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                                           nullptr, 0, nullptr, nullptr);
    if (length <= 0) {
        return std::string();
    }

    std::string utf8(static_cast<size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                        &utf8[0], length, nullptr, nullptr);
    return utf8;
}

HWND ffmpegkittest::ui::createButton(HWND parent, int controlId, const wchar_t* text) {
    // BS_OWNERDRAW rather than BS_PUSHBUTTON: a themed push button paints itself
    // and ignores WM_CTLCOLORBTN, so the shared green is only reachable by
    // drawing the button. It still reports BN_CLICKED and still takes part in
    // tab order, so nothing in the tabs changes.
    return createControl(parent, L"BUTTON", text, BS_OWNERDRAW | WS_TABSTOP, 0, controlId);
}

bool ffmpegkittest::ui::drawOwnerDrawnControl(const DRAWITEMSTRUCT& item) {
    if (item.hDC == nullptr || item.hwndItem == nullptr) {
        return false;
    }

    if (item.CtlType == ODT_BUTTON) {
        drawOwnerDrawnButton(item);
        return true;
    }

    if (item.CtlType == ODT_COMBOBOX) {
        drawOwnerDrawnComboBox(item);
        return true;
    }

    return false;
}

bool ffmpegkittest::ui::measureOwnerDrawnControl(MEASUREITEMSTRUCT& item) {
    if (item.CtlType != ODT_COMBOBOX) {
        return false;
    }

    item.itemHeight = ComboBoxItemHeight;
    return true;
}

HWND ffmpegkittest::ui::createLabel(HWND parent, int controlId, const wchar_t* text) {
    return createControl(parent, L"STATIC", text, SS_LEFT | SS_ENDELLIPSIS, 0, controlId);
}

HWND ffmpegkittest::ui::createEdit(HWND parent, int controlId) {
    // No WS_EX_CLIENTEDGE: the themed sunken edge is replaced by the palette
    // border Tab::windowProcedure paints around the control.
    HWND control = createControl(parent, L"EDIT", L"", ES_AUTOHSCROLL | WS_TABSTOP, 0, controlId);
    applyEditMargins(control);
    return control;
}

HWND ffmpegkittest::ui::createComboBox(HWND parent, int controlId) {
    // CBS_OWNERDRAWFIXED for the same reason the buttons are owner drawn.
    // CBS_HASSTRINGS keeps the control storing the strings comboAddItem() adds,
    // which an owner drawn combo box otherwise treats as opaque item data and
    // which the painting code reads back with CB_GETLBTEXT.
    return createControl(parent, L"COMBOBOX", L"",
                         CBS_DROPDOWNLIST | CBS_OWNERDRAWFIXED | CBS_HASSTRINGS | WS_TABSTOP | WS_VSCROLL,
                         0, controlId);
}

void ffmpegkittest::ui::setCueBanner(HWND edit, const wchar_t* text) {
    if (edit != nullptr) {
        // EM_SETCUEBANNER needs the version 6 common controls, which the
        // application manifest requests.
        SendMessageW(edit, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(text));
    }
}

HWND ffmpegkittest::ui::createOutput(HWND parent, int controlId) {
    HWND control = createControl(parent, L"EDIT", L"",
                                 ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | WS_VSCROLL | WS_HSCROLL | WS_TABSTOP,
                                 0, controlId);
    applyEditMargins(control);
    return control;
}

void ffmpegkittest::ui::setControlText(HWND control, const std::string& text) {
    if (control == nullptr) {
        return;
    }
    SetWindowTextW(control, toEditLineEndings(toWide(text)).c_str());
}

std::string ffmpegkittest::ui::getControlText(HWND control) {
    if (control == nullptr) {
        return std::string();
    }

    const int length = GetWindowTextLengthW(control);
    if (length <= 0) {
        return std::string();
    }

    std::wstring wide(static_cast<size_t>(length) + 1, L'\0');
    const int copied = GetWindowTextW(control, &wide[0], length + 1);
    wide.resize(static_cast<size_t>(copied < 0 ? 0 : copied));
    return toUtf8(wide);
}

void ffmpegkittest::ui::appendControlText(HWND control, const std::string& text) {
    if (control == nullptr || text.empty()) {
        return;
    }

    const std::wstring wide = toEditLineEndings(toWide(text));
    const int length = GetWindowTextLengthW(control);

    // Selecting the end and replacing the (empty) selection appends without
    // reading the whole buffer back, which matters once a long FFmpeg run has
    // produced tens of thousands of log lines.
    SendMessageW(control, EM_SETSEL, static_cast<WPARAM>(length), static_cast<LPARAM>(length));
    SendMessageW(control, EM_REPLACESEL, FALSE, reinterpret_cast<LPARAM>(wide.c_str()));
    SendMessageW(control, EM_SCROLLCARET, 0, 0);
}

void ffmpegkittest::ui::clearControlText(HWND control) {
    if (control != nullptr) {
        SetWindowTextW(control, L"");
    }
}

void ffmpegkittest::ui::comboAddItem(HWND combo, const std::string& text) {
    if (combo != nullptr) {
        SendMessageW(combo, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(toWide(text).c_str()));
    }
}

void ffmpegkittest::ui::comboSetSelection(HWND combo, int index) {
    if (combo != nullptr) {
        SendMessageW(combo, CB_SETCURSEL, static_cast<WPARAM>(index), 0);
    }
}

int ffmpegkittest::ui::comboGetSelection(HWND combo) {
    if (combo == nullptr) {
        return -1;
    }
    return static_cast<int>(SendMessageW(combo, CB_GETCURSEL, 0, 0));
}

void ffmpegkittest::ui::setEnabled(HWND control, bool enabled) {
    if (control != nullptr) {
        EnableWindow(control, enabled ? TRUE : FALSE);
    }
}

void ffmpegkittest::ui::setVisible(HWND control, bool visible) {
    if (control != nullptr) {
        ShowWindow(control, visible ? SW_SHOW : SW_HIDE);
    }
}

ffmpegkittest::ui::Column::Column(int width, int height, int margin, int spacing)
    : width(width), height(height), margin(margin), spacing(spacing), top(margin) {
}

RECT ffmpegkittest::ui::Column::row(int rowHeight) {
    RECT bounds;
    bounds.left = margin;
    bounds.top = top;
    bounds.right = width - margin;
    bounds.bottom = top + rowHeight;
    top = bounds.bottom + spacing;
    return bounds;
}

RECT ffmpegkittest::ui::Column::centeredRow(int itemWidth, int rowHeight) {
    RECT bounds;
    bounds.left = (width - itemWidth) / 2;
    bounds.top = top;
    bounds.right = bounds.left + itemWidth;
    bounds.bottom = top + rowHeight;
    top = bounds.bottom + spacing;
    return bounds;
}

RECT ffmpegkittest::ui::Column::centeredComboBox(int itemWidth, int closedHeight, int dropDownHeight) {
    RECT bounds;
    bounds.left = (width - itemWidth) / 2;
    bounds.top = top;
    bounds.right = bounds.left + itemWidth;
    bounds.bottom = top + dropDownHeight;

    // Advance past the closed control only. The extra window height exists so the
    // list has room to open; reserving all of it in the column is what left a gap
    // between the combo box and the controls under it.
    top += closedHeight + spacing;
    return bounds;
}

std::vector<RECT> ffmpegkittest::ui::Column::centeredRow(int itemWidth, int rowHeight, int itemCount) {
    std::vector<RECT> bounds;
    if (itemCount <= 0) {
        return bounds;
    }

    const int gap = spacing;
    const int totalWidth = (itemWidth * itemCount) + (gap * (itemCount - 1));
    int left = (width - totalWidth) / 2;
    if (left < margin) {
        left = margin;
    }

    for (int i = 0; i < itemCount; i++) {
        RECT item;
        item.left = left;
        item.top = top;
        item.right = left + itemWidth;
        item.bottom = top + rowHeight;
        bounds.push_back(item);
        left = item.right + gap;
    }

    top += rowHeight + spacing;
    return bounds;
}

RECT ffmpegkittest::ui::Column::remaining() {
    RECT bounds;
    bounds.left = margin;
    bounds.top = top;
    bounds.right = width - margin;
    bounds.bottom = height - margin;
    if (bounds.bottom < bounds.top) {
        bounds.bottom = bounds.top;
    }
    top = bounds.bottom;
    return bounds;
}

void ffmpegkittest::ui::place(HWND control, const RECT& bounds) {
    if (control == nullptr) {
        return;
    }

    MoveWindow(control, bounds.left, bounds.top,
               bounds.right - bounds.left, bounds.bottom - bounds.top, TRUE);
}

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

#ifndef FFMPEG_KIT_TEST_WIN32_UI_H
#define FFMPEG_KIT_TEST_WIN32_UI_H

#include <string>
#include <vector>
#include <windows.h>

namespace ffmpegkittest {

    /**
     * Thin helpers over the Win32 control API.
     *
     * The application uses the common controls directly rather than a widget
     * toolkit, so these wrap the repetitive parts: creating a control with the
     * system font applied, converting between the UTF-8 strings FFmpegKitNext
     * uses and the UTF-16 the wide Win32 API expects, and laying out a column of
     * controls.
     */
    namespace ui {

        /** The font Windows uses for dialog text. Applied to every control so the app matches the shell. */
        HFONT defaultFont();

        /** A larger, semibold derivative of defaultFont() used for the header band title. */
        HFONT headerFont();

        std::wstring toWide(const std::string& text);
        std::string toUtf8(const std::wstring& text);

        HWND createButton(HWND parent, int controlId, const wchar_t* text);
        HWND createLabel(HWND parent, int controlId, const wchar_t* text);
        HWND createEdit(HWND parent, int controlId);
        HWND createComboBox(HWND parent, int controlId);

        /** Grey prompt shown in an empty edit control, the placeholder text equivalent. */
        void setCueBanner(HWND edit, const wchar_t* text);

        /** A read-only multi-line edit used as the log/output pane on every tab. */
        HWND createOutput(HWND parent, int controlId);

        /**
         * Paints an owner drawn button or combo box in the shared palette.
         *
         * Called from WM_DRAWITEM, which Windows sends to the parent of the
         * control rather than the control itself. Every control lives on a Tab,
         * so Tab::windowProcedure forwards here once on behalf of all of them.
         * Returns false for anything this does not paint, leaving it to
         * DefWindowProc.
         */
        bool drawOwnerDrawnControl(const DRAWITEMSTRUCT& item);

        /**
         * Reports the row height for an owner drawn combo box.
         *
         * Called from WM_MEASUREITEM. An owner drawn combo box has no intrinsic
         * row height, so without this Windows falls back to a default that does
         * not match the control the layout asks for.
         */
        bool measureOwnerDrawnControl(MEASUREITEMSTRUCT& item);

        void setControlText(HWND control, const std::string& text);
        std::string getControlText(HWND control);

        /**
         * Appends to an output control and scrolls to the bottom.
         *
         * EDIT controls only break lines on CRLF, while FFmpeg log messages carry
         * bare LFs, so the text is translated on the way in.
         */
        void appendControlText(HWND control, const std::string& text);
        void clearControlText(HWND control);

        void comboAddItem(HWND combo, const std::string& text);
        void comboSetSelection(HWND combo, int index);
        int comboGetSelection(HWND combo);

        void setEnabled(HWND control, bool enabled);
        void setVisible(HWND control, bool visible);

        /**
         * Lays out a vertical column of controls inside a client rectangle,
         * replacing the box packing of the previous implementation.
         */
        class Column {
            public:
                Column(int width, int height, int margin = 12, int spacing = 8);

                /** Full width row of the given height. */
                RECT row(int height);

                /** Fixed width row, horizontally centered. */
                RECT centeredRow(int itemWidth, int height);

                /**
                 * Places a drop-down list, centered and fixed width.
                 *
                 * A combo box's window height is how far its list can open, not how
                 * tall the closed control is, so the two are given separately: the
                 * returned rectangle is dropDownHeight tall to leave the list room,
                 * while the column only advances past the visible closedHeight. The
                 * open list overlaps whatever follows, which is what a drop-down is
                 * meant to do.
                 */
                RECT centeredComboBox(int itemWidth, int closedHeight, int dropDownHeight);

                /** A row of evenly spaced, centered, fixed width items. */
                std::vector<RECT> centeredRow(int itemWidth, int height, int itemCount);

                /** Everything left over, for the output pane. */
                RECT remaining();

            private:
                int width;
                int height;
                int margin;
                int spacing;
                int top;
        };

        /** Moves a control into place, or hides it when the rectangle is empty. */
        void place(HWND control, const RECT& bounds);
    }
}

#endif // FFMPEG_KIT_TEST_WIN32_UI_H

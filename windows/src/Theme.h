/*
 * Copyright (c) 2026 Taner Sener
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

#ifndef FFMPEG_KIT_TEST_THEME_H
#define FFMPEG_KIT_TEST_THEME_H

#include <windows.h>

namespace ffmpegkittest {

    /**
     * The Flat UI palette the test applications share.
     *
     * The same values appear in the Linux GTK CSS (Util.cpp), the Android
     * drawables (rounded_button.xml, rounded_spinner.xml,
     * rounded_output_frame.xml), the React Native styles (style.js) and the web
     * custom properties (app.css). They are collected here so the Windows app
     * names one palette rather than repeating literals.
     *
     * The output pane and the edit fields are coloured through the WM_CTLCOLOR*
     * family in Tab::windowProcedure. Buttons and combo boxes cannot be: with
     * version 6 common controls they are painted entirely by the theme engine
     * and ignore WM_CTLCOLORBTN, so they are owner drawn instead (BS_OWNERDRAW
     * and CBS_OWNERDRAWFIXED, painted by ui::drawOwnerDrawnControl).
     */
    namespace theme {

        constexpr COLORREF Green = RGB(0x2E, 0xCC, 0x71);
        constexpr COLORREF GreenDark = RGB(0x27, 0xAE, 0x60);
        constexpr COLORREF Blue = RGB(0x34, 0x98, 0xDB);
        constexpr COLORREF BlueDark = RGB(0x29, 0x80, 0xB9);
        constexpr COLORREF Red = RGB(0xE7, 0x4C, 0x3C);
        constexpr COLORREF Yellow = RGB(0xF1, 0xC4, 0x0F);
        constexpr COLORREF Orange = RGB(0xF3, 0x9C, 0x12);
        constexpr COLORREF Purple = RGB(0x9B, 0x59, 0xB6);
        constexpr COLORREF PurpleDark = RGB(0x8E, 0x44, 0xAD);
        constexpr COLORREF Clouds = RGB(0xEC, 0xF0, 0xF1);
        constexpr COLORREF Silver = RGB(0xB9, 0xC3, 0xC7);

        constexpr COLORREF White = RGB(0xFF, 0xFF, 0xFF);
        constexpr COLORREF Black = RGB(0x00, 0x00, 0x00);

        /** The log/output pane, matching applyOutputTextStyle() on Linux. */
        constexpr COLORREF OutputBackground = Yellow;
        constexpr COLORREF OutputText = Black;
        constexpr COLORREF OutputBorder = Orange;

        /** The editable text fields, matching applyEditTextStyle() on Linux. */
        constexpr COLORREF EditBackground = White;
        constexpr COLORREF EditText = Black;
        constexpr COLORREF EditBorder = Blue;

        /** The push buttons, matching applyButtonStyle() on Linux. */
        constexpr COLORREF ButtonBackground = Green;
        constexpr COLORREF ButtonBorder = GreenDark;
        constexpr COLORREF ButtonText = White;

        /** button:active on Linux darkens the fill rather than the border. */
        constexpr COLORREF ButtonBackgroundPressed = GreenDark;

        /**
         * The disabled look. Linux never needed one because GTK dims an
         * insensitive button itself; an owner drawn button paints every state,
         * so PLAY and VIEW would otherwise look clickable before a run.
         */
        constexpr COLORREF ButtonBackgroundDisabled = Clouds;
        constexpr COLORREF ButtonBorderDisabled = Silver;
        constexpr COLORREF ButtonTextDisabled = Silver;

        /**
         * The application header band.
         *
         * Taken from headerColor in the Android colors.xml, which the web app
         * reuses for its <header> element. The other desktop apps have no
         * equivalent: Linux and macOS both rely on the native title bar.
         */
        constexpr COLORREF HeaderBackground = Red;
        constexpr COLORREF HeaderText = White;

        /** The combo boxes, matching applyComboBoxStyle() on Linux. */
        constexpr COLORREF ComboBoxBackground = Purple;
        constexpr COLORREF ComboBoxHighlight = PurpleDark;
        constexpr COLORREF ComboBoxText = White;

    }

}

#endif // FFMPEG_KIT_TEST_THEME_H

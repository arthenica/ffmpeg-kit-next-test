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

#ifndef FFMPEG_KIT_TEST_PROGRESS_DIALOG_H
#define FFMPEG_KIT_TEST_PROGRESS_DIALOG_H

#include <windows.h>

namespace ffmpegkittest {

    /**
     * A small window holding a progress bar.
     *
     * The counterpart of the gtkmm ProgressDialog the Linux test app defines: the
     * same show/update/hide lifecycle around a bar reporting how far an FFmpeg
     * session has run, in a window of the same size.
     *
     * The one deliberate difference is modality. The Linux dialog is built with
     * Gtk::DIALOG_MODAL, but the Win32 way of being modal is to disable the owner
     * window, and that would put the Subtitle tab's CANCEL button out of reach
     * during the only operation it exists to cancel. This window is therefore
     * owned by its parent, so it floats above the application and keeps out of
     * the taskbar, but it does not disable anything.
     *
     * Every method must be called on the UI thread. Progress arrives on an
     * FFmpegKitNext callback thread and reaches here through Tab::post().
     */
    class ProgressDialog {
        public:
            ProgressDialog() = default;
            ~ProgressDialog();

            ProgressDialog(const ProgressDialog&) = delete;
            ProgressDialog& operator=(const ProgressDialog&) = delete;

            /** Creates and shows the window centred on the parent. Showing twice is a no-op. */
            void show(HWND parentWindow);

            /** Moves the bar. Takes a percentage from 0 to 100, and clamps to it. */
            void update(double percentage);

            /** Destroys the window. Safe to call when nothing is showing. */
            void hide();

        private:
            static void registerWindowClass();
            static LRESULT CALLBACK windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam);

            HWND hwnd = nullptr;
            HWND progressBar = nullptr;
    };

}

#endif // FFMPEG_KIT_TEST_PROGRESS_DIALOG_H

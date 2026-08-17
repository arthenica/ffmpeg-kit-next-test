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

#ifndef FFMPEG_KIT_TEST_TAB_H
#define FFMPEG_KIT_TEST_TAB_H

#include <functional>
#include <string>
#include <windows.h>

namespace ffmpegkittest {

    /**
     * Carries a callable posted from a worker thread to the UI thread.
     *
     * FFmpegKitNext invokes its log, statistics and session complete callbacks on
     * its own threads, while a Win32 control may only be touched from the thread
     * that created it. Every callback therefore hands its work to Tab::post(),
     * which forwards it through the message queue. This is the direct counterpart
     * of the g_idle_add() calls used before the Win32 migration.
     */
    constexpr UINT WM_FFKIT_INVOKE = WM_APP + 1;

    /**
     * Base class for a page of the main tab control.
     *
     * Each tab owns a child window that hosts its controls. Subclasses create
     * their controls in onCreate(), position them in onLayout() and respond to
     * clicks in onCommand().
     */
    class Tab {
        public:
            virtual ~Tab();

            /** Creates the tab's child window. Call before setBounds() or setVisible(). */
            HWND create(HWND parent);

            HWND getHandle() const { return hwnd; }
            HWND getParentWindow() const { return parentWindow; }

            void setBounds(const RECT& bounds);
            void setVisible(const bool visible);

            /** Label shown on the tab control. */
            virtual const wchar_t* getTitle() const = 0;

            /** Called when the tab becomes the selected one. */
            virtual void setActive() {}

            /**
             * Runs the callable on the UI thread. Safe to call from any thread.
             *
             * The callable is heap allocated and freed by the handler, so a tab
             * that is destroyed while work is in flight would leak rather than
             * crash. The tabs live for the lifetime of the window, so this is not
             * a practical concern here.
             */
            void post(std::function<void()> work);

        protected:
            virtual void onCreate() = 0;
            virtual void onLayout(const int width, const int height) = 0;
            virtual void onCommand(const int controlId, const int notification) {}

            HWND hwnd = nullptr;
            HWND parentWindow = nullptr;

        private:
            static LRESULT CALLBACK windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam);
            static void registerWindowClass();
    };
}

#endif // FFMPEG_KIT_TEST_TAB_H

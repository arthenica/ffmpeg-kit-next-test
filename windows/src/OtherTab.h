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

#ifndef FFMPEG_KIT_TEST_OTHER_TAB_H
#define FFMPEG_KIT_TEST_OTHER_TAB_H

#include "Tab.h"

#include <string>

namespace ffmpegkittest {

    class OtherTab : public Tab {
        public:
            static constexpr const char* Dav1dTestDefaultUrl = "http://download.opencontent.netflix.com.s3.amazonaws.com/AV1/Sparks/Sparks-5994fps-AV1-10bit-960x540-film-grain-synthesis-854kbps.obu";

            const wchar_t* getTitle() const override { return L"Other"; }
            void setActive() override;

            void appendOutput(const std::string& text);

        protected:
            void onCreate() override;
            void onLayout(const int width, const int height) override;
            void onCommand(const int controlId, const int notification) override;

        private:
            enum ControlId {
                IdTest = 100,
                IdRun,
                IdOutput
            };

            void initTestData();
            std::string getSelectedTest();
            void runTest();
            void testChromaprint();
            void testDav1d();
            void testWebp();
            void testLibjxl();
            void testZscale();
            void testVvenc();
            std::string getChromaprintSampleFile();
            std::string getChromaprintOutputFile();
            std::string getDav1dOutputFile();
            std::string getLibjxlOutputFile();
            std::string getLibjxlDecodedOutputFile();
            std::string getVvencOutputFile();
            void clearOutput();

            HWND test = nullptr;
            HWND runButton = nullptr;
            HWND outputText = nullptr;

            int selectedTest = 0;
    };

}

#endif // FFMPEG_KIT_TEST_OTHER_TAB_H

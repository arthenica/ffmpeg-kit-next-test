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

#ifndef FFMPEG_KIT_TEST_HTTPS_TAB_H
#define FFMPEG_KIT_TEST_HTTPS_TAB_H

#include "MediaInformationSessionCompleteCallback.h"
#include "Tab.h"

#include <string>

namespace ffmpegkittest {

    class HttpsTab : public Tab {
        public:
            static constexpr const char* HttpsTestDefaultUrl = "https://download.blender.org/peach/trailer/trailer_1080p.ogg";

            static constexpr const char* HttpsTestFailUrl = "https://download2.blender.org/peach/trailer/trailer_1080p.ogg";

            static constexpr const char* HttpsTestRandomUrl1 = "https://filesamples.com/samples/video/mov/sample_640x360.mov";

            static constexpr const char* HttpsTestRandomUrl2 = "https://filesamples.com/samples/audio/mp3/sample3.mp3";

            static constexpr const char* HttpsTestRandomUrl3 = "https://filesamples.com/samples/image/webp/sample1.webp";

            const wchar_t* getTitle() const override { return L"HTTPS"; }
            void setActive() override;

            void appendOutput(const std::string& text);

        protected:
            void onCreate() override;
            void onLayout(const int width, const int height) override;
            void onCommand(const int controlId, const int notification) override;

        private:
            enum ControlId {
                IdUrlText = 100,
                IdGetInfoFromUrl,
                IdGetRandomInfo1,
                IdGetRandomInfo2,
                IdGetInfoAndFail,
                IdOutput
            };

            void runGetMediaInformation(const int buttonNumber);
            std::string getRandomTestUrl();
            ffmpegkit::MediaInformationSessionCompleteCallback createNewCompleteCallback();
            void clearOutput();

            HWND urlText = nullptr;
            HWND getInfoFromUrlButton = nullptr;
            HWND getRandomInfoButton1 = nullptr;
            HWND getRandomInfoButton2 = nullptr;
            HWND getInfoAndFailButton = nullptr;
            HWND outputText = nullptr;
    };

}

#endif // FFMPEG_KIT_TEST_HTTPS_TAB_H

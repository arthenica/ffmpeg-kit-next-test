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

#ifndef FFMPEG_KIT_TEST_AUDIO_TAB_H
#define FFMPEG_KIT_TEST_AUDIO_TAB_H

#include "Tab.h"

#include <string>

namespace ffmpegkittest {

    class AudioTab : public Tab {
        public:
            const wchar_t* getTitle() const override { return L"Audio"; }
            void setActive() override;

            void appendOutput(const std::string& text);

        protected:
            void onCreate() override;
            void onLayout(const int width, const int height) override;
            void onCommand(const int controlId, const int notification) override;

        private:
            enum ControlId {
                IdAudioCodec = 100,
                IdEncode,
                IdOutput
            };

            void createAudioSample();
            void initAudioCodecData();
            std::string getSelectedAudioCodec();
            void encodeAudio();
            std::string getAudioOutputFile();
            std::string getAudioSampleFile();
            std::string generateAudioEncodeScript();
            void clearOutput();

            HWND audioCodec = nullptr;
            HWND encodeButton = nullptr;
            HWND outputText = nullptr;

            int selectedCodec = 0;
    };

}

#endif // FFMPEG_KIT_TEST_AUDIO_TAB_H

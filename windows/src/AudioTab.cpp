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

#include "AudioTab.h"
#include "Application.h"
#include "Constants.h"
#include "Log.h"
#include "Popup.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>

#include <cstdio>
#include <iostream>

using namespace ffmpegkit;

void ffmpegkittest::AudioTab::onCreate() {
    audioCodec = ui::createComboBox(hwnd, IdAudioCodec);
    initAudioCodecData();

    encodeButton = ui::createButton(hwnd, IdEncode, L"ENCODE");
    ui::setEnabled(encodeButton, false);

    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::AudioTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);
    ui::place(audioCodec, column.centeredComboBox(240, 28, 200));
    ui::place(encodeButton, column.centeredRow(140, 30));
    ui::place(outputText, column.remaining());
}

void ffmpegkittest::AudioTab::onCommand(const int controlId, const int notification) {
    if (controlId == IdAudioCodec && notification == CBN_SELCHANGE) {
        const int selection = ui::comboGetSelection(audioCodec);
        if (selection != -1) {
            selectedCodec = selection;
        }
        return;
    }

    if (notification == BN_CLICKED && controlId == IdEncode) {
        encodeAudio();
    }
}

void ffmpegkittest::AudioTab::setActive() {
    std::cout << "Audio Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
    createAudioSample();
    FFmpegKitConfig::enableLogCallback([this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    });
}

void ffmpegkittest::AudioTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::AudioTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::AudioTab::createAudioSample() {
    std::cout << "Creating AUDIO sample before the test." << std::endl;

    auto audioSampleFile = getAudioSampleFile();
    std::remove(audioSampleFile.c_str());

    std::string ffmpegCommand = "-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le \"" + audioSampleFile + "\"";

    std::cout << "Creating audio sample with '" << ffmpegCommand << "'." << std::endl;

    auto session = FFmpegKit::execute(ffmpegCommand);
    if (ReturnCode::isSuccess(session->getReturnCode())) {
        ui::setEnabled(encodeButton, true);
        std::cout << "AUDIO sample created." << std::endl;
    } else {
        std::cout << "Creating AUDIO sample failed with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;
        Popup::show(parentWindow, MessageTypeError, "Creating AUDIO sample failed. Please check logs for the details.");
    }
}

void ffmpegkittest::AudioTab::initAudioCodecData() {
    ui::comboAddItem(audioCodec, "mp2 (twolame)");
    ui::comboAddItem(audioCodec, "mp3 (liblame)");
    ui::comboAddItem(audioCodec, "mp3 (libshine)");
    ui::comboAddItem(audioCodec, "vorbis");
    ui::comboAddItem(audioCodec, "opus");
    ui::comboAddItem(audioCodec, "amr-nb");
    ui::comboAddItem(audioCodec, "amr-wb");
    ui::comboAddItem(audioCodec, "ilbc");
    ui::comboAddItem(audioCodec, "soxr");
    ui::comboAddItem(audioCodec, "speex");
    ui::comboAddItem(audioCodec, "wavpack");
    ui::comboAddItem(audioCodec, "lc3");
    ui::comboSetSelection(audioCodec, 0);
    selectedCodec = 0;
}

std::string ffmpegkittest::AudioTab::getSelectedAudioCodec() {
    switch(selectedCodec) {
        case 0: return "mp2 (twolame)";
        case 1: return "mp3 (liblame)";
        case 2: return "mp3 (libshine)";
        case 3: return "vorbis";
        case 4: return "opus";
        case 5: return "amr-nb";
        case 6: return "amr-wb";
        case 7: return "ilbc";
        case 8: return "soxr";
        case 9: return "speex";
        case 10: return "wavpack";
        case 11: return "lc3";
        default: return "";
    }
}

void ffmpegkittest::AudioTab::encodeAudio() {
    auto audioOutputFile = getAudioOutputFile();
    std::remove(audioOutputFile.c_str());

    auto audioCodecName = getSelectedAudioCodec();

    std::cout << "Testing AUDIO encoding with '" << audioCodecName << "' codec." << std::endl;

    auto ffmpegCommand = generateAudioEncodeScript();

    clearOutput();

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();

        if (ReturnCode::isSuccess(returnCode)) {
            post([this]() {
                Popup::show(parentWindow, MessageTypeInformation, "Encode completed successfully.");
            });
            std::cout << "Encode completed successfully." << std::endl;
        } else {
            post([this]() {
                Popup::show(parentWindow, MessageTypeError, "Encode failed. Please check logs for the details.");
            });
            std::cout << "Encode failed with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << "." << session->getFailStackTrace() << std::endl;
        }
    });
}

std::string ffmpegkittest::AudioTab::getAudioOutputFile() {
    std::string audioCodecName = getSelectedAudioCodec();

    std::string extension;
    if (audioCodecName.compare("mp2 (twolame)") == 0) {
        extension = "mpg";
    } else if (audioCodecName.compare("mp3 (liblame)") == 0 || audioCodecName.compare("mp3 (libshine)") == 0) {
        extension = "mp3";
    } else if (audioCodecName.compare("vorbis") == 0) {
        extension = "ogg";
    } else if (audioCodecName.compare("opus") == 0) {
        extension = "opus";
    } else if (audioCodecName.compare("amr-nb") == 0 || audioCodecName.compare("amr-wb") == 0) {
        extension = "amr";
    } else if (audioCodecName.compare("ilbc") == 0) {
        extension = "lbc";
    } else if (audioCodecName.compare("speex") == 0) {
        extension = "spx";
    } else if (audioCodecName.compare("wavpack") == 0) {
        extension = "wv";
    } else if (audioCodecName.compare("lc3") == 0) {
        extension = "lc3";
    } else {

        // soxr
        extension = "wav";
    }

    return Application::getApplicationCacheDirectory() + "/audio." + extension;
}

std::string ffmpegkittest::AudioTab::getAudioSampleFile() {
    return Application::getApplicationCacheDirectory() + "/audio-sample.wav";
}

std::string ffmpegkittest::AudioTab::generateAudioEncodeScript() {
    auto audioCodec = getSelectedAudioCodec();
    auto audioSampleFile = getAudioSampleFile();
    auto audioOutputFile = getAudioOutputFile();

    if (audioCodec.compare("mp2 (twolame)") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a mp2 -b:a 192k \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("mp3 (liblame)") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libmp3lame -qscale:a 2 \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("mp3 (libshine)") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libshine -qscale:a 2 \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("vorbis") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libvorbis -b:a 64k \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("opus") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libopus -b:a 64k -vbr on -compression_level 10 \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("amr-nb") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -ar 8000 -ab 12.2k -c:a libopencore_amrnb \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("amr-wb") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("ilbc") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libilbc -ar 8000 -b:a 15200 \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("speex") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a libspeex -ar 16000 \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("wavpack") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -c:a wavpack -b:a 64k \"" + audioOutputFile + "\"";
    } else if (audioCodec.compare("lc3") == 0) {
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -ar 48000 -ac 1 -c:a liblc3 -b:a 96k -frame_duration 10 \"" + audioOutputFile + "\"";
    } else {

        // soxr
        return "-hide_banner -y -i \"" + audioSampleFile + "\" -af aresample=resampler=soxr -ar 44100 \"" + audioOutputFile + "\"";
    }
}

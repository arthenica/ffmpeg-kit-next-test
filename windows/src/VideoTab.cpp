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

#include "VideoTab.h"
#include "Application.h"
#include "Constants.h"
#include "Log.h"
#include "Popup.h"
#include "Util.h"
#include "Video.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>

#include <cstdio>
#include <iostream>

using namespace ffmpegkit;

void ffmpegkittest::VideoTab::onCreate() {
    videoCodec = ui::createComboBox(hwnd, IdVideoCodec);
    initVideoCodecData();

    encodeButton = ui::createButton(hwnd, IdEncode, L"ENCODE");

    playButton = ui::createButton(hwnd, IdPlay, L"PLAY");
    ui::setEnabled(playButton, false);

    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::VideoTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);

    ui::place(videoCodec, column.centeredComboBox(240, 28, 200));

    const std::vector<RECT> buttons = column.centeredRow(140, 30, 2);
    ui::place(encodeButton, buttons[0]);
    ui::place(playButton, buttons[1]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::VideoTab::onCommand(const int controlId, const int notification) {
    if (controlId == IdVideoCodec && notification == CBN_SELCHANGE) {
        const int selection = ui::comboGetSelection(videoCodec);
        if (selection != -1) {
            selectedCodec = selection;
        }
        return;
    }

    if (notification != BN_CLICKED) {
        return;
    }

    if (controlId == IdEncode) {
        encodeVideo();
    } else if (controlId == IdPlay) {
        playOutputFile();
    }
}

void ffmpegkittest::VideoTab::setActive() {
    std::cout << "Video Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::VideoTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::VideoTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::VideoTab::setPlayButtonEnabled(const bool enabled) {
    ui::setEnabled(playButton, enabled);
}

void ffmpegkittest::VideoTab::playOutputFile() {
    const std::string videoFile = getVideoFile();

    if (!Util::openInSystemPlayer(videoFile, parentWindow)) {
        Popup::show(parentWindow, MessageTypeInformation,
                    "No application is registered to play this file.\n\nIt was written to:\n" + videoFile);
    }
}

void ffmpegkittest::VideoTab::updateProgressDialog(const std::shared_ptr<ffmpegkit::Statistics> statistics) {
    if (statistics == nullptr || statistics->getTime() < 0) {
        return;
    }

    this->statistics = statistics;
    double timeInMilliseconds = this->statistics->getTime();
    int totalVideoDuration = 9000;
    double completePercentage = timeInMilliseconds*100/totalVideoDuration;
    progressDialog.update(completePercentage);
    std::cout << "Encoding completed " << completePercentage << "%" << std::endl;
}

void ffmpegkittest::VideoTab::showProgressDialog() {
    progressDialog.show(parentWindow);
}

void ffmpegkittest::VideoTab::hideProgressDialog() {
    progressDialog.hide();
}

void ffmpegkittest::VideoTab::initVideoCodecData() {
    ui::comboAddItem(videoCodec, "mpeg4");
    ui::comboAddItem(videoCodec, "x264");
    ui::comboAddItem(videoCodec, "openh264");
    ui::comboAddItem(videoCodec, "x265");
    ui::comboAddItem(videoCodec, "xvid");
    ui::comboAddItem(videoCodec, "vp8");
    ui::comboAddItem(videoCodec, "vp9");
    ui::comboAddItem(videoCodec, "aom");
    ui::comboAddItem(videoCodec, "svt-av1");
    ui::comboAddItem(videoCodec, "kvazaar");
    ui::comboAddItem(videoCodec, "theora");
    ui::comboAddItem(videoCodec, "hap");
    ui::comboSetSelection(videoCodec, 0);
    selectedCodec = 0;
}

std::string ffmpegkittest::VideoTab::getSelectedVideoCodec() {
    switch(selectedCodec) {
        case 0: return "mpeg4";
        case 1: return "libx264";
        case 2: return "libopenh264";
        case 3: return "libx265";
        case 4: return "libxvid";
        case 5: return "vp8";
        case 6: return "vp9";
        case 7: return "libaom-av1";
        case 8: return "libsvtav1";
        case 9: return "libkvazaar";
        case 10: return "theora";
        case 11: return "hap";
        default: return "";
    }
}

void ffmpegkittest::VideoTab::encodeVideo() {
    clearOutput();

    std::string image1File = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string image2File = Application::getApplicationInstallDirectory() + "/share/images/lake.jpg";
    std::string image3File = Application::getApplicationInstallDirectory() + "/share/images/sunset.jpg";
    std::string videoFile = getVideoFile();

    std::remove(videoFile.c_str());

    std::string videoCodecName = this->getSelectedVideoCodec();

    std::cout << "Testing VIDEO encoding with '" << videoCodecName << "' codec" << std::endl;

    std::string ffmpegCommand = Video::generateEncodeVideoScript(image1File, image2File, image3File, videoFile, videoCodecName, getPixelFormat(), getCustomOptions());

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    showProgressDialog();

    auto session = FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();

        post([this]() { hideProgressDialog(); });

        if (ReturnCode::isSuccess(returnCode)) {
            std::cout << "Encode completed successfully in " << session->getDuration() << " milliseconds." << std::endl;
            post([this]() { setPlayButtonEnabled(true); });
        } else {
            post([this]() {
                Popup::show(parentWindow, MessageTypeError, "Encode failed. Please check logs for the details.");
            });
            std::cout << "Encode failed with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << "." << session->getFailStackTrace() << std::endl;
        }
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, [this](auto statistics) {
        post([this, statistics]() { updateProgressDialog(statistics); });
    });

    std::cout << "Async FFmpeg process started with sessionId " << session->getSessionId() << "." << std::endl;
}

std::string ffmpegkittest::VideoTab::getPixelFormat() {
    std::string videoCodecName = this->getSelectedVideoCodec();

    std::string pixelFormat;
    if (videoCodecName.compare("libx265") == 0) {
        pixelFormat = "yuv420p10le";
    } else {
        pixelFormat = "yuv420p";
    }

    return pixelFormat;
}

std::string ffmpegkittest::VideoTab::getVideoFile() {
    std::string videoCodecName = this->getSelectedVideoCodec();

    std::string extension;
    if (videoCodecName.compare("vp8") == 0 || videoCodecName.compare("vp9") == 0) {
        extension = "webm";
    } else if (videoCodecName.compare("theora") == 0) {
        extension = "ogv";
    } else if (videoCodecName.compare("hap") == 0) {
        extension = "mov";
    } else {

        // mpeg4, libx264, libx265, libxvid, kvazaar, libopenh264
        extension = "mp4";
    }

    return Application::getApplicationCacheDirectory() + "/video." + extension;
}

std::string ffmpegkittest::VideoTab::getCustomOptions() {
    std::string videoCodecName = this->getSelectedVideoCodec();

    if (videoCodecName.compare("libx265") == 0) {
        return "-crf 28 -preset fast ";
    } else if (videoCodecName.compare("vp8") == 0) {
        return "-b:v 1M -crf 10 ";
    } else if (videoCodecName.compare("vp9") == 0) {
        return "-b:v 2M ";
    } else if (videoCodecName.compare("libaom-av1") == 0) {
        return "-crf 30 -strict experimental ";
    } else if (videoCodecName.compare("libsvtav1") == 0) {
        return "-preset 8 -crf 35 ";
    } else if (videoCodecName.compare("theora") == 0) {
        return "-qscale:v 7 ";
    } else if (videoCodecName.compare("hap") == 0) {
        return "-format hap_q ";
    } else {

        // kvazaar, mpeg4, libx264, libxvid, libopenh264
        return "";
    }
}

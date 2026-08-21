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

#include "SubtitleTab.h"
#include "Application.h"
#include "Constants.h"
#include "Log.h"
#include "Popup.h"
#include "Util.h"
#include "Video.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>

#include <iostream>

using namespace ffmpegkit;

enum State {
    StateIdle,
    StateCreating,
    StateBurning
};

static State state = StateIdle;

static long sessionId = -1;

void ffmpegkittest::SubtitleTab::onCreate() {
    encodeButton = ui::createButton(hwnd, IdBurn, L"BURN SUBTITLES");
    cancelButton = ui::createButton(hwnd, IdCancel, L"CANCEL");

    playButton = ui::createButton(hwnd, IdPlay, L"PLAY");
    ui::setEnabled(playButton, false);

    outputText = ui::createOutput(hwnd, IdOutput);

    state = StateIdle;
}

void ffmpegkittest::SubtitleTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);

    const std::vector<RECT> buttons = column.centeredRow(150, 30, 3);
    ui::place(encodeButton, buttons[0]);
    ui::place(cancelButton, buttons[1]);
    ui::place(playButton, buttons[2]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::SubtitleTab::onCommand(const int controlId, const int notification) {
    if (notification != BN_CLICKED) {
        return;
    }

    if (controlId == IdBurn) {
        burnSubtitles();
    } else if (controlId == IdCancel) {
        cancel();
    } else if (controlId == IdPlay) {
        playOutputFile();
    }
}

void ffmpegkittest::SubtitleTab::setActive() {
    std::cout << "Subtitle Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback([this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    });
    FFmpegKitConfig::enableStatisticsCallback([this](auto statistics) {
        post([this, statistics]() { updateProgressDialog(statistics); });
    });
}

void ffmpegkittest::SubtitleTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::SubtitleTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::SubtitleTab::setPlayButtonEnabled(const bool enabled) {
    ui::setEnabled(playButton, enabled);
}

void ffmpegkittest::SubtitleTab::playOutputFile() {
    const std::string outputFile = getVideoWithSubtitlesFile();

    if (!Util::openInSystemPlayer(outputFile, parentWindow)) {
        Popup::show(parentWindow, MessageTypeInformation,
                    "No application is registered to play this file.\n\nIt was written to:\n" + outputFile);
    }
}

void ffmpegkittest::SubtitleTab::updateProgressDialog(const std::shared_ptr<ffmpegkit::Statistics> statistics) {
    if (statistics == nullptr || statistics->getTime() < 0) {
        return;
    }

    this->statistics = statistics;
    double timeInMilliseconds = this->statistics->getTime();
    int totalVideoDuration = 9000;
    double completePercentage = timeInMilliseconds*100/totalVideoDuration;

    progressDialog.update(completePercentage);

    if (state == StateCreating) {
        std::cout << "Creating video: " << completePercentage << "%" << std::endl;
    } else if (state == StateBurning) {
        std::cout << "Burning subtitles: " << completePercentage << "%" << std::endl;
    }
}

void ffmpegkittest::SubtitleTab::burnSubtitles() {
    clearOutput();

    std::string image1File = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string image2File = Application::getApplicationInstallDirectory() + "/share/images/lake.jpg";
    std::string image3File = Application::getApplicationInstallDirectory() + "/share/images/sunset.jpg";
    std::string videoFile = getVideoFile();
    std::string videoWithSubtitlesFile = getVideoWithSubtitlesFile();

    std::cout << "Testing SUBTITLE burning." << std::endl;

    std::string videoCodec = Video::packageVideoCodec();
    std::string ffmpegCommand = Video::generateEncodeVideoScript(image1File, image2File, image3File, videoFile, videoCodec, "");

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    state = StateCreating;

    showProgressDialog();

    sessionId = FFmpegKit::executeAsync(ffmpegCommand, [this, videoFile, videoWithSubtitlesFile, videoCodec](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            std::cout << "Create completed successfully; burning subtitles." << std::endl;

            // The subtitle path sits inside a filter option value, so its drive
            // letter colon has to be escaped. See Util::toFilterPath().
            std::string burnSubtitlesCommand = "-y -i \"" + videoFile + "\" -vf subtitles=filename='" + Util::toFilterPath(getSubtitleFile()) + "':force_style='FontName=MyFontName' -c:v " + videoCodec + " \"" + videoWithSubtitlesFile + "\"";

            std::cout << "FFmpeg process started with arguments: '" << burnSubtitlesCommand << "'." << std::endl;

            state = StateBurning;

            FFmpegKit::executeAsync(burnSubtitlesCommand, [this](auto secondSession) {
                state = StateIdle;

                post([this]() { hideProgressDialog(); });

                std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(secondSession->getState()) << " and rc " << secondSession->getReturnCode() << "." << secondSession->getFailStackTrace() << std::endl;

                if (ReturnCode::isSuccess(secondSession->getReturnCode())) {
                    std::cout << "Burn subtitles completed successfully." << std::endl;
                    post([this]() { setPlayButtonEnabled(true); });
                } else if (ReturnCode::isCancel(secondSession->getReturnCode())) {
                    post([this]() {
                        Popup::show(parentWindow, MessageTypeInformation, "Burn subtitles operation cancelled.");
                    });
                    std::cout << "Burn subtitles operation cancelled." << std::endl;
                } else {
                    post([this]() {
                        Popup::show(parentWindow, MessageTypeError, "Burn subtitles failed. Please check logs for the details.");
                    });
                }
            });
        } else {
            state = StateIdle;
            post([this]() {
                hideProgressDialog();
                Popup::show(parentWindow, MessageTypeError, "Create video failed. Please check logs for the details.");
            });
        }
    })->getSessionId();
}

void ffmpegkittest::SubtitleTab::showProgressDialog() {
    progressDialog.show(parentWindow);
}

void ffmpegkittest::SubtitleTab::hideProgressDialog() {
    progressDialog.hide();
}

void ffmpegkittest::SubtitleTab::cancel() {
    std::cout << "Cancelling FFmpeg process with sessionId " << sessionId << "." << std::endl;
    FFmpegKit::cancel();
}

std::string ffmpegkittest::SubtitleTab::getSubtitleFile() {
    return Application::getApplicationInstallDirectory() + "/share/subtitles/subtitle.srt";
}

std::string ffmpegkittest::SubtitleTab::getVideoFile() {
    return Application::getApplicationCacheDirectory() + "/video.mp4";
}

std::string ffmpegkittest::SubtitleTab::getVideoWithSubtitlesFile() {
    return Application::getApplicationCacheDirectory() + "/video-with-subtitles.mp4";
}

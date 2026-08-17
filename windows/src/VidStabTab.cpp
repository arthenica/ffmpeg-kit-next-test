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

#include "VidStabTab.h"
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

void ffmpegkittest::VidStabTab::onCreate() {
    stabilizeVideoButton = ui::createButton(hwnd, IdStabilize, L"STABILIZE VIDEO");

    playButton = ui::createButton(hwnd, IdPlay, L"PLAY");
    ui::setEnabled(playButton, false);

    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::VidStabTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);

    const std::vector<RECT> buttons = column.centeredRow(150, 30, 2);
    ui::place(stabilizeVideoButton, buttons[0]);
    ui::place(playButton, buttons[1]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::VidStabTab::onCommand(const int controlId, const int notification) {
    if (notification != BN_CLICKED) {
        return;
    }

    if (controlId == IdStabilize) {
        stabilizeVideo();
    } else if (controlId == IdPlay) {
        playOutputFile();
    }
}

void ffmpegkittest::VidStabTab::setActive() {
    std::cout << "VidStab Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback([this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    });
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::VidStabTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::VidStabTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::VidStabTab::setPlayButtonEnabled(const bool enabled) {
    ui::setEnabled(playButton, enabled);
}

void ffmpegkittest::VidStabTab::playOutputFile() {
    const std::string outputFile = getStabilizedVideoFile();

    if (!Util::openInSystemPlayer(outputFile, parentWindow)) {
        Popup::show(parentWindow, MessageTypeInformation,
                    "No application is registered to play this file.\n\nIt was written to:\n" + outputFile);
    }
}

void ffmpegkittest::VidStabTab::stabilizeVideo() {
    clearOutput();

    std::string image1File = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string image2File = Application::getApplicationInstallDirectory() + "/share/images/lake.jpg";
    std::string image3File = Application::getApplicationInstallDirectory() + "/share/images/sunset.jpg";
    std::string shakeResultsFile = getShakeResultsFile();
    std::string videoFile = getVideoFile();
    std::string stabilizedVideoFile = getStabilizedVideoFile();

    std::remove(shakeResultsFile.c_str());
    std::remove(videoFile.c_str());
    std::remove(stabilizedVideoFile.c_str());

    std::cout << "Testing VID.STAB." << std::endl;

    std::string videoCodec = Video::packageVideoCodec();
    std::string ffmpegCommand = Video::generateShakingVideoScript(image1File, image2File, image3File, videoFile, videoCodec);

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this, videoFile, shakeResultsFile, stabilizedVideoFile, videoCodec](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            std::cout << "Create completed successfully; stabilizing video." << std::endl;

            // shakeResultsFile sits inside a filter option value, so its drive
            // letter colon has to be escaped. See Util::toFilterPath().
            std::string analyzeVideoCommand = "-y -i \"" + videoFile + "\" -vf vidstabdetect=shakiness=10:accuracy=15:result=" + Util::toFilterPath(shakeResultsFile) + " -f null -";

            std::cout << "FFmpeg process started with arguments: '" << analyzeVideoCommand << "'." << std::endl;

            FFmpegKit::executeAsync(analyzeVideoCommand, [this, videoFile, shakeResultsFile, stabilizedVideoFile, videoCodec](auto secondSession) {
                std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(secondSession->getState()) << " and rc " << secondSession->getReturnCode() << "." << secondSession->getFailStackTrace() << std::endl;

                if (ReturnCode::isSuccess(secondSession->getReturnCode())) {
                    std::string stabilizeVideoCommand = "-y -i \"" + videoFile + "\" -vf vidstabtransform=smoothing=30:input=" + Util::toFilterPath(shakeResultsFile) + " -c:v " + videoCodec + " \"" + stabilizedVideoFile + "\"";

                    std::cout << "FFmpeg process started with arguments: '" << stabilizeVideoCommand << "'." << std::endl;

                    FFmpegKit::executeAsync(stabilizeVideoCommand, [this](auto thirdSession) {

                        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(thirdSession->getState()) << " and rc " << thirdSession->getReturnCode() << "." << thirdSession->getFailStackTrace() << std::endl;

                        if (ReturnCode::isSuccess(thirdSession->getReturnCode())) {
                            std::cout << "Stabilize video completed successfully." << std::endl;
                            post([this]() { setPlayButtonEnabled(true); });
                        } else {
                            post([this]() {
                                Popup::show(parentWindow, MessageTypeError, "Stabilize video failed. Please check logs for the details.");
                            });
                        }
                    });
                } else {
                    post([this]() {
                        Popup::show(parentWindow, MessageTypeError, "Stabilize video failed. Please check logs for the details.");
                    });
                }
            });
        } else {
            post([this]() {
                Popup::show(parentWindow, MessageTypeError, "Create video failed. Please check logs for the details.");
            });
        }
    });
}

std::string ffmpegkittest::VidStabTab::getShakeResultsFile() {
    return Application::getApplicationCacheDirectory() + "/transforms.trf";
}

std::string ffmpegkittest::VidStabTab::getVideoFile() {
    return Application::getApplicationCacheDirectory() + "/video.mp4";
}

std::string ffmpegkittest::VidStabTab::getStabilizedVideoFile() {
    return Application::getApplicationCacheDirectory() + "/video-stabilized.mp4";
}

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

#include "ConcurrentExecutionTab.h"
#include "Application.h"
#include "Constants.h"
#include "Log.h"
#include "Video.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>

#include <iostream>

using namespace ffmpegkit;

static long sessionId1 = -1;
static long sessionId2 = -1;
static long sessionId3 = -1;

void ffmpegkittest::ConcurrentExecutionTab::onCreate() {
    encodeButton1 = ui::createButton(hwnd, IdEncode1, L"ENCODE 1");
    encodeButton2 = ui::createButton(hwnd, IdEncode2, L"ENCODE 2");
    encodeButton3 = ui::createButton(hwnd, IdEncode3, L"ENCODE 3");
    cancelButton1 = ui::createButton(hwnd, IdCancel1, L"CANCEL 1");
    cancelButton2 = ui::createButton(hwnd, IdCancel2, L"CANCEL 2");
    cancelButton3 = ui::createButton(hwnd, IdCancel3, L"CANCEL 3");
    cancelButton4 = ui::createButton(hwnd, IdCancelAll, L"CANCEL ALL");
    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::ConcurrentExecutionTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);

    const std::vector<RECT> encodeButtons = column.centeredRow(120, 30, 3);
    ui::place(encodeButton1, encodeButtons[0]);
    ui::place(encodeButton2, encodeButtons[1]);
    ui::place(encodeButton3, encodeButtons[2]);

    const std::vector<RECT> cancelButtons = column.centeredRow(120, 30, 4);
    ui::place(cancelButton1, cancelButtons[0]);
    ui::place(cancelButton2, cancelButtons[1]);
    ui::place(cancelButton3, cancelButtons[2]);
    ui::place(cancelButton4, cancelButtons[3]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::ConcurrentExecutionTab::onCommand(const int controlId, const int notification) {
    if (notification != BN_CLICKED) {
        return;
    }

    switch (controlId) {
    case IdEncode1: encodeVideo(1); break;
    case IdEncode2: encodeVideo(2); break;
    case IdEncode3: encodeVideo(3); break;
    case IdCancel1: cancel(1); break;
    case IdCancel2: cancel(2); break;
    case IdCancel3: cancel(3); break;
    case IdCancelAll: cancel(0); break;
    default: break;
    }
}

void ffmpegkittest::ConcurrentExecutionTab::setActive() {
    std::cout << "Concurrent Execution Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback([this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    });
}

void ffmpegkittest::ConcurrentExecutionTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::ConcurrentExecutionTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::ConcurrentExecutionTab::encodeVideo(const int buttonNumber) {
    clearOutput();

    std::string image1File = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string image2File = Application::getApplicationInstallDirectory() + "/share/images/lake.jpg";
    std::string image3File = Application::getApplicationInstallDirectory() + "/share/images/sunset.jpg";
    std::string videoFile = Application::getApplicationCacheDirectory() + "/video" + std::to_string(buttonNumber) + ".mp4";

    std::cout << "Testing CONCURRENT EXECUTION for button " << buttonNumber << "." << std::endl;

    std::string ffmpegCommand = Video::generateEncodeVideoScript(image1File, image2File, image3File, videoFile, "mpeg4", "");

    std::cout << "FFmpeg process starting for button " << buttonNumber << " with arguments: '" << ffmpegCommand << "'." << std::endl;

    auto session = FFmpegKit::executeAsync(ffmpegCommand, [this, buttonNumber](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();

        if (ReturnCode::isCancel(returnCode)) {
            std::cout << "FFmpeg process ended with cancel for button " << buttonNumber << " with sessionId " << session->getSessionId() << "." << std::endl;
        } else {
            std::cout << "FFmpeg process ended with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << " for button " << buttonNumber << " with sessionId " << session->getSessionId() << "." << session->getFailStackTrace() << std::endl;
        }
    });

    const long sessionId = session->getSessionId();

    std::cout << "Async FFmpeg process started for button " << buttonNumber << " with sessionId " << session->getSessionId() << "." << std::endl;

    switch (buttonNumber) {
        case 1: {
            sessionId1 = sessionId;
        }
        break;
        case 2: {
            sessionId2 = sessionId;
        }
        break;
        default: {
            sessionId3 = sessionId;
        }
    }

    Application::listFFmpegSessions();
}

void ffmpegkittest::ConcurrentExecutionTab::cancel(const int buttonNumber) {
    long sessionId = 0;

    switch (buttonNumber) {
        case 1: {
            sessionId = sessionId1;
        }
        break;
        case 2: {
            sessionId = sessionId2;
        }
        break;
        case 3: {
            sessionId = sessionId3;
        }
    }

    std::cout << "Cancelling FFmpeg process for button " << buttonNumber << " with sessionId " << sessionId << "." << std::endl;

    if (sessionId == 0) {
        FFmpegKit::cancel();
    } else {
        FFmpegKit::cancel(sessionId);
    }
}

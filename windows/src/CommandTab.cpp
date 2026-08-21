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

#include "CommandTab.h"
#include "Application.h"
#include "Constants.h"
#include "Popup.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>
#include <FFprobeSession.h>

#include <iostream>

using namespace ffmpegkit;

void ffmpegkittest::CommandTab::onCreate() {
    commandText = ui::createEdit(hwnd, IdCommandText);
    ui::setCueBanner(commandText, L"Enter command");

    runFFmpegButton = ui::createButton(hwnd, IdRunFFmpeg, L"RUN FFMPEG");
    runFFprobeButton = ui::createButton(hwnd, IdRunFFprobe, L"RUN FFPROBE");
    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::CommandTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);
    ui::place(commandText, column.row(24));

    const std::vector<RECT> buttons = column.centeredRow(140, 30, 2);
    ui::place(runFFmpegButton, buttons[0]);
    ui::place(runFFprobeButton, buttons[1]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::CommandTab::onCommand(const int controlId, const int notification) {
    if (notification != BN_CLICKED) {
        return;
    }

    if (controlId == IdRunFFmpeg) {
        runFFmpeg();
    } else if (controlId == IdRunFFprobe) {
        runFFprobe();
    }
}

void ffmpegkittest::CommandTab::setActive() {
    std::cout << "Command Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
}

void ffmpegkittest::CommandTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::CommandTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::CommandTab::runFFmpeg() {
    clearOutput();

    std::string ffmpegCommand = ui::getControlText(commandText);

    std::cout << "Current log level is " << FFmpegKitConfig::logLevelToString(FFmpegKitConfig::getLogLevel()) << "." << std::endl;

    std::cout << "Testing FFmpeg COMMAND asynchronously." << std::endl;

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'" << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();

        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << "." << session->getFailStackTrace() << std::endl;

        if (state == SessionStateFailed || !returnCode->isValueSuccess()) {
            post([this]() {
                Popup::show(parentWindow, MessageTypeError, "Command failed. Please check output for the details.");
            });
        }
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

void ffmpegkittest::CommandTab::runFFprobe() {
    clearOutput();

    std::string ffprobeCommand = ui::getControlText(commandText);

    std::cout << "Testing FFprobe COMMAND asynchronously." << std::endl;

    std::cout << "FFprobe process started with arguments: '" << ffprobeCommand << "'" << std::endl;

    auto session = FFprobeSession::create(FFmpegKitConfig::parseArguments(ffprobeCommand.c_str()), [this](auto session) {
        const auto state = session->getState();
        auto returnCode = session->getReturnCode();

        const std::string output = session->getOutput();
        post([this, output]() { appendOutput(output); });

        std::cout << "FFprobe process exited with state " << FFmpegKitConfig::sessionStateToString(state) << " and rc " << returnCode << "." << session->getFailStackTrace() << std::endl;

        if (state == SessionStateFailed || !returnCode->isValueSuccess()) {
            post([this]() {
                Popup::show(parentWindow, MessageTypeError, "Command failed. Please check output for the details.");
            });
        }

    }, nullptr, LogRedirectionStrategyNeverPrintLogs);

    FFmpegKitConfig::asyncFFprobeExecute(session);

    ffmpegkittest::Application::listFFprobeSessions();
}

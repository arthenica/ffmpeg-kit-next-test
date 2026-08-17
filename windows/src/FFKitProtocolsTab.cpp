/*
 * Copyright (c) 2026 Taner Sener
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

#include "FFKitProtocolsTab.h"
#include "Application.h"
#include "Constants.h"
#include "Popup.h"
#include "Util.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>
#include <FFmpegKitInputBuffer.h>
#include <FFmpegKitOutputBuffer.h>
#include <FFprobeKit.h>

#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>

using namespace ffmpegkit;

static std::string ffkitEscapeDrawtextText(const std::string& text) {
    std::string escaped;
    for (const char c : text) {
        if (c == '\\') {
            escaped += "\\\\";
        } else if (c == '"') {
            escaped += "\\\"";
        } else if (c == '\'') {
            escaped += "'\\''";
        } else {
            escaped += c;
        }
    }
    return escaped;
}

static std::string ffkitBuildMemProtocolCommand(const std::string& inputUrl, const std::string& outputUrl, const std::string& fontPath, const std::string& text) {
    // The font path sits inside a filter option value, so its drive letter colon
    // has to be escaped. See Util::toFilterPath().
    std::string drawtext = "drawtext=fontfile=" + ffmpegkittest::Util::toFilterPath(fontPath) + ":text='" + ffkitEscapeDrawtextText(text) + "':x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5";
    return "-y -i " + inputUrl + " -vf \"" + drawtext + "\" -frames:v 1 -f image2 -c:v mjpeg -update 1 " + outputUrl;
}

static std::string ffkitHumanReadableByteCount(const long bytes) {
    std::ostringstream out;
    if (bytes < 1024) {
        out << bytes << " B";
        return out.str();
    }
    double kb = static_cast<double>(bytes) / 1024.0;
    out.setf(std::ios::fixed);
    out.precision(1);
    if (kb < 1024) {
        out << kb << " KB";
    } else {
        out << (kb / 1024.0) << " MB";
    }
    return out.str();
}

static std::string ffkitFormatStatus(const std::string& inputUrl, const long inputSize, const std::string& outputUrl, const long outputSize) {
    return "in " + inputUrl + " (" + ffkitHumanReadableByteCount(inputSize) + ") -> drawtext -> out " + outputUrl + " (" + ffkitHumanReadableByteCount(outputSize) + ")";
}

void ffmpegkittest::FFKitProtocolsTab::onCreate() {
    protocolCombo = ui::createComboBox(hwnd, IdProtocol);
    initProtocolData();

    overlayText = ui::createEdit(hwnd, IdOverlayText);
    ui::setCueBanner(overlayText, L"Overlay text");
    ui::setControlText(overlayText, "FFmpegKitNext");

    runFFmpegButton = ui::createButton(hwnd, IdRunFFmpeg, L"RUN FFMPEG");
    runFFprobeButton = ui::createButton(hwnd, IdRunFFprobe, L"RUN FFPROBE");

    viewButton = ui::createButton(hwnd, IdView, L"VIEW");
    ui::setEnabled(viewButton, false);

    statusLabel = ui::createLabel(hwnd, IdStatus, L"");
    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::FFKitProtocolsTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);
    ui::place(protocolCombo, column.centeredComboBox(240, 28, 200));
    ui::place(overlayText, column.row(24));

    const std::vector<RECT> buttons = column.centeredRow(150, 30, 3);
    ui::place(runFFmpegButton, buttons[0]);
    ui::place(runFFprobeButton, buttons[1]);
    ui::place(viewButton, buttons[2]);

    ui::place(statusLabel, column.row(20));
    ui::place(outputText, column.remaining());
}

void ffmpegkittest::FFKitProtocolsTab::onCommand(const int controlId, const int notification) {
    if (controlId == IdProtocol && notification == CBN_SELCHANGE) {
        const int selection = ui::comboGetSelection(protocolCombo);
        if (selection == 0) {
            selectedProtocol = "ffkitmem";
        } else if (selection == 1) {
            selectedProtocol = "ffkitstream";
        }
        return;
    }

    if (notification != BN_CLICKED) {
        return;
    }

    if (controlId == IdRunFFmpeg) {
        runFFmpeg();
    } else if (controlId == IdRunFFprobe) {
        runFFprobe();
    } else if (controlId == IdView) {
        openProducedImage();
    }
}

void ffmpegkittest::FFKitProtocolsTab::setActive() {
    std::cout << "FFKit Protocols Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::FFKitProtocolsTab::initProtocolData() {
    ui::comboAddItem(protocolCombo, "ffkitmem");
    ui::comboAddItem(protocolCombo, "ffkitstream");
    ui::comboSetSelection(protocolCombo, 0);
    selectedProtocol = "ffkitmem";
}

std::string ffmpegkittest::FFKitProtocolsTab::getSelectedProtocol() {
    return selectedProtocol;
}

void ffmpegkittest::FFKitProtocolsTab::showTextResult(const std::string& text) {
    ui::setControlText(outputText, text);
}

void ffmpegkittest::FFKitProtocolsTab::setStatus(const std::string& text) {
    ui::setControlText(statusLabel, text);
}

bool ffmpegkittest::FFKitProtocolsTab::chooseImage(std::vector<uint8_t>& outBytes) {
    std::string path;
    if (!Util::chooseImageFile(parentWindow, path)) {
        return false;
    }

    std::ifstream file(path, std::ios::binary);
    if (!file) {
        Popup::show(parentWindow, MessageTypeError, "Could not read the selected image.");
        return false;
    }

    outBytes.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
    if (outBytes.empty()) {
        Popup::show(parentWindow, MessageTypeError, "Could not read the selected image.");
        return false;
    }

    return true;
}

void ffmpegkittest::FFKitProtocolsTab::runFFmpeg() {
    if (getSelectedProtocol() != "ffkitmem") {
        Popup::show(parentWindow, MessageTypeInformation, "This protocol is not implemented yet.");
        return;
    }

    std::vector<uint8_t> bytes;
    if (!chooseImage(bytes)) {
        return;
    }

    runFFmpegMem(bytes);
}

void ffmpegkittest::FFKitProtocolsTab::runFFprobe() {
    if (getSelectedProtocol() != "ffkitmem") {
        Popup::show(parentWindow, MessageTypeInformation, "This protocol is not implemented yet.");
        return;
    }

    std::vector<uint8_t> bytes;
    if (!chooseImage(bytes)) {
        return;
    }

    runFFprobeMem(bytes);
}

void ffmpegkittest::FFKitProtocolsTab::runFFmpegMem(const std::vector<uint8_t>& bytes) {
    std::string fontPath = Application::getApplicationInstallDirectory() + "/share/fonts/doppioone_regular.ttf";

    auto input = FFmpegKitInputBuffer::fromByteArray(bytes, "jpg");
    auto output = FFmpegKitOutputBuffer::create("jpg");
    if (input == nullptr || output == nullptr) {
        Popup::show(parentWindow, MessageTypeError, "Could not create memory buffers.");
        return;
    }

    std::string command = ffkitBuildMemProtocolCommand(input->getUrl(), output->getUrl(), fontPath, ui::getControlText(overlayText));
    long inputSize = input->getSize();

    setStatus("Running...");
    std::cout << "ffkitmem ffmpeg command: " << command << std::endl;

    FFmpegKit::executeAsync(command, [this, input, output, inputSize](const std::shared_ptr<ffmpegkit::FFmpegSession> session) {
        auto returnCode = session->getReturnCode();
        const bool success = ReturnCode::isSuccess(returnCode);
        const long outputSize = output->getSize();
        const std::string inputUrl = input->getUrl();
        const std::string outputUrl = output->getUrl();

        const std::string summary = ffkitFormatStatus(inputUrl, inputSize, outputUrl, outputSize);

        std::string producedFile;
        if (success) {
            auto result = output->toByteArray();
            if (result != nullptr && !result->empty()) {
                producedFile = writeProducedImage(*result);
            }
        }

        post([this, success, summary, producedFile]() {
            showTextResult(summary);
            setStatus(success ? summary : std::string("Failed"));
            if (success) {
                lastProducedImageFile = producedFile;
                setViewButtonEnabled(!producedFile.empty());
            }
            if (!success) {
                Popup::show(parentWindow, MessageTypeError, "Protocol test failed. Please check logs for the details.");
            }
        });

        input->close();
        output->close();
    });
}

std::string ffmpegkittest::FFKitProtocolsTab::writeProducedImage(const std::vector<uint8_t>& bytes) {
    const std::string path = Application::getApplicationCacheDirectory() + "/ffkit_protocol_output.jpg";

    std::ofstream out(path, std::ios::binary);
    if (out) {
        out.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    }
    if (!out) {
        std::cout << "Failed to write produced image to " << path << "." << std::endl;
        return std::string();
    }

    return path;
}

void ffmpegkittest::FFKitProtocolsTab::setViewButtonEnabled(const bool enabled) {
    ui::setEnabled(viewButton, enabled);
}

void ffmpegkittest::FFKitProtocolsTab::openProducedImage() {
    if (lastProducedImageFile.empty()) {
        return;
    }

    if (!Util::openInSystemPlayer(lastProducedImageFile, parentWindow)) {
        Popup::show(parentWindow, MessageTypeInformation,
                    "No application is registered to open this image.\n\nIt was written to:\n" + lastProducedImageFile);
    }
}

void ffmpegkittest::FFKitProtocolsTab::runFFprobeMem(const std::vector<uint8_t>& bytes) {
    auto input = FFmpegKitInputBuffer::fromByteArray(bytes, "jpg");
    if (input == nullptr) {
        Popup::show(parentWindow, MessageTypeError, "Could not create memory buffer.");
        return;
    }

    std::string inputUrl = input->getUrl();
    std::string command = "-hide_banner -print_format json -show_format -show_streams " + inputUrl;

    setStatus("Running...");
    std::cout << "ffkitmem ffprobe command: " << command << std::endl;

    FFprobeKit::executeAsync(command, [this, input, inputUrl](const std::shared_ptr<ffmpegkit::FFprobeSession> session) {
        auto returnCode = session->getReturnCode();
        const bool success = ReturnCode::isSuccess(returnCode);
        const std::string out = session->getOutput();
        const std::string status = "ffprobe -> " + inputUrl;

        post([this, success, out, status]() {
            showTextResult(out);
            setStatus(status);
            if (!success) {
                Popup::show(parentWindow, MessageTypeError, "Protocol test failed. Please check logs for the details.");
            }
        });

        input->close();
    });
}

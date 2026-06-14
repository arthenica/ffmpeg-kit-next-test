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
#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>
#include <FFmpegKitInputBuffer.h>
#include <FFmpegKitOutputBuffer.h>
#include <FFprobeKit.h>
#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>
#include <utility>

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
    std::string drawtext = "drawtext=fontfile=" + fontPath + ":text='" + ffkitEscapeDrawtextText(text) + "':x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5";
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

namespace ffmpegkittest {

    struct ImageResultPayload {
        FFKitProtocolsTab* tab;
        std::vector<uint8_t> bytes;
        std::string status;
    };

    struct TextResultPayload {
        FFKitProtocolsTab* tab;
        std::string text;
        std::string status;
        bool error;
    };

}

static gboolean showProtocolFailedPopup(Gtk::Window* window) {
    ffmpegkittest::Popup::show(window, Gtk::MESSAGE_ERROR, "Processing failed. Please check output for the details.");
    return FALSE;
}

static gboolean applyImageResult(ffmpegkittest::ImageResultPayload* payload) {
    payload->tab->showImageResult(payload->bytes);
    payload->tab->setStatus(payload->status);
    delete payload;
    return FALSE;
}

static gboolean applyTextResult(ffmpegkittest::TextResultPayload* payload) {
    payload->tab->showTextResult(payload->text);
    payload->tab->setStatus(payload->status);
    delete payload;
    return FALSE;
}

ffmpegkittest::FFKitProtocolsTab::FFKitProtocolsTab() : selectedProtocol("ffkitmem"), parentWindow(nullptr) {
    protocolModel = Gtk::ListStore::create(protocolModelColumn);
    protocolCombo.set_model(protocolModel);
    protocolCombo.set_size_request(240, 30);
    protocolCombo.signal_changed().connect(sigc::mem_fun(*this, &FFKitProtocolsTab::onProtocolChanged));
    Util::applyComboBoxStyle(protocolCombo);

    initProtocolData();

    overlayText.set_text("FFmpegKitNext");
    overlayText.set_placeholder_text("Enter overlay text");
    Util::applyEditTextStyle(overlayText);

    runFFmpegButton.set_label("RUN FFMPEG");
    runFFmpegButton.set_size_request(120, 30);
    runFFmpegButton.set_tooltip_text(Constants::FFKitProtocolsTestFFmpegTooltipText);
    runFFmpegButton.signal_clicked().connect(sigc::mem_fun(*this, &FFKitProtocolsTab::runFFmpeg));
    Util::applyButtonStyle(runFFmpegButton);
    runFFmpegButtonBox.pack_start(runFFmpegButton, Gtk::PACK_EXPAND_PADDING);

    runFFprobeButton.set_label("RUN FFPROBE");
    runFFprobeButton.set_size_request(120, 30);
    runFFprobeButton.set_tooltip_text(Constants::FFKitProtocolsTestFFprobeTooltipText);
    runFFprobeButton.signal_clicked().connect(sigc::mem_fun(*this, &FFKitProtocolsTab::runFFprobe));
    Util::applyButtonStyle(runFFprobeButton);
    runFFprobeButtonBox.pack_start(runFFprobeButton, Gtk::PACK_EXPAND_PADDING);

    statusLabel.set_text("Select a protocol, then run FFmpeg or FFprobe.");
    statusLabel.set_line_wrap(true);

    resultImage.set_halign(Gtk::ALIGN_CENTER);
    resultImage.set_valign(Gtk::ALIGN_CENTER);
    resultImageWindow.add(resultImage);

    outputText.set_editable(false);
    Util::applyOutputTextStyle(outputText);
    outputTextWindow.add(outputText);

    resultStack.add(resultImageWindow, "image");
    resultStack.add(outputTextWindow, "output");
    resultStack.set_visible_child("output");

    pack_start(protocolComboBox, Gtk::PACK_SHRINK);
    protocolComboBox.pack_start(protocolCombo, Gtk::PACK_EXPAND_PADDING);
    pack_start(overlayText, Gtk::PACK_SHRINK);
    pack_start(runFFmpegButtonBox, Gtk::PACK_SHRINK);
    pack_start(runFFprobeButtonBox, Gtk::PACK_SHRINK);
    pack_start(statusLabel, Gtk::PACK_SHRINK);
    add(resultStack);
}

void ffmpegkittest::FFKitProtocolsTab::initProtocolData() {
    auto row = *(protocolModel->append());
    row[protocolModelColumn.columnId] = "1";
    row[protocolModelColumn.columnName] = "ffkitmem";

    protocolCombo.pack_start(protocolModelColumn.columnName);
    protocolCombo.set_entry_text_column(protocolModelColumn.columnId);
    protocolCombo.set_active(0);
}

void ffmpegkittest::FFKitProtocolsTab::onProtocolChanged() {
    int rowNumber = protocolCombo.get_active_row_number();
    if (rowNumber != -1) {
        Gtk::TreeModel::iterator iter = protocolCombo.get_active();
        if (iter) {
            Gtk::TreeModel::Row row = *iter;
            Glib::ustring name = row[protocolModelColumn.columnName];
            selectedProtocol = name;
        }
    }
}

std::string ffmpegkittest::FFKitProtocolsTab::getSelectedProtocol() {
    return selectedProtocol;
}

void ffmpegkittest::FFKitProtocolsTab::setParentWindow(Gtk::Window* parentWindow) {
    this->parentWindow = parentWindow;
}

void ffmpegkittest::FFKitProtocolsTab::setActive() {
    std::cout << "FFKitProtocols Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

bool ffmpegkittest::FFKitProtocolsTab::chooseImage(std::vector<uint8_t>& outBytes) {
    Gtk::FileChooserDialog dialog("Select an image", Gtk::FILE_CHOOSER_ACTION_OPEN);
    if (parentWindow != nullptr) {
        dialog.set_transient_for(*parentWindow);
    }
    dialog.add_button("_Cancel", Gtk::RESPONSE_CANCEL);
    dialog.add_button("_Open", Gtk::RESPONSE_OK);

    auto filter = Gtk::FileFilter::create();
    filter->set_name("Images");
    filter->add_mime_type("image/jpeg");
    filter->add_mime_type("image/png");
    filter->add_pattern("*.jpg");
    filter->add_pattern("*.jpeg");
    filter->add_pattern("*.png");
    dialog.add_filter(filter);

    if (dialog.run() != Gtk::RESPONSE_OK) {
        return false;
    }

    std::string filename = dialog.get_filename();
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_ERROR, "Could not read the selected image.");
        return false;
    }

    outBytes.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
    if (outBytes.empty()) {
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_ERROR, "Could not read the selected image.");
        return false;
    }

    return true;
}

void ffmpegkittest::FFKitProtocolsTab::runFFmpeg() {
    if (getSelectedProtocol() != "ffkitmem") {
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_INFO, "This protocol is not implemented yet.");
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
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_INFO, "This protocol is not implemented yet.");
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
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_ERROR, "Could not create memory buffers.");
        return;
    }

    std::string command = ffkitBuildMemProtocolCommand(input->getUrl(), output->getUrl(), fontPath, overlayText.get_text());
    long inputSize = input->getSize();

    setStatus("Running...");
    std::cout << "ffkitmem ffmpeg command: " << command << std::endl;

    FFmpegKit::executeAsync(command, [this, input, output, inputSize](const std::shared_ptr<ffmpegkit::FFmpegSession> session) {
        auto returnCode = session->getReturnCode();
        if (ReturnCode::isSuccess(returnCode)) {
            auto result = output->toByteArray();
            long outputSize = output->getSize();
            if (result != nullptr && !result->empty()) {
                auto payload = new ImageResultPayload();
                payload->tab = this;
                payload->bytes = *result;
                payload->status = ffkitFormatStatus(input->getUrl(), inputSize, output->getUrl(), outputSize);
                g_idle_add((GSourceFunc)applyImageResult, payload);
            } else {
                auto payload = new TextResultPayload();
                payload->tab = this;
                payload->text = "FFmpeg succeeded but the output image could not be decoded.";
                payload->status = "Decode failed.";
                payload->error = true;
                g_idle_add((GSourceFunc)applyTextResult, payload);
                g_idle_add((GSourceFunc)showProtocolFailedPopup, this->parentWindow);
            }
        } else {
            std::string logs = session->getAllLogsAsString();
            std::cout << "ffkitmem ffmpeg failed: " << logs << std::endl;
            auto payload = new TextResultPayload();
            payload->tab = this;
            payload->text = logs;
            payload->status = "Processing failed.";
            payload->error = true;
            g_idle_add((GSourceFunc)applyTextResult, payload);
            g_idle_add((GSourceFunc)showProtocolFailedPopup, this->parentWindow);
        }

        input->close();
        output->close();
    });
}

void ffmpegkittest::FFKitProtocolsTab::runFFprobeMem(const std::vector<uint8_t>& bytes) {
    auto input = FFmpegKitInputBuffer::fromByteArray(bytes, "jpg");
    if (input == nullptr) {
        ffmpegkittest::Popup::show(parentWindow, Gtk::MESSAGE_ERROR, "Could not create memory buffer.");
        return;
    }

    std::string inputUrl = input->getUrl();
    std::string command = "-hide_banner -print_format json -show_format -show_streams " + inputUrl;

    setStatus("Running...");
    std::cout << "ffkitmem ffprobe command: " << command << std::endl;

    FFprobeKit::executeAsync(command, [this, input, inputUrl](const std::shared_ptr<ffmpegkit::FFprobeSession> session) {
        auto returnCode = session->getReturnCode();
        bool success = ReturnCode::isSuccess(returnCode);
        std::string out = session->getOutput();

        auto payload = new TextResultPayload();
        payload->tab = this;
        payload->text = out;
        payload->status = "ffprobe -> " + inputUrl;
        payload->error = !success;
        g_idle_add((GSourceFunc)applyTextResult, payload);

        if (!success) {
            g_idle_add((GSourceFunc)showProtocolFailedPopup, this->parentWindow);
        }

        input->close();
    });
}

void ffmpegkittest::FFKitProtocolsTab::showImageResult(const std::vector<uint8_t>& bytes) {
    try {
        auto loader = Gdk::PixbufLoader::create();
        loader->write(bytes.data(), bytes.size());
        loader->close();
        resultImage.set(loader->get_pixbuf());
    } catch (const Glib::Error& error) {
        showTextResult("The processed image could not be decoded.");
        return;
    }

    resultStack.set_visible_child("image");
}

void ffmpegkittest::FFKitProtocolsTab::showTextResult(const std::string& text) {
    outputText.get_buffer()->set_text(text);
    resultStack.set_visible_child("output");
}

void ffmpegkittest::FFKitProtocolsTab::setStatus(const std::string& text) {
    statusLabel.set_text(text);
}

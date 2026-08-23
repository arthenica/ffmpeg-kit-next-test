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

#include "Application.h"
#include "HttpsTab.h"
#include "Constants.h"
#include "Popup.h"
#include <AbstractSession.h>
#include <FFmpegKitConfig.h>
#include <cstdlib>
#include <json/Value.h>

using namespace ffmpegkit;

static std::recursive_mutex outputMutex;

static std::string escapeJsonString(const std::string& value) {
    std::string escaped;
    for (const char character : value) {
        switch (character) {
            case '"': escaped += "\\\""; break;
            case '\\': escaped += "\\\\"; break;
            case '\b': escaped += "\\b"; break;
            case '\f': escaped += "\\f"; break;
            case '\n': escaped += "\\n"; break;
            case '\r': escaped += "\\r"; break;
            case '\t': escaped += "\\t"; break;
            default: escaped += character; break;
        }
    }
    return escaped;
}

std::string toString(const ffmpegkit::json::Value& value) {
    switch (value.getType()) {
        case ffmpegkit::json::Value::Type::Null:
            return "null";
        case ffmpegkit::json::Value::Type::Bool:
            return *value.getBool() ? "true" : "false";
        case ffmpegkit::json::Value::Type::Int:
            return std::to_string(*value.getInt());
        case ffmpegkit::json::Value::Type::Double:
            return std::to_string(*value.getDouble());
        case ffmpegkit::json::Value::Type::String:
            return "\"" + escapeJsonString(*value.getString()) + "\"";
        case ffmpegkit::json::Value::Type::Array: {
            const std::vector<ffmpegkit::json::Value>& elements = value.getArray();
            std::string serialized("[");
            for (auto element = elements.cbegin(); element != elements.cend(); ++element) {
                if (element != elements.cbegin()) {
                    serialized += ",";
                }
                serialized += toString(*element);
            }
            return serialized + "]";
        }
        case ffmpegkit::json::Value::Type::Object: {
            const std::map<std::string, ffmpegkit::json::Value>& members = value.getObject();
            std::string serialized("{");
            for (auto member = members.cbegin(); member != members.cend(); ++member) {
                if (member != members.cbegin()) {
                    serialized += ",";
                }
                serialized += "\"" + escapeJsonString(member->first) + "\":" + toString(member->second);
            }
            return serialized + "}";
        }
    }
    return "null";
}

static gboolean appendLog(const std::pair<ffmpegkittest::HttpsTab*,const std::string>* parameters) {
    ffmpegkittest::HttpsTab* httpsTab = parameters->first;
    auto string = parameters->second;
    httpsTab->appendOutput(string);
    delete parameters;
    return FALSE;
}

void appendLogToMainLoop(const ffmpegkittest::HttpsTab* httpsTab,const std::string string) {
    g_idle_add((GSourceFunc)appendLog, new std::pair<const ffmpegkittest::HttpsTab*,const std::string>(httpsTab, string));
}

ffmpegkittest::HttpsTab::HttpsTab() : parentWindow(nullptr) {
    urlText.set_placeholder_text("Enter https url");
    Util::applyEditTextStyle(urlText);

    getInfoFromUrlButton.set_label("GET INFO FROM URL");
    getInfoFromUrlButton.set_size_request(120, 30);
    getInfoFromUrlButton.set_tooltip_text(Constants::HttpsTestTooltipText);
    getInfoFromUrlButton.signal_clicked().connect(sigc::bind(sigc::mem_fun(*this, &HttpsTab::runGetMediaInformation), 1));
    Util::applyButtonStyle(getInfoFromUrlButton);
    getInfoFromUrlButtonBox.pack_start(getInfoFromUrlButton, Gtk::PACK_EXPAND_PADDING);

    getRandomInfoButton1.set_label("GET RANDOM INFO");
    getRandomInfoButton1.set_size_request(120, 30);
    getRandomInfoButton1.signal_clicked().connect(sigc::bind(sigc::mem_fun(*this, &HttpsTab::runGetMediaInformation), 2));
    Util::applyButtonStyle(getRandomInfoButton1);
    getRandomInfoButton1Box.pack_start(getRandomInfoButton1, Gtk::PACK_EXPAND_PADDING);

    getRandomInfoButton2.set_label("GET RANDOM INFO");
    getRandomInfoButton2.set_size_request(120, 30);
    getRandomInfoButton2.signal_clicked().connect(sigc::bind(sigc::mem_fun(*this, &HttpsTab::runGetMediaInformation), 3));
    Util::applyButtonStyle(getRandomInfoButton2);
    getRandomInfoButton2Box.pack_start(getRandomInfoButton2, Gtk::PACK_EXPAND_PADDING);

    getInfoAndFailButton.set_label("GET INFO AND FAIL");
    getInfoAndFailButton.set_size_request(120, 30);

    getInfoAndFailButton.signal_clicked().connect(sigc::bind(sigc::mem_fun(*this, &HttpsTab::runGetMediaInformation), 4));
    Util::applyButtonStyle(getInfoAndFailButton);
    getInfoAndFailButtonBox.pack_start(getInfoAndFailButton, Gtk::PACK_EXPAND_PADDING);

    outputText.set_editable(false);
    Util::applyOutputTextStyle(outputText);
    outputTextWindow.add(outputText);

    pack_start(urlText, Gtk::PACK_SHRINK);
    pack_start(getInfoFromUrlButtonBox, Gtk::PACK_SHRINK);
    pack_start(getRandomInfoButton1Box, Gtk::PACK_SHRINK);
    pack_start(getRandomInfoButton2Box, Gtk::PACK_SHRINK);
    pack_start(getInfoAndFailButtonBox, Gtk::PACK_SHRINK);
    add(outputTextWindow);
}

void ffmpegkittest::HttpsTab::setActive() {
    std::cout << "Https Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::HttpsTab::setParentWindow(Gtk::Window* parentWindow) {
    this->parentWindow = parentWindow;
}

void ffmpegkittest::HttpsTab::appendOutput(const std::string& string) {
    outputText.get_buffer()->set_text(outputText.get_buffer()->get_text() + string);
    Glib::RefPtr<Gtk::Adjustment> adj = outputText.get_vadjustment();
    adj->set_value(adj->get_upper());
}

void ffmpegkittest::HttpsTab::clearOutput() {
    outputText.get_buffer()->set_text("");
}

void ffmpegkittest::HttpsTab::runGetMediaInformation(const int buttonNumber) {

    // SELECT TEST URL
    std::string testUrl;
    switch (buttonNumber) {
        case 1: {
            testUrl = urlText.get_text();
            if (testUrl.empty()) {
                testUrl = HttpsTestDefaultUrl;
                urlText.set_text(testUrl);
            }
        }
        break;
        case 2:
        case 3: {
            testUrl = getRandomTestUrl();
        }
        break;
        case 4:
        default: {
            testUrl = HttpsTestFailUrl;
            urlText.set_text(testUrl);
        }
    }

    std::cout << "Testing HTTPS with custom ca bundle for button " << buttonNumber << " using url " << testUrl << "." << std::endl;

    if (buttonNumber == 4) {

        // ONLY THIS BUTTON CLEARS THE TEXT VIEW
        clearOutput();
    }

    std::string caCertificateBundlePath = Application::getCACertificateBundlePath();

    // GET MEDIA INFORMATION USING A CUSTOM COMMAND WITH A CA CERTIFICATE BUNDLE
    // PROVIDING A CA CERTIFICATE BUNDLE IS REQUIRED BY OPENSSL ON LINUX UNLESS "-tls_verify 0" IS PROVIDED FOR FFMPEG 9+
    std::shared_ptr<ffmpegkit::MediaInformationSession> mediaInformationSession = MediaInformationSession::create(
        std::list<std::string>{"-v", "error", "-hide_banner", "-print_format", "json", "-show_format",
               "-show_streams", "-show_chapters", "-ca_file", caCertificateBundlePath, "-i", testUrl
        },
        createNewCompleteCallback()
    );

    FFmpegKitConfig::asyncGetMediaInformationExecute(mediaInformationSession, AbstractSession::DefaultTimeoutForAsynchronousMessagesInTransmit);
}

std::string ffmpegkittest::HttpsTab::getRandomTestUrl() {
    switch (std::rand() % 3) {
        case 0:
            return HttpsTestRandomUrl1;
        case 1:
            return HttpsTestRandomUrl2;
        default:
            return HttpsTestRandomUrl3;
    }
}

MediaInformationSessionCompleteCallback ffmpegkittest::HttpsTab::createNewCompleteCallback() {
    return [this](auto session) {
        std::unique_lock<std::recursive_mutex> lock(outputMutex);
        auto information = session->getMediaInformation();
        if (information == nullptr) {
            appendLogToMainLoop(this, "Get media information failed\n");
            appendLogToMainLoop(this, "State: " + FFmpegKitConfig::sessionStateToString(session->getState()) + "\n");
            appendLogToMainLoop(this, "Duration: " + std::to_string(session->getDuration()) + "\n");
            if (session->getReturnCode() != nullptr) {
                appendLogToMainLoop(this, "Return Code: " + std::to_string(session->getReturnCode()->getValue()) + "\n");
            }
            appendLogToMainLoop(this, "Fail stack trace: " + session->getFailStackTrace() + "\n");
            appendLogToMainLoop(this, "Output: " + session->getOutput() + "\n");
        } else {
            if (information->getFilename() != nullptr) {
                appendLogToMainLoop(this, "Media information for " + *information->getFilename() + "\n");
            }
            if (information->getFormat() != nullptr) {
                appendLogToMainLoop(this, "Format: " + *information->getFormat() + "\n");
            }
            if (information->getBitrate() != nullptr) {
                appendLogToMainLoop(this, "Bitrate: " + *information->getBitrate() + "\n");
            }
            if (information->getDuration() != nullptr) {
                appendLogToMainLoop(this, "Duration: " + *information->getDuration() + "\n");
            }
            if (information->getStartTime() != nullptr) {
                appendLogToMainLoop(this, "Start time: " + *information->getStartTime() + "\n");
            }
            if (information->getTags() != nullptr) {
                auto tags = information->getTags();
                for (const auto& tag : tags->getObject()) {
                    appendLogToMainLoop(this, std::string("Tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                }
            }
            if (information->getStreams() != nullptr) {
                auto streams = information->getStreams();
                std::for_each(streams->cbegin(), streams->cend(), [this](const std::shared_ptr<ffmpegkit::StreamInformation>& stream) {
                    if (stream->getIndex() != nullptr) {
                        appendLogToMainLoop(this, "Stream index: " + std::to_string(*stream->getIndex()) + "\n");
                    }
                    if (stream->getType() != nullptr) {
                        appendLogToMainLoop(this, "Stream type: " + *stream->getType() + "\n");
                    }
                    if (stream->getCodec() != nullptr) {
                        appendLogToMainLoop(this, "Stream codec: " + *stream->getCodec() + "\n");
                    }
                    if (stream->getCodecLong() != nullptr) {
                        appendLogToMainLoop(this, "Stream codec long: " + *stream->getCodecLong() + "\n");
                    }
                    if (stream->getFormat() != nullptr) {
                        appendLogToMainLoop(this, "Stream format: " + *stream->getFormat() + "\n");
                    }

                    if (stream->getWidth() != nullptr) {
                        appendLogToMainLoop(this, "Stream width: " + std::to_string(*stream->getWidth()) + "\n");
                    }
                    if (stream->getHeight() != nullptr) {
                        appendLogToMainLoop(this, "Stream height: " + std::to_string(*stream->getHeight()) + "\n");
                    }

                    if (stream->getBitrate() != nullptr) {
                        appendLogToMainLoop(this, "Stream bitrate: " + *stream->getBitrate() + "\n");
                    }
                    if (stream->getSampleRate() != nullptr) {
                        appendLogToMainLoop(this, "Stream sample rate: " + *stream->getSampleRate() + "\n");
                    }
                    if (stream->getSampleFormat() != nullptr) {
                        appendLogToMainLoop(this, "Stream sample format: " + *stream->getSampleFormat() + "\n");
                    }
                    if (stream->getChannelLayout() != nullptr) {
                        appendLogToMainLoop(this, "Stream channel layout: " + *stream->getChannelLayout() + "\n");
                    }

                    if (stream->getSampleAspectRatio() != nullptr) {
                        appendLogToMainLoop(this, "Stream sample aspect ratio: " + *stream->getSampleAspectRatio() + "\n");
                    }
                    if (stream->getDisplayAspectRatio() != nullptr) {
                        appendLogToMainLoop(this, "Stream display ascpect ratio: " + *stream->getDisplayAspectRatio() + "\n");
                    }
                    if (stream->getAverageFrameRate() != nullptr) {
                        appendLogToMainLoop(this, "Stream average frame rate: " + *stream->getAverageFrameRate() + "\n");
                    }
                    if (stream->getRealFrameRate() != nullptr) {
                        appendLogToMainLoop(this, "Stream real frame rate: " + *stream->getRealFrameRate() + "\n");
                    }
                    if (stream->getTimeBase() != nullptr) {
                        appendLogToMainLoop(this, "Stream time base: " + *stream->getTimeBase() + "\n");
                    }
                    if (stream->getCodecTimeBase() != nullptr) {
                        appendLogToMainLoop(this, "Stream codec time base: " + *stream->getCodecTimeBase() + "\n");
                    }

                    if (stream->getTags() != nullptr) {
                        auto tags = stream->getTags();
                        for (const auto& tag : tags->getObject()) {
                            appendLogToMainLoop(this, std::string("Stream tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                        }
                    }
                });
            }

            if (information->getChapters() != nullptr) {
                auto chapters = information->getChapters();
                std::for_each(chapters->cbegin(), chapters->cend(), [this](const std::shared_ptr<ffmpegkit::Chapter>& chapter) {
                    if (chapter->getId() != nullptr) {
                        appendLogToMainLoop(this, "Chapter id: " + std::to_string(*chapter->getId()) + "\n");
                    }
                    if (chapter->getTimeBase() != nullptr) {
                        appendLogToMainLoop(this, "Chapter time base: " + *chapter->getTimeBase() + "\n");
                    }
                    if (chapter->getStart() != nullptr) {
                        appendLogToMainLoop(this, "Chapter start: " + std::to_string(*chapter->getStart()) + "\n");
                    }
                    if (chapter->getStartTime() != nullptr) {
                        appendLogToMainLoop(this, "Chapter start time: " + *chapter->getStartTime() + "\n");
                    }
                    if (chapter->getEnd() != nullptr) {
                        appendLogToMainLoop(this, "Chapter end: " + std::to_string(*chapter->getEnd()) + "\n");
                    }
                    if (chapter->getEndTime() != nullptr) {
                        appendLogToMainLoop(this, "Chapter end time: " + *chapter->getEndTime() + "\n");
                    }
                    if (chapter->getTags() != nullptr) {
                        auto tags = chapter->getTags();
                        for (const auto& tag : tags->getObject()) {
                            appendLogToMainLoop(this, std::string("Chapter tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                        }
                    }
                });
            }
        }
    };
}
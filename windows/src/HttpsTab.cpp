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
#include "Win32Ui.h"

#include <AbstractSession.h>
#include <FFprobeKit.h>
#include <FFmpegKitConfig.h>
#include <json/Value.h>

#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <mutex>

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


/** Marshals one line of media information onto the UI thread. */
static void appendLogToUi(ffmpegkittest::HttpsTab* httpsTab, const std::string& text) {
    httpsTab->post([httpsTab, text]() { httpsTab->appendOutput(text); });
}

void ffmpegkittest::HttpsTab::onCreate() {
    urlText = ui::createEdit(hwnd, IdUrlText);
    ui::setCueBanner(urlText, L"Enter https url");

    getInfoFromUrlButton = ui::createButton(hwnd, IdGetInfoFromUrl, L"GET INFO FROM URL");
    getRandomInfoButton1 = ui::createButton(hwnd, IdGetRandomInfo1, L"GET RANDOM INFO");
    getRandomInfoButton2 = ui::createButton(hwnd, IdGetRandomInfo2, L"GET RANDOM INFO");
    getInfoAndFailButton = ui::createButton(hwnd, IdGetInfoAndFail, L"GET INFO AND FAIL");

    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::HttpsTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);
    ui::place(urlText, column.row(24));

    const std::vector<RECT> buttons = column.centeredRow(160, 30, 4);
    ui::place(getInfoFromUrlButton, buttons[0]);
    ui::place(getRandomInfoButton1, buttons[1]);
    ui::place(getRandomInfoButton2, buttons[2]);
    ui::place(getInfoAndFailButton, buttons[3]);

    ui::place(outputText, column.remaining());
}

void ffmpegkittest::HttpsTab::onCommand(const int controlId, const int notification) {
    if (notification != BN_CLICKED) {
        return;
    }

    switch (controlId) {
    case IdGetInfoFromUrl: runGetMediaInformation(1); break;
    case IdGetRandomInfo1: runGetMediaInformation(2); break;
    case IdGetRandomInfo2: runGetMediaInformation(3); break;
    case IdGetInfoAndFail: runGetMediaInformation(4); break;
    default: break;
    }
}

void ffmpegkittest::HttpsTab::setActive() {
    std::cout << "Https Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::HttpsTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::HttpsTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::HttpsTab::runGetMediaInformation(const int buttonNumber) {

    // SELECT TEST URL
    std::string testUrl;
    switch (buttonNumber) {
        case 1: {
            testUrl = ui::getControlText(urlText);
            if (testUrl.empty()) {
                testUrl = HttpsTestDefaultUrl;
                ui::setControlText(urlText, testUrl);
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
            ui::setControlText(urlText, testUrl);
        }
    }

    std::cout << "Testing HTTPS with custom ca bundle for button " << buttonNumber << " using url " << testUrl << "." << std::endl;

    if (buttonNumber == 4) {

        // ONLY THIS BUTTON CLEARS THE TEXT VIEW
        clearOutput();
    }

    std::string caCertificateBundlePath = Application::getCACertificateBundlePath();

    // GET MEDIA INFORMATION USING A CUSTOM COMMAND WITH A CA CERTIFICATE BUNDLE
    // PROVIDING A CA CERTIFICATE BUNDLE IS REQUIRED BY OPENSSL ON WINDOWS UNLESS "-tls_verify 0" IS PROVIDED FOR FFMPEG 9+
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

ffmpegkit::MediaInformationSessionCompleteCallback ffmpegkittest::HttpsTab::createNewCompleteCallback() {
    return [this](auto session) {
        std::unique_lock<std::recursive_mutex> lock(outputMutex);
        auto information = session->getMediaInformation();
        if (information == nullptr) {
            appendLogToUi(this, "Get media information failed\n");
            appendLogToUi(this, "State: " + FFmpegKitConfig::sessionStateToString(session->getState()) + "\n");
            appendLogToUi(this, "Duration: " + std::to_string(session->getDuration()) + "\n");
            if (session->getReturnCode() != nullptr) {
                appendLogToUi(this, "Return Code: " + std::to_string(session->getReturnCode()->getValue()) + "\n");
            }
            appendLogToUi(this, "Fail stack trace: " + session->getFailStackTrace() + "\n");
            appendLogToUi(this, "Output: " + session->getOutput() + "\n");
        } else {
            if (information->getFilename() != nullptr) {
                appendLogToUi(this, "Media information for " + *information->getFilename() + "\n");
            }
            if (information->getFormat() != nullptr) {
                appendLogToUi(this, "Format: " + *information->getFormat() + "\n");
            }
            if (information->getBitrate() != nullptr) {
                appendLogToUi(this, "Bitrate: " + *information->getBitrate() + "\n");
            }
            if (information->getDuration() != nullptr) {
                appendLogToUi(this, "Duration: " + *information->getDuration() + "\n");
            }
            if (information->getStartTime() != nullptr) {
                appendLogToUi(this, "Start time: " + *information->getStartTime() + "\n");
            }
            if (information->getTags() != nullptr) {
                auto tags = information->getTags();
                for (const auto& tag : tags->getObject()) {
                    appendLogToUi(this, std::string("Tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                }
            }
            if (information->getStreams() != nullptr) {
                auto streams = information->getStreams();
                std::for_each(streams->cbegin(), streams->cend(), [this](const std::shared_ptr<ffmpegkit::StreamInformation>& stream) {
                    if (stream->getIndex() != nullptr) {
                        appendLogToUi(this, "Stream index: " + std::to_string(*stream->getIndex()) + "\n");
                    }
                    if (stream->getType() != nullptr) {
                        appendLogToUi(this, "Stream type: " + *stream->getType() + "\n");
                    }
                    if (stream->getCodec() != nullptr) {
                        appendLogToUi(this, "Stream codec: " + *stream->getCodec() + "\n");
                    }
                    if (stream->getCodecLong() != nullptr) {
                        appendLogToUi(this, "Stream codec long: " + *stream->getCodecLong() + "\n");
                    }
                    if (stream->getFormat() != nullptr) {
                        appendLogToUi(this, "Stream format: " + *stream->getFormat() + "\n");
                    }

                    if (stream->getWidth() != nullptr) {
                        appendLogToUi(this, "Stream width: " + std::to_string(*stream->getWidth()) + "\n");
                    }
                    if (stream->getHeight() != nullptr) {
                        appendLogToUi(this, "Stream height: " + std::to_string(*stream->getHeight()) + "\n");
                    }

                    if (stream->getBitrate() != nullptr) {
                        appendLogToUi(this, "Stream bitrate: " + *stream->getBitrate() + "\n");
                    }
                    if (stream->getSampleRate() != nullptr) {
                        appendLogToUi(this, "Stream sample rate: " + *stream->getSampleRate() + "\n");
                    }
                    if (stream->getSampleFormat() != nullptr) {
                        appendLogToUi(this, "Stream sample format: " + *stream->getSampleFormat() + "\n");
                    }
                    if (stream->getChannelLayout() != nullptr) {
                        appendLogToUi(this, "Stream channel layout: " + *stream->getChannelLayout() + "\n");
                    }

                    if (stream->getSampleAspectRatio() != nullptr) {
                        appendLogToUi(this, "Stream sample aspect ratio: " + *stream->getSampleAspectRatio() + "\n");
                    }
                    if (stream->getDisplayAspectRatio() != nullptr) {
                        appendLogToUi(this, "Stream display ascpect ratio: " + *stream->getDisplayAspectRatio() + "\n");
                    }
                    if (stream->getAverageFrameRate() != nullptr) {
                        appendLogToUi(this, "Stream average frame rate: " + *stream->getAverageFrameRate() + "\n");
                    }
                    if (stream->getRealFrameRate() != nullptr) {
                        appendLogToUi(this, "Stream real frame rate: " + *stream->getRealFrameRate() + "\n");
                    }
                    if (stream->getTimeBase() != nullptr) {
                        appendLogToUi(this, "Stream time base: " + *stream->getTimeBase() + "\n");
                    }
                    if (stream->getCodecTimeBase() != nullptr) {
                        appendLogToUi(this, "Stream codec time base: " + *stream->getCodecTimeBase() + "\n");
                    }

                    if (stream->getTags() != nullptr) {
                        auto tags = stream->getTags();
                        for (const auto& tag : tags->getObject()) {
                            appendLogToUi(this, std::string("Stream tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                        }
                    }
                });
            }

            if (information->getChapters() != nullptr) {
                auto chapters = information->getChapters();
                std::for_each(chapters->cbegin(), chapters->cend(), [this](const std::shared_ptr<ffmpegkit::Chapter>& chapter) {
                    if (chapter->getId() != nullptr) {
                        appendLogToUi(this, "Chapter id: " + std::to_string(*chapter->getId()) + "\n");
                    }
                    if (chapter->getTimeBase() != nullptr) {
                        appendLogToUi(this, "Chapter time base: " + *chapter->getTimeBase() + "\n");
                    }
                    if (chapter->getStart() != nullptr) {
                        appendLogToUi(this, "Chapter start: " + std::to_string(*chapter->getStart()) + "\n");
                    }
                    if (chapter->getStartTime() != nullptr) {
                        appendLogToUi(this, "Chapter start time: " + *chapter->getStartTime() + "\n");
                    }
                    if (chapter->getEnd() != nullptr) {
                        appendLogToUi(this, "Chapter end: " + std::to_string(*chapter->getEnd()) + "\n");
                    }
                    if (chapter->getEndTime() != nullptr) {
                        appendLogToUi(this, "Chapter end time: " + *chapter->getEndTime() + "\n");
                    }
                    if (chapter->getTags() != nullptr) {
                        auto tags = chapter->getTags();
                        for (const auto& tag : tags->getObject()) {
                            appendLogToUi(this, std::string("Chapter tag: ") + tag.first + ":" + toString(tag.second) + "\n");
                        }
                    }
                });
            }
        }
    };
}
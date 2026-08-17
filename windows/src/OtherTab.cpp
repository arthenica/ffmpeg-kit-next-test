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

#include "OtherTab.h"
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

void ffmpegkittest::OtherTab::onCreate() {
    test = ui::createComboBox(hwnd, IdTest);
    initTestData();

    runButton = ui::createButton(hwnd, IdRun, L"RUN");
    outputText = ui::createOutput(hwnd, IdOutput);
}

void ffmpegkittest::OtherTab::onLayout(const int width, const int height) {
    ui::Column column(width, height);
    ui::place(test, column.centeredComboBox(240, 28, 200));
    ui::place(runButton, column.centeredRow(140, 30));
    ui::place(outputText, column.remaining());
}

void ffmpegkittest::OtherTab::onCommand(const int controlId, const int notification) {
    if (controlId == IdTest && notification == CBN_SELCHANGE) {
        const int selection = ui::comboGetSelection(test);
        if (selection != -1) {
            selectedTest = selection;
        }
        return;
    }

    if (notification == BN_CLICKED && controlId == IdRun) {
        runTest();
    }
}

void ffmpegkittest::OtherTab::setActive() {
    std::cout << "Other Tab Activated" << std::endl;
    FFmpegKitConfig::enableLogCallback(nullptr);
    FFmpegKitConfig::enableStatisticsCallback(nullptr);
}

void ffmpegkittest::OtherTab::appendOutput(const std::string& text) {
    ui::appendControlText(outputText, text);
}

void ffmpegkittest::OtherTab::clearOutput() {
    ui::clearControlText(outputText);
}

void ffmpegkittest::OtherTab::initTestData() {
    ui::comboAddItem(test, "chromaprint");
    ui::comboAddItem(test, "dav1d");
    ui::comboAddItem(test, "webp");
    ui::comboAddItem(test, "libjxl");
    ui::comboAddItem(test, "zscale");
    ui::comboAddItem(test, "vvenc");
    ui::comboSetSelection(test, 0);
    selectedTest = 0;
}

std::string ffmpegkittest::OtherTab::getSelectedTest() {
    switch(selectedTest) {
        case 0: return "chromaprint";
        case 1: return "dav1d";
        case 2: return "webp";
        case 3: return "libjxl";
        case 4: return "zscale";
        case 5: return "vvenc";
        default: return "";
    }
}

void ffmpegkittest::OtherTab::runTest() {
    clearOutput();

    std::string selected = this->getSelectedTest();

    if (selected.compare("chromaprint") == 0) {
        testChromaprint();
    } else if (selected.compare("dav1d") == 0) {
        testDav1d();
    } else if (selected.compare("webp") == 0) {
        testWebp();
    } else if (selected.compare("libjxl") == 0) {
        testLibjxl();
    } else if (selected.compare("zscale") == 0) {
        testZscale();
    } else if (selected.compare("vvenc") == 0) {
        testVvenc();
    }
}

/** Popup helpers that hop back to the UI thread from an FFmpegKit callback. */
static void showSuccess(ffmpegkittest::OtherTab* tab, const std::string& message);
static void showFailure(ffmpegkittest::OtherTab* tab, const std::string& message);

void ffmpegkittest::OtherTab::testChromaprint() {
    std::cout << "Testing 'chromaprint' mutex." << std::endl;

    std::string audioSampleFile = getChromaprintSampleFile();
    std::remove(audioSampleFile.c_str());

    std::string ffmpegCommand = "-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le \"" + audioSampleFile + "\"";

    std::cout << "Creating audio sample with '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this,audioSampleFile](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            std::cout << "AUDIO sample created." << std::endl;

            std::string chromaprintCommand = "-hide_banner -y -i \"" + audioSampleFile + "\" -f chromaprint -fp_format 2 \"" + getChromaprintOutputFile() + "\"";

            std::cout << "FFmpeg process started with arguments: '" << chromaprintCommand << "'." << std::endl;

            FFmpegKit::executeAsync(chromaprintCommand, [this](auto secondSession) {
                std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(secondSession->getState()) << " and rc " << secondSession->getReturnCode() << "." << secondSession->getFailStackTrace() << std::endl;
                if (ReturnCode::isSuccess(secondSession->getReturnCode())) {
                    showSuccess(this, "Testing chromaprint completed successfully.");
                } else {
                    showFailure(this, "Testing chromaprint failed. Please check logs for the details.");
                }
            }, [this](auto log) {
                const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
            }, nullptr);

        } else {
            showFailure(this, "Creating AUDIO sample failed. Please check logs for the details.");
        }
    });
}

void ffmpegkittest::OtherTab::testDav1d() {
    std::cout << "Testing decoding 'av1' codec." << std::endl;

    std::string ffmpegCommand = std::string("-hide_banner -y -i ") + Dav1dTestDefaultUrl + " -c:v mpeg4 " + getDav1dOutputFile();

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

void ffmpegkittest::OtherTab::testWebp() {
    std::string imageFile = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string outputFile = Application::getApplicationCacheDirectory() + "/video.webp";

    std::cout << "Testing 'webp' codec." << std::endl;

    std::string ffmpegCommand = "-hide_banner -y -i \"" + imageFile + "\" \"" + outputFile + "\"";

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    auto session = FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            showSuccess(this, "Encode webp completed successfully.");
        } else {
            showFailure(this, "Encode webp failed. Please check logs for the details.");
        }
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

void ffmpegkittest::OtherTab::testZscale() {
    std::string videoFile = Application::getApplicationCacheDirectory() + "/video.mp4";
    std::string zscaledVideoFile = Application::getApplicationCacheDirectory() + "/video-zscaled.mp4";

    std::cout << "Testing 'zscale' filter with video file created on the Video tab." << std::endl;

    std::string ffmpegCommand = Video::generateZscaleVideoScript(videoFile, zscaledVideoFile);

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    auto session = FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            showSuccess(this, "zscale completed successfully.");
        } else {
            showFailure(this, "zscale failed. Please check logs for the details.");
        }
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

void ffmpegkittest::OtherTab::testLibjxl() {
    std::string imageFile = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string jxlOutputFile = getLibjxlOutputFile();
    std::string decodedOutputFile = getLibjxlDecodedOutputFile();

    std::remove(jxlOutputFile.c_str());
    std::remove(decodedOutputFile.c_str());

    std::cout << "Testing 'libjxl' codec." << std::endl;

    std::string ffmpegCommand = "-hide_banner -y -i \"" + imageFile + "\" -frames:v 1 -vf format=rgb24,setparams=range=pc:color_primaries=bt709:color_trc=iec61966-2-1:colorspace=gbr -c:v libjxl -distance 1.0 -xyb 1 -update 1 \"" + jxlOutputFile + "\"";

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this,jxlOutputFile,decodedOutputFile](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;

        if (ReturnCode::isSuccess(session->getReturnCode())) {
            std::string decodeCommand = "-hide_banner -y -i \"" + jxlOutputFile + "\" -frames:v 1 -c:v png -update 1 \"" + decodedOutputFile + "\"";

            std::cout << "FFmpeg process started with arguments: '" << decodeCommand << "'." << std::endl;

            FFmpegKit::executeAsync(decodeCommand, [](auto secondSession) {
                std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(secondSession->getState()) << " and rc " << secondSession->getReturnCode() << "." << secondSession->getFailStackTrace() << std::endl;
            }, [this](auto log) {
                const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
            }, nullptr);
        }
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

void ffmpegkittest::OtherTab::testVvenc() {
    std::string image1File = Application::getApplicationInstallDirectory() + "/share/images/tree.jpg";
    std::string image2File = Application::getApplicationInstallDirectory() + "/share/images/lake.jpg";
    std::string image3File = Application::getApplicationInstallDirectory() + "/share/images/sunset.jpg";
    std::string outputFile = getVvencOutputFile();

    std::remove(outputFile.c_str());

    std::cout << "Testing 'vvenc' codec." << std::endl;

    std::string ffmpegCommand = Video::generateEncodeVideoScript(image1File, image2File, image3File, outputFile, "libvvenc", "yuv420p10le", "-preset faster -qp 32 ");

    std::cout << "FFmpeg process started with arguments: '" << ffmpegCommand << "'." << std::endl;

    FFmpegKit::executeAsync(ffmpegCommand, [this](auto session) {
        std::cout << "FFmpeg process exited with state " << FFmpegKitConfig::sessionStateToString(session->getState()) << " and rc " << session->getReturnCode() << "." << session->getFailStackTrace() << std::endl;
    }, [this](auto log) {
        const std::string message = log->getMessage();
        post([this, message]() { appendOutput(message); });
    }, nullptr);
}

std::string ffmpegkittest::OtherTab::getChromaprintSampleFile() {
    return Application::getApplicationCacheDirectory() + "/audio-sample.wav";
}

std::string ffmpegkittest::OtherTab::getDav1dOutputFile() {
    return Application::getApplicationCacheDirectory() + "/video.mp4";
}

std::string ffmpegkittest::OtherTab::getChromaprintOutputFile() {
    return Application::getApplicationCacheDirectory() + "/chromaprint.txt";
}

std::string ffmpegkittest::OtherTab::getLibjxlOutputFile() {
    return Application::getApplicationCacheDirectory() + "/image.jxl";
}

std::string ffmpegkittest::OtherTab::getLibjxlDecodedOutputFile() {
    return Application::getApplicationCacheDirectory() + "/image.jxl.png";
}

std::string ffmpegkittest::OtherTab::getVvencOutputFile() {
    return Application::getApplicationCacheDirectory() + "/video.266";
}

static void showSuccess(ffmpegkittest::OtherTab* tab, const std::string& message) {
    tab->post([tab, message]() {
        ffmpegkittest::Popup::show(tab->getParentWindow(), ffmpegkittest::MessageTypeInformation, message);
    });
}

static void showFailure(ffmpegkittest::OtherTab* tab, const std::string& message) {
    tab->post([tab, message]() {
        ffmpegkittest::Popup::show(tab->getParentWindow(), ffmpegkittest::MessageTypeError, message);
    });
}

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

#ifndef FFMPEG_KIT_TEST_FFKIT_PROTOCOLS_TAB_H
#define FFMPEG_KIT_TEST_FFKIT_PROTOCOLS_TAB_H

#include "Util.h"
#include <gtkmm.h>
#include <cstdint>
#include <string>
#include <vector>

namespace ffmpegkittest {

    class FFKitProtocolsTab: public Gtk::VBox {
        public:
            FFKitProtocolsTab();
            void setActive();
            void setParentWindow(Gtk::Window* parentWindow);
            void showImageResult(const std::vector<uint8_t>& bytes);
            void showTextResult(const std::string& text);
            void setStatus(const std::string& text);

        private:
            void initProtocolData();
            void onProtocolChanged();
            std::string getSelectedProtocol();
            void runFFmpeg();
            void runFFprobe();
            void runFFmpegMem(const std::vector<uint8_t>& bytes);
            void runFFprobeMem(const std::vector<uint8_t>& bytes);
            bool chooseImage(std::vector<uint8_t>& outBytes);

            Glib::RefPtr<Gtk::ListStore> protocolModel;
            ComboBoxModelColumn protocolModelColumn;
            Gtk::ComboBox protocolCombo;
            Gtk::HBox protocolComboBox;
            std::string selectedProtocol;
            Gtk::Entry overlayText;
            Gtk::Button runFFmpegButton;
            Gtk::HBox runFFmpegButtonBox;
            Gtk::Button runFFprobeButton;
            Gtk::HBox runFFprobeButtonBox;
            Gtk::Label statusLabel;
            Gtk::Stack resultStack;
            Gtk::Image resultImage;
            Gtk::ScrolledWindow resultImageWindow;
            Gtk::TextView outputText;
            Gtk::ScrolledWindow outputTextWindow;
            Gtk::Window* parentWindow;
    };

}

#endif // FFMPEG_KIT_TEST_FFKIT_PROTOCOLS_TAB_H

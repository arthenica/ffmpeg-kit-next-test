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

import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_next_flutter/ffprobe_kit.dart';
import 'package:flutter/material.dart';

import 'abstract.dart';
import 'app_files.dart';
import 'media_information_output.dart';
import 'popup.dart';
import 'tooltip.dart';
import 'util.dart';
import 'video_util.dart';

/// Web only: probes a file in the virtual file storage.
class MediaInformationTab {
  late Refreshable _refreshable;
  late TextEditingController _pathText;
  String _outputText = "";

  void init(Refreshable refreshable) {
    _refreshable = refreshable;
    _pathText = TextEditingController();
    this.clearOutput();
  }

  void setActive() async {
    print("Media Information Tab Activated");
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);
    if (_pathText.text.isEmpty) {
      _pathText.text = await AppFiles.assetPath(VideoUtil.ASSET_1);
    }
    showPopup(MEDIA_INFORMATION_TEST_TOOLTIP_TEXT);
  }

  void appendOutput(String logMessage) {
    _outputText += logMessage;
    _refreshable.refresh();
  }

  void clearOutput() {
    _outputText = "";
    _refreshable.refresh();
  }

  void getMediaInformation() async {
    final path = _pathText.text.trim();
    if (path.isEmpty) {
      showPopup("Enter a file in the virtual file storage.");
      return;
    }
    this.clearOutput();
    ffprint("Getting media information of $path.");
    final session = await FFprobeKit.getMediaInformation(path);
    await writeMediaInformationResult(this.appendOutput, session);
  }

  String getOutputText() => _outputText;

  TextEditingController getPathText() => _pathText;

  void dispose() {
    _pathText.dispose();
  }
}

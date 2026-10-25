/*
 * Copyright (c) 2018-2022 Taner Sener
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

import 'dart:math';

import 'package:ffmpeg_kit_next_flutter/abstract_session.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_next_flutter/ffprobe_kit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'abstract.dart';
import 'app_files.dart';
import 'media_information_output.dart';
import 'popup.dart';
import 'tooltip.dart';
import 'util.dart';
import 'video_util.dart';

class HttpsTab {
  static const String HTTPS_TEST_DEFAULT_URL =
      "https://download.blender.org/peach/trailer/trailer_1080p.ogg";

  static const String HTTPS_TEST_FAIL_URL =
      "https://download2.blender.org/peach/trailer/trailer_1080p.ogg";

  static const String HTTPS_TEST_RANDOM_URL_1 =
      "https://filesamples.com/samples/video/mov/sample_640x360.mov";

  static const String HTTPS_TEST_RANDOM_URL_2 =
      "https://filesamples.com/samples/audio/mp3/sample3.mp3";

  static const String HTTPS_TEST_RANDOM_URL_3 =
      "https://filesamples.com/samples/image/webp/sample1.webp";

  // Served with CORS headers, so a web page may download it.
  static const String HTTPS_WEB_TEST_DEFAULT_URL =
      "https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg";

  static final Random testUrlRandom = new Random();

  late Refreshable _refreshable;
  late TextEditingController _urlText;
  String _outputText = "";

  void init(Refreshable refreshable) {
    _refreshable = refreshable;
    _urlText = TextEditingController();
    this.clearOutput();
  }

  void setActive() {
    print("Https Tab Activated");
    FFmpegKitConfig.enableLogCallback(null);
    FFmpegKitConfig.enableStatisticsCallback(null);
    if (kIsWeb) {
      if (_urlText.text.isEmpty) _urlText.text = HTTPS_WEB_TEST_DEFAULT_URL;
      showPopup(HTTPS_WEB_TEST_TOOLTIP_TEXT);
    } else {
      showPopup(HTTPS_TEST_TOOLTIP_TEXT);
    }
  }

  /// Web: FFmpeg's own https cannot open sockets in the browser, so the browser downloads the
  /// url, the bytes go into the virtual file storage and FFprobe reads them there.
  void fetchAndProbe() async {
    var url = _urlText.text.trim();
    if (url.isEmpty) {
      url = HTTPS_WEB_TEST_DEFAULT_URL;
      _urlText.text = url;
    }
    this.clearOutput();
    this.appendOutput("Fetching $url with the browser\n");
    try {
      final bytes = await AppFiles.fetchBytes(url);
      final name = Uri.parse(url).pathSegments.lastWhere((segment) => segment.isNotEmpty,
          orElse: () => "download");
      final path = "${await AppFiles.workDir()}/$name";
      await AppFiles.writeBytes(path, bytes);
      this.appendOutput("Wrote ${bytes.length} bytes to $path\n");
      final session = await FFprobeKit.getMediaInformation(path);
      await writeMediaInformationResult(this.appendOutput, session);
    } catch (e) {
      this.appendOutput("Fetch failed: $e\n"
          "The server must allow this page with CORS headers.\n");
    }
  }

  void appendOutput(String logMessage) {
    _outputText += logMessage;
    _refreshable.refresh();
  }

  void clearOutput() {
    _outputText = "";
    _refreshable.refresh();
  }

  String getRandomTestUrl() {
    switch (testUrlRandom.nextInt(3)) {
      case 0:
        return HTTPS_TEST_RANDOM_URL_1;
      case 1:
        return HTTPS_TEST_RANDOM_URL_2;
      default:
        return HTTPS_TEST_RANDOM_URL_3;
    }
  }

  void runGetMediaInformation(int buttonNumber) {
    VideoUtil.assetPath(VideoUtil.CA_CERTIFICATE_BUNDLE_ASSET)
        .then((caCertificateBundlePath) {
      // SELECT TEST URL
      String testUrl = "";
      switch (buttonNumber) {
        case 1:
          {
            testUrl = _urlText.text;
            if (testUrl.trim().length <= 0) {
              testUrl = HTTPS_TEST_DEFAULT_URL;
              _urlText.text = testUrl;
            }
            break;
          }
        case 2:
        case 3:
          {
            testUrl = this.getRandomTestUrl();
            break;
          }
        case 4:
        default:
          {
            testUrl = HTTPS_TEST_FAIL_URL;
            _urlText.text = testUrl;
          }
      }

      ffprint(
          "Testing HTTPS with custom ca bundle for button ${buttonNumber} using url ${testUrl}.");

      if (buttonNumber == 4) {
        // ONLY THIS BUTTON CLEARS THE TEXT VIEW
        this.clearOutput();
      }

      // GET MEDIA INFORMATION USING A CUSTOM COMMAND WITH A CA CERTIFICATE BUNDLE
      // PROVIDING A CA CERTIFICATE BUNDLE IS REQUIRED BY OPENSSL ON ANDROID/IOS/MACOS/LINUX UNLESS "-tls_verify 0" IS PROVIDED FOR FFMPEG 9+
      FFprobeKit.getMediaInformationFromCommandArgumentsAsync([
        "-v",
        "error",
        "-hide_banner",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        "-show_chapters",
        "-ca_file",
        caCertificateBundlePath,
        "-i",
        testUrl
      ], (session) async {
        await writeMediaInformationResult(this.appendOutput, session);
      }, null, AbstractSession.defaultTimeoutForAsynchronousMessagesInTransmit);
    });
  }

  String getOutputText() => _outputText;

  TextEditingController getUrlText() => _urlText;

  void dispose() {
    _urlText.dispose();
  }
}

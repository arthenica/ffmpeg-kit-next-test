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

import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_input_buffer.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_output_buffer.dart';
import 'package:ffmpeg_kit_next_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_next_flutter/log.dart';
import 'package:ffmpeg_kit_next_flutter/return_code.dart';
import 'package:ffmpeg_kit_next_flutter/statistics.dart';
import 'package:flutter/material.dart';

import 'abstract.dart';
import 'popup.dart';
import 'tooltip.dart';
import 'util.dart';
import 'video_util.dart';

const String PROTOCOL_FFKITMEM = "ffkitmem";
const String PROTOCOL_FFKITSAF = "ffkitsaf";

/// Escapes overlay text for a single-quoted drawtext `text='...'` value that
/// itself lives inside a double-quoted `-vf` argument. Ported from the Android
/// FFmpegCommands.escapeDrawtextText.
String escapeDrawtextText(String text) {
  return text
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll("'", "'\\''");
}

/// Builds the ffkitmem drawtext command. Ported verbatim from the Android
/// FFmpegCommands.buildFFKitMemProtocolCommand.
String buildFFKitMemProtocolCommand(
    String inputUrl, String outputUrl, String fontPath, String text) {
  final String drawtext = "drawtext=fontfile=$fontPath"
      ":text='${escapeDrawtextText(text)}'"
      ":x=(w-text_w)/2:y=h-th-40:fontsize=h/15"
      ":fontcolor=white:box=1:boxcolor=black@0.5";
  return "-y -i $inputUrl -vf \"$drawtext\""
      " -frames:v 1 -f image2 -c:v mjpeg $outputUrl";
}

String humanReadableByteCount(int bytes) {
  if (bytes < 1024) {
    return "$bytes B";
  }
  final double kb = bytes / 1024.0;
  if (kb < 1024) {
    return "${kb.toStringAsFixed(1)} KB";
  }
  return "${(kb / 1024.0).toStringAsFixed(1)} MB";
}

class FFKitProtocolsTab {
  late RefreshablePlayerDialogFactory _refreshablePlayerDialogFactory;
  final TextEditingController _overlayText =
      TextEditingController(text: "FFmpegKitNext");
  String _selectedProtocol = PROTOCOL_FFKITMEM;
  String _outputText = "";
  String _statusText = "Select a protocol, then run FFmpeg or FFprobe.";
  Uint8List? _resultImage;
  Statistics? _statistics;

  void init(RefreshablePlayerDialogFactory refreshablePlayerDialogFactory) {
    _refreshablePlayerDialogFactory = refreshablePlayerDialogFactory;
    _statistics = null;
    this.clearOutput();
  }

  void setActive() {
    print("FFKitProtocols Tab Activated");
    FFmpegKitConfig.enableLogCallback(this.logCallback);
    FFmpegKitConfig.enableStatisticsCallback(this.statisticsCallback);
    showPopup(FFKIT_PROTOCOLS_TEST_TOOLTIP_TEXT);
  }

  void logCallback(Log log) {
    this.appendOutput(log.getMessage());
  }

  void statisticsCallback(Statistics statistics) {
    this._statistics = statistics;
    this.updateProgressDialog();
  }

  // region Dropdown

  List<DropdownMenuItem<String>> getProtocolList() {
    return <String>[PROTOCOL_FFKITMEM, PROTOCOL_FFKITSAF]
        .map((protocol) => DropdownMenuItem<String>(
            value: protocol, child: Center(child: Text(protocol))))
        .toList();
  }

  String getSelectedProtocol() => _selectedProtocol;

  void changedProtocol(String? selectedProtocol) {
    if (selectedProtocol == null) {
      return;
    }
    _selectedProtocol = selectedProtocol;
    _resultImage = null;
    this.clearOutput();
    _statusText = "Select a protocol, then run FFmpeg or FFprobe.";
    _refreshablePlayerDialogFactory.refresh();
  }

  // endregion

  // region Button dispatch

  void runFFmpeg() {
    if (_selectedProtocol == PROTOCOL_FFKITSAF) {
      if (!Platform.isAndroid) {
        showPopup("SAF is only available on Android.");
        return;
      }
      this._encodeVideoSaf();
    } else {
      this._runFFKitMemFFmpeg();
    }
  }

  void runFFprobe() {
    if (_selectedProtocol == PROTOCOL_FFKITSAF) {
      if (!Platform.isAndroid) {
        showPopup("SAF is only available on Android.");
        return;
      }
      this._runFFprobeSaf();
    } else {
      this._runFFKitMemFFprobe();
    }
  }

  // endregion

  // region ffkitmem protocol

  void _runFFKitMemFFmpeg() async {
    this.clearOutput();
    _resultImage = null;
    _statusText = "Running…";
    _refreshablePlayerDialogFactory.refresh();

    final String imagePath = await VideoUtil.assetPath(VideoUtil.ASSET_1);
    final String fontPath = await VideoUtil.assetPath(VideoUtil.FONT_ASSET_1);
    final Uint8List bytes = await File(imagePath).readAsBytes();

    final FFmpegKitInputBuffer input =
        await FFmpegKitInputBuffer.fromByteArray(bytes, "jpg");
    final FFmpegKitOutputBuffer output =
        await FFmpegKitOutputBuffer.create(extension: "jpg");
    final String inputUrl = input.getUrl();
    final int inputSize = input.getSize();
    final String command = buildFFKitMemProtocolCommand(
        inputUrl, output.getUrl(), fontPath, _overlayText.text);

    ffprint("ffkitmem ffmpeg command: $command");

    FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final Uint8List result = await output.toByteArray();
        final int outputSize = await output.getSize();
        _resultImage = result;
        _statusText = "in $inputUrl (${humanReadableByteCount(inputSize)})"
            " -> drawtext -> "
            "out ${output.getUrl()} (${humanReadableByteCount(outputSize)})";
      } else {
        _resultImage = null;
        _statusText = "Processing failed.";
        showPopup("Processing failed. Please check output for the details.");
      }
      _refreshablePlayerDialogFactory.refresh();
      await input.close();
      await output.close();
    });
  }

  void _runFFKitMemFFprobe() async {
    this.clearOutput();
    _resultImage = null;
    _statusText = "Running…";
    _refreshablePlayerDialogFactory.refresh();

    final String imagePath = await VideoUtil.assetPath(VideoUtil.ASSET_1);
    final Uint8List bytes = await File(imagePath).readAsBytes();
    final FFmpegKitInputBuffer input =
        await FFmpegKitInputBuffer.fromByteArray(bytes, "jpg");
    final String inputUrl = input.getUrl();
    final String command =
        "-hide_banner -print_format json -show_format -show_streams $inputUrl";

    ffprint("ffkitmem ffprobe command: $command");

    FFprobeKit.execute(command).then((session) async {
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();
      this.appendOutput(output ?? "");
      _statusText = "ffprobe -> $inputUrl";
      if (!ReturnCode.isSuccess(returnCode)) {
        showPopup("Command failed. Please check output for the details.");
      }
      _refreshablePlayerDialogFactory.refresh();
      await input.close();
    });
  }

  // endregion

  // region saf protocol (Android only)

  void _runFFprobeSaf() {
    FFmpegKitConfig.selectDocumentForRead(
        "*/*", ["image/*", "video/*", "audio/*"]).then((uri) {
      FFmpegKitConfig.getSafParameterForRead(uri!).then((safUrl) {
        this.clearOutput();
        _resultImage = null;

        final String ffprobeCommand =
            "-hide_banner -print_format json -show_format -show_streams ${safUrl}";

        ffprint("Testing FFprobe COMMAND asynchronously.");
        ffprint("FFprobe process started with arguments: '$ffprobeCommand'");

        FFprobeKit.execute(ffprobeCommand).then((session) async {
          final state =
              FFmpegKitConfig.sessionStateToString(await session.getState());
          final returnCode = await session.getReturnCode();
          final failStackTrace = await session.getFailStackTrace();
          session.getOutput().then((output) => this.appendOutput(output ?? ""));

          ffprint(
              "FFprobe process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}");

          if (!ReturnCode.isSuccess(returnCode)) {
            showPopup("Command failed. Please check output for the details.");
          }
        });
      });
    });
  }

  void _encodeVideoSaf() {
    FFmpegKitConfig.selectDocumentForWrite("video.mp4", "video/*").then((uri) {
      FFmpegKitConfig.getSafParameterForWrite(uri!).then((safUrl) {
        VideoUtil.assetPath(VideoUtil.ASSET_1).then((image1Path) {
          VideoUtil.assetPath(VideoUtil.ASSET_2).then((image2Path) {
            VideoUtil.assetPath(VideoUtil.ASSET_3).then((image3Path) {
              final String videoFile = safUrl!;
              final videoCodec = 'mpeg4';

              ffprint("Testing VIDEO encoding with '${videoCodec}' codec");

              this.clearOutput();
              _resultImage = null;
              this.hideProgressDialog();
              this.showProgressDialog();

              final ffmpegCommand = VideoUtil.generateEncodeVideoScript(
                  image1Path, image2Path, image3Path, videoFile, videoCodec, "");

              ffprint(
                  "FFmpeg process started with arguments: '${ffmpegCommand}'.");

              FFmpegKit.executeAsync(ffmpegCommand, (session) async {
                final state = FFmpegKitConfig.sessionStateToString(
                    await session.getState());
                final returnCode = await session.getReturnCode();
                final failStackTrace = await session.getFailStackTrace();

                ffprint(
                    "FFmpeg process exited with state ${state} and rc ${returnCode}.${notNull(failStackTrace, "\\n")}");

                this.hideProgressDialog();

                if (ReturnCode.isSuccess(returnCode)) {
                  ffprint("Encode completed successfully.");
                } else {
                  showPopup("Encode failed. Please check log for the details.");
                }
              }).then((session) => ffprint(
                  "Async FFmpeg process started with sessionId ${session.getSessionId()}."));
            });
          });
        });
      });
    });
  }

  // endregion

  // region progress dialog (saf)

  void showProgressDialog() {
    _statistics = null;
    _refreshablePlayerDialogFactory.dialogShow("Encoding video");
  }

  void updateProgressDialog() {
    var statistics = this._statistics;
    if (statistics == null || statistics.getTime() < 0) {
      return;
    }

    double timeInMilliseconds = statistics.getTime();
    int totalVideoDuration = 9000;
    int completePercentage = (timeInMilliseconds * 100) ~/ totalVideoDuration;

    _refreshablePlayerDialogFactory
        .dialogUpdate("Encoding video % $completePercentage");
    _refreshablePlayerDialogFactory.refresh();
  }

  void hideProgressDialog() {
    _refreshablePlayerDialogFactory.dialogHide();
  }

  // endregion

  // region output helpers

  void appendOutput(String logMessage) {
    _outputText += logMessage;
    _refreshablePlayerDialogFactory.refresh();
  }

  void clearOutput() {
    _outputText = "";
    _refreshablePlayerDialogFactory.refresh();
  }

  TextEditingController getOverlayText() => _overlayText;

  String getOutputText() => _outputText;

  Uint8List? getResultImage() => _resultImage;

  String getStatusText() => _statusText;

  // endregion
}

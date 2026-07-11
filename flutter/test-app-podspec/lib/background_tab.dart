/*
 * Copyright (c) 2018-2022, 2026 Taner Sener
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

// Exercises FFmpegKit from a background isolate.
//
// A background isolate has no Activity/UI attached, so this verifies that the
// plugin's channels (execution, log forwarding and statistics forwarding) are
// available outside the main UI context. The isolate is provided by
// flutter_background_service, which runs a dedicated headless engine.
//
// This is Android/iOS only: background isolates can only use plugin channels on
// those embedders. On desktop (macOS) the Flutter engine does not support
// platform channels from a background isolate - attempting it aborts the
// process natively - so the tab reports that instead of running.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_next_flutter/return_code.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'abstract.dart';

// The name flutter_background_service reports results back to the UI isolate on.
const String _backgroundResultMethod = "ffmpegKitBackgroundResult";

// FFmpeg command executed inside the background isolate. It generates its input
// synthetically with lavfi (no bundled asset / path_provider needed), so the
// only plugin under test is ffmpeg_kit_next_flutter. mpeg4 + testsrc are always
// available and produce both log output and statistics, so we can verify that
// log/statistics forwarding works from a background isolate too - not just plain
// execution.
String _backgroundCommand() {
  final output = "${Directory.systemTemp.path}/ffmpeg_kit_background_test.mp4";
  return "-y -f lavfi -i testsrc=duration=1:size=320x240:rate=15 -c:v mpeg4 $output";
}

/// Entry point executed inside the headless engine spawned by
/// flutter_background_service (Android / iOS). Log and statistics forwarding is
/// observed through the global event-channel callbacks, which this dedicated
/// engine owns exclusively.
@pragma('vm:entry-point')
void ffmpegKitBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  var logReceived = false;
  var statisticsReceived = false;

  FFmpegKitConfig.enableLogCallback((log) {
    logReceived = true;
  });
  FFmpegKitConfig.enableStatisticsCallback((statistics) {
    statisticsReceived = true;
  });

  try {
    final session = await FFmpegKit.execute(_backgroundCommand());
    final returnCode = await session.getReturnCode();
    final state =
        FFmpegKitConfig.sessionStateToString(await session.getState());
    final failStackTrace = await session.getFailStackTrace();

    // Give any trailing log/statistics events a moment to flush over the event
    // channel before we report and tear the isolate down.
    await Future.delayed(const Duration(milliseconds: 500));

    service.invoke(_backgroundResultMethod, {
      "ok": ReturnCode.isSuccess(returnCode),
      "returnCode": returnCode?.getValue(),
      "state": state,
      "logReceived": logReceived,
      "statisticsReceived": statisticsReceived,
      "failStackTrace": failStackTrace,
      "error": null,
    });
  } catch (e, stack) {
    service.invoke(_backgroundResultMethod, {
      "ok": false,
      "error": e.toString(),
      "stack": stack.toString(),
    });
  } finally {
    await service.stopSelf();
  }
}

/// iOS foreground/background execution is limited; this handler only exists to
/// satisfy IosConfiguration. The actual work runs through onForeground.
@pragma('vm:entry-point')
Future<bool> ffmpegKitBackgroundServiceIosBackground(
    ServiceInstance service) async {
  return true;
}

class BackgroundTab {
  late Refreshable _refreshable;
  String _outputText = "";
  bool _configured = false;
  bool _running = false;
  StreamSubscription<Map<String, dynamic>?>? _resultSubscription;
  Timer? _timeoutTimer;

  void init(Refreshable refreshable) {
    _refreshable = refreshable;
    clearOutput();
  }

  void setActive() {
    print("Background Tab Activated");
  }

  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _resultSubscription?.cancel();
    _resultSubscription = null;
  }

  void appendOutput(String text) {
    _outputText += text;
    _refreshable.refresh();
  }

  void clearOutput() {
    _outputText = "";
    _refreshable.refresh();
  }

  Future<void> runTest() async {
    if (_running) {
      appendOutput("Background test already running...\n");
      return;
    }

    // Background isolates can only use plugin channels on Android and iOS. The
    // desktop (macOS) Flutter embedder does not support platform channels from a
    // background isolate - doing so aborts the process natively, which Dart
    // cannot catch - so we report that here instead of running.
    if (!(Platform.isAndroid || Platform.isIOS)) {
      clearOutput();
      appendOutput(
          "Background-isolate plugin channels are only supported on Android "
          "and iOS.\n\nThe macOS Flutter embedder does not support platform "
          "channels from a background isolate, so this test runs on Android "
          "and iOS.\n");
      return;
    }

    _running = true;
    clearOutput();
    appendOutput("Running FFmpegKit in a background isolate...\n");
    await _runViaBackgroundService();
  }

  Future<void> _runViaBackgroundService() async {
    final service = FlutterBackgroundService();

    try {
      if (!_configured) {
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: ffmpegKitBackgroundServiceStart,
            autoStart: false,
            isForegroundMode: false,
          ),
          iosConfiguration: IosConfiguration(
            autoStart: false,
            onForeground: ffmpegKitBackgroundServiceStart,
            onBackground: ffmpegKitBackgroundServiceIosBackground,
          ),
        );
        _resultSubscription =
            service.on(_backgroundResultMethod).listen(_renderResult);
        _configured = true;
      }

      await service.startService();

      // The service may be killed (or crash) before it reports back - notably
      // with isForegroundMode:false - which would otherwise leave the tab stuck
      // in the running state. Give up after a grace period so the button stays
      // usable.
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 20), () {
        if (_running) {
          _running = false;
          appendOutput(
              "FAIL: no result from the background service within 20s.\n");
        }
      });
    } catch (e) {
      _running = false;
      appendOutput("FAIL: could not start background service: $e\n");
    }
  }

  void _renderResult(Map<String, dynamic>? event) {
    _timeoutTimer?.cancel();
    _running = false;

    if (event == null) {
      appendOutput("FAIL: background isolate returned no data.\n");
      return;
    }

    final error = event["error"];
    if (error != null) {
      appendOutput("FAIL: FFmpegKit threw in the background isolate:\n$error\n");
      return;
    }

    final ok = event["ok"] == true;
    final logReceived = event["logReceived"] == true;
    final statisticsReceived = event["statisticsReceived"] == true;

    appendOutput("execute return code : ${event["returnCode"]}\n");
    appendOutput("session state       : ${event["state"]}\n");
    appendOutput(
        "log forwarding      : ${logReceived ? "received" : "MISSING"}\n");
    appendOutput(
        "statistics          : ${statisticsReceived ? "received" : "MISSING"}\n");

    final failStackTrace = event["failStackTrace"];
    if (failStackTrace != null) {
      appendOutput("fail stack trace    : $failStackTrace\n");
    }

    final everything = ok && logReceived && statisticsReceived;
    appendOutput(everything
        ? "\nPASS: FFmpegKit works in a background isolate "
            "(execute + log forwarding + statistics).\n"
        : "\nFAIL: FFmpegKit did not fully work in the background isolate.\n");
  }

  String getOutputText() => _outputText;
}

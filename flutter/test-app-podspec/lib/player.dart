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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_files.dart';
import 'decoration.dart';
import 'popup.dart';
import 'util.dart';

class PlayerTab {
  void setController(VideoPlayerController controller) {}
}

// On web a player plays an object URL of the file's bytes, which can only be made once the file
// has been written. Each web player registers how to reload itself for its tab.
final _reloads = Expando<Future<void> Function()>();

/// Reloads the tab's player from its file before playback. Does nothing on native platforms.
Future<void> reloadPlayer(PlayerTab tab) async => await _reloads[tab]?.call();

/// Initializes and starts [controller]. A video the player cannot decode is reported with a popup
/// instead of an unhandled error: browsers, for example, do not play every codec FFmpeg writes.
Future<void> startPlayback(VideoPlayerController controller) async {
  try {
    await controller.initialize();
    await controller.play();
  } catch (e) {
    ffprint("Video playback failed: $e");
    showPopup(kIsWeb
        ? "This browser cannot play the video. Its codec is not supported here."
        : "The video cannot be played. Its codec is not supported here.");
  }
}

class EmbeddedPlayer extends StatefulWidget {
  final String _filePath;
  final PlayerTab _playerTab;

  EmbeddedPlayer(this._filePath, this._playerTab);

  @override
  _EmbeddedPlayerState createState() =>
      _EmbeddedPlayerState(_filePath, _playerTab);
}

class _EmbeddedPlayerState extends State<EmbeddedPlayer> {
  final PlayerTab _playerTab;
  final String _filePath;
  VideoPlayerController? _videoPlayerController;
  String? _url;
  bool startedPlaying = false;

  _EmbeddedPlayerState(this._filePath, this._playerTab);

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _reloads[_playerTab] = _reload;
    } else if (!isLinux && !isWindows) {
      // video_player has no Linux or Windows implementation, so skip a controller
      // there. The owning tab keeps a null controller and skips playback.
      _videoPlayerController = AppFiles.videoController(_filePath);
      _playerTab.setController(_videoPlayerController!);
    }
  }

  Future<void> _reload() async {
    final url = await AppFiles.playableUrl(_filePath);
    if (!mounted) {
      AppFiles.releasePlayableUrl(url);
      return;
    }
    _release();
    _url = url;
    _videoPlayerController = AppFiles.videoController(url);
    _playerTab.setController(_videoPlayerController!);
    setState(() {});
  }

  void _release() {
    _videoPlayerController?.dispose();
    if (_url != null) AppFiles.releasePlayableUrl(_url!);
    _url = null;
  }

  @override
  void dispose() {
    if (_reloads[_playerTab] == _reload) _reloads[_playerTab] = null;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoPlayerController == null && kIsWeb) {
      return Material(
          elevation: 0,
          child: Center(
            child: Container(
              alignment: Alignment(0.0, 0.0),
              decoration: videoPlayerFrameDecoration,
            ),
          ));
    }
    if (_videoPlayerController == null) {
      return Material(
          elevation: 0,
          child: Center(
            child: Container(
              alignment: Alignment(0.0, 0.0),
              decoration: videoPlayerFrameDecoration,
              child: Text(
                'Video preview is not available on this platform.',
                textAlign: TextAlign.center,
              ),
            ),
          ));
    }

    return Material(
        elevation: 0,
        child: Center(
          child: FutureBuilder<bool>(
            future: Future.value(_videoPlayerController!.value.isInitialized),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.data == true) {
                return Container(
                  alignment: Alignment(0.0, 0.0),
                  child: VideoPlayer(_videoPlayerController!),
                );
              } else {
                return Container(
                  alignment: Alignment(0.0, 0.0),
                  decoration: videoPlayerFrameDecoration,
                );
              }
            },
          ),
        ));
  }
}

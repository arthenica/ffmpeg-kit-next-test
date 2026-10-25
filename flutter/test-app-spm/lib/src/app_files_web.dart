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

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_virtual_directory.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_virtual_file.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

class AppFiles {
  static const String _root = '/app';

  /// The folder the tabs write their outputs to, in the virtual file storage.
  static Future<String> workDir() async {
    await FFmpegKitVirtualDirectory.from(_root).create(recursive: true);
    return _root;
  }

  /// Where a bundled asset is saved.
  static Future<String> assetPath(String asset) async => '$_root/assets/$asset';

  /// The browser exposes no font folders.
  static List<String> systemFontDirectories() => const [];

  static Future<Uint8List> readBytes(String path) =>
      FFmpegKitVirtualFile.from(path).readAsBytes();

  static Future<void> writeBytes(String path, Uint8List bytes) async {
    await FFmpegKitVirtualDirectory.from(p.posix.dirname(path))
        .create(recursive: true);
    await FFmpegKitVirtualFile.from(path).writeAsBytes(bytes);
  }

  static Future<bool> exists(String path) =>
      FFmpegKitVirtualFile.from(path).exists();

  static Future<void> delete(String path) =>
      FFmpegKitVirtualFile.from(path).delete();

  /// Downloads [url] with the browser; the server must allow the page with CORS headers.
  static Future<Uint8List> fetchBytes(String url) async {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) {
      throw StateError('HTTP ${response.status} for $url');
    }
    return (await response.arrayBuffer().toDart).toDart.asUint8List();
  }

  /// An object URL of the file's bytes; release it with [releasePlayableUrl].
  static Future<String> playableUrl(String path) async {
    // The analyzer sees the non-web stub, whose readAsBlob answers Object.
    final blob = await FFmpegKitVirtualFile.from(path).readAsBlob(
            type: path.endsWith('.mp4') ? 'video/mp4' : 'application/octet-stream')
        as web.Blob;
    return web.URL.createObjectURL(blob);
  }

  static void releasePlayableUrl(String url) => web.URL.revokeObjectURL(url);

  static VideoPlayerController videoController(String url) =>
      VideoPlayerController.networkUrl(Uri.parse(url));
}

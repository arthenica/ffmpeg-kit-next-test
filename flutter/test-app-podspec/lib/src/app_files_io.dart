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

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class AppFiles {
  /// The folder the tabs write their outputs to.
  static Future<String> workDir() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// Where a bundled asset is saved.
  static Future<String> assetPath(String asset) async =>
      join((await getTemporaryDirectory()).path, asset);

  /// The platform's own font folders.
  static List<String> systemFontDirectories() => Platform.isWindows
      ? [join(Platform.environment['WINDIR'] ?? r'C:\Windows', 'Fonts')]
      : ['/system/fonts', '/System/Library/Fonts'];

  static Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  static Future<void> writeBytes(String path, Uint8List bytes) async {
    // On macOS the temporary directory is not guaranteed to exist.
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes, mode: FileMode.writeOnly, flush: true);
  }

  static Future<bool> exists(String path) => File(path).exists();

  static Future<void> delete(String path) => File(path).delete();

  /// Downloads [url].
  static Future<Uint8List> fetchBytes(String url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode} for $url');
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  /// The URL a video player opens: the path itself on native platforms.
  static Future<String> playableUrl(String path) async => path;

  static void releasePlayableUrl(String url) {}

  static VideoPlayerController videoController(String url) =>
      VideoPlayerController.file(File(url));
}

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

import 'package:ffmpeg_kit_next_flutter/chapter.dart';
import 'package:ffmpeg_kit_next_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_next_flutter/media_information_session.dart';
import 'package:ffmpeg_kit_next_flutter/stream_information.dart';

import 'util.dart';

/// Writes the media information of [session], or why getting it failed, through [append].
Future<void> writeMediaInformationResult(
    void Function(String) append, MediaInformationSession session) async {
  final information = await session.getMediaInformation();

  if (information == null) {
    final state =
        FFmpegKitConfig.sessionStateToString(await session.getState());
    final returnCode = await session.getReturnCode();
    final failStackTrace = await session.getFailStackTrace();
    final duration = await session.getDuration();
    final output = await session.getOutput();

    append("Get media information failed\n");
    append("State: ${state}\n");
    append("Duration: ${duration}\n");
    append("Return Code: ${returnCode}\n");
    append(
        "Fail stack trace: ${notNull(failStackTrace, "\\n")}\n");
    append("Output: ${output}\n");
  } else {
    append(
        "Media information for ${information.getFilename()}\n");

    if (information.getFormat() != null) {
      append("Format: ${information.getFormat()}\n");
    }
    if (information.getBitrate() != null) {
      append("Bitrate: ${information.getBitrate()}\n");
    }
    if (information.getDuration() != null) {
      append("Duration: ${information.getDuration()}\n");
    }
    if (information.getStartTime() != null) {
      append("Start time: ${information.getStartTime()}\n");
    }
    if (information.getTags() != null) {
      final tags = information.getTags();
      if (tags != null) {
        tags.forEach((key, value) {
          append("Tag: ${key}:${tags[key]}\n");
        });
      }
    }

    List<StreamInformation> streams = information.getStreams();
    for (var i = 0; i < streams.length; ++i) {
      StreamInformation stream = streams[i];
      if (stream.getIndex() != null) {
        append("Stream index: ${stream.getIndex()}\n");
      }
      if (stream.getType() != null) {
        append("Stream type: ${stream.getType()}\n");
      }
      if (stream.getCodec() != null) {
        append("Stream codec: ${stream.getCodec()}\n");
      }
      if (stream.getCodecLong() != null) {
        append(
            "Stream codec long: ${stream.getCodecLong()}\n");
      }
      if (stream.getFormat() != null) {
        append("Stream format: ${stream.getFormat()}\n");
      }
      if (stream.getWidth() != null) {
        append("Stream width: ${stream.getWidth()}\n");
      }
      if (stream.getHeight() != null) {
        append("Stream height: ${stream.getHeight()}\n");
      }
      if (stream.getBitrate() != null) {
        append("Stream bitrate: ${stream.getBitrate()}\n");
      }
      if (stream.getSampleRate() != null) {
        append(
            "Stream sample rate: ${stream.getSampleRate()}\n");
      }
      if (stream.getSampleFormat() != null) {
        append(
            "Stream sample format: ${stream.getSampleFormat()}\n");
      }
      if (stream.getChannelLayout() != null) {
        append(
            "Stream channel layout: ${stream.getChannelLayout()}\n");
      }
      if (stream.getSampleAspectRatio() != null) {
        append(
            "Stream sample aspect ratio: ${stream.getSampleAspectRatio()}\n");
      }
      if (stream.getDisplayAspectRatio() != null) {
        append(
            "Stream display ascpect ratio: ${stream.getDisplayAspectRatio()}\n");
      }
      if (stream.getAverageFrameRate() != null) {
        append(
            "Stream average frame rate: ${stream.getAverageFrameRate()}\n");
      }
      if (stream.getRealFrameRate() != null) {
        append(
            "Stream real frame rate: ${stream.getRealFrameRate()}\n");
      }
      if (stream.getTimeBase() != null) {
        append("Stream time base: ${stream.getTimeBase()}\n");
      }
      if (stream.getCodecTimeBase() != null) {
        append(
            "Stream codec time base: ${stream.getCodecTimeBase()}\n");
      }
      if (stream.getTags() != null) {
        final tags = stream.getTags();
        if (tags != null) {
          tags.forEach((key, value) {
            append("Stream tag: ${key}:${tags[key]}\n");
          });
        }
      }
    }

    List<Chapter> chapters = information.getChapters();
    for (var i = 0; i < chapters.length; ++i) {
      Chapter chapter = chapters[i];
      if (chapter.getId() != null) {
        append("Chapter id: ${chapter.getId()}\n");
      }
      if (chapter.getTimeBase() != null) {
        append("Chapter time base: ${chapter.getTimeBase()}\n");
      }
      if (chapter.getStart() != null) {
        append("Chapter start: ${chapter.getStart()}\n");
      }
      if (chapter.getStartTime() != null) {
        append("Chapter start time: ${chapter.getStartTime()}\n");
      }
      if (chapter.getEnd() != null) {
        append("Chapter end: ${chapter.getEnd()}\n");
      }
      if (chapter.getEndTime() != null) {
        append("Chapter end time: ${chapter.getEndTime()}\n");
      }
      if (chapter.getTags() != null) {
        final tags = chapter.getTags();
        if (tags != null) {
          tags.forEach((key, value) {
            append("Chapter tag: ${key}:${tags[key]}\n");
          });
        }
      }
    }
  }
}

/*
 * Copyright (c) 2018-2026 Taner Sener
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

import Foundation
import ffmpegkit

func testMediaInformationJsonParser() {
    let mediaInformationJson = """
    {
      "streams": [
        {
          "index": 0,
          "codec_name": "h264",
          "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
          "codec_type": "video",
          "width": 1280,
          "height": 720,
          "pix_fmt": "yuv420p",
          "sample_aspect_ratio": "1:1",
          "display_aspect_ratio": "16:9",
          "avg_frame_rate": "30/1",
          "r_frame_rate": "30/1",
          "time_base": "1/15360",
          "codec_time_base": "1/60",
          "bit_rate": "9166570",
          "tags": {
            "language": "und"
          }
        }
      ],
      "format": {
        "filename": "sample.mp4",
        "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
        "start_time": "0.000000",
        "duration": "14.000000",
        "bit_rate": "9168090",
        "tags": {
          "encoder": "Lavf58.33.100"
        }
      }
    }
    """

    guard let mediaInformation = MediaInformationJsonParser.from(mediaInformationJson) else {
        assertionFailure("Media information should parse.")
        return
    }
    assert(mediaInformation.getFilename() == "sample.mp4")
    assert(mediaInformation.getFormat() == "mov,mp4,m4a,3gp,3g2,mj2")
    assert(mediaInformation.getDuration() == "14.000000")
    assert(mediaInformation.getStartTime() == "0.000000")
    assert(mediaInformation.getBitrate() == "9168090")
    let tags = mediaInformation.getTags() as? [String: Any]
    assert(tags?["encoder"] as? String == "Lavf58.33.100")
    let streams = mediaInformation.getStreams() as? [StreamInformation]
    assert(streams?.count == 1)
    let stream = streams![0]
    assert(stream.getIndex() == 0)
    assert(stream.getType() == "video")
    assert(stream.getCodec() == "h264")
    assert(stream.getCodecLong() == "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10")
    assert(stream.getFormat() == "yuv420p")
    assert(stream.getWidth() == 1280)
    assert(stream.getHeight() == 720)
    assert(stream.getSampleAspectRatio() == "1:1")
    assert(stream.getDisplayAspectRatio() == "16:9")
    assert(stream.getBitrate() == "9166570")
    assert(stream.getAverageFrameRate() == "30/1")
    assert(stream.getRealFrameRate() == "30/1")
    assert(stream.getTimeBase() == "1/15360")
    assert(stream.getCodecTimeBase() == "1/60")
    NSLog("MediaInformationJsonParserTest passed.")
}

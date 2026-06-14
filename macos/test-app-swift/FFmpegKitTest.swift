/*
 * Copyright (c) 2019-2026 Taner Sener
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

func parseArguments(_ command: String) -> [String] {
    var argumentArray: [String] = []
    var currentArgument = ""
    var singleQuoteStarted = false
    var doubleQuoteStarted = false
    let chars = Array(command)

    for i in chars.indices {
        let previousChar = i > 0 ? chars[i - 1] : "\0"
        let currentChar = chars[i]
        if currentChar == " " {
            if singleQuoteStarted || doubleQuoteStarted {
                currentArgument.append(currentChar)
            } else if !currentArgument.isEmpty {
                argumentArray.append(currentArgument)
                currentArgument = ""
            }
        } else if currentChar == "'" && previousChar != "\\" {
            if singleQuoteStarted {
                singleQuoteStarted = false
            } else if doubleQuoteStarted {
                currentArgument.append(currentChar)
            } else {
                singleQuoteStarted = true
            }
        } else if currentChar == "\"" && previousChar != "\\" {
            if doubleQuoteStarted {
                doubleQuoteStarted = false
            } else if singleQuoteStarted {
                currentArgument.append(currentChar)
            } else {
                doubleQuoteStarted = true
            }
        } else {
            currentArgument.append(currentChar)
        }
    }

    if !currentArgument.isEmpty {
        argumentArray.append(currentArgument)
    }
    return argumentArray
}

private func assertString(_ expected: String, _ actual: String) {
    assert(expected == actual)
}

private func testParseSimpleCommand() {
    let argumentArray = parseArguments("-hide_banner -loop 1 -i file.jpg -filter_complex [0:v]setpts=PTS-STARTPTS[video] -map [video] -fps_mode cfr video.mp4")
    assert(argumentArray.count == 12)
    assertString("-hide_banner", argumentArray[0])
    assertString("-loop", argumentArray[1])
    assertString("1", argumentArray[2])
    assertString("-i", argumentArray[3])
    assertString("file.jpg", argumentArray[4])
    assertString("-filter_complex", argumentArray[5])
    assertString("[0:v]setpts=PTS-STARTPTS[video]", argumentArray[6])
    assertString("-map", argumentArray[7])
    assertString("[video]", argumentArray[8])
    assertString("-fps_mode", argumentArray[9])
    assertString("cfr", argumentArray[10])
    assertString("video.mp4", argumentArray[11])
}

private func testParseSingleQuotesInCommand() {
    let argumentArray = parseArguments("-loop 1 'file one.jpg'  -filter_complex  '[0:v]setpts=PTS-STARTPTS[video]'  -map  [video]  video.mp4 ")
    assert(argumentArray.count == 8)
    assertString("file one.jpg", argumentArray[2])
    assertString("[0:v]setpts=PTS-STARTPTS[video]", argumentArray[4])
}

private func testParseDoubleQuotesInCommand() {
    var argumentArray = parseArguments("-loop  1 \"file one.jpg\"   -filter_complex \"[0:v]setpts=PTS-STARTPTS[video]\"  -map  [video]  video.mp4 ")
    assert(argumentArray.count == 8)
    assertString("file one.jpg", argumentArray[2])
    assertString("[0:v]setpts=PTS-STARTPTS[video]", argumentArray[4])

    argumentArray = parseArguments(" -i   file:///tmp/input.mp4 -vcodec libx264 -vf \"scale=1024:1024,pad=width=1024:height=1024:x=0:y=0:color=black\"  -acodec copy  -q:v 0  -q:a   0 video.mp4")
    assert(argumentArray.count == 13)
    assertString("scale=1024:1024,pad=width=1024:height=1024:x=0:y=0:color=black", argumentArray[5])
}

private func testParseDoubleQuotesAndEscapesInCommand() {
    var argumentArray = parseArguments("  -i   file:///tmp/input.mp4 -vf \"subtitles=file:///tmp/subtitles.srt:force_style='FontSize=16,PrimaryColour=&HFFFFFF&'\" -vcodec libx264   -acodec copy  -q:v 0 -q:a  0  video.mp4")
    assert(argumentArray.count == 13)
    assertString("subtitles=file:///tmp/subtitles.srt:force_style='FontSize=16,PrimaryColour=&HFFFFFF&'", argumentArray[3])

    argumentArray = parseArguments("  -i   file:///tmp/input.mp4 -vf \"subtitles=file:///tmp/subtitles.srt:force_style=\\\"FontSize=16,PrimaryColour=&HFFFFFF&\\\"\" -vcodec libx264   -acodec copy  -q:v 0 -q:a  0  video.mp4")
    assert(argumentArray.count == 13)
    assertString("subtitles=file:///tmp/subtitles.srt:force_style=\\\"FontSize=16,PrimaryColour=&HFFFFFF&\\\"", argumentArray[3])
}

private func getSessionIdTest() {
    let testArguments = ["argument1", "argument2"]
    let sessions1 = FFmpegSession.create(testArguments)!
    let sessions2 = FFprobeSession.create(testArguments)!
    let sessions3 = MediaInformationSession.create(testArguments)!
    let session1: Session = sessions1
    let session2: Session = sessions2
    let session3: Session = sessions3
    assert(session3.getId() > session2.getId())
    assert(session3.getId() > session1.getId())
    assert(session2.getId() > session1.getId())
    assert(session1.getId() > 0)
    assert(session2.getId() > 0)
    assert(session3.getId() > 0)
}

private func setSessionHistorySizeTest() {
    let testArguments = ["argument1", "argument2"]
    var newSize: Int32 = 15
    FFmpegKitConfig.setSessionHistorySize(newSize)
    for _ in 1...(newSize + 5) {
        _ = FFmpegSession.create(testArguments)
        assert((FFmpegKitConfig.getSessions()?.count ?? 0) <= Int(newSize))
    }
    newSize = 3
    FFmpegKitConfig.setSessionHistorySize(newSize)
    for _ in 1...(newSize + 5) {
        _ = FFmpegSession.create(testArguments)
        assert((FFmpegKitConfig.getSessions()?.count ?? 0) <= Int(newSize))
    }
}

func testFFmpegKit() {
    testParseSimpleCommand()
    testParseSingleQuotesInCommand()
    testParseDoubleQuotesInCommand()
    testParseDoubleQuotesAndEscapesInCommand()
    getSessionIdTest()
    setSessionHistorySizeTest()
    NSLog("FFmpegKitTest passed.")
}

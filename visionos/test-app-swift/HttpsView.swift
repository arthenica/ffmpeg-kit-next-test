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

import SwiftUI
import ffmpegkit

@MainActor final class HttpsModel: ObservableObject {
    @Published var url = ""
    @Published var output = ""

    private let outputLock = NSObject()

    func setActive() {
        NSLog("Https Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func appendOutput(_ message: String) {
        output = output.appending(message)
    }

    func clearOutput() {
        output = ""
    }

    func getRandomTestUrl() -> String {
        switch arc4random_uniform(3) {
        case 0: return HTTPS_TEST_RANDOM_URL_1
        case 1: return HTTPS_TEST_RANDOM_URL_2
        default: return HTTPS_TEST_RANDOM_URL_3
        }
    }

    func runGetMediaInformation(_ buttonNumber: Int32) {
        let testUrl: String
        switch buttonNumber {
        case 1:
            if !url.isEmpty {
                testUrl = url
            } else {
                testUrl = HTTPS_TEST_DEFAULT_URL
                url = testUrl
            }
        case 2, 3:
            testUrl = getRandomTestUrl()
        default:
            testUrl = HTTPS_TEST_FAIL_URL
            url = testUrl
        }
        NSLog("Testing HTTPS with custom ca bundle for button %d using url %@.", buttonNumber, testUrl)
        if buttonNumber == 4 {
            clearOutput()
        }

        let caCertificateBundlePath = Sessions.getCACertificateBundlePath()

        // GET MEDIA INFORMATION USING A CUSTOM COMMAND WITH A CA CERTIFICATE BUNDLE
        // PROVIDING A CA CERTIFICATE BUNDLE IS REQUIRED ON VISIONOS UNLESS "-tls_verify 0" IS PROVIDED FOR FFMPEG 9+
        let mediaInformationSession = MediaInformationSession.create([
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
        ],
        withCompleteCallback: self.createNewCompleteCallback())

        FFmpegKitConfig.asyncGetMediaInformationExecute(mediaInformationSession, withTimeout: AbstractSessionDefaultTimeoutForAsynchronousMessagesInTransmit)
    }

    func createNewCompleteCallback() -> MediaInformationSessionCompleteCallback {
        return { session in
            guard let session = session else { return }
            addUIAction {
                objc_sync_enter(self.outputLock)
                defer { objc_sync_exit(self.outputLock) }
                let anySession: Session = session
                if let information = session.getMediaInformation() {
                    self.appendOutput("Media information for \(information.getFilename() ?? "")\n")
                    self.appendIfPresent("Format", information.getFormat())
                    self.appendIfPresent("Bitrate", information.getBitrate())
                    self.appendIfPresent("Duration", information.getDuration())
                    self.appendIfPresent("Start time", information.getStartTime())
                    if let tags = information.getTags() as? [String: Any] {
                        for key in tags.keys {
                            self.appendOutput("Tag: \(key):\(tags[key] ?? "")\n")
                        }
                    }
                    if let streams = information.getStreams() as? [StreamInformation] {
                        for stream in streams {
                            self.appendIfPresent("Stream index", stream.getIndex())
                            self.appendIfPresent("Stream type", stream.getType())
                            self.appendIfPresent("Stream codec", stream.getCodec())
                            self.appendIfPresent("Stream codec long", stream.getCodecLong())
                            self.appendIfPresent("Stream format", stream.getFormat())
                            self.appendIfPresent("Stream width", stream.getWidth())
                            self.appendIfPresent("Stream height", stream.getHeight())
                            self.appendIfPresent("Stream bitrate", stream.getBitrate())
                            self.appendIfPresent("Stream sample rate", stream.getSampleRate())
                            self.appendIfPresent("Stream sample format", stream.getSampleFormat())
                            self.appendIfPresent("Stream channel layout", stream.getChannelLayout())
                            self.appendIfPresent("Stream sample aspect ratio", stream.getSampleAspectRatio())
                            self.appendIfPresent("Stream display ascpect ratio", stream.getDisplayAspectRatio())
                            self.appendIfPresent("Stream average frame rate", stream.getAverageFrameRate())
                            self.appendIfPresent("Stream real frame rate", stream.getRealFrameRate())
                            self.appendIfPresent("Stream time base", stream.getTimeBase())
                            self.appendIfPresent("Stream codec time base", stream.getCodecTimeBase())
                            if let tags = stream.getTags() as? [String: Any] {
                                for key in tags.keys {
                                    self.appendOutput("Stream tag: \(key):\(tags[key] ?? "")\n")
                                }
                            }
                        }
                    }
                    if let chapters = information.getChapters() as? [Chapter] {
                        for chapter in chapters {
                            self.appendIfPresent("Chapter id", chapter.getId())
                            self.appendIfPresent("Chapter time base", chapter.getTimeBase())
                            self.appendIfPresent("Chapter start", chapter.getStart())
                            self.appendIfPresent("Chapter start time", chapter.getStartTime())
                            self.appendIfPresent("Chapter end", chapter.getEnd())
                            self.appendIfPresent("Chapter end time", chapter.getEndTime())
                            if let tags = chapter.getTags() as? [String: Any] {
                                for key in tags.keys {
                                    self.appendOutput("Chapter tag: \(key):\(tags[key] ?? "")\n")
                                }
                            }
                        }
                    }
                } else {
                    self.appendOutput("Get media information failed\n")
                    self.appendOutput("State: \(FFmpegKitConfig.sessionState(toString: anySession.getState()) ?? "")\n")
                    self.appendOutput("Duration: \(anySession.getDuration())\n")
                    self.appendOutput("Return Code: \(String(describing: anySession.getReturnCode()))\n")
                    self.appendOutput("Fail stack trace: \(notNull(anySession.getFailStackTrace(), "\n"))\n")
                    self.appendOutput("Output: \(anySession.getOutput() ?? "")\n")
                }
            }
        }
    }

    private func appendIfPresent(_ label: String, _ value: Any?) {
        if let value = value {
            appendOutput("\(label): \(value)\n")
        }
    }
}

struct HttpsView: View {
    @StateObject private var model = HttpsModel()
    private let buttonColumns = [
        GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("https url of a media file", text: $model.url).textFieldStyle(.roundedBorder)
            LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 12) {
                Button("GET INFO FROM URL") { model.runGetMediaInformation(1) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .lineLimit(2)
                Button("GET RANDOM INFO") { model.runGetMediaInformation(2) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .lineLimit(2)
                Button("GET RANDOM INFO") { model.runGetMediaInformation(3) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .lineLimit(2)
                Button("GET INFO AND FAIL") { model.runGetMediaInformation(4) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .lineLimit(2)
            }
            OutputConsole(text: model.output)
        }
        .padding(24).onAppear { model.setActive() }
    }
}

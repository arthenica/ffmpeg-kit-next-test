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

import AVFoundation
import AVKit
import SwiftUI
import ffmpegkit

private enum SubtitleUITestState {
    case idle
    case creating
    case burning
}

@MainActor final class SubtitleModel: ObservableObject {
    @Published var progress: String? = nil
    @Published var alertMessage: String? = nil
    let player = AVQueuePlayer()

    private var statistics: Statistics?
    private var state = SubtitleUITestState.idle
    private var sessionId: Int = 0

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            NSLog("%@", log?.getMessage() ?? "")
        }
    }

    func enableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback { statistics in
            addUIAction {
                self.statistics = statistics
                self.updateProgressDialog()
            }
        }
    }

    func cancel() {
        if state == .creating {
            if sessionId != 0 {
                FFmpegKit.cancel(sessionId)
            }
        } else if state == .burning {
            FFmpegKit.cancel()
        }
    }

    func burnSubtitles() {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("machupicchu.jpg")
        let image2 = resourceFolder.appendingPathComponent("pyramid.jpg")
        let image3 = resourceFolder.appendingPathComponent("stonehenge.jpg")
        let subtitle = getSubtitlePath()
        let videoFile = getVideoPath()
        let videoWithSubtitlesFile = getVideoWithSubtitlesPath()
        player.removeAllItems()
        NSLog("Testing SUBTITLE burning\n")
        showProgressDialog("Creating video\n\n")
        let ffmpegCommand = Video.generateVideoEncodeScript(image1, image2, image3, videoFile, "mpeg4", "")
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        state = .creating
        let firstSession = FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
            addUIAction { self.hideProgressDialog() }
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                NSLog("Create completed successfully; burning subtitles.\n")
                let burnSubtitlesCommand = "-hide_banner -y -i \(videoFile) -vf subtitles=filename='\(subtitle)':force_style='FontName=MyFontName' \(videoWithSubtitlesFile)"
                addUIAction { self.showProgressDialog("Burning subtitles\n\n") }
                NSLog("FFmpeg process started with arguments '%@'.\n", burnSubtitlesCommand)
                self.state = .burning
                FFmpegKit.executeAsync(burnSubtitlesCommand) { secondSession in
                    guard let secondSession = secondSession else { return }
                    let anySecondSession: Session = secondSession
                    addUIAction {
                        self.hideProgressDialog()
                        if ReturnCode.isSuccess(anySecondSession.getReturnCode()) {
                            NSLog("Burn subtitles completed successfully; playing video.\n")
                            self.playVideo()
                        } else if ReturnCode.isCancel(anySecondSession.getReturnCode()) {
                            NSLog("Burn subtitles operation cancelled\n")
                            self.progress = nil
                            self.alertMessage = "Burn subtitles operation cancelled."
                        } else {
                            NSLog("Burn subtitles failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySecondSession.getState()), String(describing: anySecondSession.getReturnCode()), notNull(anySecondSession.getFailStackTrace(), "\n"))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                self.hideProgressDialogAndAlert("Burn subtitles failed. Please check logs for the details.")
                            }
                        }
                    }
                }
            }
        }
        if let firstSession = firstSession {
            let anySession: Session = firstSession
            sessionId = anySession.getId()
        }
        NSLog("Async FFmpeg process started with sessionId %ld.\n", sessionId)
    }

    func playVideo() {
        let asset = AVAsset(url: URL(fileURLWithPath: getVideoWithSubtitlesPath()))
        let newVideo = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        player.insert(newVideo, after: nil)
        player.play()
    }

    func getSubtitlePath() -> String {
        return (Bundle.main.resourcePath ?? "").appendingPathComponent("subtitle.srt")
    }

    func getVideoPath() -> String {
        return documentsDirectory().appendingPathComponent("video.mp4")
    }

    func getVideoWithSubtitlesPath() -> String {
        return documentsDirectory().appendingPathComponent("video-with-subtitles.mp4")
    }

    func setActive() {
        NSLog("Subtitle Tab Activated")
        enableLogCallback()
        enableStatisticsCallback()
    }

    func showProgressDialog(_ dialogMessage: String) {
        statistics = nil
        progress = dialogMessage
    }

    func updateProgressDialog() {
        guard let statistics = statistics, statistics.getTime() >= 0 else { return }
        let percentage = Int(statistics.getTime() * 100 / 9000)
        if state == .creating {
            progress = "Creating video  % \(percentage) \n\n"
        } else if state == .burning {
            progress = "Burning subtitles  % \(percentage) \n\n"
        }
    }

    func hideProgressDialog() {
        progress = nil
    }

    func hideProgressDialogAndAlert(_ message: String) {
        progress = nil
        alertMessage = message
    }
}

struct SubtitleView: View {
    @StateObject private var model = SubtitleModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tap the button to burn subtitles. The created video plays in the frame below.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("BURN SUBTITLES") { model.burnSubtitles() }.buttonStyle(.borderedProminent)
            VideoBox(player: model.player)
        }
        .padding(24).onAppear { model.setActive() }
        .overlay { if let p = model.progress { ProgressOverlay(message: p, onCancel: { model.cancel() }) } }
        .alert("Error", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

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

@MainActor final class VideoModel: ObservableObject {
    @Published var codec = "h264 (x264)"
    @Published var progress: String? = nil
    @Published var alertTitle: String = "Error"
    @Published var alertMessage: String? = nil
    let codecs = ["h264 (x264)", "h264 (openh264)", "h264 (videotoolbox)", "x265", "xvid", "vp8", "vp9", "aom", "svt-av1", "kvazaar", "theora", "hap"]
    let player = AVQueuePlayer()

    private var activeItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var statistics: Statistics?

    func encodeVideo() {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
        let videoFile = getVideoPath()
        player.removeAllItems()
        activeItem = nil
        try? FileManager.default.removeItem(atPath: videoFile)
        let videoCodec = codec
        NSLog("Testing VIDEO encoding with '%@' codec\n", videoCodec)
        showProgressDialog("Encoding video\n\n")
        let ffmpegCommand = Video.generateVideoEncodeScriptWithCustomPixelFormat(image1, image2, image3, videoFile, getSelectedVideoCodec(), getPixelFormat(), getCustomOptions())
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        let session = FFmpegKit.executeAsync(ffmpegCommand, withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            addUIAction { self.hideProgressDialog() }
            if ReturnCode.isSuccess(returnCode) {
                NSLog("Encode completed successfully in %ld milliseconds; playing video.\n", anySession.getDuration())
                addUIAction { self.playVideo() }
            } else {
                NSLog("Encode failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: state), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
                addUIAction { self.hideProgressDialogAndAlert("Encode failed. Please check logs for the details.") }
            }
        }, withLogCallback: { log in
            NSLog("%@", log?.getMessage() ?? "")
        }, withStatisticsCallback: { statistics in
            addUIAction {
                self.statistics = statistics
                self.updateProgressDialog()
            }
        })
        if let session = session {
            let anySession: Session = session
            NSLog("Async FFmpeg process started with sessionId %ld.\n", anySession.getId())
        }
    }

    func playVideo() {
        let asset = AVAsset(url: URL(fileURLWithPath: getVideoPath()))
        let newVideo = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        activeItem = newVideo
        statusObservation = newVideo.observe(\.status, options: [.old, .new]) { item, _ in
            let status = item.status.rawValue
            addUIAction {
                switch status {
                case AVPlayerItem.Status.readyToPlay.rawValue:
                    self.player.play()
                case AVPlayerItem.Status.failed.rawValue:
                    if let error = self.activeItem?.error {
                        let nsError = error as NSError
                        self.alertTitle = "Player Error"
                        self.alertMessage = nsError.localizedFailureReason ?? nsError.localizedDescription
                    }
                default:
                    NSLog("Status %ld received from player.\n", status)
                }
            }
        }
        player.insert(newVideo, after: nil)
    }

    func getPixelFormat() -> String {
        return codec == "x265" ? "yuv420p10le" : "yuv420p"
    }

    func getSelectedVideoCodec() -> String {
        let videoCodec = codec
        switch videoCodec {
        case "h264 (x264)": return "libx264"
        case "h264 (openh264)": return "libopenh264"
        case "h264 (videotoolbox)": return "h264_videotoolbox"
        case "x265": return "libx265"
        case "xvid": return "libxvid"
        case "vp8": return "libvpx"
        case "vp9": return "libvpx-vp9"
        case "aom": return "libaom-av1"
        case "svt-av1": return "libsvtav1"
        case "kvazaar": return "libkvazaar"
        case "theora": return "libtheora"
        default: return videoCodec
        }
    }

    func getVideoPath() -> String {
        let videoCodec = codec
        let ext: String
        if videoCodec == "vp8" || videoCodec == "vp9" {
            ext = "webm"
        } else if videoCodec == "theora" {
            ext = "ogv"
        } else if videoCodec == "hap" {
            ext = "mov"
        } else {
            ext = "mp4"
        }
        return documentsDirectory().appendingPathComponent("video.").appending(ext)
    }

    func getCustomOptions() -> String {
        switch codec {
        case "x265": return "-crf 28 -preset fast "
        case "vp8": return "-b:v 1M -crf 10 "
        case "vp9": return "-b:v 2M "
        case "aom": return "-crf 30 -strict experimental "
        case "svt-av1": return "-preset 8 -crf 35 "
        case "theora": return "-qscale:v 7 "
        case "hap": return "-format hap_q "
        default: return ""
        }
    }

    func setActive() {
        NSLog("Video Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func showProgressDialog(_ dialogMessage: String) {
        statistics = nil
        progress = dialogMessage
    }

    func updateProgressDialog() {
        guard let statistics = statistics, statistics.getTime() >= 0 else { return }
        let percentage = Int(statistics.getTime() * 100 / 9000)
        progress = "Encoding video  % \(percentage) \n\n"
    }

    func hideProgressDialog() {
        progress = nil
    }

    func hideProgressDialogAndAlert(_ message: String) {
        progress = nil
        alertTitle = "Error"
        alertMessage = message
    }
}

struct VideoView: View {
    @StateObject private var model = VideoModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Video codec", selection: $model.codec) {
                ForEach(model.codecs, id: \.self) { Text($0) }
            }
            Button("ENCODE") { model.encodeVideo() }.buttonStyle(.borderedProminent)
            VideoBox(player: model.player)
        }
        .padding(24)
        .onAppear { model.setActive() }
        .overlay { if let p = model.progress { ProgressOverlay(message: p) } }
        .alert(model.alertTitle, isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

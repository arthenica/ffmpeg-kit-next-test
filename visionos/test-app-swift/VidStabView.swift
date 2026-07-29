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

@MainActor final class VidStabModel: ObservableObject {
    @Published var progress: String? = nil
    @Published var alertMessage: String? = nil
    let player = AVQueuePlayer()
    let stabilizedVideoPlayer = AVQueuePlayer()

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            NSLog("%@", log?.getMessage() ?? "")
        }
    }

    func stabilizedVideo() {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
        let shakeResultsFile = getShakeResultsFilePath()
        let videoFile = getVideoPath()
        let stabilizedVideoFile = getStabilizedVideoPath()
        player.removeAllItems()
        stabilizedVideoPlayer.removeAllItems()
        try? FileManager.default.removeItem(atPath: shakeResultsFile)
        try? FileManager.default.removeItem(atPath: videoFile)
        try? FileManager.default.removeItem(atPath: stabilizedVideoFile)
        NSLog("Testing VID.STAB\n")
        showProgressDialog("Creating video\n\n")
        let videoCodec = Video.packageVideoCodec()
        let ffmpegCommand = Video.generateShakingVideoScript(image1, image2, image3, videoFile, videoCodec)
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
            addUIAction { self.hideProgressDialog() }
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                NSLog("Create completed successfully; stabilizing video.\n")
                let analyzeVideoCommand = "-hide_banner -y -i \(videoFile) -vf vidstabdetect=shakiness=10:accuracy=15:result=\(shakeResultsFile) -f null -"
                addUIAction { self.showProgressDialog("Stabilizing video\n\n") }
                NSLog("FFmpeg process started with arguments '%@'.\n", analyzeVideoCommand)
                FFmpegKit.executeAsync(analyzeVideoCommand) { secondSession in
                    guard let secondSession = secondSession else { return }
                    let anySecondSession: Session = secondSession
                    NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySecondSession.getState()), String(describing: anySecondSession.getReturnCode()), notNull(anySecondSession.getFailStackTrace(), "\n"))
                    if ReturnCode.isSuccess(anySecondSession.getReturnCode()) {
                        let stabilizeVideoCommand = "-hide_banner -y -i \(videoFile) -vf vidstabtransform=smoothing=30:input=\(shakeResultsFile) -c:v \(videoCodec) \(stabilizedVideoFile)"
                        NSLog("FFmpeg process started with arguments '%@'.\n", stabilizeVideoCommand)
                        FFmpegKit.executeAsync(stabilizeVideoCommand) { thirdSession in
                            guard let thirdSession = thirdSession else { return }
                            let anyThirdSession: Session = thirdSession
                            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anyThirdSession.getState()), String(describing: anyThirdSession.getReturnCode()), notNull(anyThirdSession.getFailStackTrace(), "\n"))
                            addUIAction {
                                self.hideProgressDialog()
                                if ReturnCode.isSuccess(anyThirdSession.getReturnCode()) {
                                    NSLog("Stabilize video completed successfully; playing videos.\n")
                                    self.playVideo()
                                    self.playStabilizedVideo()
                                } else {
                                    self.hideProgressDialogAndAlert("Stabilize video failed. Please check logs for the details.")
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            self.hideProgressDialogAndAlert("Stabilize video failed. Please check logs for the details.")
                        }
                    }
                }
            } else {
                addUIAction { self.hideProgressDialogAndAlert("Create video failed. Please check logs for the details.") }
            }
        }
    }

    func playVideo() {
        let asset = AVAsset(url: URL(fileURLWithPath: getVideoPath()))
        let video = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        player.insert(video, after: nil)
        player.play()
    }

    func playStabilizedVideo() {
        let asset = AVAsset(url: URL(fileURLWithPath: getStabilizedVideoPath()))
        let video = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        stabilizedVideoPlayer.insert(video, after: nil)
        stabilizedVideoPlayer.play()
    }

    func getShakeResultsFilePath() -> String {
        return documentsDirectory().appendingPathComponent("transforms.trf")
    }

    func getVideoPath() -> String {
        return documentsDirectory().appendingPathComponent("video.mp4")
    }

    func getStabilizedVideoPath() -> String {
        return documentsDirectory().appendingPathComponent("video-stabilized.mp4")
    }

    func setActive() {
        NSLog("VidStab Tab Activated")
        enableLogCallback()
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func showProgressDialog(_ dialogMessage: String) {
        progress = dialogMessage
    }

    func hideProgressDialog() {
        progress = nil
    }

    func hideProgressDialogAndAlert(_ message: String) {
        progress = nil
        alertMessage = message
    }
}

struct VidStabView: View {
    @StateObject private var model = VidStabModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Original video plays above, stabilized video below.").font(.subheadline).foregroundStyle(.secondary)
            Button("STABILIZE VIDEO") { model.stabilizedVideo() }.buttonStyle(.borderedProminent)
            VideoBox(player: model.player)
            VideoBox(player: model.stabilizedVideoPlayer)
        }
        .padding(24).onAppear { model.setActive() }
        .overlay { if let p = model.progress { ProgressOverlay(message: p) } }
        .alert("Error", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

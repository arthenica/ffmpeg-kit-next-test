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

import AVFoundation
import AVKit
import QuartzCore
import SwiftUI
import ffmpegkit

@MainActor final class PipeModel: ObservableObject {
    @Published var progress: String? = nil
    @Published var alertTitle: String = "Error"
    @Published var alertMessage: String? = nil
    let player = AVQueuePlayer()

    private var activeItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var statistics: Statistics?

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            addUIAction { NSLog("%@", log?.getMessage() ?? "") }
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

    nonisolated static func startAsyncCopyImageProcess(_ imagePath: String, onPipe namedPipePath: String) {
        DispatchQueue.global(qos: .default).async {
            NSLog("Starting copy %@ to pipe %@ operation.\n", imagePath, namedPipePath)
            guard let fileHandle = FileHandle(forReadingAtPath: imagePath) else {
                NSLog("Failed to open file %@.\n", imagePath)
                return
            }
            guard let pipeHandle = FileHandle(forWritingAtPath: namedPipePath) else {
                NSLog("Failed to open pipe %@.\n", namedPipePath)
                fileHandle.closeFile()
                return
            }
            let startTime = CACurrentMediaTime()
            var totalBytes: UInt64 = 0
            fileHandle.seek(toFileOffset: 0)
            while true {
                let data = fileHandle.readData(ofLength: 4096)
                if data.isEmpty { break }
                totalBytes += UInt64(data.count)
                pipeHandle.write(data)
            }
            let endTime = CACurrentMediaTime()
            NSLog("Completed copy %@ to pipe %@ operation. %lu bytes copied in %f seconds.\n", imagePath, namedPipePath, totalBytes, endTime - startTime)
            fileHandle.closeFile()
            pipeHandle.closeFile()
        }
    }

    func createVideo() {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
        let videoFile = getVideoPath()
        let pipe1 = FFmpegKitConfig.registerNewFFmpegPipe()
        let pipe2 = FFmpegKitConfig.registerNewFFmpegPipe()
        let pipe3 = FFmpegKitConfig.registerNewFFmpegPipe()
        player.removeAllItems()
        activeItem = nil
        try? FileManager.default.removeItem(atPath: videoFile)
        let videoCodec = Video.packageVideoCodec()
        NSLog("Testing PIPE with '%@' codec\n", videoCodec)
        showProgressDialog("Creating video\n\n")
        let ffmpegCommand = Video.generateCreateVideoWithPipesScript(pipe1 ?? "", pipe2 ?? "", pipe3 ?? "", videoFile, videoCodec)
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: state), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
            addUIAction { self.hideProgressDialog() }
            if let pipe1 = pipe1 { FFmpegKitConfig.closeFFmpegPipe(pipe1) }
            if let pipe2 = pipe2 { FFmpegKitConfig.closeFFmpegPipe(pipe2) }
            if let pipe3 = pipe3 { FFmpegKitConfig.closeFFmpegPipe(pipe3) }
            addUIAction {
                if ReturnCode.isSuccess(returnCode) {
                    NSLog("Create completed successfully; playing video.\n")
                    self.playVideo()
                } else {
                    self.hideProgressDialogAndAlert("Create failed. Please check logs for the details.")
                }
            }
        }
        if let pipe1 = pipe1 { PipeModel.startAsyncCopyImageProcess(image1, onPipe: pipe1) }
        if let pipe2 = pipe2 { PipeModel.startAsyncCopyImageProcess(image2, onPipe: pipe2) }
        if let pipe3 = pipe3 { PipeModel.startAsyncCopyImageProcess(image3, onPipe: pipe3) }
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

    func getVideoPath() -> String {
        return documentsDirectory().appendingPathComponent("video.mp4")
    }

    func setActive() {
        NSLog("Pipe Tab Activated")
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
        progress = "Creating video  % \(percentage) \n\n"
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

struct PipeView: View {
    @StateObject private var model = PipeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Creates a video using pipe redirection. The created video plays below.").font(.subheadline).foregroundStyle(.secondary)
            Button("CREATE") { model.createVideo() }.buttonStyle(.borderedProminent)
            VideoBox(player: model.player)
        }
        .padding(24).onAppear { model.setActive() }
        .overlay { if let p = model.progress { ProgressOverlay(message: p) } }
        .alert(model.alertTitle, isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

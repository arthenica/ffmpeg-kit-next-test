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
import UIKit
import ffmpegkit

@objc(PipeViewController)
class PipeViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet var videoPlayerFrame: UILabel!

    private var player: AVQueuePlayer!
    private var playerLayer: AVPlayerLayer!
    private var activeItem: AVPlayerItem?
    private var alertController: UIAlertController?
    private var indicator: UIActivityIndicatorView!
    private var progressMessageLabel: UILabel?
    private var statistics: Statistics?

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyButtonStyle(createButton)
        Util.applyVideoPlayerFrameStyle(videoPlayerFrame)
        Util.applyHeaderStyle(header)
        player = AVQueuePlayer()
        playerLayer = AVPlayerLayer(player: player)
        var rectangularFrame = view.layer.bounds
        rectangularFrame.size.width = view.layer.bounds.size.width - 40
        rectangularFrame.origin.x = 20
        rectangularFrame.origin.y = createButton.layer.bounds.origin.y + 120
        playerLayer.frame = rectangularFrame
        view.layer.addSublayer(playerLayer)
        addUIAction { self.setActive() }
    }

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

    static func startAsyncCopyImageProcess(_ imagePath: String, onPipe namedPipePath: String) {
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

    @IBAction func createVideo(_ sender: Any) {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("machupicchu.jpg")
        let image2 = resourceFolder.appendingPathComponent("pyramid.jpg")
        let image3 = resourceFolder.appendingPathComponent("stonehenge.jpg")
        let videoFile = getVideoPath()
        let pipe1 = FFmpegKitConfig.registerNewFFmpegPipe()
        let pipe2 = FFmpegKitConfig.registerNewFFmpegPipe()
        let pipe3 = FFmpegKitConfig.registerNewFFmpegPipe()
        player.removeAllItems()
        activeItem = nil
        try? FileManager.default.removeItem(atPath: videoFile)
        NSLog("Testing PIPE with 'mpeg4' codec\n")
        showProgressDialog("Creating video\n\n")
        let ffmpegCommand = Video.generateCreateVideoWithPipesScript(pipe1 ?? "", pipe2 ?? "", pipe3 ?? "", videoFile)
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
        if let pipe1 = pipe1 { PipeViewController.startAsyncCopyImageProcess(image1, onPipe: pipe1) }
        if let pipe2 = pipe2 { PipeViewController.startAsyncCopyImageProcess(image2, onPipe: pipe2) }
        if let pipe3 = pipe3 { PipeViewController.startAsyncCopyImageProcess(image3, onPipe: pipe3) }
    }

    func playVideo() {
        let asset = AVAsset(url: URL(fileURLWithPath: getVideoPath()))
        let newVideo = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        activeItem = newVideo
        newVideo.addObserver(self, forKeyPath: "status", options: [.old, .new], context: nil)
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
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alertController = alert
        indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.color = .black
        progressMessageLabel = Util.showProgressLabel(dialogMessage, indicator: indicator, on: alert)
        indicator.startAnimating()
        present(alert, animated: true, completion: nil)
    }

    func updateProgressDialog() {
        guard let statistics = statistics, statistics.getTime() >= 0 else { return }
        let percentage = Int(statistics.getTime() * 100 / 9000)
        progressMessageLabel?.text = "Creating video  % \(percentage)"
    }

    func hideProgressDialog() {
        indicator.stopAnimating()
        dismiss(animated: true, completion: nil)
    }

    func hideProgressDialogAndAlert(_ message: String) {
        indicator.stopAnimating()
        dismiss(animated: true) {
            Util.alert(self, withTitle: "Error", message: message, andButtonText: "OK")
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        let status = (change?[.newKey] as? NSNumber)?.intValue ?? -1
        switch status {
        case AVPlayerItem.Status.readyToPlay.rawValue:
            player.play()
        case AVPlayerItem.Status.failed.rawValue:
            if let error = activeItem?.error {
                let nsError = error as NSError
                Util.alert(self, withTitle: "Player Error", message: nsError.localizedFailureReason ?? nsError.localizedDescription, andButtonText: "OK")
            }
        default:
            NSLog("Status %ld received from player.\n", status)
        }
    }
}

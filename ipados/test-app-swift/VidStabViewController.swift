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
import UIKit
import ffmpegkit

@objc(VidStabViewController)
class VidStabViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var stabilizeVideoButton: UIButton!
    @IBOutlet var videoPlayerFrame: UILabel!
    @IBOutlet var stabilizedVideoPlayerFrame: UILabel!

    private var player: AVQueuePlayer!
    private var playerLayer: AVPlayerLayer!
    private var stabilizedVideoPlayer: AVQueuePlayer!
    private var stabilizedVideoPlayerLayer: AVPlayerLayer!
    private var indicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyButtonStyle(stabilizeVideoButton)
        Util.applyVideoPlayerFrameStyle(videoPlayerFrame)
        Util.applyVideoPlayerFrameStyle(stabilizedVideoPlayerFrame)
        Util.applyHeaderStyle(header)
        player = AVQueuePlayer()
        playerLayer = AVPlayerLayer(player: player)
        stabilizedVideoPlayer = AVQueuePlayer()
        stabilizedVideoPlayerLayer = AVPlayerLayer(player: stabilizedVideoPlayer)
        stabilizedVideoPlayerFrame.frame = CGRect(x: 20, y: 20, width: view.bounds.size.width - 40, height: view.bounds.size.height / 4)
        var upperRectangularFrame = view.bounds
        upperRectangularFrame.size.width = stabilizedVideoPlayerFrame.bounds.size.width
        upperRectangularFrame.size.height = stabilizedVideoPlayerFrame.bounds.size.height - 4
        upperRectangularFrame.origin.x = 0
        upperRectangularFrame.origin.y = view.bounds.size.height / 100 - 4
        playerLayer.frame = upperRectangularFrame
        playerLayer.videoGravity = .resizeAspect
        videoPlayerFrame.layer.addSublayer(playerLayer)
        var lowerRectangularFrame = view.bounds
        lowerRectangularFrame.size.width = stabilizedVideoPlayerFrame.bounds.size.width
        lowerRectangularFrame.size.height = stabilizedVideoPlayerFrame.bounds.size.height + 4
        lowerRectangularFrame.origin.x = 0
        lowerRectangularFrame.origin.y = view.bounds.size.height / 50 - 4
        stabilizedVideoPlayerLayer.frame = lowerRectangularFrame
        stabilizedVideoPlayerLayer.videoGravity = .resizeAspect
        stabilizedVideoPlayerFrame.layer.addSublayer(stabilizedVideoPlayerLayer)
        addUIAction { self.setActive() }
    }

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            NSLog("%@", log?.getMessage() ?? "")
        }
    }

    @IBAction func stabilizedVideo(_ sender: Any) {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("machupicchu.jpg")
        let image2 = resourceFolder.appendingPathComponent("pyramid.jpg")
        let image3 = resourceFolder.appendingPathComponent("stonehenge.jpg")
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
        let ffmpegCommand = Video.generateShakingVideoScript(image1, image2, image3, videoFile)
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
                        let stabilizeVideoCommand = "-hide_banner -y -i \(videoFile) -vf vidstabtransform=smoothing=30:input=\(shakeResultsFile) \(stabilizedVideoFile)"
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
        let pending = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.color = .black
        Util.showProgressLabel(dialogMessage, indicator: indicator, on: pending)
        indicator.startAnimating()
        present(pending, animated: true, completion: nil)
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
}

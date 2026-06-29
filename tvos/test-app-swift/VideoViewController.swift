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

@objc(VideoViewController)
class VideoViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var videoCodecText: UITextField!
    @IBOutlet var encodeButton: UIButton!
    @IBOutlet var videoPlayerFrame: UILabel!

    private var player: AVQueuePlayer!
    private var playerLayer: AVPlayerLayer!
    private var activeItem: AVPlayerItem?
    private var alertController: UIAlertController?
    private var indicator: UIActivityIndicatorView!
    private var statistics: Statistics?

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyEditTextStyle(videoCodecText)
        Util.applyButtonStyle(encodeButton)
        Util.applyVideoPlayerFrameStyle(videoPlayerFrame)
        Util.applyHeaderStyle(header)
        player = AVQueuePlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resize
        let rectangularFrame = CGRect(
            x: videoPlayerFrame.frame.origin.x + 20,
            y: videoPlayerFrame.frame.origin.y + 20,
            width: videoPlayerFrame.frame.size.width - 40,
            height: videoPlayerFrame.frame.size.height - 40
        )
        playerLayer.frame = rectangularFrame
        view.layer.addSublayer(playerLayer)
        addUIAction { self.setActive() }
    }

    @IBAction func encodeVideo(_ sender: Any) {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("machupicchu.jpg")
        let image2 = resourceFolder.appendingPathComponent("pyramid.jpg")
        let image3 = resourceFolder.appendingPathComponent("stonehenge.jpg")
        let videoFile = getVideoPath()
        player.removeAllItems()
        activeItem = nil
        try? FileManager.default.removeItem(atPath: videoFile)
        let videoCodec = videoCodecText.text ?? ""
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
        newVideo.addObserver(self, forKeyPath: "status", options: [.old, .new], context: nil)
        player.insert(newVideo, after: nil)
    }

    func getPixelFormat() -> String {
        return videoCodecText.text == "x265" ? "yuv420p10le" : "yuv420p"
    }

    func getSelectedVideoCodec() -> String {
        let videoCodec = videoCodecText.text ?? ""
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
        let videoCodec = videoCodecText.text ?? ""
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
        switch videoCodecText.text ?? "" {
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
        alertController = UIAlertController(title: nil, message: dialogMessage, preferredStyle: .alert)
        indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.color = .black
        indicator.translatesAutoresizingMaskIntoConstraints = false
        alertController?.view.addSubview(indicator)
        let views: [String: Any] = ["pending": alertController!.view as Any, "indicator": indicator as Any]
        alertController?.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[indicator]-(20)-|", options: [], metrics: nil, views: views))
        alertController?.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[indicator]|", options: [], metrics: nil, views: views))
        indicator.startAnimating()
        present(alertController!, animated: true, completion: nil)
    }

    func updateProgressDialog() {
        guard let statistics = statistics, statistics.getTime() >= 0, let alertController = alertController else { return }
        let percentage = Int(statistics.getTime() * 100 / 9000)
        alertController.message = "Encoding video  % \(percentage) \n\n"
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

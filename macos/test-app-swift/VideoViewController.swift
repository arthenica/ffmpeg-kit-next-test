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
import Cocoa
import ffmpegkit

@objc(VideoViewController)
class VideoViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, ActivatableTab {
    @IBOutlet var videoCodecComboBox: NSComboBox!
    @IBOutlet var encodeButton: NSButton!
    @IBOutlet var videoPlayerFrame: AVPlayerView!

    private let codecData = ["mpeg4", "h264 (x264)", "h264 (openh264)", "h264 (videotoolbox)", "x265", "xvid", "vp8", "vp9", "aom", "svt-av1", "kvazaar", "theora", "hap"]
    private var selectedCodec = 0
    private var player = AVQueuePlayer()
    private var activeItem: AVPlayerItem?
    private var indicator = ProgressIndicator()
    private var statistics: Statistics?

    override func viewDidLoad() {
        super.viewDidLoad()
        videoCodecComboBox.usesDataSource = true
        videoCodecComboBox.dataSource = self
        videoCodecComboBox.delegate = self
        videoCodecComboBox.stringValue = codecData[selectedCodec]
        Util.applyComboBoxStyle(videoCodecComboBox)
        Util.applyButtonStyle(encodeButton)
        Util.applyVideoPlayerFrameStyle(videoPlayerFrame)
        videoPlayerFrame.player = player
        addUIAction { self.setActive() }
    }

    func comboBox(_ comboBox: NSComboBox, indexOfItemWithStringValue string: String) -> Int {
        return codecData.firstIndex(of: string) ?? NSNotFound
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return codecData[index]
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return codecData.count
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        selectedCodec = videoCodecComboBox.indexOfSelectedItem
    }

    @IBAction func encodeVideo(_ sender: Any) {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
        let videoFile = getVideoPath()
        player.removeAllItems()
        activeItem = nil
        try? FileManager.default.removeItem(atPath: videoFile)
        let videoCodec = codecData[selectedCodec]
        NSLog("Testing VIDEO encoding with '%@' codec\n", videoCodec)
        showProgressDialog("Encoding video\n\n")
        let ffmpegCommand = Video.generateVideoEncodeScriptWithCustomPixelFormat(image1, image2, image3, videoFile, getSelectedVideoCodec(), getPixelFormat(), getCustomOptions())
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)

        let session = FFmpegKit.executeAsync(ffmpegCommand, withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            addUIAction { self.hideProgressDialog() }
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                NSLog("Encode completed successfully in %ld milliseconds; playing video.\n", anySession.getDuration())
                addUIAction { self.playVideo() }
            } else {
                NSLog("Encode failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
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
        return codecData[selectedCodec] == "x265" ? "yuv420p10le" : "yuv420p"
    }

    func getSelectedVideoCodec() -> String {
        switch codecData[selectedCodec] {
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
        default: return codecData[selectedCodec]
        }
    }

    func getVideoPath() -> String {
        let videoCodec = codecData[selectedCodec]
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
        switch codecData[selectedCodec] {
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
        indicator.show(view, message: dialogMessage, indeterminate: true, asyncBlock: nil)
    }

    func updateProgressDialog() {
        guard let statistics = statistics, statistics.getTime() >= 0 else { return }
        indicator.updateMessage("Encoding video", percentage: Int32(statistics.getTime() * 100 / 9000))
    }

    func hideProgressDialog() {
        indicator.hide()
    }

    func hideProgressDialogAndAlert(_ message: String) {
        indicator.hide()
        Util.alert(view.window, withTitle: "Error", message: message, buttonText: "OK")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        let status = (change?[.newKey] as? NSNumber)?.intValue ?? -1
        switch status {
        case AVPlayerItem.Status.readyToPlay.rawValue:
            player.play()
        case AVPlayerItem.Status.failed.rawValue:
            if let error = activeItem?.error {
                let nsError = error as NSError
                Util.alert(view.window, withTitle: "Player Error", message: nsError.localizedFailureReason ?? nsError.localizedDescription, buttonText: "OK")
            }
        default:
            NSLog("Status %ld received from player.\n", status)
        }
    }
}

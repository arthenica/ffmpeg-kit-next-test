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

import UIKit
import ffmpegkit

@objc(OtherViewController)
class OtherViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var otherTestText: UITextField!
    @IBOutlet var runButton: UIButton!
    @IBOutlet var outputText: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyEditTextStyle(otherTestText)
        Util.applyButtonStyle(runButton)
        Util.applyOutputTextStyle(outputText)
        Util.applyHeaderStyle(header)
        addUIAction { self.setActive() }
    }

    @IBAction func runTest(_ sender: Any) {
        let selectedTest = otherTestText.text ?? ""
        clearOutput()
        if selectedTest == "chromaprint" {
            testChromaprint()
        } else if selectedTest == "dav1d" {
            testDav1d()
        } else if selectedTest == "webp" {
            testWebp()
        } else if selectedTest == "libjxl" {
            testLibjxl()
        } else if selectedTest == "zscale" {
            testZscale()
        } else if selectedTest == "vvenc" {
            testVvenc()
        }
    }

    func testChromaprint() {
        NSLog("Testing 'chromaprint' mutex\n")
        let audioSampleFile = getChromaprintSamplePath()
        try? FileManager.default.removeItem(atPath: audioSampleFile)
        let ffmpegCommand = "-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le \(audioSampleFile)"
        NSLog("Creating audio sample with '%@'.\n", ffmpegCommand)
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                NSLog("AUDIO sample created\n")
                let command = "-hide_banner -y -i \(audioSampleFile) -f chromaprint -fp_format 2 \(self.getChromaprintOutputPath())"
                NSLog("FFmpeg process started with arguments '%@'.\n", command)
                FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                    guard let session = session else { return }
                    let anySession: Session = session
                    NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
                }, withLogCallback: { log in
                    addUIAction { self.appendOutput(log?.getMessage() ?? "") }
                }, withStatisticsCallback: nil)
            }
        }
    }

    func testDav1d() {
        NSLog("Testing decoding 'av1' codec\n")
        let ffmpegCommand = "-hide_banner -y -i %@ -c:v mpeg4 %@"
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    func testWebp() {
        let imageFile = (Bundle.main.resourcePath ?? "").appendingPathComponent("machupicchu.jpg")
        let outputFile = documentsDirectory().appendingPathComponent("video.webp")
        NSLog("Testing 'webp' codec\n")
        let ffmpegCommand = "-hide_banner -y -i \(imageFile) \(outputFile)"
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    func testLibjxl() {
        let imageFile = (Bundle.main.resourcePath ?? "").appendingPathComponent("machupicchu.jpg")
        let jxlOutputFile = getLibjxlOutputPath()
        let decodedOutputFile = getLibjxlDecodedOutputPath()
        try? FileManager.default.removeItem(atPath: jxlOutputFile)
        try? FileManager.default.removeItem(atPath: decodedOutputFile)
        NSLog("Testing 'libjxl' codec\n")
        let ffmpegCommand = "-hide_banner -y -i \(imageFile) -frames:v 1 -vf format=rgb24,setparams=range=pc:color_primaries=bt709:color_trc=iec61966-2-1:colorspace=gbr -c:v libjxl -distance 1.0 -xyb 1 -update 1 \(jxlOutputFile)"
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        FFmpegKit.executeAsync(ffmpegCommand, withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                let decodeCommand = "-hide_banner -y -i \(jxlOutputFile) -frames:v 1 -c:v png -update 1 \(decodedOutputFile)"
                NSLog("FFmpeg process started with arguments '%@'.\n", decodeCommand)
                self.executeWithOutput(decodeCommand)
            }
        }, withLogCallback: { log in
            addUIAction { self.appendOutput(log?.getMessage() ?? "") }
        }, withStatisticsCallback: nil)
    }

    func testZscale() {
        let videoFile = documentsDirectory().appendingPathComponent("video.mp4")
        let zscaledVideoFile = documentsDirectory().appendingPathComponent("video.zscaled.mp4")
        NSLog("Testing 'zscale' filter with video file created on the Video tab\n")
        let ffmpegCommand = Video.generateZscaleVideoScript(videoFile, zscaledVideoFile)
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    func testVvenc() {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("machupicchu.jpg")
        let image2 = resourceFolder.appendingPathComponent("pyramid.jpg")
        let image3 = resourceFolder.appendingPathComponent("stonehenge.jpg")
        let outputFile = getVvencOutputPath()
        try? FileManager.default.removeItem(atPath: outputFile)
        NSLog("Testing 'vvenc' codec\n")
        let ffmpegCommand = Video.generateVideoEncodeScriptWithCustomPixelFormat(image1, image2, image3, outputFile, "libvvenc", "yuv420p10le", "-preset faster -qp 32 ")
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    private func executeWithOutput(_ command: String) {
        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
        }, withLogCallback: { log in
            addUIAction { self.appendOutput(log?.getMessage() ?? "") }
        }, withStatisticsCallback: nil)
    }

    func getChromaprintSamplePath() -> String {
        return documentsDirectory().appendingPathComponent("audio-sample.wav")
    }

    func getDav1dOutputPath() -> String {
        return documentsDirectory().appendingPathComponent("video.mp4")
    }

    func getChromaprintOutputPath() -> String {
        return documentsDirectory().appendingPathComponent("chromaprint.txt")
    }

    func getLibjxlOutputPath() -> String {
        return documentsDirectory().appendingPathComponent("image.jxl")
    }

    func getLibjxlDecodedOutputPath() -> String {
        return documentsDirectory().appendingPathComponent("image.jxl.png")
    }

    func getVvencOutputPath() -> String {
        return documentsDirectory().appendingPathComponent("video.266")
    }

    func setActive() {
        NSLog("Other Tab Activated")
    }

    func appendOutput(_ message: String) {
        outputText.text = outputText.text.appending(message)
        if !outputText.text.isEmpty {
            outputText.scrollRangeToVisible(NSRange(location: outputText.text.count - 1, length: 1))
        }
    }

    func clearOutput() {
        outputText.text = ""
    }
}

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

import Cocoa
import ffmpegkit

@objc(OtherViewController)
class OtherViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, ActivatableTab {
    @IBOutlet var otherTestComboBox: NSComboBox!
    @IBOutlet var runButton: NSButton!
    @IBOutlet var outputText: NSTextView!

    private let testData = ["chromaprint", "dav1d", "webp", "libjxl", "zscale", "vvenc"]
    private var selectedTest = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        otherTestComboBox.usesDataSource = true
        otherTestComboBox.dataSource = self
        otherTestComboBox.delegate = self
        otherTestComboBox.stringValue = testData[selectedTest]
        Util.applyComboBoxStyle(otherTestComboBox)
        Util.applyButtonStyle(runButton)
        Util.applyOutputTextStyle(outputText)
        addUIAction { self.setActive() }
    }

    func comboBox(_ comboBox: NSComboBox, indexOfItemWithStringValue string: String) -> Int {
        return testData.firstIndex(of: string) ?? NSNotFound
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return testData[index]
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return testData.count
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        selectedTest = otherTestComboBox.indexOfSelectedItem
    }

    @IBAction func runTest(_ sender: Any) {
        clearOutput()
        switch selectedTest {
        case 0: testChromaprint()
        case 1: testDav1d()
        case 2: testWebp()
        case 3: testLibjxl()
        case 4: testZscale()
        case 5: testVvenc()
        default: break
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
        let ffmpegCommand = "-hide_banner -y -i \(DAV1D_TEST_DEFAULT_URL) -c:v mpeg4 \(getDav1dOutputPath())"
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    func testWebp() {
        let imageFile = (Bundle.main.resourcePath ?? "").appendingPathComponent("tree.jpg")
        let outputFile = documentsDirectory().appendingPathComponent("video.webp")
        NSLog("Testing 'webp' codec\n")
        let ffmpegCommand = "-hide_banner -y -i \(imageFile) \(outputFile)"
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)
        executeWithOutput(ffmpegCommand)
    }

    func testLibjxl() {
        let imageFile = (Bundle.main.resourcePath ?? "").appendingPathComponent("tree.jpg")
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
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
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
        outputText.string = outputText.string.appending(message)
        outputText.scrollRangeToVisible(NSRange(location: outputText.string.count, length: 0))
    }

    func clearOutput() {
        outputText.string = ""
    }
}

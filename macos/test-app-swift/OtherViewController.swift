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

    private let testData = ["chromaprint", "dav1d", "webp", "zscale"]
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
        case 3: testZscale()
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
        let ffmpegCommand = "-hide_banner -y -i \(DAV1D_TEST_DEFAULT_URL) \(getDav1dOutputPath())"
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

    func testZscale() {
        let videoFile = documentsDirectory().appendingPathComponent("video.mp4")
        let zscaledVideoFile = documentsDirectory().appendingPathComponent("video.zscaled.mp4")
        NSLog("Testing 'zscale' filter with video file created on the Video tab\n")
        let ffmpegCommand = Video.generateZscaleVideoScript(videoFile, zscaledVideoFile)
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

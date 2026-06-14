/*
 * Copyright (c) 2026 Taner Sener
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

private func ffkitEscapeDrawtextText(_ text: String) -> String {
    return text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "'", with: "'\\''")
}

private func ffkitBuildMemProtocolCommand(_ inputUrl: String, _ outputUrl: String, _ fontPath: String, _ text: String) -> String {
    let drawtext = "drawtext=fontfile=\(fontPath):text='\(ffkitEscapeDrawtextText(text))':x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5"
    return "-y -i \(inputUrl) -vf \"\(drawtext)\" -frames:v 1 -f image2 -c:v mjpeg -update 1 \(outputUrl)"
}

private func ffkitHumanReadableByteCount(_ bytes: Int64) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    }
    let kb = Double(bytes) / 1024.0
    if kb < 1024 {
        return String(format: "%.1f KB", kb)
    }
    return String(format: "%.1f MB", kb / 1024.0)
}

private func ffkitFormatStatus(_ inputUrl: String, _ inputSize: Int64, _ outputUrl: String, _ outputSize: Int64) -> String {
    return "in \(inputUrl) (\(ffkitHumanReadableByteCount(inputSize))) -> drawtext -> out \(outputUrl) (\(ffkitHumanReadableByteCount(outputSize)))"
}

@objc(FFKitProtocolsViewController)
class FFKitProtocolsViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, ActivatableTab {
    @IBOutlet var protocolComboBox: NSComboBox!
    @IBOutlet var overlayText: NSTextField!
    @IBOutlet var runFFmpegButton: NSButton!
    @IBOutlet var runFFprobeButton: NSButton!
    @IBOutlet var resultImageView: NSImageView!
    @IBOutlet var outputText: NSTextView!
    @IBOutlet var statusText: NSTextField!

    private let protocolList = ["ffkitmem"]
    private var selectedProtocol = "ffkitmem"

    override func viewDidLoad() {
        super.viewDidLoad()
        protocolComboBox.usesDataSource = true
        protocolComboBox.dataSource = self
        protocolComboBox.delegate = self
        protocolComboBox.selectItem(at: 0)
        overlayText.stringValue = "FFmpegKitNext"
        Util.applyComboBoxStyle(protocolComboBox)
        Util.applyEditTextStyle(overlayText)
        Util.applyButtonStyle(runFFmpegButton)
        Util.applyButtonStyle(runFFprobeButton)
        Util.applyOutputTextStyle(outputText)
        resultImageView.isHidden = true
        outputText.enclosingScrollView?.isHidden = true
        statusText.stringValue = "Select a protocol, then run FFmpeg or FFprobe."
        addUIAction { self.setActive() }
    }

    func setActive() {
        NSLog("FFKitProtocols Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return protocolList.count
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return protocolList[index]
    }

    func comboBox(_ comboBox: NSComboBox, indexOfItemWithStringValue string: String) -> Int {
        return protocolList.firstIndex(of: string) ?? NSNotFound
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        let index = protocolComboBox.indexOfSelectedItem
        if index >= 0 && index < protocolList.count {
            selectedProtocol = protocolList[index]
        }
    }

    @IBAction func runFFmpeg(_ sender: Any) {
        guard selectedProtocol == "ffkitmem" else {
            Util.alert(view.window, withTitle: "FFKit Protocols", message: "This protocol is not implemented yet.", buttonText: "OK")
            return
        }
        if let bytes = pickImageBytes() {
            runFFmpegMemWithBytes(bytes)
        }
    }

    @IBAction func runFFprobe(_ sender: Any) {
        guard selectedProtocol == "ffkitmem" else {
            Util.alert(view.window, withTitle: "FFKit Protocols", message: "This protocol is not implemented yet.", buttonText: "OK")
            return
        }
        if let bytes = pickImageBytes() {
            runFFprobeMemWithBytes(bytes)
        }
    }

    func pickImageBytes() -> Data? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["jpg", "jpeg", "png"]
        guard panel.runModal() == .OK, let url = panel.urls.first else {
            return nil
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            Util.alert(view.window, withTitle: "Error", message: "Could not read the selected image.", buttonText: "OK")
            return nil
        }
    }

    func runFFmpegMemWithBytes(_ bytes: Data) {
        let fontPath = (Bundle.main.resourcePath ?? "").appendingPathComponent("doppioone_regular.ttf")
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg"),
              let output = FFmpegKitOutputBuffer.create("jpg") else {
            Util.alert(view.window, withTitle: "Error", message: "Could not create ffkitmem buffers.", buttonText: "OK")
            return
        }
        guard let inputUrl = input.getUrl(), let outputUrl = output.getUrl() else {
            Util.alert(view.window, withTitle: "Error", message: "Could not create ffkitmem URLs.", buttonText: "OK")
            input.close()
            output.close()
            return
        }
        let command = ffkitBuildMemProtocolCommand(inputUrl, outputUrl, fontPath, overlayText.stringValue)
        let inputSize = input.getSize()
        statusText.stringValue = "Running..."
        NSLog("ffkitmem ffmpeg command: %@", command)

        FFmpegKit.executeAsync(command) { session in
            guard let session = session else { return }
            let anySession: Session = session
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                guard let result = output.toData() else {
                    addUIAction {
                        self.showTextResult("FFmpeg succeeded but the output image could not be read.")
                        self.statusText.stringValue = "Read failed."
                        Util.alert(self.view.window, withTitle: "Error", message: "The processed image could not be read.", buttonText: "OK")
                    }
                    input.close()
                    output.close()
                    return
                }
                let outputSize = output.getSize()
                if let image = NSImage(data: result) {
                    let status = ffkitFormatStatus(inputUrl, Int64(inputSize), outputUrl, Int64(outputSize))
                    addUIAction {
                        self.showImageResult(image)
                        self.statusText.stringValue = status
                    }
                } else {
                    addUIAction {
                        self.showTextResult("FFmpeg succeeded but the output image could not be decoded.")
                        self.statusText.stringValue = "Decode failed."
                        Util.alert(self.view.window, withTitle: "Error", message: "The processed image could not be decoded.", buttonText: "OK")
                    }
                }
            } else {
                let logs = anySession.getAllLogsAsString() ?? ""
                NSLog("ffkitmem ffmpeg failed: %@", logs)
                addUIAction {
                    self.showTextResult(logs)
                    self.statusText.stringValue = "Processing failed."
                    Util.alert(self.view.window, withTitle: "Error", message: "Processing failed. Please check output for the details.", buttonText: "OK")
                }
            }
            input.close()
            output.close()
        }
    }

    func runFFprobeMemWithBytes(_ bytes: Data) {
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg") else {
            Util.alert(view.window, withTitle: "Error", message: "Could not create ffkitmem input buffer.", buttonText: "OK")
            return
        }
        guard let inputUrl = input.getUrl() else {
            Util.alert(view.window, withTitle: "Error", message: "Could not create ffkitmem input URL.", buttonText: "OK")
            input.close()
            return
        }
        let command = "-hide_banner -print_format json -show_format -show_streams \(inputUrl)"
        statusText.stringValue = "Running..."
        NSLog("ffkitmem ffprobe command: %@", command)

        FFprobeKit.executeAsync(command) { session in
            guard let session = session else { return }
            let anySession: Session = session
            let success = ReturnCode.isSuccess(anySession.getReturnCode())
            let out = anySession.getOutput() ?? ""
            addUIAction {
                self.showTextResult(out)
                self.statusText.stringValue = "ffprobe -> \(inputUrl)"
                if !success {
                    Util.alert(self.view.window, withTitle: "Error", message: "Processing failed. Please check output for the details.", buttonText: "OK")
                }
            }
            input.close()
        }
    }

    func showImageResult(_ image: NSImage) {
        outputText.enclosingScrollView?.isHidden = true
        resultImageView.isHidden = false
        resultImageView.image = image
    }

    func showTextResult(_ text: String) {
        resultImageView.isHidden = true
        outputText.enclosingScrollView?.isHidden = false
        outputText.string = text
        outputText.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}

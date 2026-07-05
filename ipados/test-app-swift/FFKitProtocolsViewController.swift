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

import UIKit
import ffmpegkit

private func ffkitEscapeDrawtextText(_ text: String) -> String {
    var escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    escaped = escaped.replacingOccurrences(of: "'", with: "'\\''")
    return escaped
}

private func ffkitBuildMemProtocolCommand(_ inputUrl: String, _ outputUrl: String, _ fontPath: String, _ text: String) -> String {
    let drawtext = "drawtext=fontfile=\(fontPath):text='\(ffkitEscapeDrawtextText(text))':x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5"
    return "-y -i \(inputUrl) -vf \"\(drawtext)\" -frames:v 1 -f image2 -c:v mjpeg -update 1 \(outputUrl)"
}

private func ffkitHumanReadableByteCount(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    }
    let kb = Double(bytes) / 1024.0
    if kb < 1024 {
        return String(format: "%.1f KB", kb)
    }
    return String(format: "%.1f MB", kb / 1024.0)
}

private func ffkitFormatStatus(_ inputUrl: String, _ inputSize: Int, _ outputUrl: String, _ outputSize: Int) -> String {
    return "in \(inputUrl) (\(ffkitHumanReadableByteCount(inputSize))) -> drawtext -> out \(outputUrl) (\(ffkitHumanReadableByteCount(outputSize)))"
}

@objc(FFKitProtocolsViewController)
class FFKitProtocolsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var protocolPicker: UIPickerView!
    @IBOutlet var overlayText: UITextField!
    @IBOutlet var runFFmpegButton: UIButton!
    @IBOutlet var runFFprobeButton: UIButton!
    @IBOutlet var resultImageView: UIImageView!
    @IBOutlet var outputText: UITextView!
    @IBOutlet var statusText: UILabel!

    private let protocolList = ["ffkitmem"]
    private var selectedProtocol = "ffkitmem"
    private var pendingFFprobe = false

    override func viewDidLoad() {
        super.viewDidLoad()
        protocolPicker.dataSource = self
        protocolPicker.delegate = self
        overlayText.text = "FFmpegKitNext"
        Util.applyHeaderStyle(header)
        Util.applyPickerViewStyle(protocolPicker)
        Util.applyEditTextStyle(overlayText)
        Util.applyButtonStyle(runFFmpegButton)
        Util.applyButtonStyle(runFFprobeButton)
        Util.applyOutputTextStyle(outputText)
        resultImageView.isHidden = true
        outputText.isHidden = true
        statusText.text = "Select a protocol, then run FFmpeg or FFprobe."
        addUIAction { self.setActive() }
    }

    func setActive() {
        NSLog("FFKitProtocols Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return protocolList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return protocolList[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedProtocol = protocolList[row]
    }

    @IBAction func runFFmpeg(_ sender: Any) {
        if selectedProtocol != "ffkitmem" {
            Util.alert(self, withTitle: "FFKit Protocols", message: "This protocol is not implemented yet.", andButtonText: "OK")
            return
        }
        pendingFFprobe = false
        showImageSourceChooser()
    }

    @IBAction func runFFprobe(_ sender: Any) {
        if selectedProtocol != "ffkitmem" {
            Util.alert(self, withTitle: "FFKit Protocols", message: "This protocol is not implemented yet.", andButtonText: "OK")
            return
        }
        pendingFFprobe = true
        showImageSourceChooser()
    }

    func showImageSourceChooser() {
        overlayText.endEditing(true)
        let sheet = UIAlertController(title: "Select image source", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
                self.launchPickerWithSourceType(.camera)
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in
            self.launchPickerWithSourceType(.photoLibrary)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        let anchor = pendingFFprobe ? runFFprobeButton : runFFmpegButton
        sheet.popoverPresentationController?.sourceView = anchor
        sheet.popoverPresentationController?.sourceRect = anchor?.bounds ?? .zero
        present(sheet, animated: true, completion: nil)
    }

    func launchPickerWithSourceType(_ sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage, let bytes = image.jpegData(compressionQuality: 0.9) else {
            Util.alert(self, withTitle: "Error", message: "Could not read the selected image.", andButtonText: "OK")
            return
        }
        if pendingFFprobe {
            runFFprobeMemWithBytes(bytes)
        } else {
            runFFmpegMemWithBytes(bytes)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func runFFmpegMemWithBytes(_ bytes: Data) {
        let fontPath = (Bundle.main.resourcePath ?? "").appendingPathComponent("doppioone_regular.ttf")
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg"),
              let output = FFmpegKitOutputBuffer.create("jpg") else {
            Util.alert(self, withTitle: "Error", message: "Could not create memory buffers.", andButtonText: "OK")
            return
        }
        let command = ffkitBuildMemProtocolCommand(input.getUrl(), output.getUrl(), fontPath, overlayText.text ?? "")
        let inputSize = Int(input.getSize())
        statusText.text = "Running..."
        NSLog("ffkitmem ffmpeg command: %@", command)
        FFmpegKit.executeAsync(command) { session in
            defer {
                input.close()
                output.close()
            }
            guard let session = session else { return }
            let anySession: Session = session
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                let result = output.toData()
                let outputSize = Int(output.getSize())
                if let result = result, let image = UIImage(data: result) {
                    let status = ffkitFormatStatus(input.getUrl(), inputSize, output.getUrl(), outputSize)
                    addUIAction {
                        self.showImageResult(image)
                        self.statusText.text = status
                    }
                } else {
                    addUIAction {
                        self.showTextResult("FFmpeg succeeded but the output image could not be decoded.")
                        self.statusText.text = "Decode failed."
                        Util.alert(self, withTitle: "Error", message: "The processed image could not be decoded.", andButtonText: "OK")
                    }
                }
            } else {
                let logs = anySession.getAllLogsAsString() ?? ""
                NSLog("ffkitmem ffmpeg failed: %@", logs)
                addUIAction {
                    self.showTextResult(logs)
                    self.statusText.text = "Processing failed."
                    Util.alert(self, withTitle: "Error", message: "Processing failed. Please check output for the details.", andButtonText: "OK")
                }
            }
        }
    }

    func runFFprobeMemWithBytes(_ bytes: Data) {
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg") else {
            Util.alert(self, withTitle: "Error", message: "Could not create memory buffer.", andButtonText: "OK")
            return
        }
        let inputUrl = input.getUrl() ?? ""
        let command = "-hide_banner -print_format json -show_format -show_streams \(inputUrl)"
        statusText.text = "Running..."
        NSLog("ffkitmem ffprobe command: %@", command)
        FFprobeKit.executeAsync(command) { session in
            defer { input.close() }
            guard let session = session else { return }
            let anySession: Session = session
            let success = ReturnCode.isSuccess(anySession.getReturnCode())
            let out = anySession.getOutput() ?? ""
            addUIAction {
                self.showTextResult(out)
                self.statusText.text = "ffprobe -> \(inputUrl)"
                if !success {
                    Util.alert(self, withTitle: "Error", message: "Processing failed. Please check output for the details.", andButtonText: "OK")
                }
            }
        }
    }

    func showImageResult(_ image: UIImage) {
        outputText.isHidden = true
        resultImageView.isHidden = false
        resultImageView.image = image
    }

    func showTextResult(_ text: String) {
        resultImageView.isHidden = true
        outputText.isHidden = false
        outputText.text = text
        outputText.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}

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

import SwiftUI
import ffmpegkit

// Ported verbatim from the Android FFmpegCommands/FFKitProtocolsTabFragment helpers.

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

@MainActor final class FFKitProtocolsModel: ObservableObject {
    @Published var overlayText = "FFmpegKitNext"
    @Published var statusText = "Protocol: ffkitmem. Tap Run FFmpeg or Run FFprobe."
    @Published var outputText = ""
    @Published var resultImage: UIImage? = nil
    @Published var alertTitle: String = "Error"
    @Published var alertMessage: String? = nil

    private var selectedProtocol = "ffkitmem"

    func setActive() {
        NSLog("FFKitProtocols Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
        FFmpegKitConfig.enableStatisticsCallback(nil)
    }

    func runFFmpeg() {
        if selectedProtocol != "ffkitmem" {
            alertTitle = "FFKit Protocols"
            alertMessage = "This protocol is not implemented yet."
            return
        }
        if let bytes = sampleImageBytes() {
            runFFmpegMemWithBytes(bytes)
        }
    }

    func runFFprobe() {
        if selectedProtocol != "ffkitmem" {
            alertTitle = "FFKit Protocols"
            alertMessage = "This protocol is not implemented yet."
            return
        }
        if let bytes = sampleImageBytes() {
            runFFprobeMemWithBytes(bytes)
        }
    }

    func sampleImageBytes() -> Data? {
        let path = (Bundle.main.resourcePath ?? "").appendingPathComponent("machupicchu.jpg")
        let bytes = try? Data(contentsOf: URL(fileURLWithPath: path))
        if bytes == nil {
            alertTitle = "Error"
            alertMessage = "Could not read the sample image."
        }
        return bytes
    }

    func runFFmpegMemWithBytes(_ bytes: Data) {
        let fontPath = (Bundle.main.resourcePath ?? "").appendingPathComponent("doppioone_regular.ttf")
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg"),
              let output = FFmpegKitOutputBuffer.create("jpg") else {
            alertTitle = "Error"
            alertMessage = "Could not create memory buffers."
            return
        }
        let command = ffkitBuildMemProtocolCommand(input.getUrl(), output.getUrl(), fontPath, overlayText)
        let inputSize = Int(input.getSize())
        statusText = "Running..."
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
                        self.statusText = status
                    }
                } else {
                    addUIAction {
                        self.showTextResult("FFmpeg succeeded but the output image could not be decoded.")
                        self.statusText = "Decode failed."
                        self.alertTitle = "Error"
                        self.alertMessage = "The processed image could not be decoded."
                    }
                }
            } else {
                let logs = anySession.getAllLogsAsString() ?? ""
                NSLog("ffkitmem ffmpeg failed: %@", logs)
                addUIAction {
                    self.showTextResult(logs)
                    self.statusText = "Processing failed."
                    self.alertTitle = "Error"
                    self.alertMessage = "Processing failed. Please check output for the details."
                }
            }
        }
    }

    func runFFprobeMemWithBytes(_ bytes: Data) {
        guard let input = FFmpegKitInputBuffer.fromData(bytes, extension: "jpg") else {
            alertTitle = "Error"
            alertMessage = "Could not create memory buffer."
            return
        }
        let inputUrl = input.getUrl() ?? ""
        let command = "-hide_banner -print_format json -show_format -show_streams \(inputUrl)"
        statusText = "Running..."
        NSLog("ffkitmem ffprobe command: %@", command)
        FFprobeKit.executeAsync(command) { session in
            defer { input.close() }
            guard let session = session else { return }
            let anySession: Session = session
            let success = ReturnCode.isSuccess(anySession.getReturnCode())
            let out = anySession.getOutput() ?? ""
            addUIAction {
                self.showTextResult(out)
                self.statusText = "ffprobe -> \(inputUrl)"
                if !success {
                    self.alertTitle = "Error"
                    self.alertMessage = "Processing failed. Please check output for the details."
                }
            }
        }
    }

    func showImageResult(_ image: UIImage) {
        outputText = ""
        resultImage = image
    }

    func showTextResult(_ text: String) {
        resultImage = nil
        outputText = text
    }
}

struct FFKitProtocolsView: View {
    @StateObject private var model = FFKitProtocolsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protocol: ffkitmem").font(.headline)
            TextField("overlay text", text: $model.overlayText).textFieldStyle(.roundedBorder)
            HStack {
                Button("RUN FFMPEG") { model.runFFmpeg() }.buttonStyle(.borderedProminent)
                Button("RUN FFPROBE") { model.runFFprobe() }.buttonStyle(.bordered)
            }
            Text(model.statusText).font(.footnote).foregroundStyle(.secondary)
            if let image = model.resultImage {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 320)
            } else {
                OutputConsole(text: model.outputText)
            }
        }
        .padding(24).onAppear { model.setActive() }
        .alert(model.alertTitle, isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

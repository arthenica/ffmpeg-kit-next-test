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

@objc(AudioViewController)
class AudioViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, ActivatableTab {
    @IBOutlet var audioCodecComboBox: NSComboBox!
    @IBOutlet var encodeButton: NSButton!
    @IBOutlet var outputText: NSTextView!

    private let codecData = ["aac (audiotoolbox)", "mp2 (twolame)", "mp3 (liblame)", "mp3 (libshine)", "vorbis", "opus", "amr-nb", "amr-wb", "ilbc", "soxr", "speex", "wavpack"]
    private var selectedCodec = 0
    private var indicator = ProgressIndicator()

    override func viewDidLoad() {
        super.viewDidLoad()
        audioCodecComboBox.usesDataSource = true
        audioCodecComboBox.dataSource = self
        audioCodecComboBox.delegate = self
        audioCodecComboBox.stringValue = codecData[selectedCodec]
        Util.applyComboBoxStyle(audioCodecComboBox)
        Util.applyButtonStyle(encodeButton)
        Util.applyOutputTextStyle(outputText)
        addUIAction { self.setActive() }
    }

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            addUIAction { self.appendOutput(log?.getMessage() ?? "") }
        }
    }

    func disableLogCallback() {
        FFmpegKitConfig.enableLogCallback(nil)
    }

    func disableStatisticsCallback() {
        FFmpegKitConfig.enableStatisticsCallback(nil)
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
        selectedCodec = audioCodecComboBox.indexOfSelectedItem
    }

    @IBAction func encodeAudio(_ sender: Any) {
        disableLogCallback()
        createAudioSample()
        enableLogCallback()
        let audioOutputFile = getAudioOutputFilePath()
        try? FileManager.default.removeItem(atPath: audioOutputFile)
        let audioCodec = codecData[selectedCodec]
        NSLog("Testing AUDIO encoding with '%@' codec\n", audioCodec)
        let ffmpegCommand = generateAudioEncodeScript()
        showProgressDialog("Encoding audio\n\n")
        clearOutput()
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)

        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            if ReturnCode.isSuccess(anySession.getReturnCode()) {
                NSLog("Encode completed successfully.\n")
                addUIAction { self.hideProgressDialogAndAlert("Success", and: "Encode completed successfully.") }
            } else {
                NSLog("Encode failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
                addUIAction { self.hideProgressDialogAndAlert("Error", and: "Encode failed. Please check logs for the details.") }
            }
        }
    }

    func createAudioSample() {
        NSLog("Creating AUDIO sample before the test.\n")
        let audioSampleFile = getAudioSamplePath()
        try? FileManager.default.removeItem(atPath: audioSampleFile)
        let ffmpegCommand = "-y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le \(audioSampleFile)"
        NSLog("Creating audio sample with '%@'\n", ffmpegCommand)
        guard let session = FFmpegKit.execute(ffmpegCommand) else { return }
        let anySession: Session = session
        if ReturnCode.isSuccess(anySession.getReturnCode()) {
            NSLog("AUDIO sample created\n")
        } else {
            NSLog("Creating AUDIO sample failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()), notNull(anySession.getFailStackTrace(), "\n"))
            addUIAction {
                Util.alert(self.view.window, withTitle: "Error", message: "Creating AUDIO sample failed. Please check logs for the details.", buttonText: "OK")
            }
        }
    }

    func getAudioOutputFilePath() -> String {
        let audioCodec = codecData[selectedCodec]
        let ext: String
        if audioCodec == "aac (audiotoolbox)" {
            ext = "m4a"
        } else if audioCodec == "mp2 (twolame)" {
            ext = "mpg"
        } else if audioCodec == "mp3 (liblame)" || audioCodec == "mp3 (libshine)" {
            ext = "mp3"
        } else if audioCodec == "vorbis" {
            ext = "ogg"
        } else if audioCodec == "opus" {
            ext = "opus"
        } else if audioCodec == "amr-nb" || audioCodec == "amr-wb" {
            ext = "amr"
        } else if audioCodec == "ilbc" {
            ext = "lbc"
        } else if audioCodec == "speex" {
            ext = "spx"
        } else if audioCodec == "wavpack" {
            ext = "wv"
        } else {
            ext = "wav"
        }
        return documentsDirectory().appendingPathComponent("audio.").appending(ext)
    }

    func getAudioSamplePath() -> String {
        return documentsDirectory().appendingPathComponent("audio-sample.wav")
    }

    func setActive() {
        NSLog("Audio Tab Activated")
        disableStatisticsCallback()
        enableLogCallback()
    }

    func appendOutput(_ message: String) {
        outputText.string = outputText.string.appending(message)
        outputText.scrollRangeToVisible(NSRange(location: outputText.string.count, length: 0))
    }

    func clearOutput() {
        outputText.string = ""
    }

    func showProgressDialog(_ dialogMessage: String) {
        indicator.show(view, message: "Encoding video", indeterminate: false, asyncBlock: nil)
    }

    func hideProgressDialogAndAlert(_ title: String, and message: String) {
        indicator.hide()
        Util.alert(view.window, withTitle: title, message: message, buttonText: "OK")
    }

    func generateAudioEncodeScript() -> String {
        let audioCodec = codecData[selectedCodec]
        let audioSampleFile = getAudioSamplePath()
        let audioOutputFile = getAudioOutputFilePath()
        if audioCodec == "aac (audiotoolbox)" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a aac_at -b:a 192k \(audioOutputFile)"
        } else if audioCodec == "mp2 (twolame)" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a mp2 -b:a 192k \(audioOutputFile)"
        } else if audioCodec == "mp3 (liblame)" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libmp3lame -qscale:a 2 \(audioOutputFile)"
        } else if audioCodec == "mp3 (libshine)" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libshine -qscale:a 2 \(audioOutputFile)"
        } else if audioCodec == "vorbis" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libvorbis -b:a 64k \(audioOutputFile)"
        } else if audioCodec == "opus" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libopus -b:a 64k -vbr on -compression_level 10 \(audioOutputFile)"
        } else if audioCodec == "amr-nb" {
            return "-hide_banner -y -i \(audioSampleFile) -ar 8000 -ab 12.2k -c:a libopencore_amrnb \(audioOutputFile)"
        } else if audioCodec == "amr-wb" {
            return "-hide_banner -y -i \(audioSampleFile) -ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental \(audioOutputFile)"
        } else if audioCodec == "ilbc" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a ilbc -ar 8000 -b:a 15200 \(audioOutputFile)"
        } else if audioCodec == "speex" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libspeex -ar 16000 \(audioOutputFile)"
        } else if audioCodec == "wavpack" {
            return "-hide_banner -y -i \(audioSampleFile) -c:a wavpack -b:a 64k \(audioOutputFile)"
        } else {
            return "-hide_banner -y -i \(audioSampleFile) -af aresample=resampler=soxr -ar 44100 \(audioOutputFile)"
        }
    }
}

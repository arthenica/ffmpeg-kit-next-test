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

@objc(AudioViewController)
class AudioViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var audioCodecText: UITextField!
    @IBOutlet var encodeButton: UIButton!
    @IBOutlet var outputText: UITextView!

    private var indicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyEditTextStyle(audioCodecText)
        Util.applyButtonStyle(encodeButton)
        Util.applyOutputTextStyle(outputText)
        Util.applyHeaderStyle(header)
        encodeButton.isEnabled = false
        createAudioSample()
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

    @IBAction func encodeAudio(_ sender: Any) {
        let audioOutputFile = getAudioOutputFilePath()
        try? FileManager.default.removeItem(atPath: audioOutputFile)
        let audioCodec = audioCodecText.text ?? ""
        NSLog("Testing AUDIO encoding with '%@' codec\n", audioCodec)
        let ffmpegCommand = generateAudioEncodeScript()
        showProgressDialog("Encoding audio\n\n")
        clearOutput()
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)

        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                NSLog("Encode completed successfully.\n")
                addUIAction { self.hideProgressDialogAndAlert("Success", and: "Encode completed successfully.") }
            } else {
                NSLog("Encode failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: state), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
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
        let returnCode = anySession.getReturnCode()
        if ReturnCode.isSuccess(returnCode) {
            encodeButton.isEnabled = true
            NSLog("AUDIO sample created\n")
        } else {
            NSLog("Creating AUDIO sample failed with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
            addUIAction {
                Util.alert(self, withTitle: "Error", message: "Creating AUDIO sample failed. Please check logs for the details.", andButtonText: "OK")
            }
        }
    }

    func getAudioOutputFilePath() -> String {
        let audioCodec = audioCodecText.text ?? ""
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
        } else if audioCodec == "lc3" {
            ext = "lc3"
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
        disableLogCallback()
        createAudioSample()
        enableLogCallback()
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

    func showProgressDialog(_ dialogMessage: String) {
        let pending = UIAlertController(title: nil, message: dialogMessage, preferredStyle: .alert)
        indicator = UIActivityIndicatorView(style: .whiteLarge)
        indicator.color = .black
        indicator.translatesAutoresizingMaskIntoConstraints = false
        pending.view.addSubview(indicator)
        let views: [String: Any] = ["pending": pending.view as Any, "indicator": indicator as Any]
        pending.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[indicator]-(20)-|", options: [], metrics: nil, views: views))
        pending.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[indicator]|", options: [], metrics: nil, views: views))
        indicator.startAnimating()
        present(pending, animated: true, completion: nil)
    }

    func hideProgressDialog() {
        indicator.stopAnimating()
        dismiss(animated: true, completion: nil)
    }

    func hideProgressDialogAndAlert(_ title: String, and message: String) {
        indicator.stopAnimating()
        dismiss(animated: true) {
            Util.alert(self, withTitle: title, message: message, andButtonText: "OK")
        }
    }

    func generateAudioEncodeScript() -> String {
        let audioCodec = audioCodecText.text ?? ""
        let audioSampleFile = getAudioSamplePath()
        let audioOutputFile = getAudioOutputFilePath()
        if audioCodec.contains("aac") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a aac_at -b:a 192k \(audioOutputFile)"
        } else if audioCodec.contains("mp2") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a mp2 -b:a 192k \(audioOutputFile)"
        } else if audioCodec.contains("mp3") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libmp3lame -qscale:a 2 \(audioOutputFile)"
        } else if audioCodec.contains("mp3 (libshine)") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libshine -qscale:a 2 \(audioOutputFile)"
        } else if audioCodec.contains("vorbis") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libvorbis -b:a 64k \(audioOutputFile)"
        } else if audioCodec.contains("opus") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libopus -b:a 64k -vbr on -compression_level 10 \(audioOutputFile)"
        } else if audioCodec.contains("amr-nb") {
            return "-hide_banner -y -i \(audioSampleFile) -ar 8000 -ab 12.2k -c:a libopencore_amrnb \(audioOutputFile)"
        } else if audioCodec.contains("amr-wb") {
            return "-hide_banner -y -i \(audioSampleFile) -ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental \(audioOutputFile)"
        } else if audioCodec.contains("ilbc") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libilbc -ar 8000 -b:a 15200 \(audioOutputFile)"
        } else if audioCodec.contains("speex") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a libspeex -ar 16000 \(audioOutputFile)"
        } else if audioCodec.contains("wavpack") {
            return "-hide_banner -y -i \(audioSampleFile) -c:a wavpack -b:a 64k \(audioOutputFile)"
        } else if audioCodec.contains("lc3") {
            return "-hide_banner -y -i \(audioSampleFile) -ar 48000 -ac 1 -c:a liblc3 -b:a 96k -frame_duration 10 \(audioOutputFile)"
        } else {
            return "-hide_banner -y -i \(audioSampleFile) -af aresample=resampler=soxr -ar 44100 \(audioOutputFile)"
        }
    }
}

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

@objc(CommandViewController)
class CommandViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var commandText: UITextField!
    @IBOutlet var runFFmpegButton: UIButton!
    @IBOutlet var runFFprobeButton: UIButton!
    @IBOutlet var outputText: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        Util.applyEditTextStyle(commandText)
        Util.applyButtonStyle(runFFmpegButton)
        Util.applyButtonStyle(runFFprobeButton)
        Util.applyOutputTextStyle(outputText)
        Util.applyHeaderStyle(header)
        addUIAction { self.setActive() }
    }

    @IBAction func runFFmpeg(_ sender: Any) {
        clearOutput()
        commandText.endEditing(true)
        let ffmpegCommand = "-hide_banner \(commandText.text ?? "")"
        NSLog("Current log level is %d.\n", FFmpegKitConfig.getLogLevel())
        NSLog("Testing FFmpeg COMMAND asynchronously.\n")
        NSLog("FFmpeg process started with arguments '%@'.\n", ffmpegCommand)

        FFmpegKit.executeAsync(ffmpegCommand, withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            NSLog("FFmpeg process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: state), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
            if state == .failed || !(returnCode?.isValueSuccess() ?? false) {
                addUIAction {
                    Util.alert(self, withTitle: "Error", message: "Command failed. Please check output for the details.", andButtonText: "OK")
                }
            }
        }, withLogCallback: { log in
            addUIAction { self.appendOutput(log?.getMessage() ?? "") }
        }, withStatisticsCallback: nil)
    }

    @IBAction func runFFprobe(_ sender: Any) {
        clearOutput()
        commandText.endEditing(true)
        let ffprobeCommand = "-hide_banner \(commandText.text ?? "")"
        NSLog("Testing FFprobe COMMAND asynchronously.\n")
        NSLog("FFprobe process started with arguments '%@'.\n", ffprobeCommand)

        let session = FFprobeSession.create(FFmpegKitConfig.parseArguments(ffprobeCommand), withCompleteCallback: { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            addUIAction { self.appendOutput(anySession.getOutput() ?? "") }
            NSLog("FFprobe process exited with state %@ and rc %@.%@", FFmpegKitConfig.sessionState(toString: state), String(describing: returnCode), notNull(anySession.getFailStackTrace(), "\n"))
            if state == .failed || !(returnCode?.isValueSuccess() ?? false) {
                addUIAction {
                    Util.alert(self, withTitle: "Error", message: "Command failed. Please check output for the details.", andButtonText: "OK")
                }
            }
        }, withLogCallback: nil, with: .neverPrintLogs)

        FFmpegKitConfig.asyncFFprobeExecute(session)
        AppDelegate.listFFprobeSessions()
    }

    func setActive() {
        NSLog("Command Tab Activated")
        FFmpegKitConfig.enableLogCallback(nil)
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


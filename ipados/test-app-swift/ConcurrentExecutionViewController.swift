/*
 * Copyright (c) 2020-2026 Taner Sener
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

@objc(ConcurrentExecutionViewController)
class ConcurrentExecutionViewController: UIViewController, ActivatableTab {
    @IBOutlet var header: UILabel!
    @IBOutlet var encode1Button: UIButton!
    @IBOutlet var encode2Button: UIButton!
    @IBOutlet var encode3Button: UIButton!
    @IBOutlet var cancel1Button: UIButton!
    @IBOutlet var cancel2Button: UIButton!
    @IBOutlet var cancel3Button: UIButton!
    @IBOutlet var cancelAllButton: UIButton!
    @IBOutlet var outputText: UITextView!

    private var sessionId1 = 0
    private var sessionId2 = 0
    private var sessionId3 = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        [encode1Button, encode2Button, encode3Button, cancel1Button, cancel2Button, cancel3Button, cancelAllButton].forEach { Util.applyButtonStyle($0!) }
        Util.applyOutputTextStyle(outputText)
        Util.applyHeaderStyle(header)
        addUIAction { self.setActive() }
    }

    func enableLogCallback() {
        FFmpegKitConfig.enableLogCallback { log in
            addUIAction {
                guard let log = log else { return }
                self.appendOutput("\(log.getSessionId()) -> \(log.getMessage() ?? "")")
            }
        }
    }

    @IBAction func encode1Clicked(_ sender: Any) {
        encodeVideo(1)
    }

    @IBAction func encode2Clicked(_ sender: Any) {
        encodeVideo(2)
    }

    @IBAction func encode3Clicked(_ sender: Any) {
        encodeVideo(3)
    }

    @IBAction @objc(cancel1Button:) func cancel1ButtonAction(_ sender: Any) {
        cancel(1)
    }

    @IBAction @objc(cancel2Button:) func cancel2ButtonAction(_ sender: Any) {
        cancel(2)
    }

    @IBAction @objc(cancel3Button:) func cancel3ButtonAction(_ sender: Any) {
        cancel(3)
    }

    @IBAction @objc(cancelAllButton:) func cancelAllButtonAction(_ sender: Any) {
        cancel(0)
    }

    func encodeVideo(_ buttonNumber: Int) {
        let docFolder = documentsDirectory()
        let resourceFolder = Bundle.main.resourcePath ?? ""
        let image1 = resourceFolder.appendingPathComponent("tree.jpg")
        let image2 = resourceFolder.appendingPathComponent("lake.jpg")
        let image3 = resourceFolder.appendingPathComponent("sunset.jpg")
        let videoFile = docFolder.appendingPathComponent("video\(buttonNumber).mp4")
        NSLog("Testing CONCURRENT EXECUTION for button %d.\n", buttonNumber)
        let ffmpegCommand = Video.generateVideoEncodeScript(image1, image2, image3, videoFile, "mpeg4", "")
        NSLog("FFmpeg process starting for button %d with arguments '%@'.\n", buttonNumber, ffmpegCommand)
        let session = FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else { return }
            let anySession: Session = session
            let state = anySession.getState()
            let returnCode = anySession.getReturnCode()
            if ReturnCode.isCancel(returnCode) {
                NSLog("FFmpeg process ended with cancel for button %d with sessionId %ld.", buttonNumber, anySession.getId())
            } else {
                NSLog("FFmpeg process ended with state %lu and rc %@ for button %d with sessionId %ld.%@", state.rawValue, String(describing: returnCode), buttonNumber, anySession.getId(), notNull(anySession.getFailStackTrace(), "\n"))
                NSLog("Deleting the last session %ld\n", anySession.getId())
                FFmpegKitConfig.deleteSession(anySession.getId())
            }
        }
        guard let session = session else { return }
        let anySession: Session = session
        let sessionId = anySession.getId()
        NSLog("Async FFmpeg process started for button %d with sessionId %ld.\n", buttonNumber, sessionId)
        switch buttonNumber {
        case 1:
            sessionId1 = sessionId
        case 2:
            sessionId2 = sessionId
        default:
            sessionId3 = sessionId
            FFmpegKitConfig.setSessionHistorySize(3)
        }
        AppDelegate.listFFmpegSessions()
    }

    func cancel(_ buttonNumber: Int) {
        var sessionId = 0
        switch buttonNumber {
        case 1:
            sessionId = sessionId1
        case 2:
            sessionId = sessionId2
        case 3:
            sessionId = sessionId3
        default:
            break
        }
        NSLog("Cancelling FFmpeg process for button %d with sessionId %ld.\n", buttonNumber, sessionId)
        if sessionId == 0 {
            FFmpegKit.cancel()
        } else {
            FFmpegKit.cancel(sessionId)
        }
    }

    func setActive() {
        NSLog("Concurrent Execution Tab Activated")
        enableLogCallback()
    }

    func appendOutput(_ message: String) {
        outputText.text = outputText.text.appending(message)
        if !outputText.text.isEmpty {
            outputText.scrollRangeToVisible(NSRange(location: outputText.text.count - 1, length: 1))
        }
    }
}

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
import AVKit

typealias AsyncBlock = () -> Void

func documentsDirectory() -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
}

extension String {
    func appendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }
}

func notNull(_ string: String?, _ valuePrefix: String) -> String {
    guard let string = string else { return "" }
    return "\(valuePrefix)\(string)"
}

func addUIAction(_ asyncUpdateUIBlock: @escaping () -> Void) {
    DispatchQueue.main.async(execute: asyncUpdateUIBlock)
}

@objc(Util)
final class Util: NSObject {
    static func applyButtonStyle(_ button: NSButton) {
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor(red: 46.0 / 256.0, green: 204.0 / 256.0, blue: 113.0 / 256.0, alpha: 1.0).cgColor
        button.layer?.borderWidth = 1.0
        button.layer?.borderColor = NSColor(red: 39.0 / 256.0, green: 174.0 / 256.0, blue: 96.0 / 256.0, alpha: 1.0).cgColor
        button.layer?.cornerRadius = 5.0
        button.contentTintColor = .white
    }

    static func applyEditTextStyle(_ textField: NSTextField) {
        textField.wantsLayer = true
        textField.layer?.borderWidth = 1.0
        textField.layer?.borderColor = NSColor(red: 52.0 / 256.0, green: 152.0 / 256.0, blue: 219.0 / 256.0, alpha: 1.0).cgColor
        textField.layer?.cornerRadius = 5.0
    }

    static func applyOutputTextStyle(_ textView: NSTextView) {
        textView.wantsLayer = true
        textView.layer?.backgroundColor = NSColor(red: 241.0 / 256.0, green: 196.0 / 256.0, blue: 15.0 / 256.0, alpha: 1.0).cgColor
        textView.layer?.borderWidth = 1.0
        textView.layer?.borderColor = NSColor(red: 243.0 / 256.0, green: 156.0 / 256.0, blue: 18.0 / 256.0, alpha: 1.0).cgColor
        textView.layer?.cornerRadius = 5.0
    }

    static func applyComboBoxStyle(_ comboBox: NSComboBox) {
        comboBox.wantsLayer = true
        comboBox.layer?.backgroundColor = NSColor(red: 155.0 / 256.0, green: 89.0 / 256.0, blue: 182.0 / 256.0, alpha: 1.0).cgColor
        comboBox.layer?.borderWidth = 1.0
        comboBox.layer?.borderColor = NSColor(red: 142.0 / 256.0, green: 68.0 / 256.0, blue: 173.0 / 256.0, alpha: 1.0).cgColor
        comboBox.layer?.cornerRadius = 5.0
    }

    static func applyVideoPlayerFrameStyle(_ playerFrame: AVPlayerView) {
        playerFrame.wantsLayer = true
        playerFrame.layer?.backgroundColor = NSColor(red: 236.0 / 256.0, green: 240.0 / 256.0, blue: 241.0 / 256.0, alpha: 1.0).cgColor
        playerFrame.layer?.borderWidth = 1.0
        playerFrame.layer?.borderColor = NSColor(red: 185.0 / 256.0, green: 195.0 / 256.0, blue: 199.0 / 256.0, alpha: 1.0).cgColor
        playerFrame.layer?.cornerRadius = 5.0
    }

    static func alert(_ window: NSWindow?, withTitle title: String, message: String, buttonText: String, andHandler handler: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: buttonText)
        if let window = window {
            alert.beginSheetModal(for: window) { _ in handler?() }
        } else {
            alert.runModal()
            handler?()
        }
    }
}

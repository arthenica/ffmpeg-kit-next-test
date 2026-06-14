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

@objc(ProgressIndicator)
final class ProgressIndicator: NSObject {
    private var container: NSView?
    private var label: NSTextField?
    private var progressIndicator: NSProgressIndicator?

    func show(_ view: NSView, message: String, indeterminate: Bool, asyncBlock: AsyncBlock?) {
        hide()

        let frame = NSRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        let overlay = NSView(frame: frame)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.25).cgColor

        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 110))
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        panel.layer?.cornerRadius = 8.0
        panel.layer?.borderWidth = 1.0
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(panel)

        let text = NSTextField(labelWithString: message)
        text.alignment = .center
        text.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(text)

        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.isIndeterminate = indeterminate
        indicator.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(indicator)
        indicator.startAnimation(nil)

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 260),
            panel.heightAnchor.constraint(equalToConstant: 110),
            text.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            text.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            indicator.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 16)
        ])

        view.addSubview(overlay)
        container = overlay
        label = text
        progressIndicator = indicator
        asyncBlock?()
    }

    func updateMessage(_ message: String) {
        label?.stringValue = message
    }

    func updateMessage(_ message: String, percentage: Int32) {
        label?.stringValue = "\(message)  % \(percentage)"
    }

    func updatePercentage(_ percentage: Int32) {
        if let message = label?.stringValue.components(separatedBy: "  % ").first {
            label?.stringValue = "\(message)  % \(percentage)"
        }
    }

    func hide() {
        progressIndicator?.stopAnimation(nil)
        container?.removeFromSuperview()
        container = nil
        label = nil
        progressIndicator = nil
    }
}

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
    static func applyButtonStyle(_ button: UIButton) {
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.layer.backgroundColor = UIColor(displayP3Red: 46.0 / 256.0, green: 204.0 / 256.0, blue: 113.0 / 256.0, alpha: 1.0).cgColor
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(displayP3Red: 39.0 / 256.0, green: 174.0 / 256.0, blue: 96.0 / 256.0, alpha: 1.0).cgColor
        button.layer.cornerRadius = 5.0
    }

    static func applyEditTextStyle(_ textField: UITextField) {
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = UIColor(displayP3Red: 52.0 / 256.0, green: 152.0 / 256.0, blue: 219.0 / 256.0, alpha: 1.0).cgColor
        textField.layer.cornerRadius = 5.0
    }

    static func applyHeaderStyle(_ label: UILabel) {
        label.layer.borderWidth = 1.0
        label.layer.borderColor = UIColor(displayP3Red: 231.0 / 256.0, green: 76.0 / 256.0, blue: 60.0 / 256.0, alpha: 1.0).cgColor
        label.layer.cornerRadius = 5.0
    }

    static func applyOutputTextStyle(_ textView: UITextView) {
        textView.layer.backgroundColor = UIColor(displayP3Red: 241.0 / 256.0, green: 196.0 / 256.0, blue: 15.0 / 256.0, alpha: 1.0).cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.borderColor = UIColor(displayP3Red: 243.0 / 256.0, green: 156.0 / 256.0, blue: 18.0 / 256.0, alpha: 1.0).cgColor
        textView.layer.cornerRadius = 5.0
    }

    static func applyPickerViewStyle(_ pickerView: UIPickerView) {
        pickerView.layer.backgroundColor = UIColor(displayP3Red: 155.0 / 256.0, green: 89.0 / 256.0, blue: 182.0 / 256.0, alpha: 1.0).cgColor
        pickerView.layer.borderWidth = 1.0
        pickerView.layer.borderColor = UIColor(displayP3Red: 142.0 / 256.0, green: 68.0 / 256.0, blue: 173.0 / 256.0, alpha: 1.0).cgColor
        pickerView.layer.cornerRadius = 5.0
    }

    static func applyVideoPlayerFrameStyle(_ playerFrame: UILabel) {
        playerFrame.layer.backgroundColor = UIColor(displayP3Red: 236.0 / 256.0, green: 240.0 / 256.0, blue: 241.0 / 256.0, alpha: 1.0).cgColor
        playerFrame.layer.borderWidth = 1.0
        playerFrame.layer.borderColor = UIColor(displayP3Red: 185.0 / 256.0, green: 195.0 / 256.0, blue: 199.0 / 256.0, alpha: 1.0).cgColor
        playerFrame.layer.cornerRadius = 5.0
    }

    static func alert(_ controller: UIViewController, withTitle title: String, message: String, andButtonText buttonText: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: buttonText, style: .default, handler: { _ in }))
        controller.present(alert, animated: true, completion: nil)
    }
}

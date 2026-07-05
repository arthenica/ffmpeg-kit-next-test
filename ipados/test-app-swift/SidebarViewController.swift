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

// Implemented by every test view controller so the sidebar can notify it when it becomes visible.
protocol ActivatableTab: AnyObject {
    func setActive()
}

/// Primary (sidebar) column of the iPadOS split view. Lists the available test sections and, on
/// selection, swaps the matching view controller into the detail navigation controller. It replaces
/// the tab bar used by the iOS test app.
@objc(SidebarViewController)
class SidebarViewController: UITableViewController {

    // Detail column whose root view controller is swapped as sidebar rows are selected. Set by AppDelegate.
    weak var detailNavigationController: UINavigationController?

    private let sectionTitles = ["Command", "Video", "HTTPS", "Audio", "Subtitle", "Vid.Stab", "Pipe", "Concurrent Execution", "Other", "FFKit Protocols"]
    private let sectionIdentifiers = ["CommandViewController", "VideoViewController", "HttpsViewController", "AudioViewController", "SubtitleViewController", "VidStabViewController", "PipeViewController", "ConcurrentExecutionViewController", "OtherViewController", "FFKitProtocolsViewController"]

    // View controllers are instantiated lazily and kept alive so their state survives navigation, like tabs did.
    private var viewControllerCache: [String: UIViewController] = [:]

    private static let cellIdentifier = "SidebarCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "FFmpegKitNext"
        clearsSelectionOnViewWillAppear = false
        tableView.tintColor = UIColor(red: 244.0 / 255.0, green: 104.0 / 255.0, blue: 66.0 / 255.0, alpha: 1.0)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: SidebarViewController.cellIdentifier)

        // Show the first section by default so the detail column is never empty on launch.
        showSection(at: 0)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionTitles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SidebarViewController.cellIdentifier, for: indexPath)
        cell.textLabel?.text = sectionTitles[indexPath.row]
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showSection(at: indexPath.row)
    }

    // MARK: - Section selection

    private func showSection(at index: Int) {
        guard index >= 0, index < sectionIdentifiers.count else { return }

        let identifier = sectionIdentifiers[index]
        let controller: UIViewController
        if let cached = viewControllerCache[identifier] {
            controller = cached
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            controller = storyboard.instantiateViewController(withIdentifier: identifier)
            viewControllerCache[identifier] = controller
        }

        controller.navigationItem.title = sectionTitles[index]
        // Load the view now so IBOutlets are connected before setActive() runs (it may touch them).
        controller.loadViewIfNeeded()
        detailNavigationController?.viewControllers = [controller]
        (controller as? ActivatableTab)?.setActive()

        // Keep the row highlighted, including for the initial programmatic selection.
        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
    }
}

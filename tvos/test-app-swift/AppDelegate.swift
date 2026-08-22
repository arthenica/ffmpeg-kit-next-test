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

private func uncaughtExceptionHandler(_ exception: NSException) {
    NSLog("Uncaught exception detected: %@.", exception)
    NSLog("%@", exception.callStackSymbols)
}

private final class DetailContainerViewController: UIViewController {
    private var currentViewController: UIViewController?

    init(contentViewController: UIViewController) {
        currentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        if let currentViewController {
            install(currentViewController)
        }
    }

    func show(_ contentViewController: UIViewController) {
        guard contentViewController !== currentViewController else {
            return
        }

        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        currentViewController = contentViewController
        install(contentViewController)
    }

    private func install(_ contentViewController: UIViewController) {
        guard contentViewController.parent !== self else {
            return
        }

        addChild(contentViewController)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentViewController.view)
        NSLayoutConstraint.activate([
            contentViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        contentViewController.didMove(toParent: self)
    }
}

private final class SidebarViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let titles: [String]
    private let selectionHandler: (Int) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var selectedIndex: Int

    init(titles: [String], selectedIndex: Int, selectionHandler: @escaping (Int) -> Void) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        self.selectionHandler = selectionHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0.05, alpha: 1.0)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.remembersLastFocusedIndexPath = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 76
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SidebarCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])

        tableView.selectRow(at: IndexPath(row: selectedIndex, section: 0), animated: false, scrollPosition: .none)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        titles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SidebarCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectedBackgroundView = selectedBackgroundView()
        cell.indentationLevel = 0
        cell.indentationWidth = 0
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero
        cell.textLabel?.text = titles[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
        cell.textLabel?.textColor = .white
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        selectionHandler(indexPath.row)
    }

    private func selectedBackgroundView() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.24)
        view.layer.cornerRadius = 14
        view.layer.masksToBounds = true
        return view
    }
}

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var pageControllers: [UIViewController] = []
    private var detailContainerViewController: DetailContainerViewController?

    static func listFFprobeSessions() {
        let ffprobeSessions = FFprobeKit.listFFprobeSessions() as? [FFprobeSession] ?? []
        NSLog("Listing FFprobe sessions.\n")
        for (index, session) in ffprobeSessions.enumerated() {
            let anySession: Session = session
            NSLog("Session %d = id: %ld, startTime: %@, duration: %ld, state:%@, returnCode:%@.\n", index, anySession.getId(), String(describing: anySession.getStartTime()), anySession.getDuration(), FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()))
        }
        NSLog("Listed FFprobe sessions.\n")
    }

    static func listFFmpegSessions() {
        let ffmpegSessions = FFmpegKit.listSessions() as? [FFmpegSession] ?? []
        NSLog("Listing FFmpeg sessions.\n")
        for (index, session) in ffmpegSessions.enumerated() {
            let anySession: Session = session
            NSLog("Session %d = id: %ld, startTime: %@, duration: %ld, state:%@, returnCode:%@.\n", index, anySession.getId(), String(describing: anySession.getStartTime()), anySession.getDuration(), FFmpegKitConfig.sessionState(toString: anySession.getState()), String(describing: anySession.getReturnCode()))
        }
        NSLog("Listed FFmpeg sessions.\n")
    }

    static func getCACertificateBundlePath() -> String {
        let resourceFolder = Bundle.main.resourcePath ?? ""
        return resourceFolder.appendingPathComponent("cacert_2026_08_13.pem")
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)

        UITabBarItem.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 38)
        ], for: .selected)

        UITabBarItem.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor.darkGray,
            .font: UIFont.systemFont(ofSize: 38)
        ], for: .normal)

        let resourceFolder = Bundle.main.resourcePath ?? ""
        FFmpegKitConfig.setFontDirectoryList([resourceFolder, "/System/Library/Fonts"], with: ["MyFontName": "Doppio One"])
        FFmpegKitConfig.ignore(.xcpu)
        FFmpegKitConfig.setLogLevel(Int32(Level.avLogInfo.rawValue))
        configureSplitNavigation()
        return true
    }

    private func configureSplitNavigation() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let pageIdentifiers = [
            "CommandViewController",
            "VideoViewController",
            "HttpsViewController",
            "AudioViewController",
            "SubtitleViewController",
            "VidStabViewController",
            "PipeViewController",
            "ConcurrentExecutionViewController",
            "FFKitProtocolsViewController",
            "OtherViewController"
        ]
        pageControllers = pageIdentifiers.map { storyboard.instantiateViewController(withIdentifier: $0) }

        let titles = [
            "Command",
            "Video",
            "Https",
            "Audio",
            "Subtitle",
            "Vid.Stab",
            "Pipe",
            "Concurrent",
            "FFKit Protocols",
            "Other"
        ]

        let splitViewController = UISplitViewController()
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredPrimaryColumnWidthFraction = 0.16
        splitViewController.minimumPrimaryColumnWidth = 260
        splitViewController.maximumPrimaryColumnWidth = 320

        let detailContainerViewController = DetailContainerViewController(contentViewController: pageControllers[0])
        self.detailContainerViewController = detailContainerViewController

        let sidebarViewController = SidebarViewController(titles: titles, selectedIndex: 0) { [weak self] index in
            guard let self, pageControllers.indices.contains(index) else {
                return
            }

            let selectedViewController = pageControllers[index]
            detailContainerViewController.show(selectedViewController)
            (selectedViewController as? ActivatableTab)?.setActive()
        }

        splitViewController.viewControllers = [sidebarViewController, detailContainerViewController]

        if window == nil {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()
        (pageControllers.first as? ActivatableTab)?.setActive()
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
}

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

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

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

        // BUILD THE iPad SPLIT VIEW (sidebar + detail) IN PLACE OF THE iOS TAB BAR
        let window = UIWindow(frame: UIScreen.main.bounds)

        let sidebarController = SidebarViewController(style: .plain)
        let masterNavigationController = UINavigationController(rootViewController: sidebarController)
        let detailNavigationController = UINavigationController()
        sidebarController.detailNavigationController = detailNavigationController

        let splitViewController = UISplitViewController()
        splitViewController.viewControllers = [masterNavigationController, detailNavigationController]
        splitViewController.preferredDisplayMode = .allVisible

        window.rootViewController = splitViewController
        window.makeKeyAndVisible()
        self.window = window

        let resourceFolder = Bundle.main.resourcePath ?? ""
        FFmpegKitConfig.setFontDirectoryList([resourceFolder, "/System/Library/Fonts"], with: ["MyFontName": "Doppio One"])
        FFmpegKitConfig.ignore(.xcpu)
        FFmpegKitConfig.setLogLevel(Int32(Level.avLogInfo.rawValue))
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
}


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

import SwiftUI

private enum TestPage: CaseIterable, Hashable, Identifiable {
    case command
    case video
    case https
    case audio
    case subtitle
    case vidStab
    case pipe
    case concurrentExecution
    case ffkitProtocols
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .command:
            return "Command"
        case .video:
            return "Video"
        case .https:
            return "Https"
        case .audio:
            return "Audio"
        case .subtitle:
            return "Subtitle"
        case .vidStab:
            return "Vid.Stab"
        case .pipe:
            return "Pipe"
        case .concurrentExecution:
            return "Concurrent"
        case .ffkitProtocols:
            return "FFKit Protocols"
        case .other:
            return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .command:
            return "terminal"
        case .video:
            return "film"
        case .https:
            return "network"
        case .audio:
            return "waveform"
        case .subtitle:
            return "captions.bubble"
        case .vidStab:
            return "video.badge.checkmark"
        case .pipe:
            return "arrow.triangle.branch"
        case .concurrentExecution:
            return "square.stack.3d.up"
        case .ffkitProtocols:
            return "memorychip"
        case .other:
            return "ellipsis.circle"
        }
    }
}

struct ContentView: View {
    private let appTitle = "FFmpegKitNext visionOS"

    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedPage: TestPage? = .command

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            VStack(spacing: 0) {
                headerView
                pageView(selectedPage ?? .command)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var sidebarView: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(TestPage.allCases) { page in
                        Button {
                            selectedPage = page
                        } label: {
                            Label {
                                Text(page.title)
                                    .fontWeight(selectedPage == page ? .semibold : .regular)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } icon: {
                                Image(systemName: page.systemImage)
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                if selectedPage == page {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.quaternary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minHeight: proxy.size.height, alignment: .center)
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var headerView: some View {
        ZStack {
            HStack {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                        .symbolRenderingMode(.monochrome)
                        .font(.title2)
                }
                .help(columnVisibility == .detailOnly ? "Show Menu" : "Hide Menu")
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()
            }

            Text(appTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    @ViewBuilder
    private func pageView(_ page: TestPage) -> some View {
        switch page {
        case .command:
            CommandView()
        case .video:
            VideoView()
        case .https:
            HttpsView()
        case .audio:
            AudioView()
        case .subtitle:
            SubtitleView()
        case .vidStab:
            VidStabView()
        case .pipe:
            PipeView()
        case .concurrentExecution:
            ConcurrentExecutionView()
        case .ffkitProtocols:
            FFKitProtocolsView()
        case .other:
            OtherView()
        }
    }
}

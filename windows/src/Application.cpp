/*
 * Copyright (c) 2022, 2026 Taner Sener
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

#include "Application.h"
#include "Theme.h"
#include "Util.h"
#include "Win32Ui.h"

#include <FFmpegKit.h>
#include <FFmpegKitConfig.h>
#include <FFprobeKit.h>

#include <algorithm>
#include <chrono>
#include <commctrl.h>
#include <cstdlib>
#include <ctime>
#include <direct.h>
#include <errno.h>
#include <iostream>
#include <shlobj.h>
#include <sys/stat.h>
#include <sys/types.h>

using namespace ffmpegkit;

namespace {
    const wchar_t* MainWindowClassName = L"FFmpegKitNextTestMainWindow";

    /** Shown in the title bar and again in the header band. */
    const wchar_t* MainWindowTitle = L"FFmpegKitNext Windows";

    /**
     * Height of the red band above the tab control.
     *
     * The band is the Win32 counterpart of the Android ActionBar and the web
     * app's <header>. Neither of the other desktop apps has one, so this is the
     * only place the window chrome differs from Linux and macOS.
     */
    constexpr int HeaderHeight = 48;
    const int TabControlId = 1;

    bool fs_exists(const std::string& path, const bool isFile, const bool isDirectory) {
        struct stat info;

        if (stat(path.c_str(), &info) == 0) {
            // MinGW defines S_ISREG/S_ISDIR, but not under every language standard,
            // so the masks are applied directly.
            if (isFile && (info.st_mode & S_IFMT) == S_IFREG) {
                return true;
            }
            if (isDirectory && (info.st_mode & S_IFMT) == S_IFDIR) {
                return true;
            }
        }

        return false;
    }

    bool fs_create_dir(const std::string& path) {
        if (!fs_exists(path, false, true)) {
            // _mkdir() is the Windows CRT entry point; it takes no mode argument
            // because permissions are inherited from the parent directory's ACL.
            if (_mkdir(path.c_str()) != 0) {
                std::cout << "Failed to create directory: " << path << ". Operation failed with " << errno << "." << std::endl;
                return false;
            }
        }
        return true;
    }

    std::string localAppDataDirectory() {
        PWSTR path = nullptr;
        std::string directory;

        if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path))) {
            directory = ffmpegkittest::ui::toUtf8(path);
        }

        if (path != nullptr) {
            CoTaskMemFree(path);
        }

        if (directory.empty()) {
            const char* fallback = std::getenv("LOCALAPPDATA");
            if (fallback != nullptr) {
                directory = fallback;
            }
        }

        return directory;
    }
}

std::ostream& operator<<(std::ostream& out, const std::chrono::time_point<std::chrono::system_clock>& o) {
    char str[100];
    std::time_t t = std::chrono::system_clock::to_time_t(o);
    std::strftime(str, sizeof(str), "%c", std::localtime(&t));
    return out << str;
}

ffmpegkittest::Application::Application() : hwnd(nullptr), tabControl(nullptr) {
    tabs = {
        &commandTab,
        &videoTab,
        &httpsTab,
        &audioTab,
        &subtitleTab,
        &vidStabTab,
        &concurrentExecutionTab,
        &otherTab,
        &ffkitProtocolsTab
    };
}

bool ffmpegkittest::Application::create() {
    WNDCLASSEXW windowClass;
    ZeroMemory(&windowClass, sizeof(windowClass));
    windowClass.cbSize = sizeof(windowClass);
    windowClass.lpfnWndProc = &Application::windowProcedure;
    windowClass.hInstance = GetModuleHandleW(nullptr);
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE + 1);
    windowClass.lpszClassName = MainWindowClassName;
    windowClass.hIcon = LoadIconW(GetModuleHandleW(nullptr), L"APPICON");
    windowClass.hIconSm = windowClass.hIcon;

    if (RegisterClassExW(&windowClass) == 0) {
        std::cout << "Failed to register the main window class." << std::endl;
        return false;
    }

    // The header is added on top of the 600 the tab pages were sized for, so
    // introducing it does not take space away from them.
    hwnd = CreateWindowExW(
        0, MainWindowClassName, MainWindowTitle,
        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
        CW_USEDEFAULT, CW_USEDEFAULT, 800, 600 + HeaderHeight,
        nullptr, nullptr, GetModuleHandleW(nullptr), this);

    if (hwnd == nullptr) {
        std::cout << "Failed to create the main window." << std::endl;
        return false;
    }

    ShowWindow(hwnd, SW_SHOWNORMAL);
    UpdateWindow(hwnd);
    return true;
}

int ffmpegkittest::Application::run() {
    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {

        // IsDialogMessage gives the controls tab navigation and default button
        // handling, which a plain message loop does not provide.
        HWND activeTab = nullptr;
        const int selected = TabCtrl_GetCurSel(tabControl);
        if (selected >= 0 && selected < static_cast<int>(tabs.size())) {
            activeTab = tabs[selected]->getHandle();
        }

        if (activeTab == nullptr || !IsDialogMessageW(activeTab, &message)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }

    return static_cast<int>(message.wParam);
}

void ffmpegkittest::Application::onCreate() {
    tabControl = CreateWindowExW(
        0, WC_TABCONTROLW, L"", WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_TABS,
        0, 0, 0, 0, hwnd, reinterpret_cast<HMENU>(static_cast<INT_PTR>(TabControlId)),
        GetModuleHandleW(nullptr), nullptr);

    SendMessageW(tabControl, WM_SETFONT, reinterpret_cast<WPARAM>(ui::defaultFont()), TRUE);

    for (size_t i = 0; i < tabs.size(); i++) {
        TCITEMW item;
        ZeroMemory(&item, sizeof(item));
        item.mask = TCIF_TEXT;
        item.pszText = const_cast<wchar_t*>(tabs[i]->getTitle());
        TabCtrl_InsertItem(tabControl, static_cast<int>(i), &item);

        // create() records the parent, which the tabs use as the owner window for
        // message boxes and the open dialog.
        tabs[i]->create(hwnd);
    }

    TabCtrl_SetCurSel(tabControl, 0);
    onLayout();
    onTabChanged();

    initApplicationCacheDirectory();

    registerApplicationFonts();
    std::cout << "Application fonts registered." << std::endl;

    FFmpegKitConfig::ignoreSignal(SignalXcpu);
    FFmpegKitConfig::setLogLevel(LevelAVLogInfo);
}

void ffmpegkittest::Application::onLayout() {
    RECT client;
    GetClientRect(hwnd, &client);

    int tabControlHeight = client.bottom - HeaderHeight;
    if (tabControlHeight < 0) {
        tabControlHeight = 0;
    }

    MoveWindow(tabControl, 0, HeaderHeight, client.right, tabControlHeight, TRUE);

    // The tab control reports the rectangle left for the page once its own row of
    // tabs is accounted for. The rectangle handed in is the tab control's bounds
    // in main window coordinates, so what comes back is the page area in those
    // same coordinates, which is what the pages are positioned in.
    RECT display;
    display.left = 0;
    display.top = HeaderHeight;
    display.right = client.right;
    display.bottom = client.bottom;
    TabCtrl_AdjustRect(tabControl, FALSE, &display);

    for (Tab* tab : tabs) {
        tab->setBounds(display);
    }
}

void ffmpegkittest::Application::paintHeader(HDC deviceContext) {
    RECT client;
    GetClientRect(hwnd, &client);

    RECT header = client;
    header.bottom = HeaderHeight;

    HBRUSH brush = CreateSolidBrush(theme::HeaderBackground);
    FillRect(deviceContext, &header, brush);
    DeleteObject(brush);

    HFONT previousFont = static_cast<HFONT>(SelectObject(deviceContext, ui::headerFont()));
    const int previousBackgroundMode = SetBkMode(deviceContext, OPAQUE);
    const COLORREF previousBackgroundColor = SetBkColor(deviceContext, theme::HeaderBackground);
    const COLORREF previousTextColor = SetTextColor(deviceContext, theme::HeaderText);

    // Centred, matching the web header rather than the left aligned Android one.
    DrawTextW(deviceContext, MainWindowTitle, -1, &header,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

    SetTextColor(deviceContext, previousTextColor);
    SetBkColor(deviceContext, previousBackgroundColor);
    SetBkMode(deviceContext, previousBackgroundMode);
    SelectObject(deviceContext, previousFont);
}

void ffmpegkittest::Application::onTabChanged() {
    const int selected = TabCtrl_GetCurSel(tabControl);

    for (size_t i = 0; i < tabs.size(); i++) {
        tabs[i]->setVisible(static_cast<int>(i) == selected);
    }

    if (selected >= 0 && selected < static_cast<int>(tabs.size())) {
        tabs[selected]->setActive();
    }
}

LRESULT CALLBACK ffmpegkittest::Application::windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    auto* application = reinterpret_cast<Application*>(GetWindowLongPtrW(window, GWLP_USERDATA));

    switch (message) {
    case WM_NCCREATE: {
        auto* createStruct = reinterpret_cast<CREATESTRUCTW*>(lParam);
        application = static_cast<Application*>(createStruct->lpCreateParams);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(application));
        if (application != nullptr) {
            application->hwnd = window;
        }
        break;
    }

    case WM_CREATE:
        if (application != nullptr) {
            application->onCreate();
        }
        return 0;

    case WM_SIZE:
        if (application != nullptr && application->tabControl != nullptr) {
            application->onLayout();

            // The band spans the full width, so a resize has to repaint it.
            RECT header;
            GetClientRect(window, &header);
            header.bottom = HeaderHeight;
            InvalidateRect(window, &header, FALSE);
        }
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT paint;
        HDC deviceContext = BeginPaint(window, &paint);
        if (application != nullptr) {
            application->paintHeader(deviceContext);
        }
        EndPaint(window, &paint);
        return 0;
    }

    case WM_NOTIFY: {
        auto* header = reinterpret_cast<NMHDR*>(lParam);
        if (application != nullptr && header != nullptr && header->code == TCN_SELCHANGE) {
            application->onTabChanged();
        }
        return 0;
    }

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;

    default:
        break;
    }

    return DefWindowProcW(window, message, wParam, lParam);
}

void ffmpegkittest::Application::initApplicationCacheDirectory() {
    auto appCacheDir = ffmpegkittest::Application::getApplicationCacheDirectory();

    if (!fs_create_dir(appCacheDir)) {
        std::cout << "Failed to create application cache directory: " << appCacheDir << "." << std::endl;
    }
}

void ffmpegkittest::Application::listFFmpegSessions() {
    auto ffmpegSessions = FFmpegKit::listSessions();
    std::cout << "Listing FFmpeg sessions." << std::endl;
    int i = 0;
    std::for_each(ffmpegSessions->begin(), ffmpegSessions->end(), [&](const std::shared_ptr<ffmpegkit::FFmpegSession> session) {
        std::cout << "Session " << i++ << " = id:" << session->getSessionId() << ", startTime:" << session->getStartTime() << ", duration:" << session-> getDuration() << ", state:" << FFmpegKitConfig::sessionStateToString(session->getState()) << ", returnCode:" << session->getReturnCode() << "." << std::endl;
    });
    std::cout << "Listed FFmpeg sessions." << std::endl;
}

void ffmpegkittest::Application::listFFprobeSessions() {
    auto ffprobeSessions = FFprobeKit::listFFprobeSessions();
    std::cout << "Listing FFprobe sessions." << std::endl;
    int i = 0;
    std::for_each(ffprobeSessions->begin(), ffprobeSessions->end(), [&](const std::shared_ptr<ffmpegkit::FFprobeSession> session) {
        std::cout << "Session " << i++ << " = id:" << session->getSessionId() << ", startTime:" << session->getStartTime() << ", duration:" << session-> getDuration() << ", state:" << FFmpegKitConfig::sessionStateToString(session->getState()) << ", returnCode:" << session->getReturnCode() << "." << std::endl;
    });
    std::cout << "Listed FFprobe sessions." << std::endl;
}

std::string ffmpegkittest::Application::getApplicationCacheDirectory() {
    return Util::toCommandPath(localAppDataDirectory()) + "/ffmpegkittest";
}

std::string ffmpegkittest::Application::getApplicationInstallDirectory() {
    return Util::toCommandPath(Application::getConfiguredInstallDirectory());
}

std::string ffmpegkittest::Application::getCACertificateBundlePath() {
    return Application::getApplicationInstallDirectory() + "/share/cacert/cacert_2026_08_13.pem";
}

void ffmpegkittest::Application::registerApplicationFonts() {
    auto fontDirectory = Application::getApplicationInstallDirectory() + "/share/fonts";
    auto reportFile = Application::getApplicationCacheDirectory() + "/ffreport.txt";

    // The system font directory is %WINDIR%\Fonts. WINDIR is always defined on
    // Windows, but fall back to the conventional location if it somehow is not.
    const char* windowsDirectory = std::getenv("WINDIR");
    const std::string systemFontDirectory = Util::toCommandPath(windowsDirectory != nullptr ? std::string(windowsDirectory) : std::string("C:\\Windows")) + "/Fonts";

    FFmpegKitConfig::setFontDirectoryList(std::list<std::string>{fontDirectory, systemFontDirectory}, std::map<std::string,std::string>{{"MyFontName", "Doppio One"}});
    FFmpegKitConfig::setEnvironmentVariable("FFREPORT", reportFile.c_str());
}

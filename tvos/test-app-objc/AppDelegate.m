/*
 * Copyright (c) 2018-2021, 2026 Taner Sener
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

#include <ffmpegkit/FFmpegKitConfig.h>
#include "AppDelegate.h"

void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"Uncaught exception detected: %@.", exception);
    NSLog(@"%@", [exception callStackSymbols]);
}

typedef void (^PageSelectionHandler)(NSInteger index);

@interface DetailContainerViewController : UIViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController;
- (void)showContentViewController:(UIViewController *)contentViewController;

@end

@interface DetailContainerViewController ()

@property(nonatomic, strong) UIViewController *currentViewController;

@end

@implementation DetailContainerViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.currentViewController = contentViewController;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    [self installContentViewController:self.currentViewController];
}

- (void)showContentViewController:(UIViewController *)contentViewController {
    if (contentViewController == nil || contentViewController == self.currentViewController) {
        return;
    }

    UIViewController *previousViewController = self.currentViewController;
    [previousViewController willMoveToParentViewController:nil];
    [previousViewController.view removeFromSuperview];
    [previousViewController removeFromParentViewController];

    self.currentViewController = contentViewController;
    [self installContentViewController:contentViewController];
}

- (void)installContentViewController:(UIViewController *)contentViewController {
    if (contentViewController == nil || contentViewController.parentViewController == self) {
        return;
    }

    [self addChildViewController:contentViewController];
    contentViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:contentViewController.view];
    [NSLayoutConstraint activateConstraints:@[
        [contentViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [contentViewController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [contentViewController didMoveToParentViewController:self];
}

@end

@interface SidebarViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles
                   systemImages:(NSArray<NSString *> *)systemImages
                  selectedIndex:(NSInteger)selectedIndex
               selectionHandler:(PageSelectionHandler)selectionHandler;

@end

@interface SidebarViewController ()

@property(nonatomic, strong) NSArray<NSString *> *titles;
@property(nonatomic, strong) NSArray<NSString *> *systemImages;
@property(nonatomic, copy) PageSelectionHandler selectionHandler;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic) NSInteger selectedIndex;

@end

@implementation SidebarViewController

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles
                   systemImages:(NSArray<NSString *> *)systemImages
                  selectedIndex:(NSInteger)selectedIndex
               selectionHandler:(PageSelectionHandler)selectionHandler {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.titles = titles;
        self.systemImages = systemImages;
        self.selectedIndex = selectedIndex;
        self.selectionHandler = selectionHandler;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.remembersLastFocusedIndexPath = YES;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76.0;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"SidebarCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8.0],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40.0],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-40.0]
    ]];

    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:self.selectedIndex inSection:0];
    [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SidebarCell" forIndexPath:indexPath];
    cell.backgroundColor = UIColor.clearColor;
    cell.selectedBackgroundView = [self selectedBackgroundView];
    cell.indentationLevel = 0;
    cell.indentationWidth = 0.0;
    cell.preservesSuperviewLayoutMargins = NO;
    cell.layoutMargins = UIEdgeInsetsZero;
    cell.textLabel.text = self.titles[indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = UIColor.whiteColor;

    return cell;
}

- (UIView *)selectedBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.24];
    view.layer.cornerRadius = 14.0;
    view.layer.masksToBounds = YES;
    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndex = indexPath.row;
    if (self.selectionHandler) {
        self.selectionHandler(indexPath.row);
    }
}

@end

@interface AppDelegate ()

@property(nonatomic, strong) NSArray<UIViewController *> *pageControllers;
@property(nonatomic, strong) DetailContainerViewController *detailContainerViewController;

@end

@implementation AppDelegate

+ (void)listFFprobeSessions {
    NSArray* ffprobeSessions = [FFprobeKit listFFprobeSessions];

    NSLog(@"Listing FFprobe sessions.\n");

    for (int i = 0; i < [ffprobeSessions count]; i++) {
        FFprobeSession* session = [ffprobeSessions objectAtIndex:i];
        NSLog(@"Session %d = id: %ld, startTime: %@, duration: %ld, state:%@, returnCode:%@.\n", i, [session getSessionId], [session getStartTime], [session getDuration], [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode]);
    }

    NSLog(@"Listed FFprobe sessions.\n");
}

+ (void)listFFmpegSessions {
    NSArray* ffmpegSessions = [FFmpegKit listSessions];

    NSLog(@"Listing FFmpeg sessions.\n");

    for (int i = 0; i < [ffmpegSessions count]; i++) {
        FFmpegSession* session = [ffmpegSessions objectAtIndex:i];
        NSLog(@"Session %d = id: %ld, startTime: %@, duration: %ld, state:%@, returnCode:%@.\n", i, [session getSessionId], [session getStartTime], [session getDuration], [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode]);
    }

    NSLog(@"Listed FFmpeg sessions.\n");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);

    // SELECTED BAR ITEM
    [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [UIColor whiteColor], NSForegroundColorAttributeName,
                                                       [UIFont systemFontOfSize:38], NSFontAttributeName,
                                                       nil] forState:UIControlStateSelected];

    // NOT SELECTED BAR ITEMS
    [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [UIColor darkGrayColor], NSForegroundColorAttributeName,
                                                       [UIFont systemFontOfSize:38], NSFontAttributeName,
                                                       nil] forState:UIControlStateNormal];

    NSString *resourceFolder = [[NSBundle mainBundle] resourcePath];
    NSDictionary *fontNameMapping = @{@"MyFontName" : @"Doppio One"};

    [FFmpegKitConfig setFontDirectoryList:[[NSArray alloc] initWithObjects:resourceFolder, @"/System/Library/Fonts", nil] with:fontNameMapping];

    [FFmpegKitConfig ignoreSignal:SIGXCPU];
    [FFmpegKitConfig setLogLevel:LevelAVLogInfo];

    [self configureSplitNavigation];

    return YES;
}

- (void)configureSplitNavigation {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NSArray<NSString *> *pageIdentifiers = @[
        @"CommandViewController",
        @"VideoViewController",
        @"HttpsViewController",
        @"AudioViewController",
        @"SubtitleViewController",
        @"VidStabViewController",
        @"PipeViewController",
        @"ConcurrentExecutionViewController",
        @"FFKitProtocolsViewController",
        @"OtherViewController"
    ];
    NSMutableArray<UIViewController *> *pageControllers = [NSMutableArray arrayWithCapacity:pageIdentifiers.count];
    for (NSString *pageIdentifier in pageIdentifiers) {
        [pageControllers addObject:[storyboard instantiateViewControllerWithIdentifier:pageIdentifier]];
    }
    self.pageControllers = pageControllers;

    NSArray<NSString *> *titles = @[
        @"Command",
        @"Video",
        @"Https",
        @"Audio",
        @"Subtitle",
        @"Vid.Stab",
        @"Pipe",
        @"Concurrent",
        @"FFKit Protocols",
        @"Other"
    ];
    NSArray<NSString *> *systemImages = @[
        @"terminal",
        @"film",
        @"network",
        @"waveform",
        @"captions.bubble",
        @"video.badge.checkmark",
        @"arrow.triangle.branch",
        @"square.stack.3d.up",
        @"memorychip",
        @"ellipsis.circle"
    ];

    UISplitViewController *splitViewController = [[UISplitViewController alloc] init];
    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
    splitViewController.preferredPrimaryColumnWidthFraction = 0.16;
    splitViewController.minimumPrimaryColumnWidth = 260.0;
    splitViewController.maximumPrimaryColumnWidth = 320.0;

    self.detailContainerViewController = [[DetailContainerViewController alloc] initWithContentViewController:self.pageControllers.firstObject];
    __weak AppDelegate *weakSelf = self;
    SidebarViewController *sidebarViewController = [[SidebarViewController alloc] initWithTitles:titles systemImages:systemImages selectedIndex:0 selectionHandler:^(NSInteger index) {
        AppDelegate *strongSelf = weakSelf;
        NSArray<UIViewController *> *controllers = strongSelf.pageControllers;
        if (index < 0 || index >= controllers.count) {
            return;
        }

        UIViewController *selectedViewController = controllers[index];
        [strongSelf.detailContainerViewController showContentViewController:selectedViewController];
        [strongSelf activateViewController:selectedViewController];
    }];

    splitViewController.viewControllers = @[sidebarViewController, self.detailContainerViewController];

    if (self.window == nil) {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    self.window.rootViewController = splitViewController;
    [self.window makeKeyAndVisible];
    [self activateViewController:self.pageControllers.firstObject];
}

- (void)activateViewController:(UIViewController *)viewController {
    SEL setActiveSelector = NSSelectorFromString(@"setActive");
    if ([viewController respondsToSelector:setActiveSelector]) {
        IMP imp = [viewController methodForSelector:setActiveSelector];
        void (*func)(id, SEL) = (void *)imp;
        func(viewController, setActiveSelector);
    }
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end

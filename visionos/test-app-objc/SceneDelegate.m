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

#import "SceneDelegate.h"

typedef void (^PageSelectionHandler)(NSInteger index);
typedef void (^SidebarToggleHandler)(void);

@interface PageContainerViewController : UIViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController
                                toggleHandler:(SidebarToggleHandler)toggleHandler;

@property(nonatomic, strong, readonly) UIViewController *contentViewController;

@end

@interface PageContainerViewController ()

@property(nonatomic, strong) UIViewController *contentViewController;
@property(nonatomic, copy) SidebarToggleHandler toggleHandler;

@end

@implementation PageContainerViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController
                                toggleHandler:(SidebarToggleHandler)toggleHandler {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.contentViewController = contentViewController;
        self.toggleHandler = toggleHandler;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = nil;
    self.navigationItem.title = nil;
    self.view.backgroundColor = UIColor.clearColor;

    [self.contentViewController loadViewIfNeeded];
    self.contentViewController.title = nil;
    self.contentViewController.navigationItem.title = nil;

    [self addChildViewController:self.contentViewController];
    self.contentViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.contentViewController.view];
    [self.contentViewController didMoveToParentViewController:self];

    UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    toggleButton.backgroundColor = UIColor.clearColor;
    toggleButton.tintColor = UIColor.whiteColor;
    toggleButton.accessibilityLabel = @"Hide Menu";
    UIImageSymbolConfiguration *symbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightRegular];
    UIImage *image = [[UIImage systemImageNamed:@"sidebar.left"] imageWithConfiguration:symbolConfiguration];
    [toggleButton setImage:image forState:UIControlStateNormal];
    [toggleButton addTarget:self action:@selector(toggleSidebar:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toggleButton];

    NSLayoutYAxisAnchor *toggleButtonCenterYAnchor = [self headerCenterYAnchorForViewController:self.contentViewController];
    NSLayoutConstraint *toggleButtonVerticalConstraint = toggleButtonCenterYAnchor ?
        [toggleButton.centerYAnchor constraintEqualToAnchor:toggleButtonCenterYAnchor] :
        [toggleButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.contentViewController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [toggleButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24.0],
        toggleButtonVerticalConstraint,
        [toggleButton.widthAnchor constraintEqualToConstant:44.0],
        [toggleButton.heightAnchor constraintEqualToConstant:44.0]
    ]];
}

- (NSLayoutYAxisAnchor *)headerCenterYAnchorForViewController:(UIViewController *)viewController {
    @try {
        id header = [viewController valueForKey:@"header"];
        if ([header isKindOfClass:UILabel.class]) {
            return ((UILabel *)header).centerYAnchor;
        }
    } @catch (NSException *exception) {
    }
    return nil;
}

- (void)toggleSidebar:(id)sender {
    if (self.toggleHandler) {
        self.toggleHandler();
    }
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

    self.view.backgroundColor = UIColor.clearColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 48.0;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"SidebarCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14.0],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:self.selectedIndex inSection:0];
    [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat contentHeight = self.tableView.rowHeight * self.titles.count;
    CGFloat verticalInset = MAX(0.0, (CGRectGetHeight(self.tableView.bounds) - contentHeight) / 2.0);
    self.tableView.contentInset = UIEdgeInsetsMake(verticalInset, 0.0, verticalInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SidebarCell" forIndexPath:indexPath];
    cell.backgroundColor = UIColor.clearColor;
    cell.tintColor = UIColor.secondaryLabelColor;
    cell.selectedBackgroundView = [self selectedBackgroundView];

    UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
    content.text = self.titles[indexPath.row];
    content.textProperties.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    content.textProperties.color = UIColor.labelColor;
    content.image = [UIImage systemImageNamed:self.systemImages[indexPath.row]];
    content.imageProperties.tintColor = UIColor.secondaryLabelColor;
    content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightRegular];
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
    content.imageToTextPadding = 12.0;
    cell.contentConfiguration = content;

    return cell;
}

- (UIView *)selectedBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = UIColor.clearColor;

    UIView *background = [[UIView alloc] initWithFrame:CGRectZero];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
    background.layer.cornerRadius = 12.0;
    background.layer.cornerCurve = kCACornerCurveContinuous;
    [view addSubview:background];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:view.topAnchor constant:4.0],
        [background.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-4.0]
    ]];

    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndex = indexPath.row;
    if (self.selectionHandler) {
        self.selectionHandler(indexPath.row);
    }
}

@end

@interface SceneDelegate ()

@property(nonatomic, strong) NSArray<UIViewController *> *pageControllers;
@property(nonatomic, strong) NSArray<PageContainerViewController *> *detailControllers;

@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UITabBarController *tabBarController = (UITabBarController *)[storyboard instantiateInitialViewController];
    NSArray<UIViewController *> *storyboardControllers = tabBarController.viewControllers;
    self.pageControllers = @[
        storyboardControllers[0],
        storyboardControllers[1],
        storyboardControllers[2],
        storyboardControllers[3],
        storyboardControllers[4],
        storyboardControllers[5],
        storyboardControllers[6],
        storyboardControllers[7],
        storyboardControllers[9],
        storyboardControllers[8]
    ];
    [tabBarController setViewControllers:@[] animated:NO];

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

    UISplitViewController *splitViewController = [[UISplitViewController alloc] initWithStyle:UISplitViewControllerStyleDoubleColumn];
    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
    splitViewController.preferredSplitBehavior = UISplitViewControllerSplitBehaviorTile;
    splitViewController.preferredPrimaryColumnWidthFraction = 0.24;
    splitViewController.minimumPrimaryColumnWidth = 220.0;
    splitViewController.maximumPrimaryColumnWidth = 260.0;

    __weak UISplitViewController *weakSplitViewController = splitViewController;
    __weak SceneDelegate *weakSelf = self;
    SidebarToggleHandler toggleHandler = ^{
        UISplitViewController *strongSplitViewController = weakSplitViewController;
        if (!strongSplitViewController) {
            return;
        }

        if (strongSplitViewController.preferredDisplayMode == UISplitViewControllerDisplayModeSecondaryOnly ||
            strongSplitViewController.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
            strongSplitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
        } else {
            strongSplitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        }
    };
    NSMutableArray<PageContainerViewController *> *detailControllers = [NSMutableArray arrayWithCapacity:self.pageControllers.count];
    for (UIViewController *pageController in self.pageControllers) {
        [detailControllers addObject:[[PageContainerViewController alloc] initWithContentViewController:pageController toggleHandler:toggleHandler]];
    }
    self.detailControllers = detailControllers;

    SidebarViewController *sidebarViewController = [[SidebarViewController alloc] initWithTitles:titles systemImages:systemImages selectedIndex:0 selectionHandler:^(NSInteger index) {
        SceneDelegate *strongSelf = weakSelf;
        NSArray<UIViewController *> *controllers = strongSelf.pageControllers;
        NSArray<PageContainerViewController *> *detailControllers = strongSelf.detailControllers;
        if (index < 0 || index >= controllers.count || index >= detailControllers.count) {
            return;
        }

        UIViewController *selectedViewController = controllers[index];
        [weakSplitViewController setViewController:detailControllers[index] forColumn:UISplitViewControllerColumnSecondary];
        [strongSelf activateViewController:selectedViewController];
    }];

    [splitViewController setViewController:sidebarViewController forColumn:UISplitViewControllerColumnPrimary];
    [splitViewController setViewController:self.detailControllers.firstObject forColumn:UISplitViewControllerColumnSecondary];

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

@end

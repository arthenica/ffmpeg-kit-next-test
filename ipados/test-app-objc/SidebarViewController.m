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

#include "SidebarViewController.h"

static NSString *const SidebarCellIdentifier = @"SidebarCell";

@interface SidebarViewController ()

// Row titles shown in the sidebar.
@property (strong, nonatomic) NSArray<NSString *> *sectionTitles;
// Storyboard identifiers of the detail view controllers, aligned with sectionTitles.
@property (strong, nonatomic) NSArray<NSString *> *sectionIdentifiers;
// View controllers are instantiated lazily and kept alive so their state survives navigation, like tabs did.
@property (strong, nonatomic) NSMutableDictionary<NSString *, UIViewController *> *viewControllerCache;

@end

@implementation SidebarViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.sectionTitles = @[@"Command", @"Video", @"HTTPS", @"Audio", @"Subtitle", @"Vid.Stab", @"Pipe", @"Concurrent Execution", @"Other", @"FFKit Protocols"];
    self.sectionIdentifiers = @[@"CommandViewController", @"VideoViewController", @"HttpsViewController", @"AudioViewController", @"SubtitleViewController", @"VidStabViewController", @"PipeViewController", @"ConcurrentExecutionViewController", @"OtherViewController", @"FFKitProtocolsViewController"];
    self.viewControllerCache = [NSMutableDictionary dictionary];

    self.title = @"FFmpegKitNext";
    self.clearsSelectionOnViewWillAppear = NO;
    self.tableView.tintColor = [UIColor colorWithRed:244.0/255.0 green:104.0/255.0 blue:66.0/255.0 alpha:1.0];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:SidebarCellIdentifier];

    // Show the first section by default so the detail column is never empty on launch.
    [self showSectionAtIndex:0];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sectionTitles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SidebarCellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = self.sectionTitles[indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self showSectionAtIndex:indexPath.row];
}

#pragma mark - Section selection

- (void)showSectionAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.sectionIdentifiers.count) {
        return;
    }

    NSString *identifier = self.sectionIdentifiers[index];
    UIViewController *controller = self.viewControllerCache[identifier];
    if (controller == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        controller = [storyboard instantiateViewControllerWithIdentifier:identifier];
        self.viewControllerCache[identifier] = controller;
    }

    controller.navigationItem.title = self.sectionTitles[index];
    // Load the view now so IBOutlets are connected before setActive runs (it may touch them).
    [controller loadViewIfNeeded];
    self.detailNavigationController.viewControllers = @[controller];

    if ([controller respondsToSelector:@selector(setActive)]) {
        [(id<Activatable>)controller setActive];
    }

    // Keep the row highlighted, including for the initial programmatic selection.
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

@end

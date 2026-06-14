/*
 * Copyright (c) 2026 Taner Sener
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
#include <ffmpegkit/FFmpegKit.h>
#include <ffmpegkit/FFprobeKit.h>
#include <ffmpegkit/FFmpegKitInputBuffer.h>
#include <ffmpegkit/FFmpegKitOutputBuffer.h>
#include <ffmpegkit/ReturnCode.h>
#include "FFKitProtocolsViewController.h"

static NSString* ffkitEscapeDrawtextText(NSString* text) {
    NSString* escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return escaped;
}

static NSString* ffkitBuildMemProtocolCommand(NSString* inputUrl, NSString* outputUrl, NSString* fontPath, NSString* text) {
    NSString* drawtext = [NSString stringWithFormat:
        @"drawtext=fontfile=%@:text='%@':x=(w-text_w)/2:y=h-th-40:fontsize=h/15:fontcolor=white:box=1:boxcolor=black@0.5",
        fontPath, ffkitEscapeDrawtextText(text)];
    return [NSString stringWithFormat:@"-y -i %@ -vf \"%@\" -frames:v 1 -f image2 -c:v mjpeg -update 1 %@", inputUrl, drawtext, outputUrl];
}

static NSString* ffkitHumanReadableByteCount(long bytes) {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%ld B", bytes];
    }
    double kb = bytes / 1024.0;
    if (kb < 1024) {
        return [NSString stringWithFormat:@"%.1f KB", kb];
    }
    return [NSString stringWithFormat:@"%.1f MB", kb / 1024.0];
}

static NSString* ffkitFormatStatus(NSString* inputUrl, long inputSize, NSString* outputUrl, long outputSize) {
    return [NSString stringWithFormat:@"in %@ (%@) -> drawtext -> out %@ (%@)",
        inputUrl, ffkitHumanReadableByteCount(inputSize), outputUrl, ffkitHumanReadableByteCount(outputSize)];
}

@interface FFKitProtocolsViewController () <NSComboBoxDataSource, NSComboBoxDelegate>

@property (strong) IBOutlet NSComboBox *protocolComboBox;
@property (strong) IBOutlet NSTextField *overlayText;
@property (strong) IBOutlet NSButton *runFFmpegButton;
@property (strong) IBOutlet NSButton *runFFprobeButton;
@property (strong) IBOutlet NSImageView *resultImageView;
@property (strong) IBOutlet NSTextView *outputText;
@property (strong) IBOutlet NSTextField *statusText;

@end

@implementation FFKitProtocolsViewController {
    NSArray<NSString*>* protocolList;
    NSString* selectedProtocol;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    protocolList = @[@"ffkitmem"];
    selectedProtocol = protocolList[0];

    self.protocolComboBox.usesDataSource = YES;
    self.protocolComboBox.dataSource = self;
    self.protocolComboBox.delegate = self;
    [self.protocolComboBox selectItemAtIndex:0];

    self.overlayText.stringValue = @"FFmpegKitNext";

    [Util applyComboBoxStyle: self.protocolComboBox];
    [Util applyEditTextStyle: self.overlayText];
    [Util applyButtonStyle: self.runFFmpegButton];
    [Util applyButtonStyle: self.runFFprobeButton];
    [Util applyOutputTextStyle: self.outputText];

    self.resultImageView.hidden = YES;
    self.outputText.enclosingScrollView.hidden = YES;
    self.statusText.stringValue = @"Select a protocol, then run FFmpeg or FFprobe.";

    addUIAction(^{
        [self setActive];
    });
}

- (void)setActive {
    NSLog(@"FFKitProtocols Tab Activated");
    [FFmpegKitConfig enableLogCallback:nil];
    [FFmpegKitConfig enableStatisticsCallback:nil];
}

#pragma mark - Protocol combo box

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return protocolList.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return protocolList[index];
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    return [protocolList indexOfObject:string];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger index = [self.protocolComboBox indexOfSelectedItem];
    if (index >= 0 && index < (NSInteger)protocolList.count) {
        selectedProtocol = protocolList[index];
    }
}

#pragma mark - Button actions

- (IBAction)runFFmpeg:(id)sender {
    if (![selectedProtocol isEqualToString:@"ffkitmem"]) {
        [Util alert:self.view.window withTitle:@"FFKit Protocols" message:@"This protocol is not implemented yet." buttonText:@"OK" andHandler:nil];
        return;
    }
    NSData* bytes = [self pickImageBytes];
    if (bytes != nil) {
        [self runFFmpegMemWithBytes:bytes];
    }
}

- (IBAction)runFFprobe:(id)sender {
    if (![selectedProtocol isEqualToString:@"ffkitmem"]) {
        [Util alert:self.view.window withTitle:@"FFKit Protocols" message:@"This protocol is not implemented yet." buttonText:@"OK" andHandler:nil];
        return;
    }
    NSData* bytes = [self pickImageBytes];
    if (bytes != nil) {
        [self runFFprobeMemWithBytes:bytes];
    }
}

#pragma mark - Image selection (NSOpenPanel)

- (NSData*)pickImageBytes {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"jpg", @"jpeg", @"png"];

    if ([panel runModal] != NSModalResponseOK) {
        return nil;   // cancelled
    }
    NSURL* url = panel.URLs.firstObject;
    NSData* bytes = url != nil ? [NSData dataWithContentsOfURL:url] : nil;
    if (bytes == nil) {
        [Util alert:self.view.window withTitle:@"Error" message:@"Could not read the selected image." buttonText:@"OK" andHandler:nil];
    }
    return bytes;
}

#pragma mark - ffkitmem flows

- (void)runFFmpegMemWithBytes:(NSData*)bytes {
    NSString* fontPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"doppioone_regular.ttf"];

    FFmpegKitInputBuffer* input = [FFmpegKitInputBuffer fromData:bytes extension:@"jpg"];
    FFmpegKitOutputBuffer* output = [FFmpegKitOutputBuffer create:@"jpg"];
    NSString* command = ffkitBuildMemProtocolCommand([input getUrl], [output getUrl], fontPath, [self.overlayText stringValue]);
    long inputSize = [input getSize];

    self.statusText.stringValue = @"Running…";
    NSLog(@"ffkitmem ffmpeg command: %@", command);

    [FFmpegKit executeAsync:command withCompleteCallback:^(FFmpegSession* session) {
        if ([ReturnCode isSuccess:[session getReturnCode]]) {
            NSData* result = [output toData];
            long outputSize = [output getSize];
            NSImage* image = [[NSImage alloc] initWithData:result];
            if (image == nil) {
                addUIAction(^{
                    [self showTextResult:@"FFmpeg succeeded but the output image could not be decoded."];
                    self.statusText.stringValue = @"Decode failed.";
                    [Util alert:self.view.window withTitle:@"Error" message:@"The processed image could not be decoded." buttonText:@"OK" andHandler:nil];
                });
            } else {
                NSString* status = ffkitFormatStatus([input getUrl], inputSize, [output getUrl], outputSize);
                addUIAction(^{
                    [self showImageResult:image];
                    self.statusText.stringValue = status;
                });
            }
        } else {
            NSString* logs = [session getAllLogsAsString];
            NSLog(@"ffkitmem ffmpeg failed: %@", logs);
            addUIAction(^{
                [self showTextResult:logs];
                self.statusText.stringValue = @"Processing failed.";
                [Util alert:self.view.window withTitle:@"Error" message:@"Processing failed. Please check output for the details." buttonText:@"OK" andHandler:nil];
            });
        }
        [input close];
        [output close];
    }];
}

- (void)runFFprobeMemWithBytes:(NSData*)bytes {
    FFmpegKitInputBuffer* input = [FFmpegKitInputBuffer fromData:bytes extension:@"jpg"];
    NSString* inputUrl = [input getUrl];
    NSString* command = [NSString stringWithFormat:@"-hide_banner -print_format json -show_format -show_streams %@", inputUrl];

    self.statusText.stringValue = @"Running…";
    NSLog(@"ffkitmem ffprobe command: %@", command);

    [FFprobeKit executeAsync:command withCompleteCallback:^(FFprobeSession* session) {
        BOOL success = [ReturnCode isSuccess:[session getReturnCode]];
        NSString* out = [session getOutput] ?: @"";
        addUIAction(^{
            [self showTextResult:out];
            self.statusText.stringValue = [NSString stringWithFormat:@"ffprobe -> %@", inputUrl];
            if (!success) {
                [Util alert:self.view.window withTitle:@"Error" message:@"Processing failed. Please check output for the details." buttonText:@"OK" andHandler:nil];
            }
        });
        [input close];
    }];
}

#pragma mark - Result helpers

- (void)showImageResult:(NSImage*)image {
    self.outputText.enclosingScrollView.hidden = YES;
    self.resultImageView.hidden = NO;
    self.resultImageView.image = image;
}

- (void)showTextResult:(NSString*)text {
    self.resultImageView.hidden = YES;
    self.outputText.enclosingScrollView.hidden = NO;
    [self.outputText setString:text];
    [self.outputText scrollRangeToVisible:NSMakeRange(0, 0)];
}

@end

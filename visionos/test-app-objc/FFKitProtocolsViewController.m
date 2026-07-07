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

@interface FFKitProtocolsViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UIPickerView *protocolPicker;
@property (strong, nonatomic) IBOutlet UITextField *overlayText;
@property (strong, nonatomic) IBOutlet UIButton *runFFmpegButton;
@property (strong, nonatomic) IBOutlet UIButton *runFFprobeButton;
@property (strong, nonatomic) IBOutlet UIImageView *resultImageView;
@property (strong, nonatomic) IBOutlet UITextView *outputText;
@property (strong, nonatomic) IBOutlet UILabel *statusText;

@end

@implementation FFKitProtocolsViewController {
    NSArray<NSString*>* protocolList;
    NSString* selectedProtocol;
    BOOL pendingFFprobe;   // which action launched the image picker
}

- (void)viewDidLoad {
    [super viewDidLoad];

    protocolList = @[@"ffkitmem"];
    selectedProtocol = protocolList[0];
    pendingFFprobe = NO;

    self.protocolPicker.dataSource = self;
    self.protocolPicker.delegate = self;

    self.overlayText.text = @"FFmpegKitNext";

    [Util applyHeaderStyle: self.header];
    [Util applyPickerViewStyle: self.protocolPicker];
    [Util applyEditTextStyle: self.overlayText];
    [Util applyButtonStyle: self.runFFmpegButton];
    [Util applyButtonStyle: self.runFFprobeButton];
    [Util applyOutputTextStyle: self.outputText];

    self.resultImageView.hidden = YES;
    self.outputText.hidden = YES;
    self.statusText.text = @"Select a protocol, then run FFmpeg or FFprobe.";

    addUIAction(^{
        [self setActive];
    });
}

- (void)setActive {
    NSLog(@"FFKitProtocols Tab Activated");
    [FFmpegKitConfig enableLogCallback:nil];
    [FFmpegKitConfig enableStatisticsCallback:nil];
}

#pragma mark - Protocol picker

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return protocolList.count;
}

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return protocolList[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    selectedProtocol = protocolList[row];
}

#pragma mark - Button actions

- (IBAction)runFFmpeg:(id)sender {
    if (![selectedProtocol isEqualToString:@"ffkitmem"]) {
        [Util alert:self withTitle:@"FFKit Protocols" message:@"This protocol is not implemented yet." andButtonText:@"OK"];
        return;
    }
    pendingFFprobe = NO;
    [self showImageSourceChooser];
}

- (IBAction)runFFprobe:(id)sender {
    if (![selectedProtocol isEqualToString:@"ffkitmem"]) {
        [Util alert:self withTitle:@"FFKit Protocols" message:@"This protocol is not implemented yet." andButtonText:@"OK"];
        return;
    }
    pendingFFprobe = YES;
    [self showImageSourceChooser];
}

#pragma mark - Image selection

- (void)showImageSourceChooser {
    [self.overlayText endEditing:YES];

    UIAlertController* sheet = [UIAlertController alertControllerWithTitle:@"Select image source" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

#if !TARGET_OS_VISION
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Take Photo" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
            [self launchPickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
        }]];
    }
#endif
    [sheet addAction:[UIAlertAction actionWithTitle:@"Choose from Library" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        [self launchPickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    UIButton* anchor = pendingFFprobe ? self.runFFprobeButton : self.runFFmpegButton;
    sheet.popoverPresentationController.sourceView = anchor;
    sheet.popoverPresentationController.sourceRect = anchor.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)launchPickerWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController* picker = [[UIImagePickerController alloc] init];
    picker.sourceType = sourceType;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    UIImage* image = info[UIImagePickerControllerOriginalImage];
    NSData* bytes = image != nil ? UIImageJPEGRepresentation(image, 0.9) : nil;
    if (bytes == nil) {
        [Util alert:self withTitle:@"Error" message:@"Could not read the selected image." andButtonText:@"OK"];
        return;
    }

    if (pendingFFprobe) {
        [self runFFprobeMemWithBytes:bytes];
    } else {
        [self runFFmpegMemWithBytes:bytes];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ffkitmem flows

- (void)runFFmpegMemWithBytes:(NSData*)bytes {
    NSString* fontPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"doppioone_regular.ttf"];

    FFmpegKitInputBuffer* input = [FFmpegKitInputBuffer fromData:bytes extension:@"jpg"];
    FFmpegKitOutputBuffer* output = [FFmpegKitOutputBuffer create:@"jpg"];
    NSString* command = ffkitBuildMemProtocolCommand([input getUrl], [output getUrl], fontPath, [self.overlayText text]);
    long inputSize = [input getSize];

    self.statusText.text = @"Running…";
    NSLog(@"ffkitmem ffmpeg command: %@", command);

    [FFmpegKit executeAsync:command withCompleteCallback:^(FFmpegSession* session) {
        if ([ReturnCode isSuccess:[session getReturnCode]]) {
            NSData* result = [output toData];
            long outputSize = [output getSize];
            UIImage* image = [UIImage imageWithData:result];
            if (image == nil) {
                addUIAction(^{
                    [self showTextResult:@"FFmpeg succeeded but the output image could not be decoded."];
                    self.statusText.text = @"Decode failed.";
                    [Util alert:self withTitle:@"Error" message:@"The processed image could not be decoded." andButtonText:@"OK"];
                });
            } else {
                NSString* status = ffkitFormatStatus([input getUrl], inputSize, [output getUrl], outputSize);
                addUIAction(^{
                    [self showImageResult:image];
                    self.statusText.text = status;
                });
            }
        } else {
            NSString* logs = [session getAllLogsAsString];
            NSLog(@"ffkitmem ffmpeg failed: %@", logs);
            addUIAction(^{
                [self showTextResult:logs];
                self.statusText.text = @"Processing failed.";
                [Util alert:self withTitle:@"Error" message:@"Processing failed. Please check output for the details." andButtonText:@"OK"];
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

    self.statusText.text = @"Running…";
    NSLog(@"ffkitmem ffprobe command: %@", command);

    [FFprobeKit executeAsync:command withCompleteCallback:^(FFprobeSession* session) {
        BOOL success = [ReturnCode isSuccess:[session getReturnCode]];
        NSString* out = [session getOutput] ?: @"";
        addUIAction(^{
            [self showTextResult:out];
            self.statusText.text = [NSString stringWithFormat:@"ffprobe -> %@", inputUrl];
            if (!success) {
                [Util alert:self withTitle:@"Error" message:@"Processing failed. Please check output for the details." andButtonText:@"OK"];
            }
        });
        [input close];
    }];
}

#pragma mark - Result helpers

- (void)showImageResult:(UIImage*)image {
    self.outputText.hidden = YES;
    self.resultImageView.hidden = NO;
    self.resultImageView.image = image;
}

- (void)showTextResult:(NSString*)text {
    self.resultImageView.hidden = YES;
    self.outputText.hidden = NO;
    self.outputText.text = text;
    [self.outputText scrollRangeToVisible:NSMakeRange(0, 0)];
}

@end

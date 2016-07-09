/**
 * Copyright IBM Corporation 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

#import "STTViewController.h"


@interface STTViewController () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) IBOutlet UIButton *modelSelectorButton;
@property (strong, nonatomic) UIPickerView *pickerView;
@property NSArray *STTLanguageModels;

@end

@implementation STTViewController

@synthesize stt;
@synthesize result;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *credentialFilePath = [[NSBundle mainBundle] pathForResource:@"Credentials" ofType:@"plist"];
    NSDictionary *credentials = [[NSDictionary alloc] initWithContentsOfFile:credentialFilePath];
    
    // STT setup
    STTConfiguration *confSTT = [[STTConfiguration alloc] init];

    // Use opus compression, better for mobile devices.
    [confSTT setBasicAuthUsername:credentials[@"STTUsername"]];
    [confSTT setBasicAuthPassword:credentials[@"STTPassword"]];
    [confSTT setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_OPUS];
    [confSTT setModelName:WATSONSDK_DEFAULT_STT_MODEL];

//    [conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
//        NSURL *url = [[NSURL alloc] initWithString:@"https://<token-factory-url>"];
//        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//        [request setHTTPMethod:@"GET"];
//        [request setURL:url];
//        
//        NSError *error = [[NSError alloc] init];
//        NSHTTPURLResponse *responseCode = nil;
//        NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
//        if ([responseCode statusCode] != 200) {
//            NSLog(@"Error getting %@, HTTP status code %li", url, (long)[responseCode statusCode]);
//            return;
//        }
//        tokenHandler([[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding]);
//    } ];
    
    __weak typeof(self) weakSelf = self;
    
    self.stt = [SpeechToText initWithConfig:confSTT];
    // list models call to populate picker
    [self.stt listModels:^(NSDictionary* res, NSError* err){
        if(err == nil)
            [weakSelf modelHandler:res];
        else
            weakSelf.result.text = [err description];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pressSelectModel:(id)sender {
    [self.pickerView setHidden:NO];
    [self.pickerView setOpaque:YES];
}

-(IBAction) pressStartRecord:(id) sender {
    // start recognize
    [stt recognize:^(NSDictionary* res, NSError* err){
        // make sure the connection and recording process are finished
        if(res == nil && err == nil){
            [stt stopRecordingAudio];
            [stt endConnection];
            return;
        }

        if(err == nil) {
            if([self.stt isFinalTranscript:res]) {
                
                NSLog(@"this is the final transcript");
                [stt endRecognize];
                
                NSLog(@"confidence score is %@",[stt getConfidenceScore:res]);
            }
            result.text = [stt getTranscript:res];
        }
        else {
            NSLog(@"received error from the SDK %@",[err description]);
            [stt endRecognize];
            [self presentAlertWithTitle:@"Error" message:err.localizedDescription];
        }
    } dataHandler:^(NSData* data) {
        NSLog(@"sent out %lu bytes", (unsigned long)[data length]);
    } powerHandler:^(float power) {
        CGRect frm = self.soundbar.frame;
        frm.size.width = 3*(70 + power);
        self.soundbar.frame = frm;
        self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, self.soundbar.center.y);
    }];
}

- (void) modelHandler:(NSDictionary *) dict {
    self.STTLanguageModels = [dict objectForKey:@"models"];
    
    // create the picker view now we have the data.
    [self.pickerView setBackgroundColor:[UIColor whiteColor]];
    [self.pickerView setOpaque:YES];
    [self.pickerView setHidden:YES];
    
    // add a tap gesture recognizer so we can detect a tap on the already selected uipickerview item
    UITapGestureRecognizer* gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickerViewTapGestureRecognized:)];
    [self.pickerView addGestureRecognizer:gestureRecognizer];
    gestureRecognizer.delegate = self;

    [self.view addSubview:self.pickerView];
    // select the us broadband model by default
    if(self.STTLanguageModels){
        long row = self.STTLanguageModels.count - 1;
        for (long i = 0; i < self.STTLanguageModels.count; i++) {
            NSDictionary *model = self.STTLanguageModels[i];
            if([[model objectForKey:@"name"] isEqualToString:self.stt.config.modelName]){
                row = i;
                break;
            }
        }
        [self.pickerView selectRow:row inComponent:0 animated:NO];
        [self onSelectedModel:row];
    }
}

#pragma mark language model selection

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return true;
}

- (void)pickerViewTapGestureRecognized:(UIGestureRecognizer *)sender {
    [self onSelectedModel:[self.pickerView selectedRowInComponent:0]];
}

- (void)onSelectedModel:(long) row {
    if(self.STTLanguageModels != nil) {
        NSDictionary *model = [self.STTLanguageModels objectAtIndex:row];
        
        NSString *modelName = [model objectForKey:@"name"];
        NSString *modelDesc = [model objectForKey:@"description"];
        [self.modelSelectorButton setTitle:[NSString stringWithFormat:@"%@",modelDesc] forState:UIControlStateNormal];
        [[self.stt config] setModelName:modelName];
        [self.pickerView setHidden:YES];
    }
}

- (UIPickerView *)pickerView {
    if (!_pickerView) {
        int pickerHeight = 250;
        _pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height - pickerHeight + 33, [UIScreen mainScreen].bounds.size.width, pickerHeight)];
        _pickerView.dataSource = self;
        _pickerView.delegate = self;
    }
    
    return _pickerView;
}

#pragma mark -

- (void)presentAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }]]
    [self presentViewController:alert animated:true completion:nil];
}

#pragma mark - UIPickerViewDataSource Methods

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if(self.STTLanguageModels == nil) {
        return 0;
    }
    return [self.STTLanguageModels count];
}

#pragma mark - UIPickerViewDelegate Methods

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    return 200;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 50;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel* tView = (UILabel*)view;
    if (!tView) {
        tView = [[UILabel alloc] init];
        [tView setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        tView.numberOfLines=1;
    }
    // Fill the label text here
    NSDictionary *model = [self.STTLanguageModels objectAtIndex:row];
    tView.text=[model objectForKey:@"description"];
    return tView;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [self onSelectedModel:row];
}



@end

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
    
    
    // STT setup
    STTConfiguration *conf = [[STTConfiguration alloc] init];
    
    // Use opus compression, better for mobile devices.
    [conf setBasicAuthUsername:@""];
    [conf setBasicAuthPassword:@""];
    [conf setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_OPUS];
    [conf setModelName:@"en-US_BroadbandModel"];

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
    
    self.stt = [SpeechToText initWithConfig:conf];
    
    
    // list models call to populate picker
    [stt listModels:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            [self modelHandler:res];
        else
            result.text = [err localizedDescription];
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


-(IBAction) pressStartRecord:(id) sender
{
    
    
    
    
    // start recognize
    [stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil) {
            
            
            if([self.stt isFinalTranscript:res]) {
                
                NSLog(@"this is the final transcript");
                [stt endRecognize];
                
                NSLog(@"confidence score is %@",[stt getConfidenceScore:res]);
            }
            
            result.text = [stt getTranscript:res];
            
            
        } else {
            NSLog(@"received error from the SDK %@",[err localizedDescription]);
            [stt endRecognize];
        }
    }];
    
    // get power readings until recording has finished
    [stt getPowerLevel:^(float power){
        
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
    [self.pickerView selectRow:self.STTLanguageModels.count-1 inComponent:0 animated:NO];
    
}



#pragma mark language model selection

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    // return
    return true;
}

-(void)pickerViewTapGestureRecognized:(UIGestureRecognizer *)sender {
    
    if(self.STTLanguageModels != nil)
    {
        NSDictionary *model = [self.STTLanguageModels objectAtIndex:[self.pickerView selectedRowInComponent:0]];
        
        NSString *modelName = [model objectForKey:@"name"];
        NSString *modelDesc = [model objectForKey:@"description"];
        
        self.modelSelectorButton.titleLabel.text = [NSString stringWithFormat:@"    %@",modelDesc];
        [[self.stt config] setModelName:modelName];
        [self.pickerView setHidden:YES];
    }
    
}

- (UIPickerView *)pickerView
{
    if (!_pickerView)
    {
        int pickerHeight = 250;
        _pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height-pickerHeight+33, [UIScreen mainScreen].bounds.size.width, pickerHeight)];
        _pickerView.dataSource = self;
        _pickerView.delegate = self;
    }
    
    return _pickerView;
}

#pragma mark - UIPickerViewDataSource Methods

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    
    if(self.STTLanguageModels != nil)
    {
        return [self.STTLanguageModels count];
    }
    
    return 0;
}

#pragma mark - UIPickerViewDelegate Methods

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    return 200;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 50;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel* tView = (UILabel*)view;
    if (!tView)
    {
        tView = [[UILabel alloc] init];
        [tView setFont:[UIFont fontWithName:@"Helvetica" size:14]];
        tView.numberOfLines=1;
    }
    // Fill the label text here
    NSDictionary *model = [self.STTLanguageModels objectAtIndex:row];
    tView.text=[model objectForKey:@"description"];
    return tView;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    
    if(self.STTLanguageModels != nil)
    {
        NSDictionary *model = [self.STTLanguageModels objectAtIndex:row];
        
        NSString *modelName = [model objectForKey:@"name"];
        NSString *modelDesc = [model objectForKey:@"description"];
        
        
        self.modelSelectorButton.titleLabel.text = [NSString stringWithFormat:@"    %@",modelDesc];
        
        [[self.stt config] setModelName:modelName];
        [self.pickerView setHidden:YES];
    }
    
}



@end

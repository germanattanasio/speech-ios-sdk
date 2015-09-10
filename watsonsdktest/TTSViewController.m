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

#import "TTSViewController.h"


@interface TTSViewController () <UIGestureRecognizerDelegate>
@property (strong, nonatomic) IBOutlet UIButton *ttsButton;

@property (weak, nonatomic) IBOutlet UITextView *ttsField;
@property (strong, nonatomic) IBOutlet UIButton *voiceSelectorButton;
@property (strong, nonatomic) UIPickerView *pickerView;
@property NSArray *TTSVoices;
@property TextToSpeech *tts;
@end

@implementation TTSViewController

@synthesize ttsButton = _ttsButton;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    // TTS setup
    TTSConfiguration *confTTS = [[TTSConfiguration alloc] init];
    
    [confTTS setApiURL:@"https://stream.watsonplatform.net/text-to-speech/api/"];
    
    [confTTS setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        NSURL *url = [[NSURL alloc] initWithString:@"https://text-to-speech-nodejs-tokenfactory.mybluemix.net/token"];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"GET"];
        [request setURL:url];
        
        NSError *error = [[NSError alloc] init];
        NSHTTPURLResponse *responseCode = nil;
        NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
        if ([responseCode statusCode] != 200) {
            NSLog(@"Error getting %@, HTTP status code %i", url, [responseCode statusCode]);
            return;
        }
        tokenHandler([[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding]);
    } ];
    
    self.tts = [TextToSpeech initWithConfig:confTTS];
    
    
    // list voices call to populate picker
    [self.tts listVoices:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            [self voiceHandler:res];
        else
            self.ttsField.text = [err localizedDescription];
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pressSelectVoice:(id)sender {
    
    [self.pickerView setHidden:NO];
    [self.pickerView setOpaque:YES];
    
    
}

- (IBAction)pressSpeak:(id)sender {
    
    [self.tts synthesize:^(NSData *data, NSError *err) {
        
        // play audio and log when playgin has finished
        [self.tts playAudio:^(NSError *err) {
            
            if(!err)
                NSLog(@"audio finished playing");
            else
                NSLog(@"error playing audio %@",err.localizedDescription);
            
        } withData:data];
        
    } theText:self.ttsField.text];
}

- (void) voiceHandler:(NSDictionary *) dict {
    
    self.TTSVoices = [dict objectForKey:@"voices"];
    
    
    [self.pickerView setBackgroundColor:[UIColor whiteColor]];
    [self.pickerView setOpaque:YES];
    [self.pickerView setHidden:YES];
    
    // add a tap gesture recognizer so we can detect a tap on the already selected uipickerview item
    UITapGestureRecognizer* gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickerViewTapGestureRecognized:)];
    [self.pickerView addGestureRecognizer:gestureRecognizer];
    gestureRecognizer.delegate = self;
    
    
    [self.view addSubview:self.pickerView];
    
}



#pragma mark language model selection

// dismiss keyboard when the background is touched
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.ttsField endEditing:YES];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    // return
    return true;
}

-(void)pickerViewTapGestureRecognized:(UIGestureRecognizer *)sender {
    
    if(self.TTSVoices != nil)
    {
        NSDictionary *voice = [self.TTSVoices objectAtIndex:[self.pickerView selectedRowInComponent:0]];
        
        NSString *voiceName = [voice objectForKey:@"name"];
        NSString *voiceGender = [voice objectForKey:@"gender"];
        
        self.voiceSelectorButton.titleLabel.text = [NSString stringWithFormat:@"    %@: %@",voiceGender,voiceName];
        [[self.tts config] setVoiceName:voiceName];
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
    
    if(self.TTSVoices != nil)
    {
        return [self.TTSVoices count];
    }
    
    return 0;
}

#pragma mark - UIPickerViewDelegate Methods

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component;
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
    NSDictionary *voice = [self.TTSVoices objectAtIndex:row];
    
    NSString *voiceName = [voice objectForKey:@"name"];
    NSString *voiceGender = [voice objectForKey:@"gender"];
    
    tView.text=[NSString stringWithFormat:@"    %@: %@",voiceGender,voiceName];
    return tView;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    
    if(self.TTSVoices != nil)
    {
        NSDictionary *voice = [self.TTSVoices objectAtIndex:row];
        
        NSString *voiceName = [voice objectForKey:@"name"];
        NSString *voiceGender = [voice objectForKey:@"gender"];
        
        
        self.voiceSelectorButton.titleLabel.text = [NSString stringWithFormat:@"    %@: %@",voiceGender,voiceName];
        
        [[self.tts config] setVoiceName:voiceName];
        [self.pickerView setHidden:YES];
    }
    
}



@end

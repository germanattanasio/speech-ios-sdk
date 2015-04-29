//
//  FirstViewController.m
//  watsonSDKsample
//
//  Created by Rob Smart on 30/05/2013.
//  Copyright (c) 2013 IBM. All rights reserved.
//

#import "FirstViewController.h"

@interface FirstViewController ()
@property (strong, nonatomic) IBOutlet UIButton *ttsButton;

@end

@implementation FirstViewController

@synthesize stt;
@synthesize result;
@synthesize ttsField;
@synthesize ttsButton = _ttsButton;

- (IBAction)onTTSRequest:(id)sender {
   // [stt playTTSForString:@"This is a test"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSURL *host = [NSURL URLWithString:@"wss://speech.tap.ibm.com/speech-to-text-beta/api/v1/recognize"];
    //NSURL *host = [NSURL URLWithString:@"ws://192.168.59.103:9080/speech-to-text-beta/api/v1/models/WatsonModel/recognize"];
    //NSURL *host = [NSURL URLWithString:@"wss://dpev918.innovate.ibm.com/v1/models/WatsonModel/recognize"];
    
    self.stt = [SpeechToText initWithURL:host];
    [self.stt setDelegate:self];
    
    [self.stt setBasicAuthUsername:@"ivaniapi"];
    [self.stt setBasicAuthPassword:@"Zt1xSp33x"];
    
    
    }

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction) pressStartRecord:(id) sender
{
    NSError* error= [stt recognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);
    
    result.text = @"Starting audio stream...";
    
    [stt listModels:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            [self modelHandler:res];
        else
            NSLog(@"Error fetching models");
    }];
    
}

- (void) modelHandler:(NSDictionary *) dict {
    NSLog(@"modelHandler");
}

-(IBAction) pressStopRecord:(id) sender{
    
    NSError* error= [stt endRecognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);
   
}

- (void) PartialTranscriptCallback:(NSString*) response {
  
    result.text = response;
    
}


- (void) TranscriptionFinishedCallback:(NSString*) response{
    
    
    NSLog(@"transcript is this %@",response);
    result.text = response;
    
}

- (void) peakPowerCallback:(float) power {
    
//    NSLog(@"peak power %f",power);
   
    CGRect frm = self.soundbar.frame;
    frm.size.width = 3*(70 + power);
    self.soundbar.frame = frm;
    
    self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, self.soundbar.center.y);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    NSLog(@"textFieldShouldReturn:");
    
    [textField resignFirstResponder];
    
  //  [stt playTTSForString:textField.text];
    
    return YES;
}

@end

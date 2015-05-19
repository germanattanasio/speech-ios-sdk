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


- (void)viewDidLoad
{
    [super viewDidLoad];

    // STT setup
    STTConfiguration *conf = [[STTConfiguration alloc] init];
    [conf setApiURL:@"https://speech.tap.ibm.com/speech-to-text-beta/api"];
    [conf setBasicAuthUsername:@"ivaniapi"];
    [conf setBasicAuthPassword:@"Zt1xSp33x"];
    self.stt = [SpeechToText initWithConfig:conf];
    
    
    // TTS setup
    TTSConfiguration *confTTS = [[TTSConfiguration alloc] init];
    [confTTS setApiURL:@"https://speech.tap.ibm.com/text-to-speech-beta/api"];
    [confTTS setBasicAuthUsername:@"ivaniapi"];
    [confTTS setBasicAuthPassword:@"Zt1xSp33x"];
    self.tts = [TextToSpeech initWithConfig:confTTS];
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction) pressStartRecord:(id) sender
{
    
    // list models calls
    [stt listModels:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            [self modelHandler:res];
        else
            result.text = [err localizedDescription];
    }];
    
    
    // start recognize
    [stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            result.text = [stt getTranscript:res];
        else
            result.text = [err localizedDescription];
    }];
   
    // get power readings until recording has finished
    [stt getPowerLevel:^(float power){
        
        CGRect frm = self.soundbar.frame;
        frm.size.width = 3*(70 + power);
        self.soundbar.frame = frm;
        self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, self.soundbar.center.y);
    }];
    
    
    
}

- (IBAction)pressTTStest:(id)sender {
    

    // list voices call
    [self.tts listVoices:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            NSLog(@"%@",res);
        else
            result.text = [err localizedDescription];
    }];
    
    [self.tts synthesize:^(NSData *data, NSError *err) {
    
        // play audio and log when playgin has finished
        [self.tts playAudio:^(NSError *err) {
            
            if(!err)
                NSLog(@"audio finished playing");
            else
                NSLog(@"error playing audio %@",err.localizedDescription);
            
        } withData:data];
        
    } theText:@"this is a test of the watson text to speech service"];
}

- (void) modelHandler:(NSDictionary *) dict {
    NSLog(@"modelHandler");
}


@end

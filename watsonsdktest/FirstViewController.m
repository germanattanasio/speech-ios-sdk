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
    
    [conf setApiURL:@"https://stream.watsonplatform.net/speech-to-text/api/"];
    [conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        NSURL *url = [[NSURL alloc] initWithString:@"https://speech-to-text-demo.mybluemix.net/token"];
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

    //[conf setModelName:@"ja-JP_BroadbandModel"];
    
    self.stt = [SpeechToText initWithConfig:conf];
    
    
    // TTS setup
    TTSConfiguration *confTTS = [[TTSConfiguration alloc] init];
        
    [confTTS setApiURL:@"https://stream.watsonplatform.net/text-to-speech/api/"];

    [confTTS setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        // there are no public token based service
        // this should return a valid token;
    }];

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
        
        if(err == nil) {
            
            
            if([self.stt isFinalTranscript:res]) { NSLog(@"this is the final transcript");}
            
            result.text = [stt getTranscript:res];
        } else {
            result.text = [err localizedDescription];
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

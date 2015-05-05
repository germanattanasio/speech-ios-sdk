//
//  FirstViewController.h
//  watsonSDKsample
//
//  Created by Rob Smart on 30/05/2013.
//  Copyright (c) 2013 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <watsonsdk/SpeechToText.h>
#import <watsonsdk/STTConfiguration.h>
#import <watsonsdk/TextToSpeech.h>
#import <watsonsdk/TTSConfiguration.h>

@interface FirstViewController : UIViewController<UITextFieldDelegate>

@property SpeechToText *stt;
@property TextToSpeech *tts;
@property IBOutlet UILabel *result;
@property IBOutlet UITextField *ttsField;
@property IBOutlet UIView *soundbar;

-(IBAction) pressStartRecord:(id) sender;


@end

//
//  FirstViewController.h
//  watsonSDKsample
//
//  Created by Rob Smart on 30/05/2013.
//  Copyright (c) 2013 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <watsonsdk/SpeechToText.h>

@interface FirstViewController : UIViewController<SpeechToTextDelegate, UITextFieldDelegate>{
    
    SpeechToText *stt;
}

@property (strong,retain) SpeechToText *stt;
@property (retain, nonatomic) IBOutlet UILabel *result;
@property (retain, nonatomic) IBOutlet UITextField *ttsField;
@property (retain, nonatomic) IBOutlet UIView *soundbar;

-(IBAction) pressStartRecord:(id) sender;
-(IBAction) pressStopRecord:(id) sender;


@end

//
//  STTViewController.h
//  watsonSDKsample
//
//  Created by Rob Smart on 30/05/2013.
//  Copyright (c) 2013 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <watsonsdk/SpeechToText.h>
#import <watsonsdk/STTConfiguration.h>

@interface STTViewController : UIViewController<UITextFieldDelegate,UIPickerViewDataSource, UIPickerViewDelegate>

@property SpeechToText *stt;
@property IBOutlet UILabel *result;
@property IBOutlet UIView *soundbar;
-(IBAction) pressStartRecord:(id) sender;


@end

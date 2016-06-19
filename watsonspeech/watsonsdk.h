//
//  WatsonSDK.h
//  WatsonSDK
//
//  Created by Ignacio on 6/13/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for WatsonSDK.
FOUNDATION_EXPORT double WatsonSDKVersionNumber;

//! Project version string for WatsonSDK.
FOUNDATION_EXPORT const unsigned char WatsonSDKVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <WatsonSDK/WatsonSDK.h>

//#import "OpusHelper.h"
//#import "OggHelper.h"
//#import "AuthConfiguration.h"
//#import "SpeechUtility.h"

#import "SpeechToText.h"
#import "STTConfiguration.h"

#import "TextToSpeech.h"
#import "TTSCustomWord.h"
#import "TTSCustomVoice.h"
#import "TTSConfiguration.h"

#import "WebSocketAudioStreamer.h"

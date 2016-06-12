//
//  TTSCustomVoice.h
//  watsonsdk
//
//  Created by Mihui on 5/23/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>
#define TTS_CUSTOM_VOICE_LANGUAGE_EN_US @"en-US"
#define TTS_CUSTOM_VOICE_LANGUAGE_DE_DE @"de-DE"
#define TTS_CUSTOM_VOICE_LANGUAGE_EN_GB @"en-GB"
#define TTS_CUSTOM_VOICE_LANGUAGE_ES_ES @"es-ES"
#define TTS_CUSTOM_VOICE_LANGUAGE_ES_US @"es-US"
#define TTS_CUSTOM_VOICE_LANGUAGE_FR_FR @"fr-FR"
#define TTS_CUSTOM_VOICE_LANGUAGE_IT_IT @"it-IT"
#define TTS_CUSTOM_VOICE_LANGUAGE_JA_JP @"ja-JP"
#define TTS_CUSTOM_VOICE_LANGUAGE_PT_BR @"pt-BR"

@interface TTSCustomVoice : NSObject
@property NSString* name;
@property NSString* language;
@property NSString* description;

@property NSArray* words;

-(NSData*)producePostData;

@end

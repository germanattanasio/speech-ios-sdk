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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SpeechUtility.h"
#import "OpusHelper.h"
#import "TTSConfiguration.h"
#import "TTSCustomVoice.h"
#import "TTSCustomWord.h"

@interface TextToSpeech : NSObject <NSURLSessionDelegate>

@property (nonatomic,retain) TTSConfiguration *config;

+ (id)initWithConfig:(TTSConfiguration *)config;
- (id)initWithConfig:(TTSConfiguration *)config;

- (void)synthesize:(void (^)(NSData*, NSError*)) synthesizeHandler theText:(NSString*) text;
- (void)synthesize:(void (^)(NSData*, NSError*)) synthesizeHandler theText:(NSString*) text customizationId:(NSString*) customizationId;

- (void)listVoices:(void (^)(NSDictionary*, NSError*))handler;
- (void)saveAudio:(NSData*) audio toFile:(NSString*) path;
- (void)playAudio:(void (^)(NSError*)) audioHandler  withData:(NSData *) audio;
- (void) playAudio:(void (^)(NSError*)) audioHandler withData:(NSData *) audio sampleRate:(long) rate;
- (void)stopAudio;

- (void)createVoiceModelWithCustomVoice: (TTSCustomVoice*) customVoice handler: (void (^)(NSDictionary*, NSError*)) customizationHandler;
- (void)addWord:(NSString *)customizationId word:(TTSCustomWord *)customWord handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)addWords:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)deleteWord:(NSString *)customizationId word:(NSString *) wordString handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)listWords:(NSString *)customizationId handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)listWord:(NSString *)customizationId word:(NSString *) wordString handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)updateVoiceModelWithCustomVoice:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)deleteVoiceModel:(NSString *)customizationId handler:(void (^)(NSDictionary *, NSError *))customizationHandler;
- (void)listCustomizedVoiceModels: (void (^)(NSDictionary*, NSError*)) handler;

- (void)queryPronunciation: (void (^)(NSDictionary*, NSError*)) handler text:(NSString*) theText;
- (void)queryPronunciation: (void (^)(NSDictionary*, NSError*)) handler text:(NSString*) theText voice: (NSString*) theVoice format: (NSString*) theFormat;
@end

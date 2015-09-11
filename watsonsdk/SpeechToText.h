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
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>
#import "STTConfiguration.h"
#import "OpusHelper.h"
#import "WebSocketUploader.h"

@interface SpeechToText : NSObject <NSURLSessionDelegate>


@property (nonatomic,retain) STTConfiguration *config;

+(id)initWithConfig:(STTConfiguration *)config;
-(id)initWithConfig:(STTConfiguration *)config;


/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler;

/**
 *  stopRecording and streaming audio from the device microphone
 *
 *  @return void
 */
- (void) endRecognize;


/**
 *  listModels - List speech models supported by the service
 *
 *  @param handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 */
- (void) listModels:(void (^)(NSDictionary*, NSError*))handler;


/**
 *  listModel details with a given model ID
 *
 *  @param handler handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 *  @param modelName the name of the model e.g. WatsonModel
 */
- (void) listModel:(void (^)(NSDictionary*, NSError*))handler withName:(NSString*) modelName;


/**
 *  setIsVADenabled
 *  User voice activated detection to automatically detect when speech has finished and stop the recognize operation
 *
 *  @param isEnabled true/false
 */
//- (void) setIsVADenabled:(bool) isEnabled;


/**
 *  getTranscript - convenience method to get the transcript from the JSON results
 *
 *  @param results NSDictionary containing parsed JSON returned from the service
 *
 *  @return NSString containing transcript
 */
-(NSString*) getTranscript:(NSDictionary*) results;


/**
 *  getConfidenceScore - convenience method to get the confidence score from the JSON results
 *
 *  @param results NSDictionary containing parsed JSON returned from the service
 *
 *  @return NSNumber containing score
 */
-(NSNumber*) getConfidenceScore:(NSDictionary*) results;


/**
 *  isFinalTranscript : convenience method to check the 'final' value in the dictionary and return
 *
 *  @param results NSDictionary
 *
 *  @return BOOL
 */
-(BOOL) isFinalTranscript:(NSDictionary*) results;

/**
 *  getPowerLevel - listen for updates to the Db level of the speaker, can be used for a voice wave visualization
 *
 *  @param powerHandler - callback block
 */
- (void) getPowerLevel:(void (^)(float)) powerHandler;

@end


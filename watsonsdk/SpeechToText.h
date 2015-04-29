/**
 * Copyright 2014 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>
#import <AVFoundation/AVAudioPlayer.h>
#import "watsonSpeexdec.h"
#import "watsonSpeexenc.h"

#import <string.h>
#import <stdio.h>
#import "HTTPStreamUploader.h"
#import "AudioUploader.h"
#import "WebSocketUploader.h"
#import "UploaderDelegate.h"

#define NUM_BUFFERS 3

// encoding types
#define COMPRESSION_TYPE_NONE @"PCM"
#define COMPRESSION_TYPE_SPEEX @"spx"
#define COMPRESSION_TYPE_OPUS @"opus"

#define STREAMING_TYPE_NONE @"none"
#define STREAMING_TYPE_HTTP @"http"
#define STREAMING_TYPE_WEBSOCKETS @"websockets"


typedef struct
{
    AudioStreamBasicDescription  dataFormat;
    AudioQueueRef                queue;
    AudioQueueBufferRef          buffers[NUM_BUFFERS];
    AudioFileID                  audioFile;
    SInt64                       currentPacket;
    bool                         recording;
    FILE*						 stream;
    int                          slot;
} RecordingState;



id uploaderRef;
id delegateRef;
id opusRef;

@interface SpeechToText : NSObject <AVAudioPlayerDelegate,AudioUploadFinishedDelegate,UploaderDelegate,NSURLSessionDelegate>{
    
@private
    NSString* callbackId;
    RecordingState recordState;
    NSString *recordRate;
    char path[256];
    char wavpath[256];
    char spxpath[256];
    
    HTTPStreamUploader* uploader;
    WebSocketUploader* wsuploader;
    AVAudioPlayer *player;
    
    NSString* pathPCM;
    NSString* pathSPX;
    
    BOOL useCompression;
    BOOL isCertificateValidationDisabled;
    
}

@property (nonatomic,retain) NSString* sessionCookie;
@property (nonatomic,retain) NSString* basicAuthPassword;
@property (nonatomic,retain) NSString* basicAuthUsername;
@property (nonatomic,retain) NSString* speechModel;
@property (retain) id delegate; // delegate for sending call back to calling class

+(id)initWithURL:(NSURL *)url;
-(id)initWithURL:(NSURL *)url;

/**
 *  startRecording and streaming audio from the device microphone
 *
 *  @return NSError - nil if no error
 */
- (NSError*) recognize;


/**
 *  stopRecording and streaming audio from the device microphone
 *
 *  @return NSError - nil if no error
 */
- (NSError*) endRecognize;


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
- (void) setIsVADenabled:(bool) isEnabled;


/**
 *  setCompressionType
 *
 *  @param compressionType <#compressionType description#>
 */
- (void) setCompressionType:(NSString *)compressionType;

@end

// need some callbacks that we can fire from the calling application
// delegate for responding to AudioUpload
@protocol SpeechToTextDelegate <NSObject>
@required

- (void) PartialTranscriptCallback:(NSString*) response;
- (void) TranscriptionFinishedCallback:(NSString*) response;
- (void) peakPowerCallback:(float) power;

@end

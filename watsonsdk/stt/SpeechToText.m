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

#import <SpeechToText.h>
#import "AuthConfigurationInternal.h"

// type defs for block callbacks
#define NUM_BUFFERS 3
typedef void (^RecognizeCallbackBlockType)(NSDictionary*, NSError*);
typedef void (^PowerLevelCallbackBlockType)(float);
typedef void (^AudioDataCallbackBlockType)(NSData*);

typedef struct
{
    AudioStreamBasicDescription  dataFormat;
    AudioQueueRef                queue;
    AudioQueueBufferRef          buffers[NUM_BUFFERS];
    AudioFileID                  audioFile;
    SInt64                       currentPacket;
    bool                         recording;
    int                          slot;
} RecordingState;


@interface SpeechToText()

@property NSString* pathPCM;
@property NSTimer *PeakPowerTimer;
@property OggHelper *ogg;
@property OpusHelper* opus;
@property RecordingState recordState;
@property WebSocketAudioStreamer* audioStreamer;
@property (nonatomic, copy) RecognizeCallbackBlockType recognizeCallback;
@property (nonatomic, copy) PowerLevelCallbackBlockType powerLevelCallback;

// For capturing data has been sent out
@property (nonatomic, copy) AudioDataCallbackBlockType audioDataCallback;

@end

@implementation SpeechToText

@synthesize recognizeCallback;
@synthesize powerLevelCallback;
@synthesize audioDataCallback;
@synthesize ogg = _ogg;


// static for use by c code
static BOOL isNewRecordingAllowed;
static BOOL isCompressedOpus;
static int audioRecordedLength;

id audioStreamerRef;
id opusRef;
id oggRef;

#pragma mark public methods

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithConfig:(STTConfiguration *)config {
    SpeechToText *watson = [[self alloc] initWithConfig:config] ;
    return watson;
}

/**
 *  init method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
- (id)initWithConfig:(STTConfiguration *)config {
    self = [super init];
    self.config = config;
    // set audio encoding flags so they are accessible in c audio callbacks
    isCompressedOpus = [config.audioCodec isEqualToString:WATSONSDK_AUDIO_CODEC_TYPE_OPUS] ? YES : NO;
    isNewRecordingAllowed = YES;

    // setup opus helper
    self.opus = [[OpusHelper alloc] init];
    [self.opus createEncoder: WATSONSDK_AUDIO_SAMPLE_RATE];
    opusRef = self->_opus;

    return self;
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler{
    [self recognize:recognizeHandler dataHandler:nil powerHandler:nil];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 *  @param powerHandler (void (^)(float))
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler dataHandler: (void (^)(NSData *)) dataHandler {
    [self recognize:recognizeHandler dataHandler:dataHandler powerHandler:nil];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 *  @param powerHandler (void (^)(float))
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler powerHandler: (void (^)(float)) powerHandler {
    [self recognize:recognizeHandler dataHandler:nil powerHandler:powerHandler];
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 *  @param dataHandler (void (^) (NSData*))
 *  @param powerHandler (void (^)(float))
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler dataHandler: (void (^) (NSData*)) dataHandler powerHandler: (void (^)(float)) powerHandler {
    self.recognizeCallback = recognizeHandler;
    self.audioDataCallback = dataHandler;
    self.powerLevelCallback = powerHandler;

    if (!isNewRecordingAllowed) {
        // don't allow a new recording to be allowed until this transaction has completed
        // NSError *recordError = [SpeechUtility raiseErrorWithMessage:@"A voice query is already in progress"];
        // self.recognizeCallback(nil, recordError);
        return;
    }
    isNewRecordingAllowed = NO;

    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        // iOS 7.x and above. Needs to ask permission
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                // Permission granted
                [self startRecordingAudio];
            } else {
                // Permission denied
                isNewRecordingAllowed = YES;
                NSError *recordError = [SpeechUtility raiseErrorWithMessage:@"Record permission denied"];
                self.recognizeCallback(nil, recordError);
            }
        }];
    } else {
        // iOS 6.x: Permission is always granted.
        [self startRecordingAudio];
    }
}

/**
 *  send out end marker of a stream
 *
 *  @return YES if the data has been sent directly; NO if the data is bufferred because the connection is not established
 */
-(BOOL) endTransmission {
    return [[self audioStreamer] sendEndOfStreamMarker];
}

/**
 *  Disconnect
 */
-(void) endConnection {
    [[self audioStreamer] disconnect:@"Manually terminating socket connection"];
}

/**
 *  stopRecording and streaming audio from the device microphone
 *
 *  @return void
 */
-(void) endRecognize{
    [self stopRecordingAudio];
    [self endTransmission];
}

/**
 *  listModels - List speech models supported by the service
 *
 *  @param handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 */
- (void) listModels:(void (^)(NSDictionary*, NSError*))handler {
    
    [self performGet:handler forURL:[self.config getModelsServiceURL]];
    
}

/**
 *  listModel details with a given model ID
 *
 *  @param handler handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 *  @param modelName the name of the model e.g. WatsonModel
 */
- (void) listModel:(void (^)(NSDictionary*, NSError*))handler withName:(NSString*) modelName {
    
    [self performGet:handler forURL:[self.config getModelServiceURL:modelName]];
    
}


/**
 *  getTranscript - convenience method to get the transcript from the JSON results
 *
 *  @param results NSDictionary containing parsed JSON returned from the service
 *
 *  @return NSString containing transcript
 */
-(NSString*) getTranscript:(NSDictionary*) results {
    
    if([results objectForKey:@"results"] != nil) {
        
        NSArray *resultArray = [results objectForKey:@"results"];
        if( [resultArray count] != 0 && [resultArray objectAtIndex:0] != nil) {
            NSDictionary *result =[resultArray objectAtIndex:0];
            NSArray *alternatives = [result objectForKey:@"alternatives"];
            if([alternatives objectAtIndex:0] != nil) {
                NSDictionary *alternative = [alternatives objectAtIndex:0];
                if([alternative objectForKey:@"transcript"] != nil) {
                    NSString *transcript = [alternative objectForKey:@"transcript"];
                    return transcript;
                }
            }
        }
    }
    return nil;
}

/**
 *  getConfidenceScore - convenience method to get the confidence score from the JSON results
 *
 *  @param results NSDictionary containing parsed JSON returned from the service
 *
 *  @return NSNumber containing score
 */
-(NSNumber*) getConfidenceScore:(NSDictionary*) results {
    
    if([results objectForKey:@"results"] != nil) {
        
        NSArray *resultArray = [results objectForKey:@"results"];
        if( [resultArray count] != 0 && [resultArray objectAtIndex:0] != nil) {
            
            NSDictionary *result =[resultArray objectAtIndex:0];
            
            NSArray *alternatives = [result objectForKey:@"alternatives"];
            
            if([alternatives objectAtIndex:0] != nil) {
                NSDictionary *alternative = [alternatives objectAtIndex:0];
                
                if([alternative objectForKey:@"confidence"] != nil) {
                    NSNumber *confidence = [alternative objectForKey:@"confidence"];
                    
                    return confidence;
                }
            }
        }
    }
    
    return nil;
}

/**
 *  isFinalTranscript : check the 'final' value in the dictionary and return
 *
 *  @param results NSDictionary
 *
 *  @return BOOL
 */
-(BOOL) isFinalTranscript:(NSDictionary*) results {
    
    if([results objectForKey:@"results"] != nil) {
        
        NSArray *resultArray = [results objectForKey:@"results"];
        if( [resultArray count] != 0 && [resultArray objectAtIndex:0] != nil) {
            
            NSDictionary *result =[resultArray objectAtIndex:0];
            
            BOOL isFinal = [[result objectForKey:@"final"] boolValue];
        
            return isFinal;
        }
    }
    
    return NO;
}

/**
 *  getPowerLevel - listen for updates to the Db level of the speaker, can be used for a voice wave visualization
 *
 *  @param powerHandler - callback block
 */
- (void) getPowerLevel:(void (^)(float)) powerHandler {
    self.powerLevelCallback = powerHandler;
}

#pragma mark private methods

/**
 *  performGet - shared method for performing GET requests to a given url calling a handler parameter with the result
 *
 *  @param handler (^)(NSDictionary*, NSError*))
 *  @param url     url to perform GET request on
 */
- (void) performGet:(void (^)(NSDictionary*, NSError*))handler forURL:(NSURL*)url {
    [self performGet:handler forURL:url disableCache:NO];
}

/**
 *  performGet
 *
 *  @param handler      callback of data / error
 *  @param url          URL
 *  @param withoutCache disable cache
 */
- (void) performGet:(void (^)(NSDictionary*, NSError*))handler forURL:(NSURL*)url disableCache:(BOOL) withoutCache {
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    if(withoutCache)
        [defaultConfigObject setURLCache:nil];
    
    [self.config requestToken:^(AuthConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [SpeechUtility processJSON:handler config:config response:response data:data error:error];
        }];
        
        [dataTask resume];
    }];
}


/**
 *  Start recording audio
 */
- (void) startRecordingAudio {
    // lets start the socket connection right away
    [self initializeStreaming];
    [self setupAudioFormat:&_recordState.dataFormat];
    
    _recordState.currentPacket = 0;
    audioRecordedLength = 0;
    
    OSStatus status = AudioQueueNewInput(&_recordState.dataFormat,
                                         AudioInputStreamingCallback,
                                         &_recordState,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &_recordState.queue);
    
    
    if(status == 0) {
        
        for(int i = 0; i < NUM_BUFFERS; i++) {
            
            AudioQueueAllocateBuffer(_recordState.queue, WATSONSDK_AUDIO_SAMPLE_RATE, &_recordState.buffers[i]);
            AudioQueueEnqueueBuffer(_recordState.queue, _recordState.buffers[i], 0, NULL);
        }

        _recordState.recording = true;
        status = AudioQueueStart(_recordState.queue, NULL);
        if (status == 0) {

            UInt32 enableMetering = 1;
            status = AudioQueueSetProperty(_recordState.queue, kAudioQueueProperty_EnableLevelMetering, &enableMetering, sizeof(enableMetering));

            // start peak power timer
            if(status == 0){
                self.PeakPowerTimer = [NSTimer scheduledTimerWithTimeInterval:0.125
                                                                       target:self
                                                                     selector:@selector(samplePeakPower)
                                                                     userInfo:nil
                                                                      repeats:YES];
            }
        }
    }
}

/**
 *  Stop recording
 */
- (void) stopRecordingAudio {
    if(isNewRecordingAllowed) {
        NSLog(@"### Record stopped ###");
        return;
    }
    NSLog(@"### Stopping recording ###");
    if(self.PeakPowerTimer)
        [self.PeakPowerTimer invalidate];

    self.PeakPowerTimer = nil;

    if(_recordState.queue != NULL){
        AudioQueueReset(_recordState.queue);
    }
    if(_recordState.queue != NULL){
        AudioQueueStop(_recordState.queue, YES);
    }
    if(_recordState.queue != NULL){
        AudioQueueDispose(_recordState.queue, YES);
    }
    isNewRecordingAllowed = YES;
}


/**
 *  samplePeakPower - Get the decibel level from the AudioQueue
 */
- (void) samplePeakPower {
    AudioQueueLevelMeterState meters[1];
    UInt32 dlen = sizeof(meters);
    OSErr Status = AudioQueueGetProperty(_recordState.queue,kAudioQueueProperty_CurrentLevelMeterDB,meters,&dlen);

    if (Status == 0) {
        if(self.powerLevelCallback != nil) {
            self.powerLevelCallback(meters[0].mAveragePower);
        }
    }
}



#pragma mark audio streaming

/**
 *  Initialize streaming
 */
- (void) initializeStreaming {

    // init the websocket streamer
    self.audioStreamer = [[WebSocketAudioStreamer alloc] init];
    [self.audioStreamer setRecognizeHandler:recognizeCallback];
    [self.audioStreamer setAudioDataHandler:audioDataCallback];

    // connect if we are not connected
    if(![self.audioStreamer isWebSocketConnected]) {
        [self.config requestToken:^(AuthConfiguration *config) {
            [self.audioStreamer connect:(STTConfiguration*)config
                                headers:[config createRequestHeadersWithXWatsonLearningOptOut]];
        }];
    }

    // Adding Ogg Header
    if(isCompressedOpus){
        // Adding Ogg instance
        // setup ogg helper
        self.ogg = [[OggHelper alloc] init];
        oggRef = self->_ogg;
        // Indicate sample rate
        [self.audioStreamer writeData:[[self ogg] getOggOpusHeader:WATSONSDK_AUDIO_SAMPLE_RATE]];
    }
    
    // set a pointer to the wsuploader class so it is accessible in the c callback
    audioStreamerRef = self.audioStreamer;
}

#pragma mark audio

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    format->mSampleRate = WATSONSDK_AUDIO_SAMPLE_RATE;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFramesPerPacket = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame = 2;
    format->mBytesPerPacket = 2;
    format->mBitsPerChannel = 16;
    format->mReserved = 0;
    format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}

int getAudioRecordedLengthInMs()
{
    return audioRecordedLength/32;
}

void sendAudioOpusEncoded(NSData *data)
{
    if (data!=nil && [data length]!=0) {
        
        NSUInteger length = [data length];
        NSUInteger chunkSize = WATSONSDK_AUDIO_FRAME_SIZE * 2;
        NSUInteger offset = 0;
        
        do {
            NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
            NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[data bytes] + offset
                                                 length:thisChunkSize
                                           freeWhenDone:NO];
            
            // opus encode block
            NSData *compressed = [opusRef encode:chunk frameSize:WATSONSDK_AUDIO_FRAME_SIZE];

            if(compressed != nil){
                NSMutableData *newData = [oggRef writePacket:compressed frameSize:WATSONSDK_AUDIO_FRAME_SIZE];
                if(newData != nil){
                    [audioStreamerRef writeData:newData];
                }
            }

            offset += thisChunkSize;
        } while (offset < length);
    }
}

#pragma mark audio callbacks

void AudioInputStreamingCallback(
                                 void *inUserData,
                                 AudioQueueRef inAQ,
                                 AudioQueueBufferRef inBuffer,
                                 const AudioTimeStamp *inStartTime,
                                 UInt32 inNumberPacketDescriptions,
                                 const AudioStreamPacketDescription *inPacketDescs)
{
    OSStatus status=0;
    RecordingState* recordState = (RecordingState*)inUserData;
    
    NSData *data = [NSData  dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    audioRecordedLength += [data length];

    if(isCompressedOpus)
        sendAudioOpusEncoded(data);
    else
        [audioStreamerRef writeData:data];

    if(status == 0) {
        recordState->currentPacket += inNumberPacketDescriptions;
    }
    AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
}

@end


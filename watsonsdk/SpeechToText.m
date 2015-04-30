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

#import <SpeechToText.h>
#import "AudioUploader.h"
#import "VadProcessor.h"
#import "OpusHelper.h"

// type defs for block callbacks
typedef void (^RecognizeCallbackBlockType)(NSDictionary*, NSError*);
typedef void (^PowerLevelCallbackBlockType)(float);

@interface SpeechToText()

@property(atomic,strong) OpusHelper* opus;
@property(atomic,strong) NSString* partialTranscript;
@property (nonatomic,copy)   NSString* callbackId;
@property (nonatomic,retain) NSString* pathPCM;
@property (nonatomic,retain) NSString* pathSPX;
@property (nonatomic,retain) NSError* error;
@property (strong,retain) NSTimer *PeakPowerTimer;
@property (nonatomic,strong) NSURL* speechServer;
@property (nonatomic,strong) NSString* compressionType;
@property (assign) BOOL isCertificateValidationDisabled;
@property (nonatomic,copy) RecognizeCallbackBlockType recognizeCallback;
@property (nonatomic,copy) PowerLevelCallbackBlockType powerLevelCallback;

@end

@implementation SpeechToText

@synthesize opus;
@synthesize partialTranscript;
@synthesize callbackId;
@synthesize pathPCM;
@synthesize pathSPX;
@synthesize speechServer;
@synthesize sessionCookie;
@synthesize basicAuthPassword;
@synthesize basicAuthUsername;
@synthesize speechModel;
@synthesize isCertificateValidationDisabled;
@synthesize delegate;
@synthesize PeakPowerTimer;
@synthesize error;
@synthesize recognizeCallback;
@synthesize powerLevelCallback;


static BOOL isCompressedOpus;
static BOOL isCompressedSpeex;
static BOOL isNewRecordingAllowed;

static NSString* tmpPCM=nil;
static NSString* tmpSPX;
static NSString* tmpOpus;
static long pageSeq;
static bool isTempPathSet = false;
static bool isVadEnabled = true;
static int errorCode = 0;
static int serialno;
static int audioRecordedLength;




BOOL hasError(){
    return errorCode!=0;
}


#pragma mark public methods

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithURL:(NSURL *)newURL {
    
    SpeechToText *watson = [[self alloc] initWithURL:newURL] ;
    isNewRecordingAllowed= YES;
    return watson;
}

/**
 *  init method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
- (id)initWithURL:(NSURL *)newURL {
    
    [self setSpeechServer:newURL];
    
    // set default values
    [self setCompressionType:COMPRESSION_TYPE_NONE];
    [self setSpeechModel:DEFAULT_SPEECH_MODEL];
    [self setIsCertificateValidationDisabled:NO];
    
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(didReceiveVadStopNotification:)
     name:NOTIFICATION_VAD_STOP_EVENT
     object:nil];
    
    isNewRecordingAllowed=YES;
    
    // TODO static bool as some of the c callbacks need to access it
    
    isCompressedOpus = NO;
    isCompressedSpeex = NO;
    
    // setup opus helper
    self.opus = [[OpusHelper alloc] init];
    [self.opus createEncoder];
    opusRef = self->opus;
    
    return self;
}

- (void) setCompressionType:(NSString *)compressionType {
    
    _compressionType = compressionType;
    
    if([self.compressionType isEqualToString:COMPRESSION_TYPE_SPEEX]) {
        isCompressedSpeex = YES;
    } else if([self.compressionType isEqualToString:COMPRESSION_TYPE_OPUS]) {
        isCompressedOpus = YES;
    }
}

/**
 *  stream audio from the device microphone to the STT service
 *
 *  @param recognizeHandler (^)(NSDictionary*, NSError*)
 */
- (void) recognize:(void (^)(NSDictionary*, NSError*)) recognizeHandler {
    
    // perform asset here
    
    // store the block
    self.recognizeCallback = recognizeHandler;
    
    if(!isNewRecordingAllowed)
    {
        NSLog(@"Transcription already in progress");
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"A voice query is already in progress" forKey:NSLocalizedDescriptionKey];
        
        // populate the error object with the details
        NSError *recordError = [NSError errorWithDomain:@"com.ibm.cio.watsonsdk" code:409 userInfo:details];
        self.recognizeCallback(nil,recordError);
        return;
    }
    
    // don't allow a new recording to be allowed until this transaction has completed
    isNewRecordingAllowed= NO;
    [self startRecordingAudio];
    
    
}

-(NSError*) endRecognize
{
    [self stopRecordingAudio];
    
    if (hasError()) {
        
        NSLog(@"An error occured during recording returning error to client");
        return self.error;
    }
    
    [wsuploader sendEndOfStreamMarker];
    
    isNewRecordingAllowed=YES;
    
    
    return nil;
    
    
    
}


/**
 *  listModels - List speech models supported by the service
 *
 *  @param handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 */
- (void) listModels:(void (^)(NSDictionary*, NSError*))handler {
     
    NSString *uriStr = [NSString stringWithFormat:@"https://%@%@",speechServer.host,SERVICE_PATH_MODELS];
    NSURL * url = [NSURL URLWithString:uriStr];
    
    [self performGet:handler forURL:url];
 
}

/**
 *  listModel details with a given model ID
 *
 *  @param handler handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 *  @param modelName the name of the model e.g. WatsonModel
 */
- (void) listModel:(void (^)(NSDictionary*, NSError*))handler withName:(NSString*) modelName {
    
    NSString *uriStr = [NSString stringWithFormat:@"https://%@%@/%@",speechServer.host,SERVICE_PATH_MODELS,modelName];
    NSURL * url = [NSURL URLWithString:uriStr];
    
    [self performGet:handler forURL:url];
    
}

/**
 *  setIsVADenabled
 *  User voice activated detection to automatically detect when speech has finished and stop the recognize operation
 *
 *  @param isEnabled true/false
 */
- (void) setIsVADenabled:(bool) isEnabled {
    
    isVadEnabled = isEnabled;
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
- (void) performGet:(void (^)(NSDictionary*, NSError*))handler forURL:(NSURL*)url{
    
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSDictionary* headers = [self createRequestHeaders];
    [defaultConfigObject setHTTPAdditionalHeaders:headers];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
   
    
    NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *reqError) {
        
        if(reqError == nil)
        {
            NSString * text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            NSLog(@"Data = %@",text);
            
            NSError *localError = nil;
            NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&localError];
            
            if (localError != nil) {
                handler(nil,localError);
            } else {
                handler(parsedObject,nil);
            }
            
            
        } else {
            handler(nil,reqError);
        }
        
    }];
    
    [dataTask resume];
    
}

- (void) startRecordingAudio {
    //  NSLog(@"PERF time from touchStart to initRecordControl:%f", (CACurrentMediaTime()-timeTmp));
    
    // lets start the socket connection right away
    [self initializeStreaming];
    
    audioRecordedLength = 0;
    
    NSLog(@"start recording, host=%@",self.speechServer.host);
    
    [self setFilePaths];
    
    [self setupAudioFormat:&recordState.dataFormat];
    
    recordState.currentPacket = 0;
    
    OSStatus status;
    
    status = AudioQueueNewInput(&recordState.dataFormat,
                                    AudioInputStreamingCallback,
                                    &recordState,
                                    CFRunLoopGetCurrent(),
                                    kCFRunLoopCommonModes,
                                    0,
                                    &recordState.queue);
    
    
    if(status == 0) {
        for(int i = 0; i < NUM_BUFFERS; i++) {
            AudioQueueAllocateBuffer(recordState.queue,
                                     16000.0, &recordState.buffers[i]);
            AudioQueueEnqueueBuffer(recordState.queue,
                                    recordState.buffers[i], 0, NULL);
        }
        
        recordState.stream=fopen([self.pathPCM UTF8String],"wb");
        
        //   double t4 = CACurrentMediaTime();
        
        BOOL openFileOk = (recordState.stream!=NULL);
        if(openFileOk) {
            recordState.recording = true;
            
            
            
            OSStatus rc = AudioQueueStart(recordState.queue, NULL);
            
            UInt32 enableMetering = 1;
            status = AudioQueueSetProperty(recordState.queue, kAudioQueueProperty_EnableLevelMetering, &enableMetering,sizeof(enableMetering));
            
        
            
            // start peak power timer
            PeakPowerTimer = [NSTimer scheduledTimerWithTimeInterval:0.125
                                                              target:self
                                                            selector:@selector(samplePeakPower)
                                                            userInfo:nil
                                                             repeats:YES];
            
            
            if (rc!=0) {
                NSLog(@"startPlaying AudioQueueStart returned %ld.", rc);
            }else{
                if(isVadEnabled){
                    recordState.slot = VadProcessor_allocate(320,16000);//
                }
            }
        }
    }
    
}



- (void) stopRecordingAudio {
    
    NSLog(@"stopRecordingAudio");
    
    [PeakPowerTimer invalidate];
    PeakPowerTimer = nil;
    [self setFilePaths];
    AudioQueueReset (recordState.queue);
    AudioQueueStop (recordState.queue, YES);
    AudioQueueDispose (recordState.queue, YES);
    fclose(recordState.stream);
    
    isNewRecordingAllowed = YES;
    NSLog(@"stopRecordingAudio->fclose done");
    
}


/**
 *  samplePeakPower - Get the decibel level from the AudioQueue
 */
- (void) samplePeakPower {
    
    AudioQueueLevelMeterState meters[1];
    UInt32 dlen = sizeof(meters);
    OSErr Status = AudioQueueGetProperty(recordState.queue,kAudioQueueProperty_CurrentLevelMeterDB,meters,&dlen);
    
    if (Status == 0) {
     
        if(self.powerLevelCallback !=nil) {
            self.powerLevelCallback(meters[0].mAveragePower);
        }
        
    }
}



#pragma mark audio upload
/**
 *  syncTranscript - perform a synchronous call to upload an audio file
 *
 *  @param filePath
 *  @param url
 *
 *  @return NSString
 */
- (NSString*) syncTranscript:(NSString*) filePath iTransUrl:(NSString*) url {
    
    
    NSString *result = nil;
    
    @try {
        NSData *response = [self post:url filePath:filePath];
        
    } @catch (NSException * e) {
        result = [NSString stringWithFormat:@"{'code':1, 'text':'%@'}", [e reason]];
    }
    
    
    return result;
}


// perform an HTTP POST call
-(NSData*)post:(NSString*)url filePath:(NSString*)filePath {
    
    
    // setup POST request
    NSURL* vmURL= [NSURL URLWithString:url ];
    NSMutableURLRequest* vmRequest=[NSMutableURLRequest requestWithURL:vmURL];
    NSData *postData= [[NSData alloc] initWithContentsOfFile:filePath] ;
    NSString *postLength=[NSString stringWithFormat: @"%d",[postData length]];
    
    [vmRequest setValue:@"binary/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [vmRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [vmRequest setHTTPMethod:@"POST"];
    [vmRequest setTimeoutInterval:30.0];
    [vmRequest setHTTPBody: postData];
    
    // iTrans is for some reason sending back a JSESSIONID cookie with immediate expiry -1, this is
    // causing worklight to request reauthentication when we call the faces adapter, as such we will ignore the returned cookies
    [vmRequest setHTTPShouldHandleCookies:NO];
    
    if(self.sessionCookie != nil)
    {
        [vmRequest setValue:self.sessionCookie forHTTPHeaderField:@"Cookie"];
    }
    
    NSLog(@"post length is %d posting to %@",[postData length],url);
    AudioUploader *connection = [[AudioUploader alloc]initWithRequest:vmRequest];
    
    // set the call back delegate to be
    [connection setDelegate:self];
    [connection setIsCertificateValidationDisabled:self.isCertificateValidationDisabled];
    [connection start];
    
    
    return NULL;
    
}

- (void) AudioUploadFinished:(NSMutableData*) responseData{
    
    
    NSString* result;
    
    result = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
    NSLog(@"transcript is %@",result);
    
    
    // allow the next voice query to happen
    isNewRecordingAllowed= YES;
   // [self.delegate TranscriptionFinishedCallback:[self getLastLine:result]];
}

-(NSString *) getLastLine:(NSString*)body {
    
    NSLog(@"line --> %@",body);
    
    // tokenize the body into lines so we can get the last one.
    NSArray *transcriptionItems = [body componentsSeparatedByString:@"0:"];
    
    for (id line in [transcriptionItems reverseObjectEnumerator])
    {
        return line;
    }
    return @"";
    
}

- (NSDictionary*) createRequestHeaders {
    
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    
    if(self.sessionCookie) {
        [headers setObject:self.sessionCookie forKey:@"Cookie"];
    }
    
    if(self.basicAuthPassword && self.basicAuthUsername) {
        NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.basicAuthUsername,self.basicAuthPassword];
        NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64Encoding]];
        [headers setObject:authValue forKey:@"Authorization"];
    }
    
    return headers;
    
}

- (void) initializeStreaming {
    NSLog(@"CALL STARTING STREAM 1050");
    
        // init the websocket uploader if its nil
        if(wsuploader == nil) {
            wsuploader = [[WebSocketUploader alloc] init];
            [wsuploader setRecognizeHandler:recognizeCallback];
        }
        
        
        // connect if we are not connected
        if(![wsuploader isWebSocketConnected]){
            [wsuploader connect:self.speechServer headers:[self createRequestHeaders]];
        }
    

    uploaderRef = self->wsuploader;
    delegateRef = self->delegate;
    
    
    //write spx header
    if ([self.compressionType isEqualToString:COMPRESSION_TYPE_SPEEX]) {
        NSLog(@"Will write header for spx stream");
        //gen serialno for spx compression
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                             NSUserDomainMask, YES);
        
        NSString* docDir = [paths objectAtIndex:0];
        NSString *spxHeaderFile = [NSString stringWithFormat:@"%@%@",docDir,@"/header.bin"];
        
        FILE *fo_tmp = fopen([spxHeaderFile UTF8String], "wb");
        headerToFile(fo_tmp, serialno, &pageSeq);
        fclose(fo_tmp);
        
        [uploaderRef writeData:[NSData dataWithContentsOfFile:spxHeaderFile]];
    }
    
}


-(void)didReceiveVadStopNotification:(NSNotification *)notification {
    
    NSLog(@"didReceiveVadStopNotification-> stopping recording");
    [self endRecognize];
    
}



#pragma mark audio

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    
    format->mSampleRate = 16000.0;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFramesPerPacket = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame = 2;
    format->mBytesPerPacket = 2;
    format->mBitsPerChannel = 16;
    format->mReserved = 0;
    format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}

int getAudioRecordedLengthInMs() {
    return audioRecordedLength/32;
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
    RecordingState* recordState = (RecordingState*)inUserData;
    if(!recordState->recording)
    {
        printf("Not recording, returning\n");
    }
    OSStatus status=0;
    
    NSData *data = [NSData  dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    audioRecordedLength += [data length];
    
    NSLog(@"write data about to be called %d bytes",[data length]);
    
    
    if (isCompressedSpeex) {
        if (data!=nil && [data length]!=0) {
            
            
            [SpeechToText setTmpFilePaths];
            
            //save to PCM from iData
            [data writeToFile:tmpPCM atomically:YES];
            pcmEnc([tmpPCM UTF8String],[tmpSPX UTF8String], 0, serialno, &pageSeq);
            NSData *compressed = [NSData dataWithContentsOfFile:tmpSPX];
            
            if (hasError()) {
                NSLog(@"Has error so will not call [uploaderRef writeData:compressed]");
            } else {
                [uploaderRef writeData:compressed];
            }
            
            
            
            
            
        }
    } else if(isCompressedOpus){
        if (data!=nil && [data length]!=0) {
            
            NSUInteger length = [data length];
            NSUInteger chunkSize = 160 * 2; // Frame Size * 2
            NSUInteger offset = 0;
            
            do {
                NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
                NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[data bytes] + offset
                                                     length:thisChunkSize
                                               freeWhenDone:NO];
                
                // opus encode block
                NSData *compressed = [opusRef encode:chunk];
                
                // write data to file for debug purposes
                [SpeechToText setTmpFilePaths];
                
                //save to PCM from iData
                [compressed writeToFile:tmpOpus atomically:YES];
                if(compressed !=nil)
                {
                    [uploaderRef writeData:compressed];
                }
                offset += thisChunkSize;
            } while (offset < length);
        }
    } else {
        
        
        if (hasError()) {
            NSLog(@"Has error so will not call [uploaderRef writeData:data]");
        } else {
            [uploaderRef writeData:data];
        }
    }
    
    
    if(fwrite(inBuffer->mAudioData, 1,inBuffer->mAudioDataByteSize, recordState->stream)<=0) {
        status=-1;
    }
    
    if(isVadEnabled){
        VadProcessor_preprocessChunk(recordState->slot,(BYTE*)inBuffer->mAudioData,inBuffer->mAudioDataByteSize);
        
        if(VadProcessor_isPausing() == 1)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_VAD_STOP_EVENT object:nil];
            if(status == 0) {
                recordState->currentPacket += inNumberPacketDescriptions;
            }
            
            AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
            
            NSLog(@"VAD Stop!");
            return;
        }
    }
    
    if(status == 0) {
        recordState->currentPacket += inNumberPacketDescriptions;
    }
    
    AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
}




#pragma mark result callbacks


-(void) streamResultCallback:(NSString*)result responseBytes:(uint8_t*)responseBytes responseBytesLen:(int)responseBytesLen {
    NSLog(@"Call streamResultCallback,responseBytesLen:%d\n", responseBytesLen);
    NSString* clientResult;
    
    if (responseBytesLen==0) {
        clientResult = [NSString stringWithFormat:@"{'code':0, 'text':'%@'}",@""];
        isNewRecordingAllowed=YES;
        //[self.delegate TranscriptionFinishedCallback:clientResult];
    } else {
        
        //    if(self.useVaniBackend)
        //    {
        //     clientResult = [self playTtsAndGetClient:responseBytes responseBytesLen:responseBytesLen];
        //    }
        //    else
        //   {
        //[self AudioUploadFinished:[[NSMutableData alloc] initWithBytes:responseBytes length:responseBytesLen]];
        //   }
        //[self.delegate TranscriptionFinishedCallback:result];
    }
    
    
    
    /*  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[clientResult retain]];
     [self writeJavascript:[pluginResult toSuccessCallbackString:self.callbackId]];*/
}


- (void) streamResultPartialCallback:(NSDictionary*)result {
    self.recognizeCallback(result,nil);
}



-(void) streamErrorCallback:(NSString*)errorMessage  error:(NSError*) theError{
    NSLog(@"RecorderPlugin -> streamErrorCallback %@",theError.localizedDescription);
    
    errorCode = theError.code;
    self.error = theError;
    
    NSLog(@"RecorderPlugin -> ending of streamErrorCallback");
    [self streamClosedCallback];
}

-(void) streamClosedCallback{
    NSLog(@"RecorderPlugin -> streamClosedCallback");
    
    isNewRecordingAllowed=YES;
    
}




#pragma mark utilities

+ (void) setTmpFilePaths{
    
    if (isTempPathSet) {
        return;
    }
    isTempPathSet = true;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    
    tmpPCM = [[NSString alloc]initWithFormat:@"%@%@",docDir,@"/tmp.pcm"];
    //tmpWAV = [[NSString alloc]initWithFormat:@"%@%@",docDir,@"/tmp.wav"];
    tmpSPX = [[NSString alloc]initWithFormat:@"%@%@",docDir,@"/tmp.spx"];
    tmpOpus = [[NSString alloc]initWithFormat:@"%@%@",docDir,@"/tmp.opus"];
    
}

- (void) setFilePaths{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    
    self.pathPCM = [NSString stringWithFormat:@"%@%@",docDir,@"/out.pcm"];
    self.pathSPX = [NSString stringWithFormat:@"%@%@",docDir,@"/out.spx"];
    
}


@end


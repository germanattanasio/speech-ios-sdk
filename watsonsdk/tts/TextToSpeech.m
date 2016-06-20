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

#import "TextToSpeech.h"

typedef void (^PlayAudioCallbackBlockType)(NSError*);

@interface TextToSpeech()<AVAudioPlayerDelegate>
@property OpusHelper* opus;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (nonatomic,copy) PlayAudioCallbackBlockType playAudioCallback;
@property (assign, nonatomic) long sampleRate;
@end


@implementation TextToSpeech
@synthesize audioPlayer;
@synthesize playAudioCallback;
@synthesize sampleRate;

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithConfig:(TTSConfiguration *)config {
    
    TextToSpeech *watson = [[self alloc] initWithConfig:config] ;
    watson.sampleRate = 0;
    return watson;
}

/**
 *  init method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
- (id)initWithConfig:(TTSConfiguration *)config {
    
    self.config = config;
    self.sampleRate = 0;
    // setup opus helper
    self.opus = [[OpusHelper alloc] init];
    
    return self;
}


- (void)synthesize:(void (^)(NSData*, NSError*)) synthesizeHandler theText:(NSString*) text {
    [self performDataGet:synthesizeHandler forURL:[self.config getSynthesizeURL:text]];
}

- (void)synthesize:(void (^)(NSData*, NSError*)) synthesizeHandler theText:(NSString*) text customizationId:(NSString*) customizationId {
    [self performDataGet:synthesizeHandler forURL:[self.config getSynthesizeURL:text customizationId:customizationId]];
}

/**
 *  listVoices - List voices supported by the service
 *
 *  @param handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 */
- (void)listVoices:(void (^)(NSDictionary*, NSError*))handler {
    [self performGet:handler forURL:[self.config getVoicesServiceURL]];
}

/**
 *  createVoiceModelWithCustomVoice - Creates a new empty custom voice model that is owned by the requesting user
 *
 *  @param customVoice          TTSCustomVoice*
 *  @param customizationHandler (^)(NSDictionary*, NSError*))
 */
- (void)createVoiceModelWithCustomVoice: (TTSCustomVoice*) customVoice handler: (void (^)(NSDictionary*, NSError*)) customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler:customizationHandler forURL:[self.config getCustomizationURL] data:postData];
}

- (void)listCustomizedVoiceModels: (void (^)(NSDictionary*, NSError*)) handler {
    [self performGet:handler forURL:[self.config getCustomizationURL]];
}

- (void)queryPronunciation: (void (^)(NSDictionary*, NSError*)) handler text:(NSString*) theText {
    [self performGet:handler forURL:[self.config getPronunciationURL: theText]];
}

- (void)queryPronunciation: (void (^)(NSDictionary*, NSError*)) handler text:(NSString*) theText voice: (NSString*) theVoice format: (NSString*) theFormat {
    [self performGet:handler forURL:[self.config getPronunciationURL: theText voice:theVoice format:theFormat]];
}

- (void)addWord:(NSString *)customizationId word:(TTSCustomWord *)customWord handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    NSData* postData = [customWord producePostData];
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [[customWord word] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_PUT handler:customizationHandler forURL: url data:postData];
}

- (void)addWords:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler:customizationHandler forURL:[self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words", customizationId]] data:postData];
}

- (void)deleteWord:(NSString *)customizationId word:(NSString *) wordString handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [wordString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_DELETE handler:customizationHandler forURL: url data:nil];
}

- (void)listWords:(NSString *)customizationId handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    [self performGet:customizationHandler forURL:[self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words", customizationId]] disableCache:YES];
}

- (void)listWord:(NSString *)customizationId word:(NSString *) wordString handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    NSURL *url = [self.config getCustomizationURL: [NSString stringWithFormat:@"%@/words/%@", customizationId, [wordString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    [self performRequest:HTTP_METHOD_GET handler:customizationHandler forURL: url data:nil];
}

- (void)updateVoiceModelWithCustomVoice:(NSString *)customizationId voice:(TTSCustomVoice *)customVoice handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    NSData* postData = [customVoice producePostData];
    [self performRequest:HTTP_METHOD_POST handler: customizationHandler forURL:[self.config getCustomizationURL: customizationId] data:postData];
}

- (void)deleteVoiceModel:(NSString *)customizationId handler:(void (^)(NSDictionary *, NSError *))customizationHandler {
    [self performRequest:HTTP_METHOD_DELETE handler: customizationHandler forURL:[self.config getCustomizationURL: customizationId] data:nil];
}

#pragma mark private methods

/**
 *  Play audio data
 *
 *  @param audioHandler Audio handler
 *  @param audio        Audio data
 *  @param rate         Sample rate
 */
- (void) playAudio:(void (^)(NSError*)) audioHandler withData:(NSData *) audio sampleRate:(long) rate {
    self.playAudioCallback = audioHandler;
    
    self.sampleRate = rate;

    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        NSError * err;

        audio = [self stripAndAddWavHeader:audio];
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err];

        if (!self.audioPlayer)
            self.playAudioCallback(err);
        else
            [self.audioPlayer play];
        
    } else if ([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS]) {
        NSError * err;

        // convert audio to PCM and add wav header
        audio = [self.opus opusToPCM:audio sampleRate:self.sampleRate];
        audio = [self addWavHeader:audio];
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio fileTypeHint:AVFileTypeWAVE error:&err];
        [self.audioPlayer setDelegate:self];
        if (!self.audioPlayer)
            self.playAudioCallback(err);
        else
            [self.audioPlayer play];
    }
}

/**
 *  Play audio data
 *
 *  @param audioHandler Audio handler
 *  @param audio        Audio data
 */
- (void) playAudio:(void (^)(NSError*)) audioHandler withData:(NSData *) audio {
    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV_SAMPLE_RATE;
    }
    else if ([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS]) {
        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS_SAMPLE_RATE;
    }
    [self playAudio:audioHandler withData:audio sampleRate: self.sampleRate];
}

- (void)stopAudio {
    [self.audioPlayer stop];
    [self.audioPlayer setDelegate:nil];
    self.audioPlayer = nil;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error {
    self.playAudioCallback(error);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
   self.playAudioCallback(nil);
}


- (NSMutableData *)addWavHeader:(NSData *)wavNoheader {
    
    int headerSize = 44;
    long totalAudioLen = [wavNoheader length];
    long totalDataLen = [wavNoheader length] + headerSize-8;
    long longSampleRate = (self.sampleRate == 0 ? 48000 : self.sampleRate);
    int channels = 1;
    long byteRate = 16 * 11025 * channels/8;

    Byte *header = (Byte*)malloc(44);
    header[0] = 'R';  // RIFF/WAVE header
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
    header[4] = (Byte) (totalDataLen & 0xff);
    header[5] = (Byte) ((totalDataLen >> 8) & 0xff);
    header[6] = (Byte) ((totalDataLen >> 16) & 0xff);
    header[7] = (Byte) ((totalDataLen >> 24) & 0xff);
    header[8] = 'W';
    header[9] = 'A';
    header[10] = 'V';
    header[11] = 'E';
    header[12] = 'f';  // 'fmt ' chunk
    header[13] = 'm';
    header[14] = 't';
    header[15] = ' ';
    header[16] = 16;  // 4 bytes: size of 'fmt ' chunk
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = 1;  // format = 1
    header[21] = 0;
    header[22] = (Byte) channels;
    header[23] = 0;
    header[24] = (Byte) (longSampleRate & 0xff);
    header[25] = (Byte) ((longSampleRate >> 8) & 0xff);
    header[26] = (Byte) ((longSampleRate >> 16) & 0xff);
    header[27] = (Byte) ((longSampleRate >> 24) & 0xff);
    header[28] = (Byte) (byteRate & 0xff);
    header[29] = (Byte) ((byteRate >> 8) & 0xff);
    header[30] = (Byte) ((byteRate >> 16) & 0xff);
    header[31] = (Byte) ((byteRate >> 24) & 0xff);
    header[32] = (Byte) (2 * 8 / 8);  // block align
    header[33] = 0;
    header[34] = 16;  // bits per sample
    header[35] = 0;
    header[36] = 'd';
    header[37] = 'a';
    header[38] = 't';
    header[39] = 'a';
    header[40] = (Byte) (totalAudioLen & 0xff);
    header[41] = (Byte) ((totalAudioLen >> 8) & 0xff);
    header[42] = (Byte) ((totalAudioLen >> 16) & 0xff);
    header[43] = (Byte) ((totalAudioLen >> 24) & 0xff);
    
    NSMutableData *newWavData = [NSMutableData dataWithBytes:header length:44];
    [newWavData appendBytes:[wavNoheader bytes] length:[wavNoheader length]];
    return newWavData;
}

/**
 *  stripAndAddWavHeader - removes the wav header and metadata from downloaded TTS wav file which does not contain file length
 *  iOS avaudioplayer will not play the wav without the correct headers so we must recreate them
 *
 *  @param wav NSData containing audio
 *
 *  @return NSData with corrected wav header
 */
-(NSData*) stripAndAddWavHeader:(NSData*) wav {
    
    int headerSize = 44;
    int metadataSize = 48;

    if(sampleRate == 0 && [wav length] > 28)
        [wav getBytes:&sampleRate range: NSMakeRange(24, 4)]; // Read wav sample rate from 24

    NSData *wavNoheader= [NSMutableData dataWithData:[wav subdataWithRange:NSMakeRange(headerSize+metadataSize, [wav length])]];
    
    NSMutableData *newWavData;
    newWavData = [self addWavHeader:wavNoheader];
    
    return newWavData;
    
    
    
}

-(void) saveAudio:(NSData*) audio toFile:(NSString*) path {
    
    [ audio writeToFile:path atomically:true];
}

/**
 *  performGet - shared method for performing GET requests to a given url calling a handler parameter with the result
 *
 *  @param handler (^)(NSDictionary*, NSError*))
 *  @param url     url to perform GET request on
 */
- (void) performGet:(void (^)(NSDictionary*, NSError*))handler forURL:(NSURL*)url {
    [self performGet:handler forURL:url disableCache:NO];
}
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
 *  performGet - shared method for performing GET requests to a given url calling a handler parameter with the result
 *
 *  @param handler (^)(NSDictionary*, NSError*))
 *  @param url     url to perform GET request on
 */
- (void) performDataGet:(void (^)(NSData*, NSError*))handler forURL:(NSURL*)url {
    [self performDataGet:handler forURL:url disableCache:NO];
}

- (void) performDataGet:(void (^)(NSData*, NSError*))handler forURL:(NSURL*)url disableCache:(BOOL) withoutCache {
    
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    if(withoutCache)
        [defaultConfigObject setURLCache:nil];
    
    [self.config requestToken:^(AuthConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [SpeechUtility processData:handler config:config response:response data:data error:error];
        }];

        [dataTask resume];
    }];
}

/**
 *  performPost - shared method for performing POST requests to a given url calling a handler parameter with the result
 *
 *  @param handler (^)(NSDictionary*, NSError*))
 *  @param url     url to perform GET request on
 */
- (void) performRequest: (NSString*) method handler: (void (^)(NSDictionary*, NSError*))customizationHandler forURL:(NSURL*)url data: (NSData*) postData {
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];

    [self.config requestToken:^(AuthConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod: method];

        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];

        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [SpeechUtility processJSON:customizationHandler config:config response:response data:data error:error];
        }];

        [dataTask resume];
    }];
}

@end

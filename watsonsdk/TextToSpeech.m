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
#import "OpusHelper.h"

typedef void (^PlayAudioCallbackBlockType)(NSError*);

@interface TextToSpeech()<AVAudioPlayerDelegate>
@property  (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property OpusHelper* opus;
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


- (void) synthesize:(void (^)(NSData*, NSError*)) synthesizeHandler theText:(NSString*) text {
    
    [self performDataGet:synthesizeHandler forURL:[self.config getSynthesizeURL:text]];
}

/**
 *  listVoices - List voices supported by the service
 *
 *  @param handler(NSDictionary*, NSError*) block to be called when response has been received from the service
 */
- (void) listVoices:(void (^)(NSDictionary*, NSError*))handler {
    
    [self performGet:handler forURL:[self.config getVoicesServiceURL]];
    
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
    
    [self.config requestToken:^(AuthConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
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
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    if ([((NSHTTPURLResponse*)response) statusCode] == 401) { // authentication error
                        [config invalidateToken];
                    }
                }
                handler(nil,reqError);
            }
            
        }];
        
        [dataTask resume];
    }];
}

/**
 *  Play audio data
 *
 *  @param audioHandler Audio handler
 *  @param audio        Audio data
 */
- (void) playAudio:(void (^)(NSError*)) audioHandler  withData:(NSData *) audio {
    
    self.playAudioCallback = audioHandler;
    
    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        NSError * err;
        
        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV_SAMPLE_RATE;

        audio = [self stripAndAddWavHeader:audio];
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err];

        if (!self.audioPlayer)
            self.playAudioCallback(err);
        else
            [self.audioPlayer play];
          
    } else if ([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS]) {
        NSError * err;

        self.sampleRate = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS_SAMPLE_RATE;

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
- (void) performDataGet:(void (^)(NSData*, NSError*))handler forURL:(NSURL*)url{
    
    // Create and set authentication headers
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    [self.config requestToken:^(AuthConfiguration *config) {
        NSDictionary* headers = [config createRequestHeaders];
        [defaultConfigObject setHTTPAdditionalHeaders:headers];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        
        
        NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *reqError) {
            
            if(reqError == nil)
            {
                handler(data,nil);
            } else {
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    if ([((NSHTTPURLResponse*)response) statusCode] == 401) { // authentication error
                        [config invalidateToken];
                    }
                }
                handler(nil,reqError);
            }
            
        }];
        
        [dataTask resume];
    }];
     
    
}


@end

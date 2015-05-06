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

#import "TextToSpeech.h"

@interface TextToSpeech()
@property  (strong, nonatomic) AVAudioPlayer *audioPlayer;

@end


@implementation TextToSpeech
@synthesize audioPlayer;

/**
 *  Static method to return a SpeechToText object given the service url
 *
 *  @param newURL the service url for the STT service
 *
 *  @return SpeechToText
 */
+(id)initWithConfig:(TTSConfiguration *)config {
    
    TextToSpeech *watson = [[self alloc] initWithConfig:config] ;
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

- (NSError*) playAudio:(NSData *) audio {
    
    if([self.config.audioCodec isEqualToString:WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV]){
        
        NSError * err;
        
        audio = [self stripAndAddWavHeader:audio];
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err];
        
        if (!self.audioPlayer)
            return err;
        else
            [self.audioPlayer play];
          
    }
    
    
    return nil;
    
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
    NSData *wavNoheader= [NSMutableData dataWithData:[wav subdataWithRange:NSMakeRange(headerSize+metadataSize, [wav length])]];
    
    long totalAudioLen = [wavNoheader length];
    long totalDataLen = [wavNoheader length] + headerSize;
    long longSampleRate = 48000;
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
    NSDictionary* headers = [self createRequestHeaders];
    [defaultConfigObject setHTTPAdditionalHeaders:headers];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
    
    
    NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *reqError) {
        
        if(reqError == nil)
        {
            handler(data,nil);
        
        } else {
            handler(nil,reqError);
        }
        
    }];
    
    [dataTask resume];
    
}


- (NSDictionary*) createRequestHeaders {
    
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    
    if(self.config.basicAuthPassword && self.config.basicAuthUsername) {
        NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.config.basicAuthUsername,self.config.basicAuthPassword];
        NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64Encoding]];
        [headers setObject:authValue forKey:@"Authorization"];
    }
    
    return headers;
    
}

@end

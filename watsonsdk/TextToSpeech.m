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
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:audio error:&err] ;
        //audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:@"/Users/robsmart/iostts.wav"]  error:&err] ;
        self.audioPlayer.delegate = self;
        
        if (!self.audioPlayer) {
            NSLog(@"Sound had error %@", [err localizedDescription]);
            return err;
        } else {
            [self.audioPlayer prepareToPlay];
            [self.audioPlayer play];
            
        }
    }
    
    
    return nil;
    
}

-(void) saveAudio:(NSData*) audio toFile:(NSString*) path {
    
    [ audio writeToFile:path atomically:true];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error {
    
    NSLog(@"error playing audio %@",error.localizedDescription);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {
    NSLog(@"finished playing");
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

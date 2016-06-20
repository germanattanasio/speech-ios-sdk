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

#import "STTConfiguration.h"

@implementation STTConfiguration

@synthesize apiURL = _apiURL;
@synthesize audioSampleRate = _audioSampleRate;
@synthesize audioFrameSize = _audioFrameSize;

- (id)init {
    self = [super init];
    
    // set default values
    [self setApiEndpoint:[NSURL URLWithString:WATSONSDK_DEFAULT_STT_API_ENDPOINT]];
    [self setModelName:WATSONSDK_DEFAULT_STT_MODEL];
    [self setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_PCM];
    [self setAudioSampleRate:WATSONSDK_AUDIO_SAMPLE_RATE];
    [self setAudioFrameSize:WATSONSDK_AUDIO_FRAME_SIZE];

    [self setInterimResults: NO];
    [self setContinuous: NO];
    [self setInactivityTimeout:[NSNumber numberWithInt:30]];

    return self;
}

/**
 *  setApiUrl - override setter so we can update the NSURL endpoint
 *
 *  @param apiURL
 */
- (void)setApiURL:(NSString *)apiURLStr {
    
    _apiURL = apiURLStr;
    [self setApiEndpoint:[NSURL URLWithString:apiURLStr]];
}

- (NSString*) apiURL {
    return _apiURL;
}


#pragma mark convenience methods for obtaining service URLs

- (NSURL*)getModelsServiceURL {
    NSString *uriStr = [NSString stringWithFormat:@"%@://%@%@%@", self.apiEndpoint.scheme, self.apiEndpoint.host, self.apiEndpoint.path, WATSONSDK_SERVICE_PATH_MODELS];
    NSURL * url = [NSURL URLWithString:uriStr];
    return url;
}

/**
 *  Service URL of loading model
 *
 *  @param modelName Model name
 *
 *  @return NSURL
 */
- (NSURL*)getModelServiceURL:(NSString*) modelName {
    NSString *uriStr = [NSString stringWithFormat:@"%@://%@%@%@/%@",self.apiEndpoint.scheme,self.apiEndpoint.host,self.apiEndpoint.path,WATSONSDK_SERVICE_PATH_MODELS,modelName];
    NSURL * url = [NSURL URLWithString:uriStr];
    return url;
}

/**
 *  WebSockets URL of Speech Recognition
 *
 *  @return NSURL
 */
- (NSURL*)getWebSocketRecognizeURL {
    NSMutableString *uriStr = [[NSMutableString alloc] init];

    [uriStr appendFormat:@"%@%@%@%@%@", WEBSOCKETS_SCHEME, self.apiEndpoint.host, self.apiEndpoint.path, WATSONSDK_SERVICE_PATH_v1, WATSONSDK_SERVICE_PATH_RECOGNIZE];

    if(![self.modelName isEqualToString:WATSONSDK_DEFAULT_STT_MODEL]) {
        [uriStr appendFormat:@"?model=%@", self.modelName];
    }
    NSURL * url = [NSURL URLWithString:uriStr];
    return url;
}

/**
 *  Organize JSON string for start message of WebSockets
 *
 *  @return JSON string
 */
- (NSString *)getStartMessage {
    NSString *jsonString = @"";

    NSMutableDictionary *inputParameters = [[NSMutableDictionary alloc] init];
    [inputParameters setValue:@"start" forKey:@"action"];
    [inputParameters setValue:self.audioCodec forKey:@"content-type"];
    [inputParameters setValue:[NSNumber numberWithBool:self.interimResults] forKey:@"interim_results"];
    [inputParameters setValue:[NSNumber numberWithBool:self.continuous] forKey:@"continuous"];
    [inputParameters setValue:self.inactivityTimeout forKey:@"inactivity_timeout"];

    if([NSJSONSerialization isValidJSONObject:inputParameters]){
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:inputParameters options:NSJSONWritingPrettyPrinted error:&error];
        if(error == nil)
            jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

- (NSData *)getStopMessage {
    NSData *data = nil;
    data = [NSMutableData dataWithLength:0];
    // JSON format somehow does not work in this case
//    NSMutableDictionary *inputParameters = [[NSMutableDictionary alloc] init];
//    [inputParameters setValue:@"stop" forKey:@"action"];
//
//    if([NSJSONSerialization isValidJSONObject:inputParameters]){
//        NSError *error = nil;
//        data = [NSJSONSerialization dataWithJSONObject:inputParameters options:NSJSONWritingPrettyPrinted error:&error];
//    }

//    if(data == nil) {
//        data = [NSMutableData dataWithLength:0];
//    }

    return data;
}

@end

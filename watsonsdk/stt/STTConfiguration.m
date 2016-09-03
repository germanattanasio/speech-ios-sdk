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

- (id)init {
    self = [super init];
    
    // set default values
    [self setApiEndpoint:[NSURL URLWithString:WATSONSDK_DEFAULT_STT_API_ENDPOINT]];
    [self setModelName:WATSONSDK_DEFAULT_STT_MODEL];
    [self setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_PCM];

    [self setInterimResults: [NSNumber numberWithBool:YES]];
    [self setContinuous:[NSNumber numberWithBool:NO]];
    [self setInactivityTimeout:[NSNumber numberWithInt:WATSONSDK_INACTIVITY_TIMEOUT]];

    [self setKeywordsThreshold:[NSNumber numberWithDouble:-1]];
    [self setMaxAlternatives:[NSNumber numberWithInt:1]];
    [self setWordAlternativesThreshold:[NSNumber numberWithDouble:-1]];
    [self setKeywords:nil];
    [self setProfanityFilter:YES];
    [self setSmartFormatting:NO];
    [self setTimestamps:NO];
    [self setWordConfidence:NO];

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
- (NSString *)getStartMessage{
    NSString *jsonString = @"";

    NSMutableDictionary *inputParameters = [[NSMutableDictionary alloc] init];
    [inputParameters setValue:@"start" forKey:@"action"];
    [inputParameters setValue:self.audioCodec forKey:@"content-type"];
    if (self.interimResults) {
        [inputParameters setValue:[NSNumber numberWithBool:YES] forKey:@"interim_results"];
    }
    if ([self.inactivityTimeout intValue] != WATSONSDK_INACTIVITY_TIMEOUT) {
        [inputParameters setValue:self.inactivityTimeout forKey:@"inactivity_timeout"];
    }
    if (self.continuous) {
        [inputParameters setValue:[NSNumber numberWithBool:YES] forKey:@"continuous"];
    }
    if ([self.maxAlternatives intValue] > 1) {
        [inputParameters setValue:self.maxAlternatives forKey:@"max_alternatives"];
    }
    if ([self.keywordsThreshold doubleValue] >= 0 && [self.keywordsThreshold doubleValue] <= 1) {
        [inputParameters setValue:self.keywordsThreshold forKey:@"keywords_threshold"];
    }
    if ([self.wordAlternativesThreshold doubleValue] >= 0 && [self.wordAlternativesThreshold doubleValue] <= 1) {
        [inputParameters setValue:self.wordAlternativesThreshold forKey:@"word_alternatives_threshold"];
    }
    if (self.keywords && [self.keywords count] > 0) {
        [inputParameters setValue:self.keywords forKey:@"keywords"];
    }
    if (self.smartFormatting) {
        [inputParameters setValue:[NSNumber numberWithBool:YES] forKey:@"smart_formatting"];
    }
    if (self.timestamps) {
        [inputParameters setValue:[NSNumber numberWithBool:YES] forKey:@"timestamps"];
    }
    if (self.profanityFilter == NO) {
        [inputParameters setValue:[NSNumber numberWithBool:NO] forKey:@"profanity_filter"];
    }
    if (self.wordConfidence) {
        [inputParameters setValue:[NSNumber numberWithBool:YES] forKey:@"word_confidence"];
    }
    NSError *error = nil;
    if([NSJSONSerialization isValidJSONObject:inputParameters]){
        NSData *data = [NSJSONSerialization dataWithJSONObject:inputParameters options:NSJSONWritingPrettyPrinted error:&error];
        if(error == nil)
            jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

@end

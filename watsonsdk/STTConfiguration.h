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

// URLS
#define WATSONSDK_DEFAULT_STT_API_ENDPOINT @"https://stream.watsonplatform.net/speech-to-text-beta/api"
#define WATSONSDK_SERVICE_PATH_MODELS @"/v1/models"
#define WATSONSDK_SERVICE_PATH_RECOGNIZE @"/recognize"
#define WEBSOCKETS_SCHEME @"wss://"


// codecs
#define WATSONSDK_AUDIO_CODEC_TYPE_PCM @"audio/l16; rate=16000"
#define WATSONSDK_AUDIO_CODEC_TYPE_SPEEX @"audio/speex; rate=16000"
#define WATSONSDK_AUDIO_CODEC_TYPE_OPUS @"audio/ogg; codecs=opus; rate=16000"

// models
#define WATSONSDK_DEFAULT_STT_MODEL @"WatsonModel"

@interface STTConfiguration : NSObject

@property NSString* apiURL;
@property NSString* basicAuthUsername;
@property NSString* basicAuthPassword;
@property NSString* modelName;
@property NSString* audioCodec;
@property NSURL* apiEndpoint;
@property BOOL isCertificateValidationDisabled;


- (id)init;
- (NSURL*) getModelsServiceURL;
- (NSURL*) getModelServiceURL:(NSString*) modelName;
- (NSURL*) getWebSocketRecognizeURL;


@end

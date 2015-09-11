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

#import <Foundation/Foundation.h>
#import "AuthConfiguration.h"

// URLS
#define WATSONSDK_DEFAULT_TTS_API_ENDPOINT @"https://stream.watsonplatform.net/text-to-speech/api/"
#define WATSONSDK_SERVICE_PATH_VOICES @"/v1/voices"
#define WATSONSDK_SERVICE_PATH_SYNTHESIZE @"/v1/synthesize"

// codecs
#define WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS @"audio/opus"//; codecs=opus"
#define WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS_SAMPLE_RATE 48000   // zero means decoder detected sample rate

#define WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV @"audio/wav"
#define WATSONSDK_TTS_AUDIO_CODEC_TYPE_WAV_SAMPLE_RATE 0    // zero means reading the sample rate from wav data

// voices
#define WATSONSDK_DEFAULT_TTS_VOICE @"en-US_MichaelVoice"


@interface TTSConfiguration : AuthConfiguration

@property NSString* apiURL;
@property NSString* voiceName;
@property NSString* audioCodec;
@property NSURL* apiEndpoint;
@property BOOL isCertificateValidationDisabled;

- (id)init;
- (NSURL*) getVoicesServiceURL;
- (NSURL*) getSynthesizeURL:(NSString*) text;

@end

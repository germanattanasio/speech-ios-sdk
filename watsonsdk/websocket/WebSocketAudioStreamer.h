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
#import "STTConfiguration.h"
#import "SocketRocket.h"
#import "SpeechUtility.h"

@interface WebSocketAudioStreamer : NSObject

- (BOOL) isWebSocketConnected;
- (void) connect:(STTConfiguration*)config headers:(NSDictionary*)headers completionCallback:(void (^)(NSInteger, NSString*)) closureCallback;
- (void) reconnect;
- (void) disconnect: (NSString*) reason;
- (void) writeData:(NSData*) data;
- (void) setRecognizeHandler:(void (^)(NSDictionary*, NSError*))handler;
- (void) setAudioDataHandler:(void (^)(NSData*))handler;
- (void) sendEndOfStreamMarker;


@end


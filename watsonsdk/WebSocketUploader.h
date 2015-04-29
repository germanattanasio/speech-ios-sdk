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
#import "UploaderDelegate.h"

@interface WebSocketUploader : NSObject {
    id resultDelegate;
}

@property NSURL *speechServer;
@property NSDictionary *headers;

- (BOOL) isWebSocketConnected;
- (void) connect:(NSURL*)speechServer headers:(NSDictionary*)headers;
- (void) reconnect;
- (void) disconnect;
- (void) writeData:(NSData*) data;
- (void) setResultDelegate:(id) delegate;
- (void) sendEndOfStreamMarker;

@end


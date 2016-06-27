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

#import "WebSocketAudioStreamer.h"

typedef void (^RecognizeCallbackBlockType)(NSDictionary*, NSError*);
typedef void (^AudioDataCallbackBlockType)(NSData*);

@interface WebSocketAudioStreamer () <SRWebSocketDelegate>

@property NSDictionary *headers;
@property (strong, atomic) NSMutableData *audioBuffer;
@property (strong, atomic) NSNumber *reconnectAttempts;
@property (nonatomic, copy) RecognizeCallbackBlockType recognizeCallback;
@property (nonatomic, copy) AudioDataCallbackBlockType audioDataCallback;

@property STTConfiguration *sConfig;
@property SRWebSocket *webSocket;
@property BOOL isConnected;
@property BOOL isReadyForAudio;
@property BOOL isReadyForClosure;
@property BOOL hasDataBeenSent;

@end

@implementation WebSocketAudioStreamer
/**
 *  connect to an itrans server using websockets
 *
 *  @param speechServer   NSUrl containing the ws or wss format websocket service URI
 *  @param cookie pass a full cookie string that may have been returned in a separate authentication step
 */
- (void) connect:(STTConfiguration*)config headers:(NSDictionary*)headers  {
    self.sConfig = config;
    self.headers = headers;
    
    self.isConnected = NO;
    self.isReadyForAudio = NO;
    self.isReadyForClosure = NO;
    self.hasDataBeenSent = NO;
   
    NSLog(@"websocket connection using %@",[[self.sConfig getWebSocketRecognizeURL] absoluteString]);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self.sConfig getWebSocketRecognizeURL]];
    
    // set headers
    for(id headerName in headers) {
        [req setValue:[headers objectForKey:headerName] forHTTPHeaderField:headerName];
    }

    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:req];
    self.webSocket.delegate = self;
    [self.webSocket open];
    self.audioBuffer = [[NSMutableData alloc] initWithCapacity:0];
}

/**
 *  if the socket server is connected
 *
 *  @return BOOL
 */
- (BOOL)isWebSocketConnected {
    return self.isConnected;
}

/**
 *  reconnect with server
 */
- (void)reconnect {
    if(self.reconnectAttempts ==nil) {
        self.reconnectAttempts = [NSNumber numberWithInt:0];
    }
    
    [self connect:self.sConfig headers:self.headers];
}

/**
 *  send out end marker of a stream
 *
 *  @return YES if the data has been sent directly; NO if the data is bufferred because the connection is not established
 */
- (void)sendEndOfStreamMarker {
//    if(self.sConfig.continuous == NO){
//        return;
//    }
    [self _writeData:[self.sConfig getStopMessage] isFooter:YES];

//    NSError *error = [SpeechUtility raiseErrorWithCode:1011];
//    [self webSocket:[self webSocket] didFailWithError:error];
}

/**
 *  Disconnect with server
 *
 *  @param reason reason for disconnection
 */
- (void)disconnect:(NSString*) reason {
    if(self.isConnected || [self.webSocket readyState] != SR_CLOSED || [self.webSocket readyState] != SR_CLOSING){
        self.isReadyForAudio = NO;
        self.isConnected = NO;
        self.isReadyForClosure = NO;
        [self.webSocket closeWithCode:SRStatusCodeNormal reason: reason];
    }
}
dispatch_once_t predicate_wait;
dispatch_once_t predicate_connect;

/**
 *  Send out data, buffer as needed
 *
 *  @param data the data will be sent out
 */
- (void)writeData:(NSData*) data {
    [self _writeData:data isFooter:NO];
}
/**
 *  Send out data, buffer as needed
 *
 *  @param data the data will be sent out
 */
- (void)_writeData:(NSData*) data isFooter:(BOOL) isFooter{
    if(self.isConnected && self.isReadyForAudio) {
        // if we had previously buffered audio because we were not connected, send it now
        if([self.audioBuffer length] > 0) {
            NSLog(@"Sending buffered audio %lu bytes", (unsigned long) [self.audioBuffer length]);
            [self.webSocket sendData:self.audioBuffer];
            // reset buffer
            [self.audioBuffer setData:[NSData dataWithBytes:NULL length:0]];
        }
        else{
            predicate_wait = 0;
//            NSLog(@"sending realtime audio %lu bytes", (unsigned long)[data length]);
        }
        if(self.isReadyForClosure) {
            return;
        }
        [self.webSocket sendData:data];

        self.hasDataBeenSent = YES;
    }
    else {
        // we need to buffer this data and send it when we connect
        if(self.isConnected){
            predicate_connect = 0;
            dispatch_once(&predicate_wait, ^{
                NSLog(@"Buffering data and wait for 1st response (%u)", isFooter);
            });
        }
        else{
            dispatch_once(&predicate_connect, ^{
                NSLog(@"Buffering data and establishing connection (%u)", isFooter);
            });
        }
        
        if(self.isReadyForClosure) {
            
        }
        else {
            [self.audioBuffer appendData:data];
        }
    }
    if(isFooter) {
        self.isReadyForClosure = YES;
    }
    if(self.audioDataCallback != nil && isFooter == NO)
        self.audioDataCallback(data);
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected");
    self.isConnected = YES;
    self.hasDataBeenSent = NO;
    [self.webSocket sendString: [self.sConfig getStartMessage]];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);
    self.webSocket.delegate = nil;
    self.isConnected = NO;
    self.isReadyForAudio = NO;
    self.isReadyForClosure = NO;
    self.webSocket = nil;
    self.recognizeCallback(nil, error);

//    if ([self.reconnectAttempts intValue] < 3) {
//        self.reconnectAttempts = [NSNumber numberWithInt:[self.reconnectAttempts intValue] +1] ;
//        NSLog(@"trying to reconnect");
//        // try and open the socket again.
//        [self reconnect];
//    } else {
//        // call the recognize handler block in the clients code
//        self.recognizeCallback(nil, error);
//    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)json;
{
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    // this should be JSON parse it but check for errors
    
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];

    if(error) {
        /* JSON was malformed, act appropriately here */
        NSLog(@"JSON from service malformed, received %@", json);
        self.recognizeCallback(nil,error);
    }

    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        // look for state changes
        if([results objectForKey:@"state"] != nil) {
            NSString *state = [results objectForKey:@"state"];
            
            if([state isEqualToString:@"listening"]) {
                
                if(self.isReadyForAudio && (self.isReadyForClosure || self.sConfig.continuous == NO)) {
                    // if we receive a listening state after having sent audio it means we can now close the connection
                    [self disconnect: @"Watson completed transcribing or closure data has been written"];
                }
                else {
                    self.isReadyForAudio = YES;
                }

                NSLog(@"Watson is listening, isReadyForAudio=%u, isReadyForClosure=%u", self.isReadyForAudio, self.isReadyForClosure);
            }
        }

        if([results objectForKey:@"results"] != nil) {
            NSArray *resultsArr = [results objectForKey:@"results"];
            if([resultsArr count] > 0) {
                self.recognizeCallback(results, nil);
            }
        }

        if([results objectForKey:@"error"] != nil) {
            NSString *errorMessage = [results objectForKey:@"error"];
            NSError *error = [SpeechUtility raiseErrorWithMessage:errorMessage];
            self.recognizeCallback(nil, error);
            [self disconnect: errorMessage];
        }
    }
    else {
        // we should have had a dictionary object so this is an error
        NSLog(@"Didn't receive a dictionary json object, closing down");
        [self disconnect: @"Didn't receive a dictionary json object, closing down"];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"WebSocket closed with reason[%d]: %@", [[NSNumber numberWithInteger:code] intValue], reason);
    // sometimes the socket can close immediately before data has been sent
    if(self.hasDataBeenSent == NO){
        NSString *errorMessage = @"Websocket closed before data could be sent";
        NSError *error = [SpeechUtility raiseErrorWithCode:code message:errorMessage reason:reason suggestion:@"Try reconnecting"];
        [self webSocket:webSocket didFailWithError:error];
        return;
    }

    NSString *errorMessage = [SpeechUtility findUnexpectedErrorWithCode: code];

    if(errorMessage != nil){
        NSError *error = [SpeechUtility raiseErrorWithCode:code message:errorMessage reason:reason suggestion:@"Try reconnecting"];

        [self webSocket:webSocket didFailWithError:error];
        return;
    }

    self.webSocket.delegate = nil;
    self.isConnected = NO;
    self.isReadyForAudio = NO;
    self.isReadyForClosure = NO;
    self.webSocket = nil;
    self.reconnectAttempts = 0;
    if (code == 1006) { // authentication error
        [self.sConfig invalidateToken];
    }
    self.recognizeCallback(nil, nil);
}

#pragma mark - delegate

/**
 *  setRecognizeHandler - store the handler from the client so we can pass back results and errors
 *
 *  @param handler (void (^)(NSDictionary*, NSError*))
 */
- (void) setRecognizeHandler:(void (^)(NSDictionary*, NSError*))handler {
    self.recognizeCallback = handler;
}

/**
 *  setAudioDataHandler - store the handler from the client so we can pass back results and errors
 *
 *  @param handler (void (^)(NSDictionary*, NSError*))
 */
- (void) setAudioDataHandler:(void (^)(NSData*))handler {
    self.audioDataCallback = handler;
}

@end

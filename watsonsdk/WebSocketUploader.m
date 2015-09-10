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

#import "WebSocketUploader.h"
#import "SRWebSocket.h"


typedef void (^RecognizeCallbackBlockType)(NSDictionary*, NSError*);

@interface WebSocketUploader () <SRWebSocketDelegate>

@property NSDictionary *headers;
@property (strong,atomic) NSMutableData *audioBuffer;
@property (strong,atomic) NSNumber *reconnectAttempts;
@property (nonatomic,copy) RecognizeCallbackBlockType recognizeCallback;
@property STTConfiguration *conf;
@property SRWebSocket *webSocket;
@property BOOL isConnected;
@property BOOL isReadyForAudio;
@property BOOL hasDataBeenSent;

@end

@implementation WebSocketUploader

/**
 *  connect to an itrans server using websockets
 *
 *  @param speechServer   NSUrl containing the ws or wss format websocket service URI
 *  @param cookie pass a full cookie string that may have been returned in a separate authentication step
 */
- (void) connect:(STTConfiguration*)config headers:(NSDictionary*)headers  {
    
    self.conf = config;
    self.headers = headers;
    
    self.isConnected = NO;
    self.isReadyForAudio = NO;
   
    NSLog(@"websocket connection using %@",[[self.conf getWebSocketRecognizeURL] absoluteString]);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self.conf getWebSocketRecognizeURL]];
    
    // set headers
    for(id headerName in headers) {
        [req setValue:[headers objectForKey:headerName] forHTTPHeaderField:headerName];
    }
    
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:req];
    self.webSocket.delegate = self;
    [self.webSocket open];
    self.audioBuffer = [[NSMutableData alloc] initWithCapacity:0];
}

- (BOOL) isWebSocketConnected {
    
    return self.isConnected;
}

- (void) reconnect {
    
    if(self.reconnectAttempts ==nil) {
        self.reconnectAttempts = [NSNumber numberWithInt:0];
    }
    
    [self connect:self.conf headers:self.headers];
}

- (void) endSession {
    
    if([self isWebSocketConnected]) {
        [self.webSocket send:@"{\"name\":\"unready\"}"];
    } else {
        NSLog(@"tried to end Session but websocket was already closed");
    }
    
    
}

- (void) sendEndOfStreamMarker {
    
     if(self.isConnected && self.isReadyForAudio) {
         NSLog(@"sending end of stream marker");
         [self.webSocket send:[[NSMutableData alloc] initWithLength:0]];
         self.isReadyForAudio = NO;
     }
}

- (void) disconnect {
    
    self.isReadyForAudio = NO;
    self.isConnected = NO;
    [self.webSocket close];
    
}

- (void) writeData:(NSData*) data {
    if(self.isConnected && self.isReadyForAudio) {
        
        // if we had previously buffered audio because we were not connected, send it now
        if([self.audioBuffer length] > 0) {
            NSLog(@"sending buffered audio");
            [self.webSocket send:self.audioBuffer];
            
            //reset buffer
            [self.audioBuffer setData:[NSData dataWithBytes:NULL length:0]];
        }
        [self.webSocket send:data];
        self.hasDataBeenSent=YES;
    } else {
        // we need to buffer this data and send it when we connect
        NSLog(@"WebSocketUploader - data written but we're not connected yet");

        [self.audioBuffer appendData:data];
    }
    
}


#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected");
    self.isConnected = YES;
    self.hasDataBeenSent=NO;
    [self.webSocket send:[self buildQueryJson]];
}

- (NSString *) buildQueryJson
{
    NSString *json = [NSString stringWithFormat:@"{\"action\":\"start\",\"content-type\":\"%@\",\"interim_results\":true,\"continuous\": true}",self.conf.audioCodec];
    return json;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);
    self.webSocket = nil;
    
    if ([self.reconnectAttempts intValue] < 3) {
        self.reconnectAttempts = [NSNumber numberWithInt:[self.reconnectAttempts intValue] +1] ;
        NSLog(@"trying to reconnect");
        // try and open the socket again.
        [self reconnect];
    } else {
        
        // call the recognize handler block in the clients code
        self.recognizeCallback(nil,error);
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)json;
{
    
    NSLog(@"received --> %@",json);
    
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    // this should be JSON parse it but check for errors
    
    NSError *error = nil;
    id object = [NSJSONSerialization
                 JSONObjectWithData:data
                 options:0
                 error:&error];
    
    if(error) {
        
        /* JSON was malformed, act appropriately here */
        NSLog(@"JSON from service malformed, received %@",json);
        self.recognizeCallback(nil,error);
        
    }
    
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        
        // look for state changes
        if([results objectForKey:@"state"] != nil) {
            NSString *state = [results objectForKey:@"state"];
            
            // if we receive a listening state after having sent audio it means we can now close the connection
            if ([state isEqualToString:@"listening"] && self.isConnected && self.isReadyForAudio){
              
                [self disconnect];
                
            } else if([state isEqualToString:@"listening"]) {
                // we can send binary data now
                self.isReadyForAudio = YES;
            }
        }
        
        if([results objectForKey:@"results"] != nil) {
            
            NSArray *resultsArr = [results objectForKey:@"results"];
            
            if([resultsArr count] > 0) {
                self.recognizeCallback(results,nil);

            }
        }
        
        if([results objectForKey:@"error"] != nil) {
            NSString *errorStr = [results objectForKey:@"error"];
            
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: errorStr,
                                       NSLocalizedFailureReasonErrorKey: errorStr,
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };
            NSError *error = [NSError errorWithDomain:@"WatsonSpeechSDK"
                                                 code:500
                                             userInfo:userInfo];
            
            self.recognizeCallback(nil,error);
            [self disconnect];
        }
        
        
    }
    else
    {
        // we should have had a dictionary object so this is an error
        NSLog(@"Didn't receive a dictionary json object, closing down");
        [self disconnect];
    }
    
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"WebSocket closed with reason %@",reason);
    
    // sometimes the socket can close immediately before data has been sent
    if(!self.hasDataBeenSent)
    {
        NSString *errorStr = @"Websocket closed before data could be sent";
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: errorStr,
                                   NSLocalizedFailureReasonErrorKey: errorStr,
                                   NSLocalizedRecoverySuggestionErrorKey: @"try reconnecting"
                                   };
        NSError *error = [NSError errorWithDomain:@"WatsonSpeechSDK"
                                             code:code
                                         userInfo:userInfo];
        [self webSocket:webSocket didFailWithError:error];
        return;
    }
    
    
    self.webSocket.delegate = nil;
    self.isConnected = NO;
    self.isReadyForAudio = NO;
    self.webSocket = nil;
    self.reconnectAttempts = 0;
    if (code == 1006) { // authentication error
        [self.conf invalidateToken];
    }
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


@end

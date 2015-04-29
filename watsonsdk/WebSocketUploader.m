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

#import "WebSocketUploader.h"
#import "SRWebSocket.h"

@interface WebSocketUploader () <SRWebSocketDelegate>

@property (strong,atomic) NSMutableData *buffer;
@property (strong,atomic) NSNumber *reconnectAttempts;

@end

@implementation WebSocketUploader {
    SRWebSocket *_webSocket;
    BOOL isConnected;
    BOOL isReadyForAudio;
    
}

@synthesize speechServer;
@synthesize buffer;

/**
 *  connect to an itrans server using websockets
 *
 *  @param speechServer   NSUrl containing the ws or wss format websocket service URI
 *  @param cookie pass a full cookie string that may have been returned in a separate authentication step
 */
- (void) connect:(NSURL*)speechServerURI headers:(NSDictionary*)headers  {
    
    self.speechServer = speechServerURI;
    isConnected = NO;
    isReadyForAudio = NO;
    _webSocket.delegate = nil;
    self.headers = headers;
   
    NSLog(@"websocket connection using %@",[self.speechServer absoluteString]);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:self.speechServer];
    
    // set headers
    for(id headerName in headers) {
        [req setValue:[headers objectForKey:headerName] forHTTPHeaderField:headerName];
    }
    
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:req];
    
    _webSocket.delegate = self;
    
    NSLog(@"WeBSocket - Opening Connection...");
    [_webSocket open];
}

- (BOOL) isWebSocketConnected {
    
    return self->isConnected;
}

- (void) reconnect {
    
    if(self.reconnectAttempts ==nil) {
        self.reconnectAttempts = [NSNumber numberWithInt:0];
    }
    
    [self connect:self.speechServer headers:self.headers];
}

- (void) endSession {
    
    if([self isWebSocketConnected]) {
        [_webSocket send:@"{\"name\":\"unready\"}"];
    } else {
        NSLog(@"tried to end Session but websocket was already closed");
    }
    
    
}

- (void) sendEndOfStreamMarker {
    
     if(isConnected && isReadyForAudio) {
         NSLog(@"sending end of stream marker");
         [_webSocket send:[[NSMutableData alloc] initWithLength:0]];
         isReadyForAudio = NO;
     }
}

- (void) disconnect {
    
    isReadyForAudio = NO;
    isConnected = NO;
    [_webSocket close];
    
}

- (void) writeData:(NSData*) data {
    
    if(isConnected && isReadyForAudio) {
        
        // if we had previously buffered audio because we were not connected, send it now
        if([self.buffer length] > 0) {
            
            NSLog(@"sending buffered audio");
            [_webSocket send:self.buffer];
            
            //reset buffer
            [self.buffer setData:[NSData dataWithBytes:NULL length:0]];
        }
        
        [_webSocket send:data];
    } else {
        // we need to buffer this data and send it when we connect
        NSLog(@"WebSocketUploader - data written but we're not connected yet");
        
        [self.buffer appendData:data];
    }
    
}


#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected");
    isConnected = YES;
    
   // NSString *json = @"{\"grammar\":null,\"name\":\"listen\",\"dictionary\":null,\"wantResults\":[\"topHypothesis\",\"splitTopHypothesis\"],\"content-type\":\"audio/l16; rate=16000\",\"wantInterimResults\":true,\"EOUMode\":\"PTT\"}";
    
    NSString *json = @"{\"action\":\"start\",\"content-type\":\"audio/l16; rate=16000\",\"interim_results\":true,\"continuous\": true}";
    
    [_webSocket send:json];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);
    _webSocket = nil;
    
    if ([self.reconnectAttempts intValue] < 3) {
        self.reconnectAttempts = [NSNumber numberWithInt:[self.reconnectAttempts intValue] +1] ;
        NSLog(@"trying to reconnect");
        // try and open the socket again.
        [self reconnect];
    } else {
        
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:[error localizedDescription] forKey:NSLocalizedDescriptionKey];
        
        // populate the error object with the details
        NSError *delegateError = [NSError errorWithDomain:@"com.ibm.cio.watsonsdk" code:401 userInfo:details];
        
        // assume session has expired, no way of knowing with websockets and IMC
        [resultDelegate streamErrorCallback:[error localizedDescription] error:delegateError];
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
        
    }
    
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *results = object;
        
        // look for state changes
        if([results objectForKey:@"state"] != nil) {
            NSString *state = [results objectForKey:@"state"];
            
            // if we receive a listening state after having sent audio it means we can now close the connection
            if ([state isEqualToString:@"listening"] && isConnected && isReadyForAudio){
              
                [self disconnect];
                
            } else if([state isEqualToString:@"listening"]) {
                // we can send binary data now
                isReadyForAudio = YES;
            }
        }
        
        /*
        // look for state changes
        if([results objectForKey:@"newState"] != nil) {
            NSString *state = [results objectForKey:@"state"];
            
            if ([state isEqualToString:@"recoResultAvailable"]) {
                // this is triggered when we have a final result
                //[self endSession];
            } else if ([state isEqualToString:@"ready"]) {
                // this is triggered after we have sent the unready to signal we want to disconnet
                [self disconnect];
            }
        }
         */
        
        if([results objectForKey:@"results"] != nil) {
            
            NSArray *resultArray = [results objectForKey:@"results"];
            if( [resultArray count] != 0 && [resultArray objectAtIndex:0] != nil) {
                
                NSDictionary *result =[resultArray objectAtIndex:0];
            
            
                BOOL isEndOfSentence = [[result objectForKey:@"final"] boolValue];
                NSArray *alternatives = [result objectForKey:@"alternatives"];
                
                if([alternatives objectAtIndex:0] != nil) {
                    NSDictionary *alternative = [alternatives objectAtIndex:0];
                    
                    if([alternative objectForKey:@"transcript"] != nil) {
                        NSString *transcript = [alternative objectForKey:@"transcript"];
                        
                        if(isEndOfSentence) {
                            // send the transcript back to the delegate and initiate the connection close
                            [resultDelegate streamResultPartialCallback:transcript];
                            //[self endSession];
                        } else {
                            // send teh partial result back to the
                            [resultDelegate streamResultPartialCallback:transcript];
                        }
                    }
                }
            }
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
    _webSocket.delegate = nil;
    isConnected = NO;
    isReadyForAudio = NO;
    _webSocket = nil;
    
    // trigger the stream closed callback so the calling class can clean up
    [resultDelegate streamClosedCallback];
}

#pragma mark - Uploader delegate

// setting a delegate allows the HTTPStreamUploader to call back when either an error has occured or data is received and the stream closed
-(void) setResultDelegate:(id) delegate {
    resultDelegate = delegate;
    
}


@end

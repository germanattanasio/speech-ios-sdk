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

#import "HTTPStreamUploader.h"


uint8_t *responseBytes;
int responseBytesLen;
int bodyLen, candidateHeaderLen;

BOOL isProcessedFinish;

@implementation HTTPStreamUploader
@synthesize responseBody;
@synthesize serviceHost;
@synthesize servicePath;
@synthesize servicePort;
@synthesize LMCCookie;
@synthesize useSSL;
@synthesize isChunkedRequest;
@synthesize isCertificateValidationDisabled;

BOOL bufferEmptied = FALSE;
BOOL footerSent = FALSE;

static NSString *NETWORK_ERROR = @"Network error, please check your network connection!";
static NSString *NETWORK_401 = @"HTTP/1.1 401 Authorization Required";


// setting a delegate allows the HTTPStreamUploader to call back when either an error has occured or data is received and the stream closed
-(void) setResultDelegate:(id) delegate {
    resultDelegate = delegate;
    
}
-(void) startStreamedUpload:(NSString*)host port:(NSNumber*)port path:(NSString*)path isSecure:(BOOL)ssl cookie:(NSString*)cookie {
    responseBytesLen = 0;
    candidateHeaderLen = 0;
    bodyLen = 20000000;//very large
    isProcessedFinish = false;
    
    uint8_t tmp[0];
    responseBytes = tmp;
    
    // initialise buffer
    data = [[NSMutableData alloc]init];
    byteIndex = 0;
    bufferEmptied = FALSE;
    footerSent = FALSE;
    
    self.serviceHost=host;
    self.servicePort=port;
    self.servicePath=path;
    self.LMCCookie=cookie;
    self.useSSL=ssl;
    self.isChunkedRequest = NO;
    
    [self initNetworkCommunication];
}

-(void) stopStreamedUpload{
   // [self closeStreams];
}

-(void) getBodyOnly {
    //NSString* str = [[NSString alloc] initWithBytes:responseBytes length:responseBytesLen encoding:NSUTF8StringEncoding];
    int k=0, i = 0;
    //bool flag = false;
    
    for (; i< responseBytesLen ; i++) {
        k = (k<<8) | responseBytes[i];
        if (k==0x0d0a0d0a) {
            break;
        }
    }
    i++;
    
    responseBytesLen = responseBytesLen - i;
    
    uint8_t* tmp= (uint8_t*) malloc(responseBytesLen);
    memcpy(tmp, responseBytes + i, responseBytesLen);
    
    free(responseBytes);
    
    responseBytes = tmp;

    NSLog(@"responseBytesLen=%d", responseBytesLen);
}


/*
 parse itrans streamed format which looks a bit like this...
 
 1:at least is a test to see it's this new range of
 39
 1:at least is a test to see it's this new range of string
 3d
 1:at least is a test to see it's this new range of string was
 3f
 0:at least is a test to see it's this new range of string was.
 0
 
 0: indicates final transcription
 1: indicates partial transcription
 2: indicates stable transcription
 
 the last line will always be prepended with 0:   partial lines with   1:   and ending in   /r/n
 
 
 */
-(NSString *) getLastLine:(NSString*)body {
    
    NSLog(@"line --> %@",body);
    
    // tokenize the body into lines so we can get the last one.
    NSArray *transcriptionItems = [body componentsSeparatedByString:@"\r\n"];
    
    for (id line in [transcriptionItems reverseObjectEnumerator])
    {
        // print some info
        //NSLog(@"line --> %@",line);
        if([line hasPrefix:@"0:"]) {
            return [line substringFromIndex:2];
        }
        
        if([line hasPrefix:@"1:"]) {
            return [line substringFromIndex:2];
        }
        
        if([line hasPrefix:@"2:"]) {
            return [line substringFromIndex:2];
        }
    }
    return @"";
        
}


// this method parses the body of a chunked response (after headers have been stripped)
-(void) parseChunkedBody
{
    NSString* body = @"";
    NSString* bodyBeforeParse = [[[NSString alloc] initWithBytes:responseBytes
                                                           length:responseBytesLen
                                                        encoding:NSUTF8StringEncoding] autorelease];
    //NSString* hexlength;
    char c,n;
    int hexcount=0; // track the number of chars parsed before a \r\n is hit
    
    for (int i=0; i< responseBytesLen ; i++) {
        c = responseBytes[i];
        n = responseBytes[i+1];
        
        // look for /r/n this marks the end of the line containing the chunk length
        if (c=='\r' && n=='\n') { 
            
            // get the hex string TODO make this handle more than two characters
            NSString* hex = [NSString stringWithString:[bodyBeforeParse substringWithRange:NSMakeRange(i-hexcount, hexcount)]];
            
            // convert the hex string to an int so we can use it with the array contents
            unsigned chunklength = 0;
            NSScanner *scanner = [NSScanner scannerWithString:hex];
            [scanner scanHexInt:&chunklength];
            
            NSLog(@"chunk length is %d bytes",chunklength);
            
            if(chunklength ==0) // 0 marks the end of a chunked request
                break;
            
            body = [NSString stringWithFormat:@"%@%@",body,[bodyBeforeParse substringWithRange:NSMakeRange(i+1, chunklength+1)]];
            
            
            // skip to the end of the chunk
            i += chunklength+3; // 3 is added to avoid the /r/n on the end of the chunk text
            // reset chunk header count
            hexcount=0;
        }
        else{
            hexcount++;
        }
    }
    
   NSLog(@"parsed chunk body is %@",body);
    
    // overwrite response
    responseBytes = (uint8_t *)[body UTF8String];
    responseBytesLen = body.length;
    
    
}

- (int) getBodyLengthFromHeader : (uint8_t*) headerBytes len:(int) len{
    
    NSString* header = [[NSString alloc] initWithBytes:headerBytes length:len encoding:NSUTF8StringEncoding];
    
    NSLog(@"Response header=%@", header);
    
    NSRange httpStatus = [header rangeOfString:@"HTTP/1.1 200 OK"];
    if (httpStatus.location == NSNotFound) {
        
        
        NSRange authRequired = [header rangeOfString:NETWORK_401];
        if(authRequired.location != NSNotFound)
            return -2;
        
        return -1;
    }
    
    
    NSRange r = [header rangeOfString:@"Content-Length"];
    NSRange rchunk = [header rangeOfString:@"Transfer-Encoding: chunked"];
    
    if (r.location != NSNotFound) {
        NSRange searchRange = {r.location, 100};
        NSRange r2 = [header rangeOfString:@"\n" options:NSCaseInsensitiveSearch range:searchRange];

        if (r2.location!=NSNotFound) {
            NSRange val = {r.location + 16, r2.location};
            NSString *str = [header substringWithRange:val];
            NSLog(@"Body length=%@ ", str);
            int intVal = [str intValue];
            
            return intVal;
        }
    }
    else if(rchunk.location != NSNotFound){
        // this must be a chunked request
        NSLog(@"***Response is chunked***");
        self.isChunkedRequest = YES;
    }
    
    return 0;
}


/* NSStreamDelegate methods*/

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent{
   
    switch(streamEvent) {
        case NSStreamEventEndEncountered:
        {
            NSLog(@"handleEvent NSStreamEventEndEncountered");
            if (!isProcessedFinish) {
                isProcessedFinish = true;
                
                NSLog(@"Total response length=%d", responseBytesLen);
                if (responseBytesLen==0) {
                    NSLog(@"WARN: responseBytesLen=0");
                    [resultDelegate streamResultCallback:NULL responseBytes:NULL responseBytesLen:0];
                } else {
                  //  [self getBodyOnly];
                    
                   // [resultDelegate streamResultCallback:[self getLastLine:responseBody] responseBytes:responseBytes responseBytesLen:responseBytesLen];
                }
                
                
                if(theStream == inputStream)
                {
                 //   [self closeStreams];
                }
                break;
            }
            
        }
        case NSStreamEventHasBytesAvailable: 
        {
            NSLog(@"handleEvent NSStreamEventHasBytesAvailable inputStream");
            if (theStream == inputStream) {
                
                uint8_t buffer[1024];
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                   
                    
                    if (len > 0) {
                        if (responseBytesLen==0) {//get headerpo
                            candidateHeaderLen = len;
                            bodyLen = [self getBodyLengthFromHeader:buffer len:len];
                            
                            if (bodyLen < 0) {//error -1 or -2 for auth required
                                [outputStream close];
                                [inputStream close];
                                
                                NSMutableDictionary* details = [NSMutableDictionary dictionary];
                                [details setValue:@"Received 401 authentication challenge from the server, please include a session cookie using setSessionCookie" forKey:NSLocalizedDescriptionKey];
                                
                                // populate the error object with the details
                                NSError *error = [NSError errorWithDomain:@"com.ibm.cio.watsonsdk" code:401 userInfo:details];
                                
                                if(bodyLen == -2)
                                    [resultDelegate streamErrorCallback:NETWORK_401 error:error];
                                else
                                    [resultDelegate streamErrorCallback:NETWORK_ERROR error:error];
                                return;
                            }
                            
                            
                        }

                        //join arrays
                        uint8_t *tmp = (uint8_t*) malloc(responseBytesLen+len);
                        
                        memcpy(tmp, responseBytes, responseBytesLen);
                        memcpy(tmp+responseBytesLen, buffer, len);
                        
                        if (responseBytesLen>0) {
                            free(responseBytes);
                        }
                        responseBytes = tmp;
                        responseBytesLen += len;
                        
                        // only close if this is not a chunked request
                        if ((responseBytesLen >= bodyLen +  candidateHeaderLen) && self.isChunkedRequest == NO) {
                            if (!isProcessedFinish) {
                                isProcessedFinish = true;
                                
                                NSLog(@"Total response length=%d", responseBytesLen);
                                [self getBodyOnly];
                                [resultDelegate streamResultCallback:[self getLastLine:responseBody] responseBytes:responseBytes responseBytesLen:responseBytesLen];
                                
                               
                                
                                if(theStream == inputStream)
                                {
                                    [self closeStreams];
                                }
                                break;
                            }
                        }
                        else if(self.isChunkedRequest)
                        {
                            
                            NSString* part = [[NSString alloc] initWithBytes:responseBytes length:responseBytesLen encoding:NSUTF8StringEncoding];
                            
                            // Rob I put an additional \r\n test in front of the 0 as the 0 should  be on a newline on its own, at the moment it's picking up the websphere header which ends in 0
                            NSRange endcode = [part rangeOfString:@"\r\n0\r\n\r\n"];
                            if (endcode.location != NSNotFound) {
                                // found end of chunked request
                                NSLog(@"found end of chunked request");
                                //[self getBodyOnly];
                                //[self parseChunkedBody];
                                  // [resultDelegate streamResultCallback:part responseBytes:responseBytes responseBytesLen:responseBytesLen];
                                
                                
                                
                                [self closeStreams];
                                
                                break;
                                
                            }
                            
                            part = [self getLastLine:part];
                            [resultDelegate streamResultPartialCallback:part];
                            
                        }
                         
                        
                        
                    }
                }
            }
            else if(theStream == fileInputStream)
            {
                NSLog(@"handleEvent NSStreamEventHasBytesAvailable fileInputStream");
                // we have info from the written file
            }
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"handleEvent NSStreamEventErrorOccurred");
            
            NSError *theError = [theStream streamError];
            NSLog(@"%@",[NSString stringWithFormat:@"Error %i: %@",[theError code], [theError localizedDescription]]);
            
            
            //NSAlert *theAlert = [[ alloc] init];
            
            //[theAlert setMessageText:@"Error reading stream!"];
            
            
            
            // we need to fire some kind of event here so this is handled in the ui
            // a callback would be good
            
            [outputStream close];
            [inputStream close];
            
            // some other error
           // [self closeStreams];
            
            [resultDelegate streamErrorCallback:NETWORK_ERROR error:theError];
            break;
        }
        case NSStreamEventOpenCompleted:
        {
            
            if (theStream == outputStream)
                NSLog(@"NSStreamEventOpenCompleted outputStream");
            else if(theStream == inputStream)    
                NSLog(@"NSStreamEventOpenCompleted inputStream");
            else if(theStream == fileInputStream)    
                NSLog(@"NSStreamEventOpenCompleted fileInputStream");
            
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            NSLog(@"handleEvent NSStreamEventHasSpaceAvailable");
            if(theStream == outputStream)
            {
                NSLog(@"handleEvent- Writing to Output Stream");
                [self writeBuffertoOutputStream];
                
                break;
            }
            break;
        }
            
    }
        
    
    
}

- (void) closeStreams
{
    NSLog(@"closeStreams");
    

        // just do cleanup here after we have received endof streamevents
    //[outputStream close];
   
    [outputStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
    [outputStream release];
    outputStream = nil;
    
    //[inputStream close];
   
    [inputStream removeFromRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
    [inputStream release];
    inputStream = nil;
    
    // trigger the stream closed callback so the calling class can clean up
    [resultDelegate streamClosedCallback];
    
}

/*
 writeBuffertoOutputStream - read the contents of the file data buffer from memory and write it to the 
 output stream in 1kb chunks.
 */

NSString *writeBuffertoOutputStream_lock=@"LOCK";

- (void) writeBuffertoOutputStream
{
@synchronized(writeBuffertoOutputStream_lock) {
    NSLog(@"writeBuffer length is %d",[data length]);
    
    uint8_t *readBytes = (uint8_t *)[data mutableBytes];
    readBytes += byteIndex; // instance variable to move pointer
    int data_len = [data length];
    int chunkLen = 1024;//1024 ; 4096
    
    unsigned int len = ((data_len - byteIndex >= chunkLen) ?
                        chunkLen : (data_len-byteIndex));
    
    
    if(len > 0)
    {    
        uint8_t buf[len];
        (void)memcpy(buf, readBytes, len);
        
        bufferEmptied = FALSE;
        int sendlength = [outputStream write:(const uint8_t *)buf maxLength:len];
        
        if(sendlength == -1)
        {
            NSError *theError = [outputStream streamError];
            NSString *pString = [theError localizedDescription];
            
            NSLog(@"error writing to outputstream %@",pString);
            
            [resultDelegate streamErrorCallback:NETWORK_ERROR error:theError];
        }
        else
        {
            byteIndex += len;
        }
    }
    else {
        bufferEmptied = TRUE;
    }
    
}
}

/* Setup a TCP connection between us and the server */
- (void)initNetworkCommunication {
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    // do this here so that we have the headers in the buffer ready to write, when we connect
    [self writePostHeader];
    
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef) self.serviceHost, [self.servicePort intValue], &readStream, &writeStream);
    inputStream = (NSInputStream *)readStream;
    outputStream = (NSOutputStream *)writeStream;
    
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    if(self.useSSL)
    {
       
        NSDictionary *sslProperties;
        
        if(self.isCertificateValidationDisabled)
        {
            NSLog(@"Certificate validation disabled");
            sslProperties = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
                                       [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
                                       [NSNumber numberWithBool:NO],  kCFStreamSSLValidatesCertificateChain,
                                       kCFNull,kCFStreamSSLPeerName,
                                       @"kCFStreamSocketSecurityLevelTLSv1_0SSLv3", kCFStreamSSLLevel,
                                       nil];
        }
        else
        {
            NSLog(@"Certificate validation enabled");
            sslProperties = [[NSDictionary alloc] initWithObjectsAndKeys:
                             @"kCFStreamSocketSecurityLevelTLSv1_0SSLv3", kCFStreamSSLLevel,
                             nil];
        }
        
        [inputStream setProperty:sslProperties forKey:(NSString *)kCFStreamPropertySSLSettings];
        [outputStream setProperty:sslProperties forKey:(NSString *)kCFStreamPropertySSLSettings];
    }
    
    [inputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    [outputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    
    // schedule our input streams in the runloop
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    
    NSLog(@"about to open connection to server");
    
    // open connection
    [inputStream open];
    [outputStream open];
}



- (void) writePostHeader {
    NSLog(@"writePostHeader-> entry");
    
    NSMutableData *postHeader = [NSMutableData data];
    
    // headers
    [postHeader appendData:[[NSString stringWithFormat:@"POST %@ HTTP/1.1\r\n", self.servicePath] dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"User-Agent: watson\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[[NSString stringWithFormat:@"Host: %@:%d\r\n", self.serviceHost,[self.servicePort intValue]] dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"Connection: Keep-Alive\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"Transfer-Encoding: chunked\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    

    if(self.LMCCookie != nil)
    {
        [postHeader appendData:[[NSString stringWithFormat:@"Cookie: %@\r\n", self.LMCCookie] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [postHeader appendData:[@"Content-Type:application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        
    [data appendData:postHeader];
    
    //NSLog(@"%@",[[NSString alloc] initWithData:postHeader encoding:NSASCIIStringEncoding]);
    
}


/* create the correct hex encoded chunk header for a given section of the chunked request*/
//Unused now
- (NSMutableData *) getChunkHeader:(NSMutableData *) chunk {
    NSNumber *number;
    NSString *hexString;
    
    number = [NSNumber numberWithInt:[chunk length]];
    hexString = [NSString stringWithFormat:@"%x", [number intValue]];
    
    NSMutableData *chunkHeader = [NSMutableData data];
    [chunkHeader appendData:[[NSString stringWithFormat:@"%@\r\n", hexString] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return chunkHeader;
    
}

- (void) writeData:(NSData *)content {
    NSLog(@"writeData-> entry");
    
    // get hexadecimal string for http chunk
    NSNumber *number;
    NSString *hexString;
    
    number = [NSNumber numberWithInt:[content length]];
    hexString = [NSString stringWithFormat:@"%x", [number intValue]]; 
    
    NSLog(@"chunk header is %@",hexString);
    
    
    NSMutableData *chunkedContent = [NSMutableData data];
    [chunkedContent appendData:[[NSString stringWithFormat:@"%@\r\n", hexString] dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:chunkedContent];
    
     
    // write actual bytes
    [data appendData:content];
    
    // write carriage returns
    
    NSMutableData *carriageReturns = [NSMutableData data];
    [carriageReturns appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:carriageReturns];
    
    
    // if the handleEvent loop found no data waiting to write then it will have set the following flag
    //does we need this  ?
    if(bufferEmptied)
    {
        NSLog(@"Buffer emptied so write data manually");
        [self writeBuffertoOutputStream];
    }
    
}

- (void) writePostFooter {
    NSLog(@"writePostFooter-> entry, bufferEmptied=%d",bufferEmptied);
    
    NSMutableData *chunkingEnd = [NSMutableData data];
    [chunkingEnd appendData:[@"0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:chunkingEnd];
    
    //[self writeBuffertoOutputStream];
    
    footerSent = TRUE;
    
    if(bufferEmptied==TRUE) {
         NSLog(@"Buffer emptied so write data manually");
        [self writeBuffertoOutputStream];
    }
    
    //[self closeStreams];
    
}

- (void)dealloc {
    [responseBody release];
    [servicePort release];
    [servicePath release];
    [serviceHost release];
    [LMCCookie release];
    
    [data release];
    [super dealloc];
    
}

@end

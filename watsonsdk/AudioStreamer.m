//
//  AudioStreamer.m
//  watsonwl5FaceswatsonIphone
//
//  Created by Rob Smart on 29/11/2013.
//
//

#import "AudioStreamer.h"

#define TAG_READ_HEADER 1
#define TAG_READ_BODY 2
#define TAG_WRITE_HEADER 1
#define TAG_WRITE_BODY 2
#define TAG_WRITE_FOOTER 3

@interface AudioStreamer ()

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSString *serviceHost;
@property (nonatomic, strong) NSNumber *servicePort;
@property (nonatomic, strong) NSString *servicePath;
@property (nonatomic, strong) NSString *LMCCookie;
@property (nonatomic, strong) NSMutableData *responseBuffer;
@end

@implementation AudioStreamer
@synthesize socket;
@synthesize serviceHost;
@synthesize servicePort;
@synthesize servicePath;
@synthesize LMCCookie;
@synthesize responseBuffer;
int contentLength;

/* Performance Analysis */
double startConnectingTime;
double startWaitingTime;
double startSendingTime;
long long establishingTime;
double bufferingTime;
double lastBufferingTime;
/* Performance Analysis Ends */


/**
 * setting a delegate allows the AudioStreamer to call back when either an error has occured or data is received and the stream closed
 */
-(void) setResultDelegate:(id) delegate {
    resultDelegate = delegate;
}

/**
 * Start timeout timer
 */
-(void) startTimer{
   // [resultDelegate startTimer];
}

/**
 * Release timeout timer
 */
-(void) releaseTimer:(NSString*)reason{
  //  [resultDelegate releaseTimer:reason];
}

/**
 * Get instance of QueryStatistics
 */
//-(QueryStatistics*) getQueryStatistics{
//    return [resultDelegate getQueryStatistics];
//}

/**
 * Establishing connection with backend via TCP, using GCDAsyncSocket
 */
-(void) startStreamedUpload:(NSString*)host
                       port:(NSNumber*)port
                       path:(NSString*)path
                   isSecure:(BOOL)ssl
                     cookie:(NSString*)cookie
                   compress:(BOOL)compress
{
    NSLog(@"host=%@ ## port=%@ ##path=%@",host, port, path);
    
  //  startConnectingTime = CACurrentMediaTime();
  //  NSLog(@"[Performance] Start Connecting time=%f", startConnectingTime);
    
    startWaitingTime = 0;
    startSendingTime = 0;
    establishingTime = 0;
    bufferingTime = 0;
    lastBufferingTime = 0;
    //
    serviceHost=host;
    servicePort=port;
    servicePath=path;
    LMCCookie=cookie;
    
    // create teh responseBuffer
    responseBuffer = [[NSMutableData alloc] init];
    
    // init the socket
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *err = nil;
    if (![socket connectToHost:host onPort:[port intValue] error:&err]) // Asynchronous!
    {
        // If there was an error, it's likely something like "already connected" or "no delegate set"
        NSLog(@"Error connecting to host %@", err);
    }
    
    if(ssl){
        [socket startTLS:nil]; // options parameter can be passed in here to disable cert validation
    }
    
    // because we're using GCD this will be queued up and sent when the socket is ready
    [self writePostHeader];
    
    // tell the socket to read the full header, we will get an event with matching tag when this data is available
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
	
    // this will read the entire response header and call the didReadData delegate method
	[socket readDataToData:responseTerminatorData withTimeout:-1.0 tag:TAG_READ_HEADER];
}

/**
 * Stop uploading
 */
-(void) stopStreamedUpload{
    NSLog(@"stopStreamedUpload -> disabled currently don't need it. remove when working");
    //    [self disConnect];
}

-(void) disConnect:(NSString*)reason{
    [socket disconnect];
    [self releaseTimer:reason];
}

- (void)calculateEstablishingTime{
    NSLog(@"calculateEstablishingTime");
   // startSendingTime = CACurrentMediaTime();
  //  establishingTime = [UtilsPlugin getOffsetTime:startConnectingTime];
    
  //  [[self getQueryStatistics] setRequestEstablishingTime:[NSString stringWithFormat:@"%lld", establishingTime]];
    //NSLog(@"[Performance] Network Establishing time=%lld", establishingTime);
}

/**
 * Socket connected callback
 */
- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Socket connected");
   // [self calculateEstablishingTime];
}

/**
 * Socket disconnect callback
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"socketDidDisconnect:withError: \"%@\"", err);
}

/**
 * Write data to socket queue
 */
- (void) writeDataToSocket:(NSData*)data tag:(long)tagNumber{
     NSLog(@"writeDataToSocket");
    // Waiting for establishing connection
    /*if(startSendingTime == 0){
        NSLog(@"[Performance] Waiting for establishing connection, prepared %d bytes", [data length]);
    }
    else {
    //    if(lastBufferingTime > 0){
     //       bufferingTime += [UtilsPlugin getOffsetTime:lastBufferingTime];
     //   }
      //  lastBufferingTime = CACurrentMediaTime();
    }*/
    [socket writeData:data withTimeout:-1 tag:tagNumber];
}

/**
 * Prepare and write header data
 */
- (void) writePostHeader {
    NSLog(@"writePostHeader-> entry");
    
    NSMutableData *postHeader = [NSMutableData data];
    
    // headers
    [postHeader appendData:[[NSString stringWithFormat:@"POST %@ HTTP/1.1\r\n", servicePath] dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"User-Agent: watson\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[[NSString stringWithFormat:@"Host: %@:%d\r\n", serviceHost,[servicePort intValue]] dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"Connection: Keep-Alive\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postHeader appendData:[@"Transfer-Encoding: chunked\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    if(LMCCookie != nil)
    {
        [postHeader appendData:[[NSString stringWithFormat:@"Cookie: %@\r\n", LMCCookie] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [postHeader appendData:[@"Content-Type:application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self writeDataToSocket:postHeader tag:TAG_WRITE_HEADER];
}

/**
 * Prepare and write body data
 */
- (void) writeData:(NSData *)content {
    NSLog(@"writeData-> entry");
    
    // get hexadecimal string for http chunk
    NSNumber *number;
    NSString *hexString;
    
    number = [NSNumber numberWithInt:[content length]];
    hexString = [NSString stringWithFormat:@"%x", [number intValue]];
    
    NSLog(@"chunk header is %@, actual length is %@",hexString, number);
    /**
     * When the compression is off, we are getting the erros below:
     *
     * socketDidDisconnect:withError: "Error Domain=GCDAsyncSocketErrorDomain Code=7 "Socket closed by remote peer" UserInfo=0x17e8a940 {NSLocalizedDescription=Socket closed by remote peer}"
     *
     * It will be fixed if not to write 0 byte data
     */
    if([hexString isEqual:@"0"] || [number isEqual:0]) {
        return;
    }
    
    NSMutableData *chunkedContent = [NSMutableData data];
    [chunkedContent appendData:[[NSString stringWithFormat:@"%@\r\n", hexString] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // write actual bytes
    [chunkedContent appendData:content];
    
    // write carriage returns
    [chunkedContent appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self writeDataToSocket:chunkedContent tag:TAG_WRITE_BODY];
}

/**
 * Prepare and write footer data
 */
- (void) writePostFooter {
    NSLog(@"writePostFooter");
    NSMutableData *chunkingEnd = [NSMutableData data];
    [chunkingEnd appendData:[@"0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self writeDataToSocket:chunkingEnd tag:TAG_WRITE_FOOTER];
    [self startTimer];
}

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"didWriteDataWithTag");
    if (tag == TAG_WRITE_HEADER){
        NSLog(@"Header Written");
    }
    else if (tag == TAG_WRITE_BODY){
        NSLog(@"Body chunk Written");
    }
    else if (tag == TAG_WRITE_FOOTER){
     //   startWaitingTime = CACurrentMediaTime();
        NSLog(@"Footer Written");
        // Data Transmission time from Client to VBE, starts from time of connection established to Footer is sent
    //    NSNumber *transmissionTimeNumber = [UtilsPlugin getOffsetTimeNumber:startSendingTime];
      //  NSNumber *requestTimeNumber = [UtilsPlugin getOffsetTimeNumber:startConnectingTime];
        //double bufferingTime = bufferingTime; //([requestTimeNumber doubleValue] - [transmissionTimeNumber doubleValue] - establishingTime);
        
      //  long long transmissionTime = [transmissionTimeNumber longLongValue];
     //   long long requestTime = [requestTimeNumber longLongValue];
     //   long long bufferTime = [[NSNumber numberWithDouble:bufferingTime] longLongValue];
        
    //    [[self getQueryStatistics] setRequestTransmissionTime:[NSString stringWithFormat:@"%lld", transmissionTime]];
    //    [[self getQueryStatistics] setRequestTime:[NSString stringWithFormat:@"%lld", requestTime]];
    //    [[self getQueryStatistics] setRequestBufferingTime:[NSString stringWithFormat:@"%lld", bufferTime]];
        
    //    NSLog(@"[Performance] Rqst=%lld, Trans=%lld, Buffer=%lld, Estb=%lld", requestTime, transmissionTime, bufferTime, establishingTime);
    }
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"didReadData");
    NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (tag == TAG_READ_HEADER)
    {
        NSLog(@"we have the full header\n%@",httpResponse);
        
        contentLength = [self getBodyLengthFromHeader:httpResponse];
        if(contentLength == 0){
            [resultDelegate streamResultCallback:NULL responseBytes:contentLength responseBytesLen:contentLength];
            [self disConnect:@"Error"];
            return;
        }
        
        //[socket readDataToLength:headerLength withTimeout:20 tag:TAG_READ_BODY];
        [socket readDataWithTimeout:-1 buffer:responseBuffer bufferOffset:0 maxLength:0 tag:TAG_READ_BODY];
    }
    else if(tag == TAG_READ_BODY)
    {
        NSLog(@"we have the body, content length is %d, received=%d",contentLength, [responseBuffer length]);
        if([responseBuffer length] == contentLength)
        {
      //      long long responseTime = [UtilsPlugin getOffsetTime:startWaitingTime];
            // Streaming
      //      [[self getQueryStatistics] setResponseTime:[[NSString alloc] initWithFormat:@"%lld", responseTime]];
      //      [[self getQueryStatistics] setResponseLength:[[NSString alloc] initWithFormat:@"%d", contentLength]];
       //     [[self getQueryStatistics] setTotalNetworkTime:[UtilsPlugin getOffsetTimeNumber:startConnectingTime]];
            
       //     NSLog(@"[Performance] Response time=%lld, Response length=%d (Streaming)", responseTime, contentLength);
        //    long long totalNetwork = [[[self getQueryStatistics] totalNetworkTime] longLongValue];
        //    long long totalRequest = (totalNetwork-responseTime);
        //    long long requestTransfer = totalRequest - establishingTime;
            
            // Sometimes the Connection Establishing Time is zero, so we reset it again here
       //     [[self getQueryStatistics] setRequestEstablishingTime:[NSString stringWithFormat:@"%lld", establishingTime]];
            
     //       NSLog(@"[Performance] Network=%lld, Res=%lld, Req=%lld, Trans=%lld, Inita=%lld", totalNetwork, responseTime, totalRequest, requestTransfer, establishingTime);
            
            // the response has all been received
            [resultDelegate streamResultCallback:NULL responseBytes:(uint8_t*)[responseBuffer bytes] responseBytesLen:[responseBuffer length]];
            
            // disconnect the socket
            //            [socket disconnectAfterReading];
            [self disConnect:@"Finished Reading, data of response is fully received"];
        }
        else
        {
            // we don't have the full response yet, keep reading
            [socket readDataWithTimeout:-1 buffer:responseBuffer bufferOffset:[responseBuffer length] maxLength:contentLength tag:TAG_READ_BODY];
            //            NSLog(@"we have the body\n%@\ncontent length is %d, received=%d",responseBuffer,contentLength, [responseBuffer length]);
        }
    }
}

/**
 * Get content length of response
 */
- (int) getBodyLengthFromHeader : (NSString*) header{
    
    NSLog(@"getBodyLengthFromHeader");
    
    NSRange r = [header rangeOfString:@"content-length" options:NSCaseInsensitiveSearch];
    
    if (r.location != NSNotFound) {
        
        // remove the beginning of the string to the start of the content length
        NSString *str = [header substringFromIndex:r.location+16];
        NSRange r2 = [str rangeOfString:@"\r\n"];
        
        if (r2.location!=NSNotFound) {
            NSString *cntlen = [str substringToIndex:r2.location];
            NSLog(@"[Header] Body length=%@", cntlen);
            int intVal = [cntlen intValue];
            
            return intVal;
        }
    }
    return 0;
}


@end

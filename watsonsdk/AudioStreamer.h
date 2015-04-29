//
//  AudioStreamer.h
//  watsonwl5FaceswatsonIphone
//
//  Created by Rob Smart on 29/11/2013.
//
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "RecorderResultDelegate.h"

@interface AudioStreamer : NSObject <GCDAsyncSocketDelegate>{
    id<RecorderResultDelegate> resultDelegate;
    //    NSDate* startUploadingDate;
    //    NSDate* stopUploadingDate;
}

- (void) setResultDelegate:(id) delegate;
- (void) startStreamedUpload:(NSString*)host
                        port:(NSNumber*)port
                        path:(NSString*)path
                    isSecure:(BOOL) ssl
                      cookie:(NSString*)cookie
                    compress:(BOOL)compress;

- (void) stopStreamedUpload;
- (void) disConnect:(NSString*)reason;

- (void) writeData:(NSData *)content;
- (void) writePostFooter;
- (void) startTimer;

- (QueryStatistics*) getQueryStatistics;

@end

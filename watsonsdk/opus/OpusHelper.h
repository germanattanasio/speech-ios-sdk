//
//  OpusHelper.h
//  watsonsdk
//
//  Created by Rob Smart on 13/08/2014.
//  Copyright (c) 2014 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface OpusHelper : NSObject

@property (nonatomic,strong) dispatch_queue_t processingQueue;
@property (nonatomic) NSUInteger bitrate;

- (BOOL) createEncoder;
- (NSData*) encode:(NSData*) pcmData;

@end

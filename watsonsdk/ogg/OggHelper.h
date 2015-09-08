//
//  OggHelper.h
//  watsonsdk
//
//  Created by Mihui on 9/7/15.
//  Copyright (c) 2015 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ogg.h"

@interface OggHelper : NSObject{
    ogg_page oggPage;
    ogg_int64_t packetCount;
    ogg_int16_t granulePos;
    ogg_stream_state streamState;
}

- (OggHelper *) init;
- (NSData *) getOggOpusHeader: (int) sampleRate;
- (NSMutableData *) writePacket: (NSData*) data frameSize:(int) frameSize;
@end

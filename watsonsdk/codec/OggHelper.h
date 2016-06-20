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

#import "ogg.h"

#import "opus_defines.h"
#import "opus_header.h"
#import "opus_types.h"

static void comment_init(char **comments, long* length, const char *vendor_string);
static void comment_pad(char **comments, long* length, int amount);
#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
((buf[base+2]<<16)&0xff0000)| \
((buf[base+1]<<8)&0xff00)| \
(buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
buf[base+2]=((val)>>16)&0xff; \
buf[base+1]=((val)>>8)&0xff; \
buf[base]=(val)&0xff; \
}while(0)

@interface OggHelper : NSObject{
    ogg_page oggPage;
    ogg_int64_t packetCount;
    ogg_int16_t granulePos;
    ogg_stream_state streamState;
}

- (OggHelper *) init;
- (NSData *) getOggOpusHeader:(int) sampleRate opusHeader:(OpusHeader) header;
- (NSMutableData *) writePacket: (NSData*) data frameSize:(int) frameSize rate: (int) sampleRate;
@end

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

#import "OggHelper.h"

@implementation OggHelper

/**
 *  Initialize OggHelper instance
 *
 *  @return OggHelper instance
 */
- (OggHelper *) init{
    if (self = [super init]) {
        granulePos = 0;
        packetCount = 0;
        ogg_stream_init(&streamState, arc4random()%8888);
        return self;
    }
    return nil;
}

/**
 *  Get data of OggOpus packet
 *
 *  @param sampleRate Audio sample rate
 *
 *  @return NSMutableData instance
 */
- (NSData *) getOggOpusHeader:(int) sampleRate opusHeader:(OpusHeader) header {
    NSMutableData *newData = [[NSMutableData alloc] initWithCapacity:0];

    int ret;
    packetCount = 0, granulePos = 0;
    int headerSize = 100;
    
    unsigned char opusHeader[headerSize];

    int opusHeaderSize = opus_header_to_packet(&header, opusHeader, headerSize);

    ogg_packet packet;
    packet.packet = opusHeader;
    packet.bytes = opusHeaderSize;
    packet.b_o_s = 1;
    packet.e_o_s = 0;
    packet.granulepos = granulePos;
    packet.packetno = packetCount++;
    ogg_stream_packetin(&streamState, &packet);

    while((ret=ogg_stream_flush(&streamState, &oggPage))) {
        if(!ret)
            break;
        [newData appendBytes:oggPage.header length:oggPage.header_len];
        [newData appendBytes:oggPage.body length:oggPage.body_len];
    }

    oe_enc_opt         inopt;
    const char         *opus_version;
    char               ENCODER_string[1024];
    int                comment_padding=512;
    opus_version=opus_get_version_string();

    /*Vendor string should just be the encoder library,
     the ENCODER comment specifies the tool used.*/
    comment_init(&inopt.comments, &inopt.comments_length, opus_version);
    snprintf(ENCODER_string, sizeof(ENCODER_string), "IBM Watson Speech SDK");
    comment_add(&inopt.comments, &inopt.comments_length, "ENCODER", ENCODER_string);

    comment_pad(&inopt.comments, &inopt.comments_length, comment_padding);
    packet.packet = (unsigned char*)inopt.comments;
    packet.bytes = inopt.comments_length;
    packet.b_o_s = 0;
    packet.e_o_s = 0;
    packet.granulepos = 0;
    packet.packetno = packetCount++;
    ogg_stream_packetin(&streamState, &packet);

    while((ret=ogg_stream_flush(&streamState, &oggPage))) {
        if(!ret)
            break;
        [newData appendBytes:oggPage.header length:oggPage.header_len];
        [newData appendBytes:oggPage.body length:oggPage.body_len];
    }

//    NSLog(@"[Encoder] Ogg comments, %ld bytes are written\n", opusCommentsPacket.bytes);
    
    return newData;
}

/**
 *  Write OggOpus packet
 *
 *  @param data      Opus data
 *  @param frameSize Frame size
 *
 *  @return NSMutableData instance or nil
 */
- (NSMutableData *) writePacket: (NSData*) data frameSize:(int) frameSize rate: (int) sampleRate {
    int encGranulePos = (frameSize * 48000 / sampleRate);

    ogg_packet packet;
    
    packet.packet = (unsigned char *)[data bytes];
    packet.bytes = (long)([data length]);
    packet.b_o_s = 0;
    packet.e_o_s = 0;
    granulePos += encGranulePos;
    packet.granulepos = granulePos;
    packet.packetno = packetCount++;
    ogg_stream_packetin(&streamState, &packet);

    int ret;
    NSMutableData *newData = [[NSMutableData alloc] initWithCapacity: 0];
    while((ret=ogg_stream_flush(&streamState, &oggPage))) {
        if(!ret)
            break;
        [newData appendBytes:oggPage.header length:oggPage.header_len];
        [newData appendBytes:oggPage.body length:oggPage.body_len];
    }

    return newData;
}

static void comment_init(char **comments, long* length, const char *vendor_string)
{
    /*The 'vendor' field should be the actual encoding library used.*/
    long vendor_length=strlen(vendor_string);
    int user_comment_list_length=0;
    long len=8+4+vendor_length+4;
    char *p=(char*)malloc(len);
    if(p==NULL){
        fprintf(stderr, "malloc failed in comment_init()\n");
        exit(1);
    }
    memcpy(p, "OpusTags", 8);
    writeint(p, 8, vendor_length);
    memcpy(p+12, vendor_string, vendor_length);
    writeint(p, 12+vendor_length, user_comment_list_length);
    *length=len;
    *comments=p;
}

void comment_add(char **comments, long* length, char *tag, char *val)
{
    char* p=*comments;
    int vendor_length=readint(p, 8);
    int user_comment_list_length=readint(p, 8+4+vendor_length);
    long tag_len=(tag?strlen(tag)+1:0);
    long val_len=strlen(val);
    long len=(*length)+4+tag_len+val_len;
    
    p=(char*)realloc(p, len);
    if(p==NULL){
        fprintf(stderr, "realloc failed in comment_add()\n");
        exit(1);
    }
    
    writeint(p, *length, tag_len+val_len);      /* length of comment */
    if(tag){
        memcpy(p+*length+4, tag, tag_len);        /* comment tag */
        (p+*length+4)[tag_len-1] = '=';           /* separator */
    }
    memcpy(p+*length+4+tag_len, val, val_len);  /* comment */
    writeint(p, 8+4+vendor_length, user_comment_list_length+1);
    *comments=p;
    *length=len;
}

static void comment_pad(char **comments, long* length, int amount)
{
    if(amount>0){
        long i;
        long newlen;
        char* p=*comments;
        /*Make sure there is at least amount worth of padding free, and
         round up to the maximum that fits in the current ogg segments.*/
        newlen=(*length+amount+255)/255*255-1;
        p=realloc(p,newlen);
        if(p==NULL){
            fprintf(stderr,"realloc failed in comment_pad()\n");
            exit(1);
        }
        for(i=*length;i<newlen;i++)p[i]=0;
        *comments=p;
        *length=newlen;
    }
}
@end

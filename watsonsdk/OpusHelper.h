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
#import <AVFoundation/AVFoundation.h>
#import "CodecHeader.h"

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
((buf[base+2]<<16)&0xff0000)| \
((buf[base+1]<<8)&0xff00)| \
(buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
buf[base+2]=((val)>>16)&0xff; \
buf[base+1]=((val)>>8)&0xff; \
buf[base]=(val)&0xff; \
}while(0)

/* 120ms at 48000 */
#define MAX_FRAME_SIZE (960*6)
#define float2int(flt) ((int)(floor(.5+flt)))
#define IMIN(_a,_b) ((_a) < (_b) ? (_a) : (_b))   /**< Minimum int value.   */
#define IMAX(_a,_b) ((_a) > (_b) ? (_a) : (_b))   /**< Maximum int value.   */
#ifdef ENABLE_NLS
#include <libintl.h>
#define _(X) gettext(X)
#else
#define _(X) (X)
#define textdomain(X)
#define bindtextdomain(X, Y)
#endif
#ifdef gettext_noop
#define N_(X) gettext_noop(X)
#else
#define N_(X) (X)
#endif

typedef long (*audio_read_func)(void *src, float *buffer, int samples);

typedef struct {
    SpeexResamplerState *resampler;
    audio_read_func real_reader;
    void *real_readdata;
    float *bufs;
    int channels;
    int bufpos;
    int bufsize;
    int done;
} resampler;

typedef struct
{
    audio_read_func read_samples;
    void *readdata;
    opus_int64 total_samples_per_channel;
    int rawmode;
    int channels;
    int rate;
    int gain;
    int samplesize;
    int endianness;
    char *infilename;
    int ignorelength;
    int skip;
    int extraout;
    char *comments;
    long comments_length;
    int copy_comments;
    int copy_pictures;
} oe_enc_opt;


typedef struct {
    float * b_buf;
    float * a_buf;
    int fs;
    int mute;
} shapestate;

typedef struct {
    audio_read_func real_reader;
    void *real_readdata;
    ogg_int64_t *original_samples;
    int channels;
    int lpc_ptr;
    int *extra_samples;
    float *lpc_out;
} padder;

void setup_padder(oe_enc_opt *opt, ogg_int64_t *original_samples);

@interface OpusHelper : NSObject{
    ogg_page oggPage;
    ogg_int64_t packetCount;
    ogg_int16_t granulePos;
    ogg_stream_state streamState;
    oe_enc_opt         inopt;
    OpusHeader opusHeader;
    int currentFrameSize;
}

- (OpusHelper *) init;

- (BOOL) createEncoder: (int) rate frameSize:(int) frameSize;
- (NSData *) getOggOpusHeader:(int) sampleRate;

- (NSData*) encode:(NSData*) pcmData frameSize:(int) frameSize rate:(long) sampleRate isFooter: (BOOL) isFooter;

- (NSData*) opusToPCM:(NSData*) oggOpus sampleRate:(long) sampleRate;
@end

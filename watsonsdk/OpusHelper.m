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

#import "OpusHelper.h"

static unsigned int rngseed = 22222;
static inline unsigned int fast_rand(void) {
    rngseed = (rngseed * 96314165) + 907633515;
    return rngseed;
}

@interface OpusHelper()

@property (nonatomic) OpusMSEncoder *encoder;

@end

@implementation OpusHelper

/**
 *  Initialize OggHelper instance
 *
 *  @return OggHelper instance
 */
- (OpusHelper *) init{
    if (self = [super init]) {
        granulePos = 0;
        packetCount = 0;
        return self;
    }
    return nil;
}

/**
 *  Create Opus encoder
 *
 *  @param sampleRate Audio sample rate
 *
 *  @return BOOL
 */
- (BOOL) createEncoder: (int) rate frameSize:(int) frameSize {
    if (self.encoder) {
        return YES;
    }
    opus_int32         coding_rate=48000;
    int                complexity=10;
    int                with_hard_cbr=0;
    int                with_cvbr=0;
    int                expect_loss=0;
    ogg_int64_t        original_samples=0;
    int                chan=1;
    const char         *opus_version;
    char               ENCODER_string[22];
    int                bitrate = -1;
    int                ret = OPUS_OK;

    inopt.channels=chan;
    inopt.rate=coding_rate=rate;
    /* 0 dB gain is recommended unless you know what you're doing */
    inopt.gain=0;
    inopt.samplesize=160;
    inopt.endianness=0;
    inopt.rawmode=0;
    inopt.ignorelength=0;
    inopt.copy_comments=1;
    inopt.copy_pictures=1;
    
    opus_version=opus_get_version_string();
    
    /*Vendor string should just be the encoder library,
     the ENCODER comment specifies the tool used.*/
    comment_init(&inopt.comments, &inopt.comments_length, opus_version);
    snprintf(ENCODER_string, sizeof(ENCODER_string), "IBM Watson Speech SDK");
    comment_add(&inopt.comments, &inopt.comments_length, "ENCODER", ENCODER_string);
    
    rate=inopt.rate;
    chan=inopt.channels;
    inopt.skip=0;
    
    setup_padder(&inopt,&original_samples);
    
    if(rate>24000)coding_rate=48000;
    else if(rate>16000)coding_rate=24000;
    else if(rate>12000)coding_rate=16000;
    else if(rate>8000)coding_rate=12000;
    else coding_rate=8000;
    
    currentFrameSize=frameSize/(48000/coding_rate);
    
    /*Scale the resampler complexity, but only for 48000 output because
     the near-cutoff behavior matters a lot more at lower rates.*/
    if(rate!=coding_rate)setup_resample(&inopt,coding_rate==48000?(complexity+1)/2:5,coding_rate);
    
    /*OggOpus headers*/ /*FIXME: broke forcemono*/
    opusHeader.channels=chan;
    opusHeader.channel_mapping=opusHeader.channels>8?255:chan>2;
    opusHeader.input_sample_rate=rate;
    opusHeader.gain=inopt.gain;

    NSLog(@"Current frame size ---> %d", currentFrameSize);

    // sample rates are 8000, 12000, 16000, 24000, 48000
    // number of channels 1 or 2 mono stereo
    // app type choices OPUS_APPLICATION_VOIP, OPUS_APPLICATION_AUDIO, OPUS_APPLICATION_RESTRICTED_LOWDELAY
    //    self.encoder = opus_encoder_create(rate, opusHeader.channels, OPUS_APPLICATION_VOIP, &ret);
    
//    self.encoder = opus_multistream_encoder_create(coding_rate, chan, opusHeader.nb_streams, opusHeader.nb_coupled, opusHeader.stream_map, frameSize<480/(48000/coding_rate)?OPUS_APPLICATION_RESTRICTED_LOWDELAY:OPUS_APPLICATION_AUDIO, &ret);

    self.encoder = opus_multistream_surround_encoder_create(coding_rate, chan, opusHeader.channel_mapping, &opusHeader.nb_streams, &opusHeader.nb_coupled, opusHeader.stream_map, frameSize<480/(48000/coding_rate)?OPUS_APPLICATION_RESTRICTED_LOWDELAY:OPUS_APPLICATION_AUDIO, &ret);

    if (ret != OPUS_OK) {
        NSLog(@"Error setting up opus encoder, error code is %@",[self opusErrorMessage:ret]);
        return NO;
    }
    
    if(bitrate<0){
        /*Lower default rate for sampling rates [8000-44100) by a factor of (rate+16k)/(64k)*/
        bitrate=((64000*opusHeader.nb_streams+32000*opusHeader.nb_coupled)*
                  (IMIN(48,IMAX(8,((rate<44100?rate:48000)+1000)/1000))+16)+32)>>6;
    }
    
    if(bitrate>(1024000*opusHeader.channels)||bitrate<500){
        fprintf(stderr,"Error: Bitrate %ld bits/sec is insane.\nDid you mistake bits for kilobits?\n",(long)bitrate);
        fprintf(stderr,"--bitrate values from 6-256 kbit/sec per channel are meaningful.\n");
        return NO;
    }
    bitrate=IMIN(chan*256000,bitrate);
//    ret=opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(_bitrate));
    ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_BITRATE(bitrate));
    
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_BITRATE returned: %s\n",opus_strerror(ret));
        return NO;
    }
    
//    ret=opus_encoder_ctl(_encoder, OPUS_SET_VBR(!with_hard_cbr));
    ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_VBR(!with_hard_cbr));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_VBR returned: %s\n",opus_strerror(ret));
        return NO;
    }
    
    if(!with_hard_cbr){
//        ret=opus_encoder_ctl(_encoder, OPUS_SET_VBR_CONSTRAINT(with_cvbr));
        ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_VBR_CONSTRAINT(with_cvbr));
        if(ret!=OPUS_OK){
            fprintf(stderr,"Error OPUS_SET_VBR_CONSTRAINT returned: %s\n",opus_strerror(ret));
            return NO;
        }
    }
    
//    ret=opus_encoder_ctl(_encoder, OPUS_SET_COMPLEXITY(complexity));
    ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_COMPLEXITY(complexity));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_COMPLEXITY returned: %s\n",opus_strerror(ret));
        return NO;
    }
    
//    ret=opus_encoder_ctl(_encoder, OPUS_SET_PACKET_LOSS_PERC(expect_loss));
    ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_PACKET_LOSS_PERC(expect_loss));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_PACKET_LOSS_PERC returned: %s\n",opus_strerror(ret));
        return NO;
    }
    
#ifdef OPUS_SET_LSB_DEPTH
    ret=opus_multistream_encoder_ctl(_encoder, OPUS_SET_LSB_DEPTH(IMAX(8,IMIN(24,inopt.samplesize))));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Warning OPUS_SET_LSB_DEPTH returned: %s\n",opus_strerror(ret));
    }
#endif
    return YES;
}

/**
 *  Get data of OggOpus packet
 *
 *  @param sampleRate Audio sample rate
 *
 *  @return NSMutableData instance
 */
- (NSData *) getOggOpusHeader:(int) sampleRate {
    packetCount = 0;

    NSMutableData *newData = [[NSMutableData alloc] initWithCapacity:0];

    int ret;
    time_t             start_time;
    int                serialno;

    start_time = time(NULL);
    srand(((getpid()&65535)<<15)^(unsigned int)start_time);
    serialno=rand();
    
    /*Initialize Ogg stream struct*/
    if(ogg_stream_init(&streamState, serialno)==-1){
        fprintf(stderr,"Error: stream init failed\n");
        return nil;
    }

    unsigned char header[100];
    
    int headerSize = opus_header_to_packet(&opusHeader, header, 100);

    ogg_packet packet;
    packet.packet = header;
    packet.bytes = headerSize;
    packet.b_o_s = 1;
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
//    int                comment_padding=512;
//    comment_pad(&inopt.comments, &inopt.comments_length, comment_padding);
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
 *  Opus data encoding
 *
 *  @param pcmData   PCM data
 *  @param frameSize Frame size
 *
 *  @return NSMutableData
 */
- (NSData*) encode:(NSData*) pcmData frameSize:(int) frameSize rate:(long) sampleRate isFooter: (BOOL) isFooter {
//    float *data  = (float*) [pcmData bytes];
    opus_int16 *data  = (opus_int16*) [pcmData bytes];
    unsigned char *outBuffer  = malloc(pcmData.length * sizeof(unsigned char));
//    NSLog(@"frameSize->%d, currentFrameSize->%d", frameSize, currentFrameSize);
    // The length of the encoded packet
//    opus_int32 encodedByteCount = opus_encode(_encoder, data, frameSize, outBuffer, (opus_int32)pcmData.length);
    opus_int32 encodedByteCount = opus_multistream_encode(_encoder, data, frameSize, outBuffer, (opus_int32)[pcmData length]);
//    opus_int32 encodedByteCount = opus_multistream_encode_float(_encoder, data, currentFrameSize, outBuffer, (opus_int32)[pcmData length]);
//    opus_int32 encodedByteCount = opus_multistream_encode_float(_encoder, data, frameSize, outBuffer, (opus_int32)[pcmData length]);

    if (encodedByteCount < 0) {
        NSLog(@"encoding error %@",[self opusErrorMessage:encodedByteCount]);
        return nil;
    }

    int encGranulePos = (currentFrameSize * 48000 / sampleRate);

    ogg_packet packet;
    packet.packet = outBuffer;
    packet.bytes = encodedByteCount;
    packet.b_o_s = 0;
    packet.e_o_s = 0;
    granulePos += encGranulePos;
    packet.granulepos = granulePos;
    packet.packetno = packetCount++;
    ogg_stream_packetin(&streamState, &packet);

    if(ogg_stream_flush(&streamState, &oggPage)) {
        NSMutableData *newData = [[NSMutableData alloc] initWithCapacity: oggPage.header_len + oggPage.header_len];
        [newData appendBytes:oggPage.header length:oggPage.header_len];
        [newData appendBytes:oggPage.body length:oggPage.body_len];
        return newData;
    }
    
    return nil;
}

- (NSString*) opusErrorMessage:(int)errorCode {
    switch (errorCode) {
        case OPUS_BAD_ARG:
            return @"One or more invalid/out of range arguments";
        case OPUS_BUFFER_TOO_SMALL:
            return @"The mode struct passed is invalid";
        case OPUS_INTERNAL_ERROR:
            return @"The compressed data passed is corrupted";
        case OPUS_INVALID_PACKET:
            return @"Invalid/unsupported request number";
        case OPUS_INVALID_STATE:
            return @"An encoder or decoder structure is invalid or already freed.";
        case OPUS_UNIMPLEMENTED:
            return @"Invalid/unsupported request number.";
        case OPUS_ALLOC_FAIL:
            return @"Memory allocation has failed.";
        default:
            return nil;
            break;
    }
}

/**
 *  opusToPCM
 *
 *  @param oggopus - NSData object containing opus audio in ogg container
 *
 *  @return NSData = raw PCM
 */
- (NSData*) opusToPCM:(NSData*) oggOpus sampleRate:(long) sampleRate{
    
    return [self decodeOggOpus:oggOpus sampleRate:sampleRate];
    
}

/**
 *  decodeOggOpus
 *
 *  @param oggopus NSData containing ogg opus audio
 *
 *  @return NSData - contains PCM audio
 */
- (NSData*) decodeOggOpus:(NSData*) oggopus sampleRate:(long) sampleRate{
    NSMutableData *pcmOut = [[NSMutableData alloc] init];

    ogg_sync_state oy;
    ogg_page       og;
    ogg_packet     op;
    ogg_stream_state os;
//    ogg_int64_t audio_size=0;
    ogg_int64_t opus_serialno;
    ogg_int64_t page_granule=0;
    ogg_int64_t link_out=0;
    OpusMSDecoder *st=NULL;
    opus_int64 packet_count=0;
    
    int eos=0;
    int channels=-1;
    int mapping_family;
    int rate=(int)sampleRate;
    int wav_format=0;
    int preskip=0;
    int gran_offset=0;
    int has_opus_stream=0;
    int has_tags_packet=0;
    int fp=0;
    int streams=0;
    int frame_size=0;
    int total_links=0;
    int stream_init = 0;
    float manual_gain=0;
    float gain=1;
    float *output=0;
    
    // fixes
    shapestate shapemem;
    shapemem.a_buf=0;
    shapemem.b_buf=0;
    shapemem.mute=960;
    shapemem.fs=0;

    SpeexResamplerState *resampler=NULL;
    float loss_percent=-1;
    int dither=1;
    // fixes

    ogg_sync_init(&oy);
    
    int processedByteCount = 0;
    int opusLength = [[NSNumber numberWithLong:[oggopus length]] intValue];
    
    while (processedByteCount < opusLength)
    {
        char *data;
        int nb_read = (200 < opusLength - processedByteCount) ? 200 : opusLength - processedByteCount;
        
        data = ogg_sync_buffer(&oy, nb_read);
        
        NSRange range = {processedByteCount, nb_read};

        [oggopus getBytes:data range:range];
        processedByteCount += nb_read;

        ogg_sync_wrote(&oy, nb_read);
        
        /*Loop for all complete pages we got (most likely only one)*/
        while (ogg_sync_pageout(&oy, &og)==1)
        {
            if (stream_init == 0) {
                ogg_stream_init(&os, ogg_page_serialno(&og));
                stream_init = 1;
            }
            if (ogg_page_serialno(&og) != os.serialno) {
                /* so all streams are read. */
                ogg_stream_reset_serialno(&os, ogg_page_serialno(&og));
            }

            /*Add page to the bitstream*/
            ogg_stream_pagein(&os, &og);
            page_granule = ogg_page_granulepos(&og);
            
            /*Extract all available packets*/
            while (ogg_stream_packetout(&os, &op) == 1)
            {
                /*OggOpus streams are identified by a magic string in the initial
                 stream header.*/
                if (op.b_o_s && op.bytes>=8 && !memcmp(op.packet, "OpusHead", 8)) {
                    if(has_opus_stream && has_tags_packet)
                    {
                        /*If we're seeing another BOS OpusHead now it means
                         the stream is chained without an EOS.*/
                        has_opus_stream=0;
                        if(st)opus_multistream_decoder_destroy(st);
                        st=NULL;
                        NSLog(@"Warning: stream ended without EOS and a new stream began");
                    }
                    if(!has_opus_stream)
                    {
                        if(packet_count>0 && opus_serialno==os.serialno)
                        {
                            NSLog(@"Apparent chaining without changing serial number");
                            return nil;
                        }
                        opus_serialno = os.serialno;
                        has_opus_stream = 1;
                        has_tags_packet = 0;
                        link_out = 0;
                        packet_count = 0;
                        eos = 0;
                        total_links++;
                    } else {
                        NSLog(@"Warning: ignoring opus stream");
                    }
                }

                if (!has_opus_stream || os.serialno != opus_serialno)
                    break;
                /*If first packet in a logical stream, process the Opus header*/
                if (packet_count==0)
                {
                    st = process_header(&op, &rate, &mapping_family, &channels, &preskip, &gain, manual_gain, &streams, wav_format);
                    if (!st)
                        return nil;
                    
                    if(ogg_stream_packetout(&os, &op)!=0 || og.header[og.header_len-1]==255)
                    {
                        /*The format specifies that the initial header and tags packets are on their
                         own pages. To aid implementors in discovering that their files are wrong
                         we reject them explicitly here. In some player designs files like this would
                         fail even without an explicit test.*/
                        fprintf(stderr, "Extra packets on initial header page. Invalid stream.\n");
                        return nil;
                    }
                    /*Remember how many samples at the front we were told to skip
                     so that we can adjust the timestamp counting.*/
                    gran_offset=preskip;

                    /*Setup the memory for the dithered output*/
                    if(!shapemem.a_buf)
                    {
                        shapemem.a_buf=calloc(channels,sizeof(float)*4);
                        shapemem.b_buf=calloc(channels,sizeof(float)*4);
                        shapemem.fs=rate;
                    }
                    
                    if(!output)output=malloc(sizeof(float)*MAX_FRAME_SIZE*channels);
                    
                    /*Normal players should just play at 48000 or their maximum rate,
                     as described in the OggOpus spec.  But for commandline tools
                     like opusdec it can be desirable to exactly preserve the original
                     sampling rate and duration, so we have a resampler here.*/
                    if (rate != 48000 && resampler==NULL)
                    {
                        int err;
                        resampler = speex_resampler_init(channels, 48000, rate, 5, &err);
                        if (err!=0)
                            fprintf(stderr, "resampler error: %s\n", speex_resampler_strerror(err));
                        speex_resampler_skip_zeros(resampler);
                    }

                } else if (packet_count==1)
                {
                    has_tags_packet=1;
                    if(ogg_stream_packetout(&os, &op)!=0 || og.header[og.header_len-1]==255)
                    {
                        NSLog(@"Extra packets on initial tags page. Invalid stream.");
                        return nil;
                    }
                } else {
                    int ret = 0;
                    opus_int64 maxout;
                    opus_int64 outsamp;
                    int lost=0;
                    if (loss_percent>0 && 100*((float)rand())/RAND_MAX<loss_percent)
                        lost=1;
                    /*End of stream condition*/
                    if (op.e_o_s && os.serialno == opus_serialno)eos=1; /* don't care for anything except opus eos */

                    if (!lost){
                        /*Decode Opus packet*/
                        ret = opus_multistream_decode_float(st, (unsigned char*)op.packet, (opus_int32)op.bytes, output, MAX_FRAME_SIZE, 0);
                    } else {
                        /*Extract the original duration.
                         Normally you wouldn't have it for a lost packet, but normally the
                         transports used on lossy channels will effectively tell you.
                         This avoids opusdec squaking when the decoded samples and
                         granpos mismatches.*/
                        opus_int32 lost_size;
                        lost_size = MAX_FRAME_SIZE;
                        if(op.bytes>0){
                            opus_int32 spp;
                            spp=opus_packet_get_nb_frames(op.packet, (int)op.bytes);
                            if(spp>0){
                                spp*=opus_packet_get_samples_per_frame(op.packet, 48000/*decoding_rate*/);
                                if(spp>0)lost_size=spp;
                            }
                        }
                        /*Invoke packet loss concealment.*/
                        ret = opus_multistream_decode_float(st, NULL, 0, output, lost_size, 0);
                    }

                    /*If the decoder returned less than zero, we have an error.*/
                    if (ret<0)
                    {
                        fprintf (stderr, "Decoding error: %s\n", opus_strerror(ret));
                        break;
                    }
                    frame_size = ret;
                    
                    
                    /*Apply header gain, if we're not using an opus library new
                     enough to do this internally.*/
                    if (gain!=0){
                        for (int i=0;i<frame_size*channels;i++)
                            output[i] *= gain;
                    }
                    
                    /*This handles making sure that our output duration respects
                     the final end-trim by not letting the output sample count
                     get ahead of the granpos indicated value.*/
                    maxout=((page_granule-gran_offset)*rate/48000)-link_out;
//                    NSLog(@"frame_size->%d, page_granule->%lld, gran_offset=%d, maxout=%lld, lost=%d, packet_count=%lld", frame_size, page_granule, gran_offset, maxout, lost, packet_count);
//                    outsamp=audio_write(output, channels, frame_size, pcmOut, &preskip, 1,0>maxout?0:maxout,fp);
                    outsamp=audio_write(output, channels, frame_size, pcmOut, resampler, &preskip, dither?&shapemem:0, 1, 0>maxout?0:maxout,fp);
                    link_out+=outsamp;
                }
                packet_count++;
            }
            /*We're done, drain the resampler if we were using it.*/
            if(eos && resampler)
            {
                float *zeros;
                int drain;
                
                zeros=(float *)calloc(100*channels,sizeof(float));
                drain = speex_resampler_get_input_latency(resampler);
                do {
                    opus_int64 outsamp;
                    int tmp = drain;
                    if (tmp > 100)
                        tmp = 100;
                    outsamp=audio_write(zeros, channels, tmp, pcmOut, resampler, NULL, &shapemem, 1, ((page_granule-gran_offset)*rate/48000)-link_out,fp);
                    link_out+=outsamp;
//                    audio_size+=(fp?4:2)*outsamp*channels;
                    drain -= tmp;
                } while (drain>0);
                free(zeros);
                speex_resampler_destroy(resampler);
                resampler=NULL;
            }
            if(eos)
            {
                has_opus_stream=0;
                if(st)opus_multistream_decoder_destroy(st);
                st=NULL;
            }
            
        }
    }

    if(!total_links) fprintf (stderr, "This doesn't look like a Opus file\n");
    else
        NSLog(@"OGG/OPUS -> %lu, PCM -> %lu", (unsigned long)[oggopus length], (unsigned long)[pcmOut length]);

    opus_multistream_decoder_destroy(st);

    if (stream_init)
        ogg_stream_clear(&os);
    ogg_sync_clear(&oy);

    if(shapemem.a_buf)free(shapemem.a_buf);
    if(shapemem.b_buf)free(shapemem.b_buf);

    if(output) {
        free(output);
    }

    return pcmOut;
}

#pragma mark static methods

/*Process an Opus header and setup the opus decoder based on it.
 It takes several pointers for header values which are needed
 elsewhere in the code.*/
static OpusMSDecoder *process_header(ogg_packet *op, opus_int32 *rate,
                                     int *mapping_family, int *channels, int *preskip, float *gain,
                                     float manual_gain, int *streams, int wav_format)
{
    int err;
    OpusMSDecoder *st;
    OpusHeader header;
    
    if (opus_header_parse(op->packet, (int)op->bytes, &header)==0)
    {
        fprintf(stderr, "Cannot parse header\n");
        return NULL;
    }
    
    *mapping_family = header.channel_mapping;
    *channels = header.channels;
    
    if(!*rate)*rate=header.input_sample_rate;
    /*If the rate is unspecified we decode to 48000*/
    if(*rate==0)*rate=48000;
    if(*rate<8000||*rate>192000){
        fprintf(stderr,"Warning: Crazy input_rate %d, decoding to 48000 instead.\n",*rate);
        *rate=48000;
    }
    if(header.input_sample_rate != *rate)
        fprintf(stderr, "\n\n\n*** Sample rate detected: %d, using: %d, channels: %d, streams: %d ***\n\n\n", header.input_sample_rate, *rate, *channels, header.nb_streams);

    *preskip = header.preskip;
    st = opus_multistream_decoder_create(*rate, header.channels, header.nb_streams, header.nb_coupled, header.stream_map, &err);
    if(err != OPUS_OK){
        fprintf(stderr, "Cannot create decoder: %s\n", opus_strerror(err));
        return NULL;
    }
    if (!st)
    {
        fprintf (stderr, "Decoder initialization failed: %s\n", opus_strerror(err));
        return NULL;
    }
    
    *streams=header.nb_streams;
    
    if(header.gain!=0 || manual_gain!=0)
    {
        /*Gain API added in a newer libopus version, if we don't have it
         we apply the gain ourselves. We also add in a user provided
         manual gain at the same time.*/
        int gainadj = (int)(manual_gain*256.)+header.gain;
#ifdef OPUS_SET_GAIN
        err=opus_multistream_decoder_ctl(st,OPUS_SET_GAIN(gainadj));
        if(err==OPUS_UNIMPLEMENTED)
        {
#endif
            *gain = pow(10., gainadj/5120.);
#ifdef OPUS_SET_GAIN
        } else if (err!=OPUS_OK)
        {
            fprintf (stderr, "Error setting gain: %s\n", opus_strerror(err));
            return NULL;
        }
#endif
    }
    return st;
}

opus_int64 audio_write(float *pcm, int channels, int frame_size, NSMutableData *fout, SpeexResamplerState *resampler,
                       int *skip, shapestate *shapemem, int file, opus_int64 maxout, int fp)
{
    opus_int64 sampout=0;
    int i,tmp_skip;
    opus_int64 ret;
    spx_uint32_t out_len;
    short *out;
    float *buf;
    float *output;
    out=alloca(sizeof(short)*MAX_FRAME_SIZE*channels);
    buf=alloca(sizeof(float)*MAX_FRAME_SIZE*channels);
    maxout=maxout<0?0:maxout;
    do {
        if (skip){
            tmp_skip = (*skip>frame_size) ? (int)frame_size : *skip;
            *skip -= tmp_skip;
        } else {
            tmp_skip = 0;
        }
        if (resampler){
            unsigned in_len;
            output=buf;
            in_len = frame_size-tmp_skip;
            out_len = 1024<maxout?1024:(spx_uint32_t)maxout;
            speex_resampler_process_interleaved_float(resampler, pcm+channels*tmp_skip, &in_len, buf, &out_len);
            pcm += channels*(in_len+tmp_skip);
            frame_size -= in_len+tmp_skip;
        } else {
            output=pcm+channels*tmp_skip;
            out_len=frame_size-tmp_skip;
            frame_size=0;
        }
        
        if(!file||!fp)
        {
            /*Convert to short and save to output file*/
            if (shapemem){
                shape_dither_toshort(shapemem,out,output,out_len,channels);
            }else{
                for (i=0;i<(int)out_len*channels;i++)
                    out[i]=(short)float2int(fmaxf(-32768,fminf(output[i]*32768.f,32767)));
            }
            if ((le_short(1)!=1)&&file){
                for (i=0;i<(int)out_len*channels;i++)
                    out[i]=le_short(out[i]);
            }
        }
        
        if(maxout>0)
        {
            // refer to this method: size_t	 fwrite(const void * __restrict, size_t, size_t, FILE * __restrict) __DARWIN_ALIAS(fwrite);
//            ret=fwrite(fp?(char *)output:(char *)out, (fp?4:2)*channels, out_len<maxout?out_len:maxout, fout);
            ret = out_len<maxout?out_len:maxout;
            [fout appendBytes:out length:out_len*2];
            sampout+=ret;
            maxout-=ret;
        }
    } while (frame_size>0 && maxout>0);
    return sampout;
}

/* This implements a 16 bit quantization with full triangular dither
 and IIR noise shaping. The noise shaping filters were designed by
 Sebastian Gesemann based on the LAME ATH curves with flattening
 to limit their peak gain to 20 dB.
 (Everyone elses' noise shaping filters are mildly crazy)
 The 48kHz version of this filter is just a warped version of the
 44.1kHz filter and probably could be improved by shifting the
 HF shelf up in frequency a little bit since 48k has a bit more
 room and being more conservative against bat-ears is probably
 more important than more noise suppression.
 This process can increase the peak level of the signal (in theory
 by the peak error of 1.5 +20 dB though this much is unobservable rare)
 so to avoid clipping the signal is attenuated by a couple thousandths
 of a dB. Initially the approach taken here was to only attenuate by
 the 99.9th percentile, making clipping rare but not impossible (like
 SoX) but the limited gain of the filter means that the worst case was
 only two thousandths of a dB more, so this just uses the worst case.
 The attenuation is probably also helpful to prevent clipping in the DAC
 reconstruction filters or downstream resampling in any case.*/
static inline void shape_dither_toshort(shapestate *_ss, short *_o, float *_i, int _n, int _CC)
{
    const float gains[3]={32768.f-15.f,32768.f-15.f,32768.f-3.f};
    const float fcoef[3][8] =
    {
        {2.2374f, -.7339f, -.1251f, -.6033f, 0.9030f, .0116f, -.5853f, -.2571f}, /* 48.0kHz noise shaping filter sd=2.34*/
        {2.2061f, -.4706f, -.2534f, -.6214f, 1.0587f, .0676f, -.6054f, -.2738f}, /* 44.1kHz noise shaping filter sd=2.51*/
        {1.0000f, 0.0000f, 0.0000f, 0.0000f, 0.0000f,0.0000f, 0.0000f, 0.0000f}, /* lowpass noise shaping filter sd=0.65*/
    };
    int i;
    int rate=_ss->fs==44100?1:(_ss->fs==48000?0:2);
    float gain=gains[rate];
    float *b_buf;
    float *a_buf;
    int mute=_ss->mute;
    b_buf=_ss->b_buf;
    a_buf=_ss->a_buf;
    /*In order to avoid replacing digital silence with quiet dither noise
     we mute if the output has been silent for a while*/
    if(mute>64)
        memset(a_buf,0,sizeof(float)*_CC*4);
    for(i=0;i<_n;i++)
    {
        int c;
        int pos = i*_CC;
        int silent=1;
        for(c=0;c<_CC;c++)
        {
            int j, si;
            float r,s,err=0;
            silent&=_i[pos+c]==0;
            s=_i[pos+c]*gain;
            for(j=0;j<4;j++)
                err += fcoef[rate][j]*b_buf[c*4+j] - fcoef[rate][j+4]*a_buf[c*4+j];
            memmove(&a_buf[c*4+1],&a_buf[c*4],sizeof(float)*3);
            memmove(&b_buf[c*4+1],&b_buf[c*4],sizeof(float)*3);
            a_buf[c*4]=err;
            s = s - err;
            r=(float)fast_rand()*(1/(float)UINT_MAX) - (float)fast_rand()*(1/(float)UINT_MAX);
            if (mute>16)r=0;
            /*Clamp in float out of paranoia that the input will be >96 dBFS and wrap if the
             integer is clamped.*/
            _o[pos+c] = si = float2int(fmaxf(-32768,fminf(s + r,32767)));
            /*Including clipping in the noise shaping is generally disastrous:
             the futile effort to restore the clipped energy results in more clipping.
             However, small amounts-- at the level which could normally be created by
             dither and rounding-- are harmless and can even reduce clipping somewhat
             due to the clipping sometimes reducing the dither+rounding error.*/
            b_buf[c*4] = (mute>16)?0:fmaxf(-1.5f,fminf(si - s,1.5f));
        }
        mute++;
        if(!silent)mute=0;
    }
    _ss->mute=IMIN(mute,960);
}

static long read_resampled(void *d, float *buffer, int samples)
{
    resampler *rs = d;
    int out_samples=0;
    float *pcmbuf;
    int *inbuf;
    pcmbuf=rs->bufs;
    inbuf=&rs->bufpos;
    while(out_samples<samples){
        int i;
        int reading, ret;
        unsigned in_len, out_len;
        out_len=samples-out_samples;
        reading=rs->bufsize-*inbuf;
        if(reading>1024)reading=1024;
        ret=(int)rs->real_reader(rs->real_readdata, pcmbuf+*inbuf*rs->channels, reading);
        *inbuf+=ret;
        in_len=*inbuf;
        speex_resampler_process_interleaved_float(rs->resampler, pcmbuf, &in_len, buffer+out_samples*rs->channels, &out_len);
        out_samples+=out_len;
        if(ret==0&&in_len==0){
            for(i=out_samples*rs->channels;i<samples*rs->channels;i++)buffer[i]=0;
            return out_samples;
        }
        for(i=0;i<rs->channels*(*inbuf-(long int)in_len);i++)pcmbuf[i]=pcmbuf[i+rs->channels*in_len];
        *inbuf-=in_len;
    }
    return out_samples;
}

int setup_resample(oe_enc_opt *opt, int complexity, long outfreq) {
    resampler *rs = calloc(1, sizeof(resampler));
    int err;
    
    rs->bufsize = 5760*2; /* Have at least two output frames worth, just in case of ugly ratios */
    rs->bufpos = 0;
    
    rs->real_reader = opt->read_samples;
    rs->real_readdata = opt->readdata;
    rs->channels = opt->channels;
    rs->done = 0;
    rs->resampler = speex_resampler_init(rs->channels, (spx_uint32_t)opt->rate, (spx_uint32_t)outfreq, complexity, &err);
    if(err!=0)fprintf(stderr, _("resampler error: %s\n"), speex_resampler_strerror(err));
    
    opt->skip+=speex_resampler_get_output_latency(rs->resampler);
    
    rs->bufs = malloc(sizeof(float) * rs->bufsize * opt->channels);
    
    opt->read_samples = read_resampled;
    opt->readdata = rs;
    if(opt->total_samples_per_channel)
        opt->total_samples_per_channel = (int)((float)opt->total_samples_per_channel *
                                               ((float)outfreq/(float)opt->rate));
    opt->rate = (int)outfreq;
    
    return 0;
}

/* Read audio data, appending padding to make up any gap
 * between the available and requested number of samples
 * with LPC-predicted data to minimize the pertubation of
 * the valid data that falls in the same frame.
 */
static long read_padder(void *data, float *buffer, int samples) {
    padder *d = data;
    long in_samples = d->real_reader(d->real_readdata, buffer, samples);
    int i, extra=0;
    const int lpc_order=32;
    
    if(d->original_samples)*d->original_samples+=in_samples;
    
    if(in_samples<samples){
        if(d->lpc_ptr<0){
            d->lpc_out=calloc(d->channels * *d->extra_samples, sizeof(*d->lpc_out));
            if(in_samples>lpc_order*2){
                float *lpc=alloca(lpc_order*sizeof(*lpc));
                for(i=0;i<d->channels;i++){
                    vorbis_lpc_from_data(buffer+i,lpc,(int)in_samples,lpc_order,d->channels);
                    vorbis_lpc_predict(lpc,buffer+i+(in_samples-lpc_order)*d->channels,
                                       lpc_order,d->lpc_out+i,*d->extra_samples,d->channels);
                }
            }
            d->lpc_ptr=0;
        }
        extra=samples-(int)in_samples;
        if(extra>*d->extra_samples)extra=*d->extra_samples;
        *d->extra_samples-=extra;
    }
    memcpy(buffer+in_samples*d->channels,d->lpc_out+d->lpc_ptr*d->channels,extra*d->channels*sizeof(*buffer));
    d->lpc_ptr+=extra;
    return in_samples+extra;
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

void setup_padder(oe_enc_opt *opt,ogg_int64_t *original_samples) {
    padder *d = calloc(1, sizeof(padder));

    d->real_reader = opt->read_samples;
    d->real_readdata = opt->readdata;

    opt->read_samples = read_padder;
    opt->readdata = d;
    d->channels = opt->channels;
    d->extra_samples = &opt->extraout;
    d->original_samples=original_samples;
    d->lpc_ptr = -1;
    d->lpc_out = NULL;
}

- (void) dealloc {
    if (_encoder) {
//        opus_encoder_destroy(_encoder);
        opus_multistream_encoder_destroy(_encoder);
    }
//    if (_encoderOutputBuffer) {
//        free(_encoderOutputBuffer);
//    }
}
@end

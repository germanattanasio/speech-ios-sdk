
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#if !defined WIN32 && !defined _WIN32
#include <unistd.h>
#endif
#ifdef HAVE_GETOPT_H
#include <getopt.h>
#endif
#ifndef HAVE_GETOPT_LONG
#include "getopt_win.h"
#endif
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <speex.h>
#include "ogg.h"
#include "wav_io.h"
#include "speex_header.h"
#include "speex_stereo.h"
#include "speex_preprocess.h"

#if defined WIN32 || defined _WIN32
/* We need the following two to set stdout to binary */
#include <io.h>
#include <fcntl.h>
#endif

#include "skeleton.h"
#include "watsonSpeexenc.h"

#define MAX_FRAME_SIZE 2000
#define MAX_FRAME_BYTES 2000

void headerToFile(FILE *fout_tmp, int serialno,long *pageSeq) {
    ogg_stream_state os;
    ogg_page og;
    ogg_packet 		 op;
    
    int rate=16000;
    
    const SpeexMode *mode=NULL;
    int modeID =SPEEX_MODEID_WB;
    int nframes=1;
    spx_int32_t vbr_enabled=0;
    mode = speex_lib_get_mode (modeID);
    
    SpeexHeader header;
    
    speex_init_header(&header, rate, 1, mode);
	header.frames_per_packet=nframes;
	header.vbr=vbr_enabled;
	header.nb_channels = 1;
    
    //char vendor_string[64];
    //char *comments;
	//int comments_length;
    //comment_init(&comments, &comments_length, vendor_string);
    
    int result,ret;
    
    /*Initialize Ogg stream struct*/
	if (ogg_stream_init(&os, serialno)==-1){
		fprintf(stderr,"Error: stream init failed\n");
		exit(1);
	}
    
	{
		int packet_size;
		op.packet = (unsigned char *)speex_header_to_packet(&header, &packet_size);
		op.bytes = packet_size;
		op.b_o_s = 1;
		op.e_o_s = 0;
		op.granulepos = 0;
		op.packetno = 0;
		ogg_stream_packetin(&os, &op);
        
        free(op.packet);
        
		while((result = ogg_stream_flush(&os, &og)))
		{
            if(!result) break;
            ret = oe_write_page(&og, fout_tmp);
			if(ret != og.header_len + og.body_len){
				fprintf (stderr,"Error: failed writing header to output stream\n");
				exit(1);
			}
		}
        
		//op.packet = (unsigned char *)comments;
		//op.bytes = comments_length;
		op.b_o_s = 0;
		op.e_o_s = 0;
		op.granulepos = 0;
		op.packetno = 1;
		ogg_stream_packetin(&os, &op);
        
        
	}
    
    
	/* writing the rest of the speex header packets */
    //TODO: don't know why need this
    /*
	while((result = ogg_stream_flush(&os, &og))) {
        if(!result) break;
		ret = oe_write_page(&og, fout_tmp);
		if(ret != og.header_len + og.body_len){
			fprintf (stderr,"Error: failed writing header to output stream\n");
			exit(1);
		}
	}
     */
    
    *pageSeq = os.pageno;
}

int pcmEnc(const char *filepathPCM,const char *filepathSPX, _Bool hasHeader, int serialno, long *pageSeq) {
    printf("Call pcmEnc hasHeader=%d, serialno=%d\n", hasHeader, serialno);
    
	int nb_samples, total_samples=0, nb_encoded;
    const char *inFile, *outFile;
	FILE *fin, *fout;
	short input[MAX_FRAME_SIZE];
	spx_int32_t frame_size;
	spx_int32_t vbr_enabled=0;
	spx_int32_t vbr_max=0;
	int abr_enabled=0;
	spx_int32_t vad_enabled=0;
	spx_int32_t dtx_enabled=0;
	int nbBytes;
	const SpeexMode *mode=NULL;
	int modeID = -1;
	void *st;
	SpeexBits bits;
	char cbits[MAX_FRAME_BYTES];
    
	spx_int32_t rate=0;
	int chan=1;
	int fmt=16;
	spx_int32_t quality=-1;
	float vbr_quality=-1;
	int lsb=1;
	ogg_stream_state os;
	ogg_page 		 og;
	ogg_packet 		 op;
	int ret;
	int id=-1;
	
	int nframes=1;
	spx_int32_t complexity=3;
	const char* speex_version;
	char vendor_string[64];
	int close_in=0, close_out=0;
	int eos=0;
	char first_bytes[12];
	spx_int32_t tmp;
	SpeexPreprocessState *preprocess = NULL;
	int denoise_enabled=0, agc_enabled=0;
	spx_int32_t lookahead = 0;
    
	speex_lib_ctl(SPEEX_LIB_GET_VERSION_STRING, (void*)&speex_version);
	snprintf(vendor_string, sizeof(vendor_string), "Encoded with Speex %s", speex_version);
    
	modeID=SPEEX_MODEID_WB;
    
	quality = 7;
	vbr_quality=7;
    
	inFile=filepathPCM;
	outFile=filepathSPX;
    
	/*Initialize Ogg stream struct*/
	//srand(time(NULL));//rand()
	if (ogg_stream_init(&os, serialno)==-1){
		fprintf(stderr,"Error: stream init failed\n");
		exit(1);
	}
    
    fin = fopen(inFile, "rb");
    if (!fin){
        perror(inFile);
        exit(1);
    }
    close_in=1;
    modeID = SPEEX_MODEID_WB;
    rate=16000;
	mode = speex_lib_get_mode (modeID);
    
    
	/*fprintf (stderr, "Encoding %d Hz audio at %d bps using %s mode\n",
     header.rate, mode->bitrate, mode->modeName);*/
    
	/*Initialize Speex encoder*/
	st = speex_encoder_init(mode);
    
    fout = fopen(outFile, "wb");
    if (!fout) {
        perror(outFile);
        exit(1);
    }
    close_out=1;
    
	speex_encoder_ctl(st, SPEEX_GET_FRAME_SIZE, &frame_size);
	speex_encoder_ctl(st, SPEEX_SET_COMPLEXITY, &complexity);
	speex_encoder_ctl(st, SPEEX_SET_SAMPLING_RATE, &rate);
    
	if (quality >= 0){
		if (vbr_enabled){
			if (vbr_max>0)
				speex_encoder_ctl(st, SPEEX_SET_VBR_MAX_BITRATE, &vbr_max);
			speex_encoder_ctl(st, SPEEX_SET_VBR_QUALITY, &vbr_quality);
		}
		else
			speex_encoder_ctl(st, SPEEX_SET_QUALITY, &quality);
	}
    
	if (vbr_enabled){
		tmp=1;
		speex_encoder_ctl(st, SPEEX_SET_VBR, &tmp);
	} else if (vad_enabled){
		tmp=1;
		speex_encoder_ctl(st, SPEEX_SET_VAD, &tmp);
	}
	if (dtx_enabled)
		speex_encoder_ctl(st, SPEEX_SET_DTX, &tmp);
	if (dtx_enabled && !(vbr_enabled || abr_enabled || vad_enabled))
	{
		fprintf (stderr, "Warning: --dtx is useless without --vad, --vbr or --abr\n");
	} else if ((vbr_enabled || abr_enabled) && (vad_enabled))
	{
		fprintf (stderr, "Warning: --vad is already implied by --vbr or --abr\n");
	}
    
    
	if (abr_enabled){
		speex_encoder_ctl(st, SPEEX_SET_ABR, &abr_enabled);
	}
    
	speex_encoder_ctl(st, SPEEX_GET_LOOKAHEAD, &lookahead);
    
	if (denoise_enabled || agc_enabled){
		preprocess = speex_preprocess_state_init(frame_size, rate);
		speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_DENOISE, &denoise_enabled);
		speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_AGC, &agc_enabled);
		lookahead += frame_size;
	}
    
	/*Write header*/
    
    printf("Begin write header if needed");
    if (hasHeader) {
        headerToFile(fout, serialno, pageSeq);
        printf("\nDone header, pageSeq=%ld", *pageSeq);
    }
    //----------
    

    os.pageno = *pageSeq;
    
	//free(comments);
    
	speex_bits_init(&bits);
    
    nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, first_bytes, NULL);
	if (nb_samples==0)
		eos=1;
	total_samples += nb_samples;
	nb_encoded = -lookahead;
    
    
    /*Main encoding loop (one frame per iteration)*/
    
	while (!eos || total_samples>nb_encoded)
	{
		++id;
		if (preprocess)
			speex_preprocess(preprocess, input, NULL);
        
        speex_encode_int(st, input, &bits);
        
		nb_encoded += frame_size;
        
        
        nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, NULL, NULL);
		if (nb_samples==0) {
			eos=1;
		}
        
		if (eos && total_samples<=nb_encoded)
			op.e_o_s = 1;
		else
			op.e_o_s = 0;
		total_samples += nb_samples;
        
		if ((id+1)%nframes!=0)
			continue;
		speex_bits_insert_terminator(&bits);
		nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
		speex_bits_reset(&bits);
		op.packet = (unsigned char *)cbits;
		op.bytes = nbBytes;
		op.b_o_s = 0;
		/*Is this redundent?*/
		if (eos && total_samples<=nb_encoded)
			op.e_o_s = 1;
		else
			op.e_o_s = 0;
		op.granulepos = (id+1)*frame_size-lookahead;
		if (op.granulepos>total_samples)
			op.granulepos = total_samples;
		/*printf ("granulepos: %d %d %d %d %d %d\n", (int)op.granulepos, id, nframes, lookahead, 5, 6);*/
		op.packetno = 2+id/nframes;
        
        ogg_stream_packetin(&os, &op);
        
		/*Write all new pages (most likely 0 or 1)*/
        
        //streaming mode
        /*
        if (!hasHeader && (os.e_o_s&&os.lacing_fill)) {
            printf("3333, %d | %ld\n", os.e_o_s, os.lacing_fill);
            
        }*/
        
        while (ogg_stream_pageout(&os,&og)) {
            //printf("22222 %ld | %ld\n", og.header_len, og.body_len);
            //TODO: having a small frame before each large frame, so temporary remove it.
            if (!hasHeader && og.body_len < 100) {
                continue;
            }

			ret = oe_write_page(&og, fout);
			if(ret != og.header_len + og.body_len) {
				fprintf (stderr,"Error: failed writing header to output stream\n");
				exit(1);
			}
		}
	}
    
	if ((id+1)%nframes!=0) {
		while ((id+1)%nframes!=0)
		{
			++id;
			speex_bits_pack(&bits, 15, 5);
		}
		nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
		op.packet = (unsigned char *)cbits;
		op.bytes = nbBytes;
		op.b_o_s = 0;
		op.e_o_s = 1;
		op.granulepos = (id+1)*frame_size-lookahead;
		if (op.granulepos>total_samples)
			op.granulepos = total_samples;
        
		op.packetno = 2+id/nframes;
		ogg_stream_packetin(&os, &op);
	}
    
    
	/*Flush all pages left to be written*/
    /*
	while (ogg_stream_flush(&os, &og)) {
		ret = oe_write_page(&og, fout);
		if(ret != og.header_len + og.body_len) {
			fprintf (stderr,"Error: failed writing header to output stream\n");
			exit(1);
		}
	}
     */
    
    *pageSeq = os.pageno;
    
	speex_encoder_destroy(st);
	speex_bits_destroy(&bits);
	ogg_stream_clear(&os);
    
	if (close_in)
		fclose(fin);
	if (close_out)
		fclose(fout);
	return 0;
}

//in progress...
int pcmEncInMemory(const char *filepathPCM,const char *filepathSPX, _Bool hasHeader, int serialno, long *pageSeq) {
    printf("Call pcmEnc hasHeader=%d, serialno=%d\n", hasHeader, serialno);
    
	int nb_samples, total_samples=0, nb_encoded;
    const char *inFile, *outFile;
	FILE *fin, *fout;
	short input[MAX_FRAME_SIZE];
	spx_int32_t frame_size;
	spx_int32_t vbr_enabled=0;
	spx_int32_t vbr_max=0;
	int abr_enabled=0;
	spx_int32_t vad_enabled=0;
	spx_int32_t dtx_enabled=0;
	int nbBytes;
	const SpeexMode *mode=NULL;
	int modeID = -1;
	void *st;
	SpeexBits bits;
	char cbits[MAX_FRAME_BYTES];
    
	spx_int32_t rate=0;
	int chan=1;
	int fmt=16;
	spx_int32_t quality=-1;
	float vbr_quality=-1;
	int lsb=1;
	ogg_stream_state os;
	ogg_page 		 og;
	ogg_packet 		 op;
	int ret;
	int id=-1;
	
	int nframes=1;
	spx_int32_t complexity=3;
	const char* speex_version;
	char vendor_string[64];
	int close_in=0, close_out=0;
	int eos=0;
	char first_bytes[12];
	spx_int32_t tmp;
	SpeexPreprocessState *preprocess = NULL;
	int denoise_enabled=0, agc_enabled=0;
	spx_int32_t lookahead = 0;
    
	speex_lib_ctl(SPEEX_LIB_GET_VERSION_STRING, (void*)&speex_version);
	snprintf(vendor_string, sizeof(vendor_string), "Encoded with Speex %s", speex_version);
    
	modeID=SPEEX_MODEID_WB;
    
	quality = 7;
	vbr_quality=7;
    
	inFile=filepathPCM;
	outFile=filepathSPX;
    
	/*Initialize Ogg stream struct*/
	//srand(time(NULL));//rand()
	if (ogg_stream_init(&os, serialno)==-1){
		fprintf(stderr,"Error: stream init failed\n");
		exit(1);
	}
    
    fin = fopen(inFile, "rb");
    if (!fin){
        perror(inFile);
        exit(1);
    }
    close_in=1;
    modeID = SPEEX_MODEID_WB;
    rate=16000;
	mode = speex_lib_get_mode (modeID);
    
    
	/*fprintf (stderr, "Encoding %d Hz audio at %d bps using %s mode\n",
     header.rate, mode->bitrate, mode->modeName);*/
    
	/*Initialize Speex encoder*/
	st = speex_encoder_init(mode);
    
    fout = fopen(outFile, "wb");
    if (!fout) {
        perror(outFile);
        exit(1);
    }
    close_out=1;
    
	speex_encoder_ctl(st, SPEEX_GET_FRAME_SIZE, &frame_size);
	speex_encoder_ctl(st, SPEEX_SET_COMPLEXITY, &complexity);
	speex_encoder_ctl(st, SPEEX_SET_SAMPLING_RATE, &rate);
    
	if (quality >= 0){
		if (vbr_enabled){
			if (vbr_max>0)
				speex_encoder_ctl(st, SPEEX_SET_VBR_MAX_BITRATE, &vbr_max);
			speex_encoder_ctl(st, SPEEX_SET_VBR_QUALITY, &vbr_quality);
		}
		else
			speex_encoder_ctl(st, SPEEX_SET_QUALITY, &quality);
	}
    
	if (vbr_enabled){
		tmp=1;
		speex_encoder_ctl(st, SPEEX_SET_VBR, &tmp);
	} else if (vad_enabled){
		tmp=1;
		speex_encoder_ctl(st, SPEEX_SET_VAD, &tmp);
	}
	if (dtx_enabled)
		speex_encoder_ctl(st, SPEEX_SET_DTX, &tmp);
	if (dtx_enabled && !(vbr_enabled || abr_enabled || vad_enabled))
	{
		fprintf (stderr, "Warning: --dtx is useless without --vad, --vbr or --abr\n");
	} else if ((vbr_enabled || abr_enabled) && (vad_enabled))
	{
		fprintf (stderr, "Warning: --vad is already implied by --vbr or --abr\n");
	}
    
    
	if (abr_enabled){
		speex_encoder_ctl(st, SPEEX_SET_ABR, &abr_enabled);
	}
    
	speex_encoder_ctl(st, SPEEX_GET_LOOKAHEAD, &lookahead);
    
	if (denoise_enabled || agc_enabled){
		preprocess = speex_preprocess_state_init(frame_size, rate);
		speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_DENOISE, &denoise_enabled);
		speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_AGC, &agc_enabled);
		lookahead += frame_size;
	}
    
	/*Write header*/
    
    printf("Begin write header if needed");
    if (hasHeader) {
        headerToFile(fout, serialno, pageSeq);
        printf("\nDone header, pageSeq=%ld", *pageSeq);
    }
    //----------
    
    
    os.pageno = *pageSeq;
    
	//free(comments);
    
	speex_bits_init(&bits);
    
    nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, first_bytes, NULL);
	if (nb_samples==0)
		eos=1;
	total_samples += nb_samples;
	nb_encoded = -lookahead;
    
    
    /*Main encoding loop (one frame per iteration)*/
    
	while (!eos || total_samples>nb_encoded)
	{
		++id;
		if (preprocess)
			speex_preprocess(preprocess, input, NULL);
        
        speex_encode_int(st, input, &bits);
        
		nb_encoded += frame_size;
        
        
        nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, NULL, NULL);
		if (nb_samples==0) {
			eos=1;
		}
        
		if (eos && total_samples<=nb_encoded)
			op.e_o_s = 1;
		else
			op.e_o_s = 0;
		total_samples += nb_samples;
        
		if ((id+1)%nframes!=0)
			continue;
		speex_bits_insert_terminator(&bits);
		nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
		speex_bits_reset(&bits);
		op.packet = (unsigned char *)cbits;
		op.bytes = nbBytes;
		op.b_o_s = 0;
		/*Is this redundent?*/
		if (eos && total_samples<=nb_encoded)
			op.e_o_s = 1;
		else
			op.e_o_s = 0;
		op.granulepos = (id+1)*frame_size-lookahead;
		if (op.granulepos>total_samples)
			op.granulepos = total_samples;
		/*printf ("granulepos: %d %d %d %d %d %d\n", (int)op.granulepos, id, nframes, lookahead, 5, 6);*/
		op.packetno = 2+id/nframes;
        
        ogg_stream_packetin(&os, &op);
        
		/*Write all new pages (most likely 0 or 1)*/
        
        //streaming mode
        /*
         if (!hasHeader && (os.e_o_s&&os.lacing_fill)) {
         printf("3333, %d | %ld\n", os.e_o_s, os.lacing_fill);
         
         }*/
        
        while (ogg_stream_pageout(&os,&og)) {
            //printf("22222 %ld | %ld\n", og.header_len, og.body_len);
            //TODO: having a small frame before each large frame, so temporary remove it.
            if (!hasHeader && og.body_len < 100) {
                continue;
            }
            
			ret = oe_write_page(&og, fout);
			if(ret != og.header_len + og.body_len) {
				fprintf (stderr,"Error: failed writing header to output stream\n");
				exit(1);
			}
		}
	}
    
	if ((id+1)%nframes!=0) {
		while ((id+1)%nframes!=0)
		{
			++id;
			speex_bits_pack(&bits, 15, 5);
		}
		nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
		op.packet = (unsigned char *)cbits;
		op.bytes = nbBytes;
		op.b_o_s = 0;
		op.e_o_s = 1;
		op.granulepos = (id+1)*frame_size-lookahead;
		if (op.granulepos>total_samples)
			op.granulepos = total_samples;
        
		op.packetno = 2+id/nframes;
		ogg_stream_packetin(&os, &op);
	}
    
    
	/*Flush all pages left to be written*/
    /*
     while (ogg_stream_flush(&os, &og)) {
     ret = oe_write_page(&og, fout);
     if(ret != og.header_len + og.body_len) {
     fprintf (stderr,"Error: failed writing header to output stream\n");
     exit(1);
     }
     }
     */
    
    *pageSeq = os.pageno;
    
	speex_encoder_destroy(st);
	speex_bits_destroy(&bits);
	ogg_stream_clear(&os);
    
	if (close_in)
		fclose(fin);
	if (close_out)
		fclose(fout);
	return 0;
}

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
((buf[base+2]<<16)&0xff0000)| \
((buf[base+1]<<8)&0xff00)| \
(buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
buf[base+2]=((val)>>16)&0xff; \
buf[base+1]=((val)>>8)&0xff; \
buf[base]=(val)&0xff; \
}while(0)

#undef readint
#undef writeint

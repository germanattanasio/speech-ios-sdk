//
//  OpusHelper.m
//  watsonsdk
//
//  Created by Rob Smart on 13/08/2014.
//  Copyright (c) 2014 IBM. All rights reserved.
//

#import "OpusHelper.h"
#import "opus.h"



@interface OpusHelper()
@property (nonatomic) OpusEncoder *encoder;
@property (nonatomic) uint8_t *encoderOutputBuffer;
@property (nonatomic) NSUInteger encoderBufferLength;
//@property (nonatomic) TPCircularBuffer *circularBuffer;

@end


@implementation OpusHelper

- (void) dealloc {
    if (_encoder) {
        opus_encoder_destroy(_encoder);
    }
    if (_encoderOutputBuffer) {
        free(_encoderOutputBuffer);
    }
   /* if (self.circularBuffer) {
        TPCircularBufferCleanup(_circularBuffer);
        free(_circularBuffer);
    }*/
    
}


- (void) setBitrate:(NSUInteger)bitrate {
    if (!_encoder) {
        return;
    }
    _bitrate = bitrate;
    dispatch_async(self.processingQueue, ^{
        opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(bitrate));
    });
}

- (BOOL) createEncoder {
    if (self.encoder) {
        return YES;
    }
    int opusError = OPUS_OK;
    
    // sample rates are 8000,12000,16000,24000,48000
    // number of channels 1 or 2 mono stereo
    // app type choices OPUS_APPLICATION_VOIP,OPUS_APPLICATION_AUDIO,OPUS_APPLICATION_RESTRICTED_LOWDELAY
    self.encoder = opus_encoder_create(16000, 1, OPUS_APPLICATION_VOIP, &opusError);
    if (opusError != OPUS_OK) {
        NSLog(@"Error setting up opus encoder, error code is %@",[self opusErrorMessage:opusError]);
        return NO;
    }
    
    self.encoderBufferLength = 16000;
    self.encoderOutputBuffer = malloc(_encoderBufferLength * sizeof(uint8_t));
  /*  self.circularBuffer = malloc(sizeof(TPCircularBuffer));
    BOOL success = TPCircularBufferInit(_circularBuffer, kNumberOfSamplesPerChannel * 10);
    if (!success) {
        NSLog(@"Error allocating circular buffer");
        return NO;
    }*/
    return YES;
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

- (NSData*) encode:(NSData*) pcmData {
    NSInteger frameSize = 160;
   // NSLog(@"Input data is %d bytes",pcmData.length);

    opus_int16 *data  = (opus_int16*) [pcmData bytes];//= (opus_int16*)TPCircularBufferTail(_circularBuffer, &availableBytes);
    uint8_t *outBuffer  = malloc(pcmData.length * sizeof(uint8_t));

    // The length of the encoded packet
    opus_int32 encodedByteCount = opus_encode(_encoder, data, frameSize, outBuffer, pcmData.length);

    //TPCircularBufferConsume(_circularBuffer, kNumberOfSamplesPerChannel * _inputASBD.mBytesPerFrame);
    if (encodedByteCount < 0) {
        NSLog(@"encoding error %@",[self opusErrorMessage:encodedByteCount]);
        return nil;
    }

    // Size data
    NSData *sizeData = [NSData dataWithBytes: &encodedByteCount length: 1];//[[NSData alloc] initWithBase64EncodedString:[NSString stringWithFormat:@"%d", encodedByteCount] options:NSUTF8StringEncoding];

    // Opus data initialized with size in the first byte
    NSMutableData *outputData = [[NSMutableData alloc] initWithCapacity:320];
    [outputData appendBytes:[sizeData bytes] length:[sizeData length]];

    // Append Opus data
    [outputData appendData:[NSData dataWithBytes:outBuffer length:encodedByteCount]];

   // NSLog(@"### Output data is %d(%d, %d) bytes",[outputData length], [sizeData length], encodedByteCount);

    return outputData;
}

@end

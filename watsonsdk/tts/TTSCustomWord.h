//
//  TTSCustomWord.h
//  watsonsdk
//
//  Created by Mihui on 5/26/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTSCustomWord : NSObject

@property NSString* word;
@property NSString* translation;

- (id) initWithWord: (NSString*) text translation:(NSString*) translation;
+ (id) initWithWord: (NSString*) text translation:(NSString*) translation;

-(NSMutableDictionary*)produceDictionary;
-(NSData*)producePostData;
@end

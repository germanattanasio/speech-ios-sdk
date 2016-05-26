//
//  TTSCustomWord.m
//  watsonsdk
//
//  Created by Mihui on 5/26/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import "TTSCustomWord.h"

@implementation TTSCustomWord

@synthesize word = _word;
@synthesize translation = _translation;

- (id) init {
    self = [super init];
    if(self){
        _translation = @"";
        _word = @"";
    }
    return self;
}
- (id) initWithWord: (NSString*) text translation:(NSString*) translation{
    self = [super init];
    if(self){
        _word = text;
        _translation = translation;
    }
    return self;
}

+ (id) initWithWord: (NSString*) text translation:(NSString*) translation{
    TTSCustomWord *customWord = [[TTSCustomWord alloc] initWithWord:text translation: translation];
    return customWord;
}

-(NSMutableDictionary*)produceDictionary {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
    if(![[self word] isEqualToString:@""])
        [dict setObject:[self word] forKey:@"word"];
    if(![[self translation] isEqualToString:@""])
        [dict setObject:[self translation] forKey:@"translation"];

    NSLog(@"Produced dictionary: %@", dict);
    return dict;
}

-(NSData*)producePostData {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
    [dict setObject:[self translation] forKey:@"translation"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSLog(@"Produced data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return data;
}

@end

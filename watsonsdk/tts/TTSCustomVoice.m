//
//  TTSCustomVoice.m
//  watsonsdk
//
//  Created by Mihui on 5/23/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import "TTSCustomVoice.h"

@implementation TTSCustomVoice

@synthesize name = _name;
@synthesize language = _language;
@synthesize description = _description;
@synthesize words = _words;

- (id) init {
    self = [super init];
    _name = @"";
    _language = @"";
    _description = @"";
    _words = [[NSArray alloc] init];
    return self;
}

-(NSData*)producePostData {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:3];
    if(![[self name] isEqualToString:@""])
        [dict setObject:[self name] forKey:@"name"];
    if(![[self description] isEqualToString:@""])
        [dict setObject:[self description] forKey:@"description"];
    if(![[self language] isEqualToString:@""])
        [dict setObject:[self language] forKey:@"language"];

    if([[self words] count] > 0)
        [dict setObject:[self words] forKey:@"words"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSLog(@"Produced data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return data;
}
@end

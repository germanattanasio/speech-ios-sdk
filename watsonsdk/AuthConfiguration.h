//
//  AuthConfiguration.h
//  watsonsdk
//
//  Created by Daisuke Sato on 8/5/15.
//  Copyright (c) 2015 IBM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AuthConfiguration : NSObject

@property NSString* basicAuthUsername;
@property NSString* basicAuthPassword;


@property (readonly) NSString *token;
@property (copy, nonatomic) void (^tokenGenerator) (void (^tokenHandler)(NSString *token));

- (void) invalidateToken;
- (void) requestToken: (void(^)(AuthConfiguration *config)) completionHandler;
- (NSDictionary*) createRequestHeaders;

@end

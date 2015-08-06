//
//  AuthConfiguration.m
//  watsonsdk
//
//  Created by Daisuke Sato on 8/5/15.
//  Copyright (c) 2015 IBM. All rights reserved.
//

#import "AuthConfiguration.h"

@implementation AuthConfiguration

- (id) init
{
    self = [super init];
    _token = nil;
    return self;
}

- (void)invalidateToken
{
    _token = nil;
}

- (void)requestToken:(void (^)(AuthConfiguration *))completionHandler
{
    if (self.tokenGenerator) {
        if (!_token) {
            self.tokenGenerator(^(NSString *token) {
                _token = token;
                completionHandler(self);
            });
        } else {
            completionHandler(self);
        }
    } else {
        completionHandler(self);
    }
}

- (NSDictionary*) createRequestHeaders {
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    if (self.tokenGenerator) {
        if (self.token) {
            [headers setObject:self.token forKey:@"X-Watson-Authorization-Token"];
        }
    } else if(self.basicAuthPassword && self.basicAuthUsername) {
        NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.basicAuthUsername,self.basicAuthPassword];
        NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64Encoding]];
        [headers setObject:authValue forKey:@"Authorization"];
    }
    
    return headers;
}


@end

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

#import "AuthConfiguration.h"

@implementation AuthConfiguration

@synthesize basicAuthUsername = _basicAuthUsername;
@synthesize basicAuthPassword = _basicAuthPassword;
@synthesize token = _token;

- (id) init {
    self = [super init];
    _token = nil;
    _xWatsonLearningOptOut = NO;
    return self;
}

- (void)invalidateToken {
    _token = nil;
}

- (void)requestToken:(void (^)(AuthConfiguration *))completionHandler refreshCache:(BOOL) refreshCachedToken {
    if (self.tokenGenerator) {
        if (!_token || refreshCachedToken) {
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

- (NSMutableDictionary*) createRequestHeaders {
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


/**
 *  setApiUrl - override setter so we can update the NSURL endpoint
 *
 *  @param apiURL
 */
- (void)setApiURL:(NSString *)apiURLStr {
    _apiURL = apiURLStr;
    [self setApiEndpoint:[NSURL URLWithString:apiURLStr]];
}

@end

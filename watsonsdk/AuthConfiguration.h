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

@interface AuthConfiguration : NSObject

@property NSString* basicAuthUsername;
@property NSString* basicAuthPassword;

@property (readonly) NSString *token;
@property (copy, nonatomic) void (^tokenGenerator) (void (^tokenHandler)(NSString *token));

@property (readonly) NSString* apiURL;
@property NSURL* apiEndpoint;
@property BOOL isCertificateValidationDisabled;
@property BOOL xWatsonLearningOptOut;

- (void) invalidateToken;
- (void)requestToken:(void (^)(AuthConfiguration *config))completionHandler refreshCache:(BOOL) refreshCachedToken;
- (NSMutableDictionary*) createRequestHeaders;

- (void)setApiURL:(NSString *)apiURLStr;
@end

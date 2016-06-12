/**
 * Copyright IBM Corporation 2016
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
#import "AuthConfiguration.h"

#define WATSON_WEBSOCKETS_ERROR_CODE 506

#define HTTP_METHOD_GET @"GET"
#define HTTP_METHOD_POST @"POST"
#define HTTP_METHOD_PUT @"PUT"
#define HTTP_METHOD_DELETE @"DELETE"

@interface SpeechUtility : NSObject
+ (NSError *)raiseErrorWithCode:(NSInteger)code;
+ (NSString*)findUnexpectedErrorWithCode: (NSInteger)code;
+ (NSError*)raiseErrorWithCode: (NSInteger)code message: (NSString*) errorMessage reason: (NSString*) reasonMessage suggestion:(NSString*) suggestionMessage;
+ (NSError*)raiseErrorWithMessage:(NSString*) errorMessage;

+ (void) processJSON: (void (^)(id, NSError*))handler
                  config: (AuthConfiguration*) authConfig
                response:(NSURLResponse*) httpResponse
                    data:(NSData*) responseData
                   error: (NSError*) requestError;
+ (void) processData: (void (^)(id, NSError*))handler
              config: (AuthConfiguration*) authConfig
            response:(NSURLResponse*) httpResponse
                data:(NSData*) responseData
               error: (NSError*) requestError;
@end

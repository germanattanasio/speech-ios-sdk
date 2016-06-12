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

#import "SpeechUtility.h"

@implementation SpeechUtility

/**
 *  Find proper error message with error code
 *  refer to http://tools.ietf.org/html/rfc6455
 *
 *  @param code error code
 *
 *  @return error message
 */
+ (NSString *)findUnexpectedErrorWithCode:(NSInteger)code {
    switch (code) {
        // http
        case 400:
            return @"Bad Request";
        case 401:
            return @"Unauthorized";
        case 403:
            return @"Forbidden";
        case 404:
            return @"Not Found";
        case 405:
            return @"Method Not Allowed";
        case 406:
            return @"Not Acceptable";
        case 407:
            return @"Proxy Authentication Required";
        case 408:
            return @"Request Timeout";
        case 409:
            return @"Conflict";
        case 419:
            return @"Gone";
        case 411:
            return @"Length Required";
        case 412:
            return @"Precondition Failed";
        case 413:
            return @"Request Entity Too Large";
        case 414:
            return @"Request-URI Too Long";
        case 415:
            return @"Unsupported Media Type";
        case 416:
            return @"Requested Range Not Satisfiable";
        case 417:
            return @"Expectation Failed";
        case 500:
            return @"Internal Server Error";
        case 501:
            return @"Not Implemented";
        case 502:
            return @"Bad Gateway";
        case 503:
            return @"Service Unavailable";
        case 504:
            return @"Gateway Timeout";
        case 505:
            return @"HTTP Version Not Supported";

        // websockets
        case 1001:
            return @"Stream end encountered";
        case 1002:
            return @"The endpoint is terminating the connection due to a protocol error";
        case 1003:
            return @"The endpoint is terminating the connection because it has received a type of data it cannot accept";
        case 1007:
            return @"The endpoint is terminating the connection because it has received data within a message that was not consistent with the type of the message";
        case 1008:
            return @"The endpoint is terminating the connection because it has received a message that violates its policy";
        case 1009:
            return @"The endpoint is terminating the connection because it has received a message that is too big for it to process.";
        case 1010:
            return @"The endpoint (client) is terminating the connection because it has expected the server to negotiate one or more extension, but the server didn't return them in the response message of the WebSocket handshake";
        case 1011:
            return @"The server is terminating the connection because it encountered an unexpected condition that prevented it from fulfilling the request";
        case 1015:
            return @"The connection was closed due to a failure to perform a TLS handshake";
        default:
            return nil;
    }
}

/**
 *  Produce customized error with code
 *
 *  @param code error code
 *
 *  @return customized error
 */
+ (NSError *)raiseErrorWithCode:(NSInteger)code{
    NSString* errorMessage = [SpeechUtility findUnexpectedErrorWithCode:code];
    return [SpeechUtility raiseErrorWithCode:code message:errorMessage reason:errorMessage suggestion:@""];
}

/**
 *  Produce customized error with code
 *
 *  @param code              error codde
 *  @param errorMessage      error message
 *  @param reasonMessage     reason
 *  @param suggestionMessage suggestion
 *
 *  @return customized error
 */
+ (NSError *)raiseErrorWithCode:(NSInteger)code message:(NSString *)errorMessage reason:(NSString *)reasonMessage suggestion:(NSString *)suggestionMessage{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: errorMessage,
                               NSLocalizedFailureReasonErrorKey: reasonMessage,
                               NSLocalizedRecoverySuggestionErrorKey: suggestionMessage
                               };
    return [NSError errorWithDomain:@"WASTONSPEECHSDK"
                                         code:code
                                     userInfo:userInfo];
}

/**
 *  Produce customized error with message
 *
 *  @param errorMessage error message
 *
 *  @return customized error
 */
+ (NSError*)raiseErrorWithMessage:(NSString*) errorMessage{
    return [SpeechUtility raiseErrorWithCode:WATSON_WEBSOCKETS_ERROR_CODE
                                        message:errorMessage
                                         reason:@"WebSockets error"
                                     suggestion:@"Close connection"];
}

/**
 *  Invoke proper callbacks by data in response
 *
 *  @param handler      callback
 *  @param authConfig   authentication configuration
 *  @param httpResponse response instance
 *  @param responseData response data
 *  @param requestError request error
 */
+ (void) processData: (void (^)(id, NSError*))handler
                  config: (AuthConfiguration*) authConfig
                response:(NSURLResponse*) httpResponse
                    data:(NSData*) responseData
                   error: (NSError*) requestError
{
    // request error
    if(requestError){
        handler(nil, requestError);
        return;
    }
    
    NSDictionary *responseObject = nil;
    NSError *dataError = nil;

    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *theResponse = (NSHTTPURLResponse*) httpResponse;
        NSLog(@"--> status code: %ld", (long)[theResponse statusCode]);
        
        if([theResponse statusCode] == 200 || [theResponse statusCode] == 304) {
            handler(responseData, nil);
        }
        else{
            responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&dataError];
            // response error handling
            // https://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/text-to-speech/api/v1/#response-handling
            requestError = [SpeechUtility raiseErrorWithCode:[[responseObject valueForKey:@"code"] integerValue] message:[responseObject valueForKey:@"code_description"] reason:[responseObject valueForKey:@"error"] suggestion:@""];
            NSLog(@"server error");
            handler(nil, requestError);
        }
        return;
    }

    dataError = [SpeechUtility raiseErrorWithCode:0];
    handler(nil, dataError);
}

/**
 *  Invoke proper callbacks by parsing JSON data
 *
 *  @param handler      callback
 *  @param authConfig   authentication configuration
 *  @param httpResponse response instance
 *  @param responseData response data
 *  @param requestError request error
 */
+ (void) processJSON: (void (^)(id, NSError*))handler
                  config: (AuthConfiguration*) authConfig
                response:(NSURLResponse*) httpResponse
                    data:(NSData*) responseData
                   error: (NSError*) requestError
{
    // request error
    if(requestError){
        handler(nil, requestError);
        return;
    }
    
    NSError *dataError = nil;
    NSDictionary *responseObject = nil;
    
    if ([httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *theResponse = (NSHTTPURLResponse*) httpResponse;
        NSLog(@"--> status code: %ld", (long)[theResponse statusCode]);
        
        if([theResponse statusCode] == 201 || [theResponse statusCode] == 204) {
            NSData *noContent = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
            responseObject = [NSJSONSerialization JSONObjectWithData:noContent options:NSJSONReadingMutableContainers error:&dataError];
            handler(responseObject, nil);
        }
        else{
            responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&dataError];
            if([theResponse statusCode] == 200) {
                handler(responseObject, nil);
            }
            else{
                if(dataError == nil){
                    // response error handling
                    // https://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/text-to-speech/api/v1/#response-handling
                    requestError = [SpeechUtility raiseErrorWithCode:[[responseObject valueForKey:@"code"] integerValue] message:[responseObject valueForKey:@"code_description"] reason:[responseObject valueForKey:@"error"] suggestion:@""];
                    NSLog(@"server error");
                    handler(nil, requestError);
                }
                else{
                    NSLog(@"data error");
                    handler(nil, dataError);
                }
            }
        }
        return;
    }
    
    dataError = [SpeechUtility raiseErrorWithCode:0];
    handler(nil, dataError);
}

@end

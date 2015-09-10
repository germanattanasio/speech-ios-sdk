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

// delegate for responding to HTTPStreamedupload
@protocol UploaderDelegate <NSObject>
@required

- (void) streamErrorCallback:(NSString*) errormessage error:(NSError*) theError; // TODO change this to return an nserror
- (void) streamResultCallback:(NSString*)result responseBytes:(uint8_t*)responseBytes responseBytesLen:(int)responseBytesLen;
- (void) streamResultPartialCallback:(NSDictionary*) result;
- (void) streamClosedCallback;
@end

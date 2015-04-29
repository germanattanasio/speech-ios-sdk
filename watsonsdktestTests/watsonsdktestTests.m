//
//  watsonsdktestTests.m
//  watsonsdktestTests
//
//  Created by Rob Smart on 07/05/2014.
//  Copyright (c) 2014 IBM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <watsonsdk/SpeechToText.h>

@interface watsonsdktestTests : XCTestCase

@property (atomic, strong) SpeechToText *stt;
@end

@implementation watsonsdktestTests

@synthesize stt;

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    NSURL *host = [NSURL URLWithString:@"wss://speech.tap.ibm.com/speech-to-text-beta/api/v1/recognize"];
    self.stt = [SpeechToText initWithURL:host];
    [self.stt setDelegate:self];

    [self.stt setBasicAuthUsername:@"iwatsonapi"];
    [self.stt setBasicAuthPassword:@"Zt1xSp33x"];
    
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
   // XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

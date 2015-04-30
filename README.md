Watson Speech iOS SDK
=====================

An SDK for iOS mobile applications enabling use of the Bluemix Watson Speech To Text and Text To Speech APIs

The SDK include support for recording and streaming audio and receiving a transcript of the audio in response.

Installation
------------

**Using the framework**

1. Download the [watsonsdk.framework.zip](https://git.hursley.ibm.com/w3bluemix/WatsoniOSSpeechSDK/blob/master/watsonsdk.framework.zip) and unzip it somewhere convenient
2. Once unzipped drag the watsonsdk.framework folder into your xcode project view under the Frameworks folder.

Some additional iOS standard frameworks must be added.

1. Select your project in the Xcode file explorer and open the "Build Phases" tab. Expand the "Link Binary With Libraries" section and click the + icon

2. Add the following frameworks

- CFNetwork.framework

- AudioToolbox.framework

--- Quartzcore.framework

- CoreAudio.framework

- Security.framework

- Foundation.framework

- libicucore.dylib




Start Coding
--------------

**Include the header**

```
#import <watsonsdk/SpeechToText.h>
```

**Create a SpeechToText instance**
```objective-c
		
	self.stt = [SpeechToText initWithURL:host];
    [self.stt setDelegate:self];
    
	// Credentials are obtained by inspecting the service instance details in Bluemix
    [self.stt setBasicAuthUsername:@"xxxxxx"];
    [self.stt setBasicAuthPassword:@"xxxxxx"];
```

**Get a list of models supported by the service**

in Objective-C
```
	[stt listModels:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...

    }];
```

in Swift
```
stt.listModels({
    jsonDict in
    err in
    if(err == nil)
    	...
})
```

**Get details of a particular model**
```
	[stt listModel:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...
    
    } withName:@"WatsonModel"];
```

**Start Audio Transcription**
```
	[stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            result.text = [stt getTranscript:res];
        else
            result.text = [err localizedDescription];
    }];

```

**End Audio Transcription**

By default the SDK uses Voice Activated Detection (VAD) to detect when a user has stopped speaking, this can be disabled with [stt setIsVADenabled:true]
```
	NSError* error= [stt endRecognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);

```


**Receive speech power levels during the recognize**

```
[stt getPowerLevel:^(float power){
        
		// user the power level to make a simple UIView graphic indicator 
        CGRect frm = self.soundbar.frame;
        frm.size.width = 3*(70 + power);
        self.soundbar.frame = frm;
        self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, 	self.soundbar.center.y);
        
    }];
```

Features
--------

* Speech To Text
* Text To Speech

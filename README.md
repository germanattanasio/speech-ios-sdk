# DEPRECATED

The **Watson Speech iOS SDK** has been deprecated in favor of the new [Watson Developer Cloud iOS SDK](https://github.com/watson-developer-cloud/ios-sdk) which currently supports most of the Watson services.


----------

# THIS MODULE IS DEPRECATED

## Watson Speech iOS SDK


An SDK for iOS mobile applications enabling use of the Bluemix Watson Speech To Text and Text To Speech APIs from [Watson Developer Cloud][wdc]

The SDK include support for recording and streaming audio and receiving a transcript of the audio in response.


Table of Contents
-----------------
* [Watson Developer Cloud Speech APIs][wdc]

    * [Installation](#installation)
    * [Include headers](#include-headers)
    * [Sample Application](#sample-application)
    * [Speech To Text](#speech-to-text)
    	* [Create a Configuration](#create-a-stt-configuration) 
    	* [Authentication options](#authentication)
    	* [Create a SpeechToText instance](#create-a-speechtotext-instance) 
    	* [List supported models](#get-a-list-of-models-supported-by-the-service) 
    	* [Get model details](#get-details-of-a-particular-model)	
    	* [Use a named model](#use-a-named-model)
    	* [Enabling audio compression](#enabling-audio-compression)
    	* [Start Audio Transcription](#start-audio-transcription)
    	* [End Audio Transcription](#end-audio-transcription)
    	* [Confidence Score](#obtain-a-confidence-score)
    	* [Speech power levels](#receive-speech-power-levels-during-the-recognize)
    	
    * [Text To Speech](#text-to-speech)
    	* [Create a Configuration](#create-a-configuration)
    	* [Set the voice](#set-the-voice)
    	* [Use Token Authentication](#use-token-authentication)
    	* [Create a TextToSpeech instance](#create-a-texttospeech-instance)
    	* [List supported voices](#get-a-list-of-voices-supported-by-the-service)
    	* [Generate and play audio](#generate-and-play-audio)

Installation
------------

**Using the framework**

1. Download the [watsonsdk.framework.zip](https://github.com/watson-developer-cloud/speech-ios-sdk/raw/master/watsonsdk.framework.zip) and unzip it somewhere convenient
2. Once unzipped drag the watsonsdk.framework folder into your xcode project view under the Frameworks folder.

Some additional iOS standard frameworks must be added.

1. Select your project in the Xcode file explorer and open the "Build Phases" tab. Expand the "Link Binary With Libraries" section and click the + icon

2. Add the following frameworks
	- AudioToolbox.framework
	- AVFoundation.framework
	- CFNetwork.framework
	- CoreAudio.framework
	- Foundation.framework
	- libicucore.tbd (or libicucore.dylib on older versions)
	- Quartzcore.framework
	- Security.framework


Include headers
---------------

**in Objective-C**

```objective-c
	#import <watsonsdk/SpeechToText.h>
	#import <watsonsdk/STTConfiguration.h>
	#import <watsonsdk/TextToSpeech.h>
	#import <watsonsdk/TTSConfiguration.h>
```

**in Swift**

*Add the headers above for Objective-c into a bridging header file.*
	- Use SwiftSpeechHeader.h in Swift sample

#Sample Applications
===================

This repository contains a sample application demonstrating the SDK functionality. 

To run the application clone this repository and then navigate in Finder to folder containing the SDK files.

Double click on the watsonsdk.xcodeproj  to launch Xcode.

To run the sample application, change the compile target to 'watsonsdktest-objective-c' or 'watsonsdktest-swift' and run on the iPhone simulator.

Note that this is sample code and no security review has been performed on the code.

The Swift sample was tested in Xcode 7.2.

#Speech To Text 
==============

Create a STT Configuration
--------------------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

**in Objective-C**
```objective-c
	STTConfiguration *conf = [[STTConfiguration alloc] init];
```
**in Swift**
```swift
	let conf:STTConfiguration = STTConfiguration()
```

Authentication
----------------
There are currently two authentication options.

Basic Authentication, using the credentials provided by the Bluemix Service instance.

**in Objective-C**
```objective-c
    [conf setBasicAuthUsername:@"<userid>"];
    [conf setBasicAuthPassword:@"<password>"];
```

**in Swift**
```swift
	conf.basicAuthUsername = "<userid>"
	conf.basicAuthPassword = "<password>"
```

Token authentication, if a token authentication provider is running at https://my-token-factory/token 

```objective-c

	[conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        NSURL *url = [[NSURL alloc] initWithString:@"https://my-token-factory/token"];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"GET"];
        [request setURL:url];
        
        NSError *error = [[NSError alloc] init];
        NSHTTPURLResponse *responseCode = nil;
        NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
        if ([responseCode statusCode] != 200) {
            NSLog(@"Error getting %@, HTTP status code %i", url, [responseCode statusCode]);
            return;
        }
        tokenHandler([[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding]);
    } ];

```


Create a SpeechToText instance
------------------------------


**in Objective-C**
```objective-c
	@property SpeechToText;
	
	...
	
	self.stt = [SpeechToText initWithConfig:conf];
```

**in Swift**
```swift
	var stt:SpeechToText = SpeechToText();
	
	
	...
	
	self.stt = SpeechToText.init(config: conf)
```

Get a list of models supported by the service
------------------------------

**in Objective-C**
```objective-c
	[stt listModels:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...

    }];
```

**in Swift**
```swift
stt!.listModels({
    (jsonDict, err) in
    
    if err == nil {
    	println(jsonDict)
    }
})
```

Get details of a particular model
------------------------------

Available speech recognition models can be obtained using the listModel function.


```objective-c
	[stt listModel:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...
    
    } withName:@"WatsonModel"];
```


Use a named model
------------------------------
The speech recognition model can be changed in the configuration. 

```objective-c
	[conf setModelName:@"ja-JP_BroadbandModel"];
```

Enabling audio compression
----------------------
By default audio sent to the server is uncompressed PCM encoded data, compressed audio using the Opus codec can be enabled.

```objective-c
	[conf setAudioCodec:WATSONSDK_AUDIO_CODEC_TYPE_OPUS];
```


Start audio transcription
------------------------------
```objective-c
	[stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            result.text = [stt getTranscript:res];
        else
            result.text = [err localizedDescription];
    }];

```

End audio transcription
------------------------------

The app must indicate to the SDK when transcription should be ended. 

```objective-c
	NSError* error= [stt endRecognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);

```

The Speech to Text service end of sentence detection can be used to detect that the user has stopped speaking this is indicated in the transcription result, we can use this to automatically end the recognize operation. The following code can be used in the app to do this.

**in Objective-C**
```objective-c

	 // start recognize
    [stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil) {
            
            
            if([self.stt isFinalTranscript:res]) {
                
                NSLog(@"this is the final transcript");
                [stt endRecognize];
            }
            
            result.text = [stt getTranscript:res];
        } else {
            result.text = [err localizedDescription];
        }
    }];


```

**in Swift**
```swift
self.stt.recognize({ (res: [NSObject:AnyObject]!, err: NSError!) -> Void in
    
	if err == nil {
	
	  if self.stt.isFinalTranscript(res) {
	  
	    NSLog("this is the final transcript");
	    self.stt.endRecognize()
	  }
	  
	  result.text = self.stt.getTranscript(res);
	} else {
	  result.text = err.localizedDescription;
	}
    });
```

Obtain a confidence score
-------------------------
A confidence score is available for any final transcripts (whole sentences).
This can be obtained by passing the resulting Dictionary object.

```objective-c

    [stt getConfidenceScore:res]

```


Receive speech power levels during the recognize
------------------------------

```objective-c
[stt getPowerLevel:^(float power){
        
		// user the power level to make a simple UIView graphic indicator 
        CGRect frm = self.soundbar.frame;
        frm.size.width = 3*(70 + power);
        self.soundbar.frame = frm;
        self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, 	self.soundbar.center.y);
        
    }];
```



    	

Text To Speech 
==============


Create a Configuration
---------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

```objective-c
	TTSConfiguration *conf = [[TTSConfiguration alloc] init];
    [conf setBasicAuthUsername:@"<userid>"];
    [conf setBasicAuthPassword:@"<password>"];
```

Set the voice
-------------
You can change the voice model used for TTS by setting it in the configuration.

**in Objective-C**
```objective-c
    [conf setVoiceName:@"en-US_MichaelVoice"];
```

**in Swift**
```swift
	conf.voiceName = "en-US_MichaelVoice"
```


Use Token Authentication
------------------------

If you use tokens (from your own server) to get access to the service, provide a token generator to the Configuration. `userid` and `password` will not be used if a token generator is provided.

**in Objective-C**
```objective-c
   [conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        // get a token from your server in secure way
        NSString *token = ...

        // provide the token to the tokenHandler
        tokenHandler(token);
    }];
```

Create a TextToSpeech instance 
------------------------------
```objective-c
	self.tts = [TextToSpeech initWithConfig:conf];
```

Get a list of voices supported by the service
------------------------------

**in Objective-C**
```objective-c
	[tts listVoices:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...

    }];
```

**in Swift**
```swift
	tts!.listVoices({
            (jsonDict, err) in
            
            if err == nil {
                println(jsonDict)
            }
        })
```

Generate and play audio
------------------------------

**in Objective-C**
```objective-c
	[self.tts synthesize:^(NSData *data, NSError *reqErr) {
    	
    	// request error
    	if(reqErr){
            NSLog(@"Error requesting data: %@", [reqErr description]);
            return;
        }

        // play audio and log when playing has finished
        [self.tts playAudio:^(NSError *err) {
            if(err)
                NSLog(@"error playing audio %@", [err localizedDescription]);
            else
            	NSLog(@"audio finished playing");
            
        } withData:data];
        
    } theText:@"Hello World"];
```


**in Swift**
```swift

	tts!.synthesize({ (data: NSData!, reqError: NSError!) -> Void in
        if reqError == nil{
			tts!.playAudio({ (error: NSError!) -> Void in
				if error == nil{
					... do something after the audio has played ...
				}
				else{
					... data error handling ...
				}
			}, withData: data)
        }
        else
        	... request error handling ...

	}, theText: "Hello World")

```


Common issues
-------------

If you get an error such as...

```
Undefined symbols for architecture x86_64
```

Check that all the required frameworks have been added to your project.

[wdc]: http://www.ibm.com/smarterplanet/us/en/ibmwatson/developercloud/apis/#!/speech-to-text


## Open Source @ IBM
[Find more open source projects on the IBM Github Page.](http://ibm.github.io/)

## Copyright and license

Copyright 2016 IBM Corporation under [the Apache 2.0 license](LICENSE).

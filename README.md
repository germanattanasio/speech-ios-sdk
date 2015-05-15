Watson Speech iOS SDK
=====================

An SDK for iOS mobile applications enabling use of the Bluemix Watson Speech To Text and Text To Speech APIs from [Watson Developer Cloud][wdc]

The SDK include support for recording and streaming audio and receiving a transcript of the audio in response.


Table of Contents
-----------------
* [Watson Developer Cloud Speech APIs][wdc]

    * [Installation](#installation)
    * [Include headers](#include-headers)
    
    * [Speech To Text](#speech-to-text)
    	* [Create a Configuration](#create-a-stt-configuration)  
    	* [Create a SpeechToText instance](#Create-a-SpeechToText-instance) 
    	* [List supported models](#Get-a-list-of-models-supported-by-the-service) 
    	* [Get model details](#Get-details-of-a-particular-model)	
    	* [Start Audio Transcription](#Start-Audio-Transcription)
    	* [End Audio Transcription](#End-Audio-Transcription)
    	* [Speech power levels](#Receive-speech-power-levels-during-the-recognize)
    	
	* [Text To Speech](#text-to-speech)
    	* [Create a Configuration](#Create-a-Configuration)
    	* [Create a TextToSpeech instance](#Create-a-TextToSpeech-instance)
    	* [List supported voices](#Get-a-list-of-voices-supported-by-the-service)
    	* [Generate and play audio](#Generate-and-play-audio)

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

- AVFoundation.framework

- Quartzcore.framework

- CoreAudio.framework

- Security.framework

- Foundation.framework

- libicucore.dylib



Include headers
---------------

**in Objective-C**

```
	#import <watsonsdk/SpeechToText.h>
	#import <watsonsdk/STTConfiguration.h>
	#import <watsonsdk/TextToSpeech.h>
	#import <watsonsdk/TTSConfiguration.h>
```

**in Swift**

Add the headers above for Objective-c into a bridging header file.


Speech To Text 
==============

Create a STT Configuration
--------------------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

```
	STTConfiguration *conf = [[STTConfiguration alloc] init];
    [conf setBasicAuthUsername:@"<userid>"];
    [conf setBasicAuthPassword:@"<password>"];
```


Create a SpeechToText instance
------------------------------

```objective-c
	self.stt = [SpeechToText initWithConfig:conf];
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
```
stt!.listModels({
    (jsonDict, err) in
    
    if err == nil {
    	println(jsonDict)
    }
})
```

Get details of a particular model
------------------------------

```objective-c
	[stt listModel:^(NSDictionary* jsonDict, NSError* err){
        
        if(err == nil)
            ... read values from NSDictionary ...
    
    } withName:@"WatsonModel"];
```

Start Audio Transcription
------------------------------
```objective-c
	[stt recognize:^(NSDictionary* res, NSError* err){
        
        if(err == nil)
            result.text = [stt getTranscript:res];
        else
            result.text = [err localizedDescription];
    }];

```

End Audio Transcription
------------------------------

By default the SDK uses Voice Activated Detection (VAD) to detect when a user has stopped speaking, this can be disabled with [stt setIsVADenabled:true]
```objective-c
	NSError* error= [stt endRecognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);

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
```
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
	[self.tts synthesize:^(NSData *data, NSError *err) {
        if(err != nil)
            result.text = [err localizedDescription];
        else
            [self.tts playAudio:data];
        
    } theText:@"Hello World"];
```


**in Swift**
```
	tts!.synthesize({
		(data, err) in
            
		if err != nil {
        	println(err)
		} else {
                
        	self.tts!.playAudio(data)   
		}
            
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

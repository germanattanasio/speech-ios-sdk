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
    	* [Authentication options](#authentication)
    	* [Create a SpeechToText instance](#create-a-speechtotext-instance) 
    	* [List supported models](#get-a-list-of-models-supported-by-the-service) 
    	* [Get model details](#get-details-of-a-particular-model)	
    	* [Use a named model](#use-a-named-model)
    	* [Start Audio Transcription](#start-audio-transcription)
    	* [End Audio Transcription](#end-audio-transcription)
    	* [Speech power levels](#receive-speech-power-levels-during-the-recognize)
    	
	* [Text To Speech](#text-to-speech)
    	* [Create a Configuration](#create-a-configuration)
    	* [Create a TextToSpeech instance](#create-a-texttospeech-instance)
    	* [List supported voices](#get-a-list-of-voices-supported-by-the-service)
    	* [Generate and play audio](#generate-and-play-audio)

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

*Add the headers above for Objective-c into a bridging header file.*


#Speech To Text 
==============

Create a STT Configuration
--------------------------

By default the Configuration will use the IBM Bluemix service API endpoint, custom endpoints can be set using `setApiURL` in most cases this is not required.

```objective-c
	STTConfiguration *conf = [[STTConfiguration alloc] init];
```

Authentication
----------------
There are currently two authentication options.

Basic Authentication, using the credentials provided by the Bluemix Service instance.

```objective-c
    [conf setBasicAuthUsername:@"<userid>"];
    [conf setBasicAuthPassword:@"<password>"];
```

Token authentication, an example token authentication provider is running at https://speech-to-text-demo.mybluemix.net/token 

```objective-c

	[conf setTokenGenerator:^(void (^tokenHandler)(NSString *token)){
        NSURL *url = [[NSURL alloc] initWithString:@"https://speech-to-text-demo.mybluemix.net/token"];
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



```objective-c
	@property SpeechToText;
	
	...
	
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


Use a named model
------------------------------

```objective-c
[conf setModelName:@"ja-JP_BroadbandModel"];
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

The app must indicate to the SDK when transcription should be ended. 

```objective-c
	NSError* error= [stt endRecognize];
    if(error != nil)
        NSLog(@"error is %@",error.localizedDescription);

```

The STT services VAD end of sentence detection can be used to stop the transcription. The following code can be used in the app to do this.


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
    
        // play audio and log when playing has finished
        [self.tts playAudio:^(NSError *err) {
            
            if(!err)
                NSLog(@"audio finished playing");
            else
                NSLog(@"error playing audio %@",err.localizedDescription);
            
        } withData:data];
        
    } theText:@"Hello World"];
```


**in Swift**
```
	tts!.synthesize({
		(data, err) in
            
		tts!.playAudio({
			(err) in
            
				... do something after the audio has played ...
		
		}, withData: data)
            
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

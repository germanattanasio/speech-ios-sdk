# If you've made changes to the SDK (such as file paths), consider using `pod lib lint` to lint locally and then using the :path option in your Podfile

Pod::Spec.new do |s|

  s.name         = "Watson-iOS-SDK"
  s.version      = "0.0.1"
  s.summary      = "Watson iOS SDK for accessing Watson Bluemix Speech services from an iOS app"

  s.description  = <<-DESC
                   The Watson SDK for iOS allows you to use features including:
                   * Speech To Text transcription over WebSockets.
                   * Text To Speech generation through REST APIs.
                   DESC

  s.homepage     = "https://github.com/watson-developer-cloud/"
  s.license      = { :type => "Apache2", :file => "LICENSE" }
  s.author       = 'IBM'

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://git.hursley.ibm.com/w3bluemix/iosSpeechSDK.git",
                     :tag => "sdk-version-0.0.1"
                    }

  s.weak_frameworks = "CoreTelephony", "AssetsLibrary", "Security", "SystemConfiguration", "QuartzCore", "AVFoundation", "CoreAudio", "Foundation", "AudioToolbox", "CFNetwork"

  s.requires_arc = true
  

  s.dependency 'Bolts', '~> 1.0'
  
end

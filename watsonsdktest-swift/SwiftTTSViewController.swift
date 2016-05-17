//
//  SwiftTTSViewController.swift
//  watsonsdk
//
//  Created by Mihui on 5/17/16.
//  Copyright © 2016 IBM. All rights reserved.
//

import UIKit

class SwiftTTSViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    var ttsVoices: NSArray?
    var ttsInstance: TextToSpeech?

    @IBOutlet var voiceSelectorButton: UIButton!
    @IBOutlet weak var pickerViewContainer: UIView!
    @IBOutlet var ttsField: UITextView!

    var pickerView: UIPickerView!
    let pickerViewHeight:CGFloat = 250
    let pickerViewAnimationDuration: NSTimeInterval = 0.5
    let pickerViewAnimationDelay: NSTimeInterval = 0.1

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let confTTS: TTSConfiguration = TTSConfiguration()
        confTTS.basicAuthUsername = "<your-username>"
        confTTS.basicAuthPassword = "<your-password>"
        confTTS.audioCodec = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS
        confTTS.voiceName = WATSONSDK_DEFAULT_TTS_VOICE

        self.ttsInstance = TextToSpeech(config: confTTS)
        self.ttsInstance?.listVoices({ (jsonDict, error) -> Void in
            if error == nil{
                self.voiceHandler(jsonDict)
            }
            else{
                self.ttsField.text = error.description
            }
        })
    }
    
    // start recording
    @IBAction func onStartSynthesizing(sender: AnyObject) {
        self.ttsInstance?.synthesize({ (data: NSData!, reqError: NSError!) -> Void in
            if reqError == nil {
                self.ttsInstance?.playAudio({ (error: NSError!) -> Void in
                    if error == nil{
                        print("audio finished playing")
                    }
                    else{
                        print("error playing audio %@", error.localizedDescription)
                    }

                    }, withData: data)
            }
            else{
                print("Error requesting data: %@", reqError.description)
            }
            
            }, theText: self.ttsField.text)
    }

    @IBAction func onSelectingModel(sender: AnyObject) {
        self.hidePickerView(false, withAnimation: true)
    }
    
    func onHidingPickerView(){
        self.hidePickerView(true, withAnimation: true)
    }
    
    func onSelectedModel(row: Int){
        guard let voices = self.ttsVoices else{
            return
        }
        let voice = voices.objectAtIndex(row) as! NSDictionary
        let voiceName:String = voice.objectForKey("name") as! String
        let voiceGender:String = voice.objectForKey("gender") as! String
        self.voiceSelectorButton.setTitle(String(format: "%@: %@", voiceGender, voiceName), forState: .Normal)
        self.ttsInstance?.config.voiceName = voiceName
    }
    
    func voiceHandler(dict: NSDictionary){
        self.ttsVoices = dict.objectForKey("voices") as? NSArray
        self.getUIPickerViewInstance().backgroundColor = UIColor.whiteColor()
        self.hidePickerView(true, withAnimation: false)

        self.view.addSubview(self.getUIPickerViewInstance())
        let row = (self.ttsVoices?.count)! - 1
        self.getUIPickerViewInstance().selectRow(row, inComponent: 0, animated: false)
        self.onSelectedModel(row)
    }
    func getUIPickerViewInstance() -> UIPickerView{
        guard let _ = self.pickerView else{
            let pickerViewframe = CGRectMake(0, UIScreen.mainScreen().bounds.height - self.pickerViewHeight, UIScreen.mainScreen().bounds.width, self.pickerViewHeight)
            self.pickerView = UIPickerView(frame: pickerViewframe)
            self.pickerView.dataSource = self
            self.pickerView.delegate = self
            self.pickerView.opaque = true
            self.pickerView.showsSelectionIndicator = true
            self.pickerView.userInteractionEnabled = true
            return self.pickerView
        }
        return self.pickerView
    }
    
    func hidePickerView(hide: Bool, withAnimation: Bool){
        if withAnimation{
            UIView.animateWithDuration(self.pickerViewAnimationDuration, delay: self.pickerViewAnimationDelay, options: .CurveEaseInOut, animations: { () -> Void in
                var frame = self.getUIPickerViewInstance().frame
                if hide{
                    frame.origin.y = (UIScreen.mainScreen().bounds.height)
                }
                else{
                    self.getUIPickerViewInstance().hidden = hide
                    frame.origin.y = UIScreen.mainScreen().bounds.height - self.pickerViewHeight
                }
                self.getUIPickerViewInstance().frame =  frame
                }) { (Bool) -> Void in
                    self.getUIPickerViewInstance().hidden = hide
            }
        }
        else{
            self.getUIPickerViewInstance().hidden = hide
        }
    }
    // pickerview delegate methods
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int{
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        guard let voices = self.ttsVoices else {
            return 0
        }
        return voices.count
    }
    func pickerView(pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 50
    }
    func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return self.pickerViewHeight
    }
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
        var tView: UILabel? = view as? UILabel
        if tView == nil {
            tView = UILabel()
            tView?.font = UIFont(name: "Helvetica", size: 12)
            tView?.numberOfLines = 1
        }
        let model = self.ttsVoices?.objectAtIndex(row) as? NSDictionary
        tView?.text = String(format: "%@: %@", (model?.objectForKey("gender") as? String)!, (model?.objectForKey("name") as? String)!)
        return tView!
    }
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.onSelectedModel(row)
        self.hidePickerView(true, withAnimation: true)
    }
    // pickerview delegate methods
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

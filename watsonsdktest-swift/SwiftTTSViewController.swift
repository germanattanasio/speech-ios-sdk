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

import UIKit

class SwiftTTSViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UIGestureRecognizerDelegate {

    var ttsVoices: NSArray?
    var ttsInstance: TextToSpeech?

    @IBOutlet var voiceSelectorButton: UIButton!
    @IBOutlet weak var pickerViewContainer: UIView!
    @IBOutlet var ttsField: UITextView!

    var pickerView: UIPickerView!
    let pickerViewHeight:CGFloat = 250.0
    let pickerViewAnimationDuration: NSTimeInterval = 0.5
    let pickerViewAnimationDelay: NSTimeInterval = 0.1
    let pickerViewPositionOffset: CGFloat = 33.0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let credentialFilePath = NSBundle.mainBundle().pathForResource("Credentials", ofType: "plist")
        let credentials = NSDictionary(contentsOfFile: credentialFilePath!)
        
        let confTTS: TTSConfiguration = TTSConfiguration()
        confTTS.basicAuthUsername = credentials?["TTSUsername"] as! String
        confTTS.basicAuthPassword = credentials?["TTSPassword"] as! String
        confTTS.audioCodec = WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS
        confTTS.voiceName = WATSONSDK_DEFAULT_TTS_VOICE
        confTTS.xWatsonLearningOptOut = false // Change to true to opt-out

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
    // dismiss keyboard when the background is touched
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.ttsField.endEditing(true)
    }
    // start recording
    @IBAction func onStartSynthesizing(sender: AnyObject) {
        self.ttsInstance?.synthesize({ (data: NSData!, reqError: NSError!) -> Void in
            if reqError == nil {
                self.ttsInstance?.playAudio({ (error: NSError!) -> Void in
                    if error == nil{
                        print("Audio finished playing")
                    }
                    else{
                        print("Error playing audio %@", error.localizedDescription)
                    }

                    }, withData: data)
            }
            else{
                print("Error requesting data: %@", reqError.description)
            }
            
            }, theText: self.ttsField.text)
    }
    // show picker view when the button is clicked
    @IBAction func onSelectingModel(sender: AnyObject) {
        self.hidePickerView(false, withAnimation: true)
    }
    
    // hide picker view
    func onHidingPickerView(){
        self.hidePickerView(true, withAnimation: true)
    }
    
    // set voice name when the picker view data is changed
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

    // setup picker view after the response is back
    func voiceHandler(dict: NSDictionary){
        self.ttsVoices = dict.objectForKey("voices") as? NSArray
        self.getUIPickerViewInstance().backgroundColor = UIColor.whiteColor()
        self.hidePickerView(true, withAnimation: false)
        
        let gestureRecognizer:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SwiftTTSViewController.pickerViewTapGestureRecognized))
        gestureRecognizer.delegate = self
        self.getUIPickerViewInstance().addGestureRecognizer(gestureRecognizer);

        self.view.addSubview(self.getUIPickerViewInstance())
        var row = 0
        if let list = self.ttsVoices{
            for i in 0 ..< list.count{
                if list.objectAtIndex(i).objectForKey("name") as? String == self.ttsInstance?.config.voiceName{
                    row = i
                }
            }
        }
        else{
            row = (self.ttsVoices?.count)! - 1
        }
        self.getUIPickerViewInstance().selectRow(row, inComponent: 0, animated: false)
        self.onSelectedModel(row)
    }

    // get picker view initialized
    func getUIPickerViewInstance() -> UIPickerView{
        guard let _ = self.pickerView else{
            let pickerViewframe = CGRectMake(0, UIScreen.mainScreen().bounds.height - self.pickerViewHeight + self.pickerViewPositionOffset, UIScreen.mainScreen().bounds.width, self.pickerViewHeight)
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
    
    // display/show picker view with animations
    func hidePickerView(hide: Bool, withAnimation: Bool){
        if withAnimation{
            UIView.animateWithDuration(self.pickerViewAnimationDuration, delay: self.pickerViewAnimationDelay, options: .CurveEaseInOut, animations: { () -> Void in
                var frame = self.getUIPickerViewInstance().frame
                if hide{
                    frame.origin.y = (UIScreen.mainScreen().bounds.height)
                }
                else{
                    self.getUIPickerViewInstance().hidden = hide
                    frame.origin.y = UIScreen.mainScreen().bounds.height - self.pickerViewHeight + self.pickerViewPositionOffset
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

    func pickerViewTapGestureRecognized(sender: UIGestureRecognizer){
        self.onSelectedModel(self.getUIPickerViewInstance().selectedRowInComponent(0))
    }

    // UIGestureRecognizerDelegate
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    // UIGestureRecognizerDelegate

    // UIPickerView delegate methods
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
    // UIPickerView delegate methods

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

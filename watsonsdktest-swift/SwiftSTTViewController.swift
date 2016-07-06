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

class SwiftSTTViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    var sttLanguageModels: NSArray?
    var sttInstance: SpeechToText?

    @IBOutlet var modelSelectorButton: UIButton!
    @IBOutlet weak var pickerViewContainer: UIView!
    @IBOutlet var soundbar: UIView!
    @IBOutlet var result: UILabel!
    var pickerView: UIPickerView!
    let pickerViewHeight:CGFloat = 250.0
    let pickerViewAnimationDuration: NSTimeInterval = 0.5
    let pickerViewAnimationDelay: NSTimeInterval = 0.1
    let pickerViewPositionOffset: CGFloat = 33.0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let credentialFilePath = NSBundle.mainBundle().pathForResource("Credentials", ofType: "plist")
        let credentials = NSDictionary(contentsOfFile: credentialFilePath!)

        let confSTT: STTConfiguration = STTConfiguration()
        confSTT.basicAuthUsername = credentials!["STTUsername"] as! String
        confSTT.basicAuthPassword = credentials!["STTPassword"] as! String
        confSTT.audioCodec = WATSONSDK_AUDIO_CODEC_TYPE_OPUS
        confSTT.modelName = WATSONSDK_DEFAULT_STT_MODEL
        confSTT.learningOptOut = false // Change to `true` to opt-out learning

        self.sttInstance = SpeechToText(config: confSTT)
        self.sttInstance?.listModels({ (jsonDict, error) -> Void in
            if error == nil{
                self.modelHandler(jsonDict)
            }
            else{
                self.result.text = error.description
            }
        })
    }

    // start recording
    @IBAction func onStartRecording(sender: AnyObject) {
        self.sttInstance?.recognize({ (result: [NSObject : AnyObject]!, error: NSError!) -> Void in
            if(error == nil){
                let isFinal = self.sttInstance?.isFinalTranscript(result)
                if isFinal == nil || isFinal == false{
                    self.result.text = self.sttInstance?.getTranscript(result)
                }
                else{
                    self.sttInstance?.endRecognize()
                }
            }
            else{
                print("Error from the SDK: %@", error.localizedDescription)
                self.sttInstance?.endRecognize()
            }
        })
        
        self.sttInstance?.getPowerLevel({ (power: Float) -> Void in
            var frame = self.soundbar.frame
            var w = CGFloat.init(3*(70 + power))

            if w > self.pickerViewContainer.frame.width{
                w = self.pickerViewContainer.frame.width
            }

            frame.size.width = w
            self.soundbar.frame = frame
            self.soundbar.center = CGPointMake(self.view.frame.size.width / 2, self.soundbar.center.y);
        })
    }
    
    @IBAction func onSelectingModel(sender: AnyObject) {
        self.hidePickerView(false, withAnimation: true)
    }
    
    func onHidingPickerView(){
        self.hidePickerView(true, withAnimation: true)
    }

    func onSelectedModel(row: Int){
        guard let models = self.sttLanguageModels else{
            return
        }
        let model = models.objectAtIndex(row) as! NSDictionary
        let modelName:String = model.objectForKey("name") as! String
        let modelDesc:String = model.objectForKey("description") as! String
        self.modelSelectorButton.setTitle(modelDesc, forState: .Normal)
        self.sttInstance?.config.modelName = modelName
    }
    
    func modelHandler(dict: NSDictionary){
        self.sttLanguageModels = dict.objectForKey("models") as? NSArray
        self.getUIPickerViewInstance().backgroundColor = UIColor.whiteColor()
        self.hidePickerView(true, withAnimation: false)

        self.view.addSubview(self.getUIPickerViewInstance())
        var row = 0
        if let list = self.sttLanguageModels{
            for i in 0 ..< list.count{
                if list.objectAtIndex(i).objectForKey("name") as? String == self.sttInstance?.config.modelName{
                    row = i
                }
            }
        }
        else{
            row = (self.sttLanguageModels?.count)! - 1
        }
        self.getUIPickerViewInstance().selectRow(row, inComponent: 0, animated: false)
        self.onSelectedModel(row)
    }

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

    func hidePickerView(hide: Bool, withAnimation: Bool){
        if withAnimation{
            UIView.animateWithDuration(self.pickerViewAnimationDuration, delay: self.pickerViewAnimationDelay, options: .CurveEaseInOut, animations: { () -> Void in
                var frame = self.getUIPickerViewInstance().frame
                if hide{
                    frame.origin.y = UIScreen.mainScreen().bounds.height
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
    
    // UIPickerView delegate methods
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int{
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        guard let models = self.sttLanguageModels else {
            return 0
        }
        return models.count
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
        let model = self.sttLanguageModels?.objectAtIndex(row) as? NSDictionary
        tView?.text = model?.objectForKey("description") as? String
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


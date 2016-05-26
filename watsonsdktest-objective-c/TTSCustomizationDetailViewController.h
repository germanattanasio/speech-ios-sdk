//
//  TTSCustomizationDetailViewController.h
//  watsonsdk
//
//  Created by Mihui on 5/26/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <watsonsdk/TextToSpeech.h>
#import "TTSCustomizationDetailTableViewCell.h"

@interface TTSCustomizationDetailViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
@property NSDictionary* voice;
@end

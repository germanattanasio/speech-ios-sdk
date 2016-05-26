//
//  TTSCustomizationDetailTableViewCell.h
//  watsonsdk
//
//  Created by Mihui on 5/26/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TTSCustomizationDetailTableViewCell : UITableViewCell

@property (nonatomic, retain) IBOutlet UILabel *word;
@property (nonatomic, retain) IBOutlet UILabel *translation;
@property (nonatomic, retain) IBOutlet UIButton *oldTranslation;
@property (nonatomic, retain) IBOutlet UIButton *currentTranslation;

@end

//
//  TTSCustomizationViewController.m
//  watsonsdk
//
//  Created by Mihui on 5/25/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import "TTSCustomizationViewController.h"

@interface TTSCustomizationViewController ()
@property TextToSpeech *tts;
@property NSMutableArray *voices;
@property IBOutlet UITableView *tableView;
@property IBOutlet UITextField *nameField;
@property IBOutlet UITextField *descField;
@property IBOutlet UIButton *languageButton;
@end

@implementation TTSCustomizationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    NSString *credentialFilePath = [[NSBundle mainBundle] pathForResource:@"Credentials" ofType:@"plist"];
    NSDictionary *credentials = [[NSDictionary alloc] initWithContentsOfFile:credentialFilePath];
    // TTS setup
    TTSConfiguration *confTTS = [[TTSConfiguration alloc] init];
    [confTTS setBasicAuthUsername:credentials[@"TTSUsername"]];
    [confTTS setBasicAuthPassword:credentials[@"TTSPassword"]];
    [confTTS setAudioCodec:WATSONSDK_TTS_AUDIO_CODEC_TYPE_OPUS];

    self.tts = [TextToSpeech initWithConfig:confTTS];

    // test listing voice models
    [self.tts listCustomizedVoiceModels:^(NSDictionary* dict, NSError* error) {
        if(error) {
            NSLog(@"[Callback] error: ---> %@", [error description]);
        }
        else {
            self.voices = [[NSMutableArray alloc] initWithArray:[dict objectForKey:@"customizations"]];
            self.tableView.delegate = self;
            self.tableView.dataSource = self;
            [self.tableView reloadData];
            NSLog(@"[Callback] success: ---> %lu", (unsigned long)self.voices.count);
        }
    }];

    [self.languageButton setTitle:TTS_CUSTOM_VOICE_LANGUAGE_EN_US forState:UIControlStateNormal];
}

- (IBAction)goBack:(id)sender {
    [[self navigationController] popToRootViewControllerAnimated:YES];
}

// todo:
- (IBAction)listLanguages:(id)sender {
    [self.nameField endEditing:YES];
    [self.descField endEditing:YES];

    [self.nameField resignFirstResponder];
    [self.descField resignFirstResponder];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.nameField endEditing:YES];
    [self.descField endEditing:YES];
}

- (IBAction)createVoiceModel:(id)sender {
    __weak typeof(self) weakSelf = self;
    
    TTSCustomVoice *customVoice = [[TTSCustomVoice alloc] init];
    [customVoice setName:self.nameField.text];
    [customVoice setLanguage:[self.languageButton titleLabel].text];
    [customVoice setDescription:self.descField.text];

    [self.tts createVoiceModelWithCustomVoice:customVoice handler:^(NSDictionary* dict, NSError* error) {
        if(error){
            NSLog(@"[Callback] error: ---> %@", [error description]);
        }
        else{
            NSString *customizationId = [dict objectForKey:@"customization_id"];
            NSLog(@"[Callback] success: %@", customizationId);
            
            [weakSelf.tts listCustomizedVoiceModels:^(NSDictionary* dict, NSError* error) {
                if(error) {
                    NSLog(@"[Callback] error: ---> %@", [error description]);
                }
                else {
                    // testing updating model
                    NSArray *words = [NSArray arrayWithObjects:
                                      [[TTSCustomWord initWithWord: @"UT" translation: @"Utilization"] produceDictionary],
                                      [[TTSCustomWord initWithWord: @"MIHUI" translation: @"Me Who A"] produceDictionary],
                                      [[TTSCustomWord initWithWord: @"LOL" translation: @"Laughing out loud ha ha ha ha ha"] produceDictionary],
                                      [[TTSCustomWord initWithWord: @"IEEE" translation: @"I triple E"] produceDictionary],
                                      nil];

                    TTSCustomVoice *updateVoice = [[TTSCustomVoice alloc] init];
                    [updateVoice setName: [customVoice name]];
                    [updateVoice setDescription:[customVoice description]];
                    [updateVoice setWords:words];
                    [weakSelf.tts updateVoiceModelWithCustomVoice:customizationId voice:updateVoice handler:^(NSDictionary* updateDict, NSError* updateError) {
                        NSLog(@"[Callback] %@: %@", [updateDict description], [updateError description]);
                    }];

                    weakSelf.voices = [[NSMutableArray alloc] initWithArray:[dict objectForKey:@"customizations"]];
                    [weakSelf.tableView reloadData];
                    NSLog(@"[Callback] success: ---> %lu", (unsigned long)weakSelf.voices.count);
                }
            }];
            
        }
    }];
    [self.nameField resignFirstResponder];
    [self.descField resignFirstResponder];
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(self.voices == nil){
        return 0;
    }
    return self.voices.count;
}
// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"CustomizationID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if(cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    NSString *name = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"name"];
    NSString *language = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"language"];
    NSString *description = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"description"];
    NSNumber *created = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"created"];

    [[cell textLabel] setText:[NSString stringWithFormat:@"[%@] %@", language, name]];
    [[cell detailTextLabel] setText:[NSString stringWithFormat:@"[%@] %@", [[NSDate dateWithTimeIntervalSince1970:[created doubleValue]/1000] description], description]];
    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSString *name = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"name"];
//    NSString *language = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"language"];
//    NSString *description = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"description"];
//    NSNumber *created = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"created"];
//    NSString *customizationId = [[[self voices] objectAtIndex:[indexPath row]] objectForKey:@"customization_id"];

    NSLog(@"---> %@", [[self voices] objectAtIndex:[indexPath row]]);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    if(editingStyle == UITableViewCellEditingStyleDelete){
        NSInteger row = [indexPath row];
        NSString *customizationId = [[[self voices] objectAtIndex:row] objectForKey:@"customization_id"];
        [self.tts deleteVoiceModel:customizationId handler:^(NSDictionary* dictDeletion, NSError* errorDeletion) {
            if(errorDeletion) {
                NSLog(@"[Callback] error: ---> %@", [errorDeletion description]);
            }
            else {
                NSLog(@"[Callback] success: ---> %@", dictDeletion);
            }
        }];
        [self.voices removeObjectAtIndex:row];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
     NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
     NSDictionary *detail = [[self voices] objectAtIndex:[indexPath row]];
     TTSCustomizationDetailViewController *detailController = [segue destinationViewController];
     [detailController setVoice:detail];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

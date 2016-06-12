//
//  TTSCustomizationDetailViewController.m
//  watsonsdk
//
//  Created by Mihui on 5/26/16.
//  Copyright © 2016 IBM. All rights reserved.
//

#import "TTSCustomizationDetailViewController.h"

@interface TTSCustomizationDetailViewController ()
@property TextToSpeech *tts;
@property NSMutableArray *words;
@property IBOutlet UITableView *tableView;
@property IBOutlet UITextField *wordField;
@property IBOutlet UITextField *tranField;

@property NSString* customizationId;
@end

@implementation TTSCustomizationDetailViewController

@synthesize voice = _voice;
@synthesize words = _words;

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

    NSLog(@"viewDidLoad---> %@", [self voice]);
    self.customizationId = [[self voice] objectForKey:@"customization_id"];

    [self.tts listWords:self.customizationId handler:^(NSDictionary* dict, NSError* error) {
        if(error) {
            NSLog(@"[Callback] error: ---> %@", [error description]);
        }
        else {
            NSLog(@"[Callback] success: ---> %@", dict);
            self.words = [[NSMutableArray alloc] initWithArray:[dict objectForKey:@"words"]];
            self.tableView.delegate = self;
            self.tableView.dataSource = self;
            [self.tableView reloadData];
        }
    }];
}

- (IBAction)goBack:(id)sender {
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.wordField endEditing:YES];
    [self.tranField endEditing:YES];
}

- (IBAction)addWord:(id)sender {
    __weak typeof(self) weakSelf = self;
    TTSCustomWord *word = [TTSCustomWord initWithWord:[self.wordField text] translation:[self.tranField text]];
    [self.tts addWord:self.customizationId
                 word:word
              handler:^(NSDictionary* dict, NSError* error)
    {
        if(error){
            NSLog(@"[Callback] error: ---> %@", [error description]);
        }
        else{
            [weakSelf.tts listWords:weakSelf.customizationId handler:^(NSDictionary* dictList, NSError* errorList) {
                if(errorList) {
                    NSLog(@"[Callback] error: ---> %@", [errorList description]);
                }
                else {
                    NSLog(@"[Callback] success: ---> %@", dictList);
                    weakSelf.words = [[NSMutableArray alloc] initWithArray:[dictList objectForKey:@"words"]];
                    [weakSelf.tableView reloadData];
                }
            }];
            NSLog(@"[Callback] success: ---> %@", dict);
        }
    }];
}

- (void)listenOld:(UIButton*)sender {
    NSLog(@"Sender[%ld]: %@", (long)[sender tag], [[sender titleLabel] text]);
    NSString *word = [[[self words] objectAtIndex:[sender tag]] objectForKey:@"word"];
    
    [self.tts synthesize:^(NSData *data, NSError *reqErr) {
        if(reqErr){
            NSLog(@"Error requesting data: %@", [reqErr description]);
            return;
        }
        // play audio and log when playgin has finished
        [self.tts playAudio:^(NSError *err) {
            if(err)
                NSLog(@"Error playing audio %@",[err localizedDescription]);
            else
                NSLog(@"Audio finished playing");
            
        } withData:data];
    } theText: word];
}

- (void)listenNew:(UIButton*)sender {
    NSLog(@"Sender[%ld]: %@", (long)[sender tag], [[sender titleLabel] text]);
    NSString *word = [[[self words] objectAtIndex:[sender tag]] objectForKey:@"word"];
    
    [self.tts synthesize:^(NSData *data, NSError *reqErr) {
        if(reqErr){
            NSLog(@"Error requesting data: %@", [reqErr description]);
            return;
        }
        // play audio and log when playgin has finished
        [self.tts playAudio:^(NSError *err) {
            if(err)
                NSLog(@"Error playing audio %@",[err localizedDescription]);
            else
                NSLog(@"Audio finished playing");
            
        } withData:data];
    } theText: word customizationId:self.customizationId];
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(self.words == nil){
        return 0;
    }
    return self.words.count;
}
// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"CustomizationID";
    TTSCustomizationDetailTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if(cell == nil){
        cell = [[TTSCustomizationDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    NSString *translation = [[[self words] objectAtIndex:[indexPath row]] objectForKey:@"translation"];
    NSString *word = [[[self words] objectAtIndex:[indexPath row]] objectForKey:@"word"];

    [[cell word] setText:word];
    [[cell translation] setText:translation];
    [[cell oldTranslation] setTag:[indexPath row]];
    [[cell oldTranslation] addTarget:self action:@selector(listenOld:) forControlEvents:UIControlEventTouchUpInside];
    [[cell currentTranslation] setTag:[indexPath row]];
    [[cell currentTranslation] addTarget:self action:@selector(listenNew:) forControlEvents:UIControlEventTouchUpInside];

    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [[self words] objectAtIndex:[indexPath row]];
    NSString* word = [dict objectForKey:@"word"];
    NSLog(@"---> %@", dict);
    [self.tts listWord:self.customizationId word:word handler:^(NSDictionary* dict, NSError* error) {
        if(error) {
            NSLog(@"[Callback] error: ---> %@", [error description]);
        }
        else {
            NSLog(@"[Callback] success: ---> %@", dict);
        }
    }];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    if(editingStyle == UITableViewCellEditingStyleDelete){
        NSInteger row = [indexPath row];
        NSString *word = [[[self words] objectAtIndex:row] objectForKey:@"word"];

        [self.tts deleteWord:self.customizationId word: word handler:^(NSDictionary* dictDeletion, NSError* errorDeletion) {
            if(errorDeletion) {
                NSLog(@"[Callback] error: ---> %@", [errorDeletion description]);
            }
            else {
                NSLog(@"[Callback] success: ---> %@", dictDeletion);
            }
        }];
        [self.words removeObjectAtIndex:row];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

//
//  OCSettingsController.m
//  iOCNews

/************************************************************************
 
 Copyright 2013 Peter Hedlund peter.hedlund@me.com
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *************************************************************************/

#import "OCSettingsController.h"

@interface OCSettingsController ()

@end

@implementation OCSettingsController

@synthesize syncOnStartSwitch;
@synthesize syncinBackgroundSwitch;
@synthesize showFaviconsSwitch;
@synthesize showThumbnailsSwitch;
@synthesize markWhileScrollingSwitch;
@synthesize reverseItemOrderSwitch;
@synthesize syncOnStartCell;
@synthesize syncInBackgroundCell;
@synthesize showFaviconsCell;
@synthesize showThumbnailsCell;
@synthesize markWhileScrollingCell;
@synthesize reverseItemOrderCell;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.syncOnStartCell.accessoryView = self.syncOnStartSwitch;
    self.syncInBackgroundCell.accessoryView = self.syncinBackgroundSwitch;
    self.showFaviconsCell.accessoryView = self.showFaviconsSwitch;
    self.showThumbnailsCell.accessoryView = self.showThumbnailsSwitch;
    self.markWhileScrollingCell.accessoryView = self.markWhileScrollingSwitch;
    self.reverseItemOrderCell.accessoryView = self.reverseItemOrderSwitch;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.syncOnStartSwitch.on = [prefs boolForKey:@"SyncOnStart"];
    self.syncinBackgroundSwitch.on = [prefs boolForKey:@"SyncInBackground"];
    self.showFaviconsSwitch.on = [prefs boolForKey:@"ShowFavicons"];
    self.showThumbnailsSwitch.on = [prefs boolForKey:@"ShowThumbnails"];
    self.markWhileScrollingSwitch.on = [prefs boolForKey:@"MarkWhileScrolling"];
    self.reverseItemOrderSwitch.on = [prefs boolForKey:@"ReverseItemOrder"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
/*
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 3) {
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
            mailViewController.mailComposeDelegate = self;
            [mailViewController setToRecipients:[NSArray arrayWithObject:@"support@peterandlinda.com"]];
            [mailViewController setSubject:@"CloudNews Support Request"];
            [mailViewController setMessageBody:@"<Please state your question or problem here>" isHTML:NO ];
            mailViewController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:mailViewController animated:YES completion:nil];
        }
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    UIViewController *vc = [segue destinationViewController];
    vc.navigationItem.rightBarButtonItem = nil;
}



- (IBAction)syncOnStartChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.syncOnStartSwitch.on forKey:@"SyncOnStart"];
}

- (IBAction)syncInBackgroundChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.syncinBackgroundSwitch.on forKey:@"SyncInBackground"];
}

- (IBAction)showFaviconsChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.showFaviconsSwitch.on forKey:@"ShowFavicons"];
}

- (IBAction)showThumbnailsChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.showThumbnailsSwitch.on forKey:@"ShowThumbnails"];
}

- (IBAction)markWhileScrollingChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.markWhileScrollingSwitch.on forKey:@"MarkWhileScrolling"];
}

- (IBAction)reverseItemOrderChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.reverseItemOrderSwitch.on forKey:@"ReverseItemOrder"];
}

- (IBAction)didTapDone:(id)sender {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end

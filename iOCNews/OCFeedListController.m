//
//  FeedListController.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2012-2013 Peter Hedlund peter.hedlund@me.com
 
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

#import "OCFeedListController.h"
#import "OCFeedCell.h"
#import "OCLoginController.h"
#import "TSMessage.h"
#import "OCNewsHelper.h"
#import "Folder.h"
#import "Feed.h"
#import "UIImageView+WebCache.h"
#import "AFNetworking.h"
#import "UIViewController+MMDrawerController.h"

@interface OCFeedListController () <UIActionSheetDelegate> {
    NSNumber *currentRenameId;
    long currentIndex;
    BOOL networkHasBeenUnreachable;
}

- (void) networkSuccess:(NSNotification*)n;
- (void) networkError:(NSNotification*)n;
- (void) showMenu:(UIBarButtonItem*)sender event:(UIEvent*)event;
- (void) doHideRead;
- (void) updatePredicate;
- (void) reachabilityChanged:(NSNotification *)n;
- (void) didBecomeActive:(NSNotification *)n;

@end

@implementation OCFeedListController

@synthesize addBarButtonItem;
@synthesize backBarButtonItem;
@synthesize editBarButtonItem;
@synthesize settingsPopover;
@synthesize feedRefreshControl;
@synthesize specialFetchedResultsController;
@synthesize foldersFetchedResultsController;
@synthesize feedsFetchedResultsController;
@synthesize gearActionSheet;
@synthesize addFolderAlertView;
@synthesize renameFolderAlertView;
@synthesize addFeedAlertView;
@synthesize folderId;

- (NSFetchedResultsController *)specialFetchedResultsController {
    if (!specialFetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Feed" inManagedObjectContext:[OCNewsHelper sharedHelper].context];
        [fetchRequest setEntity:entity];
        
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"myId < 0"];
        [fetchRequest setPredicate:pred];
        
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:100];
        
        specialFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                              managedObjectContext:[OCNewsHelper sharedHelper].context
                                                                                sectionNameKeyPath:nil
                                                                                         cacheName:@"SpecialCache"];
        specialFetchedResultsController.delegate = self;
    }
    return specialFetchedResultsController;
}

- (NSFetchedResultsController *)foldersFetchedResultsController {
    if (!foldersFetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Folder" inManagedObjectContext:[OCNewsHelper sharedHelper].context];
        [fetchRequest setEntity:entity];

        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:20];
    
        foldersFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                              managedObjectContext:[OCNewsHelper sharedHelper].context
                                                                                sectionNameKeyPath:nil
                                                                                         cacheName:@"FolderCache"];
        foldersFetchedResultsController.delegate = self;
    }
    return foldersFetchedResultsController;
}

- (NSFetchedResultsController *)feedsFetchedResultsController {
    if (!feedsFetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Feed" inManagedObjectContext:[OCNewsHelper sharedHelper].context];
        [fetchRequest setEntity:entity];

        NSPredicate *pred = [NSPredicate predicateWithFormat:@"myId > 0"];
        [fetchRequest setPredicate:pred];

        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:20];
        
        feedsFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                            managedObjectContext:[OCNewsHelper sharedHelper].context
                                                                              sectionNameKeyPath:nil
                                                                                       cacheName:@"FeedCache"];
        feedsFetchedResultsController.delegate = self;
    }
    return feedsFetchedResultsController;
}

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

    self.clearsSelectionOnViewWillAppear = NO;
    self.tableView.allowsSelection = YES;
    self.tableView.allowsSelectionDuringEditing = YES;

    currentIndex = -1;
//    self.folderId = 0;
    networkHasBeenUnreachable = NO;
    
    int imageViewOffset = 14;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFavicons"]) {
        imageViewOffset = 36;
    }
    self.tableView.separatorInset = UIEdgeInsetsMake(0, imageViewOffset, 0, 0);
    
    self.refreshControl = self.feedRefreshControl;
    
    self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
//    self.navigationItem.title = @"Feeds";
    self.navigationController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;

    //Notifications
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"HideRead"
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];

    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"SyncInBackground"
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];

    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"ShowFavicons"
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:AFNetworkingReachabilityDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawerOpened:)
                                                 name:@"DrawerOpened"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawerClosed:)
                                                 name:@"DrawerClosed"
                                               object:nil];

    UINavigationController *navController = (UINavigationController*)self.mm_drawerController.centerViewController;
    if (!self.detailViewController) {
        self.detailViewController = (OCArticleListController *)navController.topViewController;
    }
    
    [self.mm_drawerController openDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
    [self updatePredicate];
}

- (void)dealloc
{
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"HideRead"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0:
            return [self.specialFetchedResultsController fetchedObjects].count;
            break;
        case 1:
            return [self.foldersFetchedResultsController fetchedObjects].count;
            break;
        case 2:
            return [self.feedsFetchedResultsController fetchedObjects].count;
            break;
            
        default:
            return 0;
            break;
    }
    
    return 0;
}

- (void)configureCell:(OCFeedCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    @try {
        NSIndexPath *indexPathTemp = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
        if (indexPathTemp.row < [self.tableView numberOfRowsInSection:indexPath.section]) {
            if (indexPath.section == 1) {
                Folder *folder = [self.foldersFetchedResultsController objectAtIndexPath:indexPathTemp];
                [cell.imageView setImage:[UIImage imageNamed:@"folder"]];
                cell.textLabel.text = folder.name;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.countBadge.value = folder.unreadCountValue;
            } else {
                Feed *feed;
                if (indexPath.section == 0) {
                    if (indexPath.row < 2) {
                        feed = [self.specialFetchedResultsController objectAtIndexPath:indexPathTemp];
                    }
                } else {
                    feed = [self.feedsFetchedResultsController objectAtIndexPath:indexPathTemp];
                }
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFavicons"]) {
                    NSString *faviconLink = feed.faviconLink;
                    if ([faviconLink hasPrefix:@"http"]) {
                        NSURL *faviconURL = [NSURL URLWithString:faviconLink] ;
                        if (faviconURL) {
                            if (cell.tag == indexPathTemp.row) {
                                [cell.imageView sd_setImageWithURL:faviconURL placeholderImage:[UIImage imageNamed:@"favicon"]];
                            }
                        }
                    } else {
                        if ((self.folderId > 0) && (indexPath.section == 0) && indexPath.row == 0) {
                            [cell.imageView setImage:[UIImage imageNamed:@"folder"]];
                        } else {
                            [cell.imageView setImage:[UIImage imageNamed:faviconLink]];
                        }
                    }
                }
                cell.accessoryType = UITableViewCellAccessoryNone;
                if ((self.folderId > 0) && (indexPath.section == 0) && indexPath.row == 0) {
                    Folder *folder = [[OCNewsHelper sharedHelper] folderWithId:[NSNumber numberWithLong:self.folderId]];
                    cell.countBadge.value = folder.unreadCountValue;
                    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
                    if ([prefs boolForKey:@"HideRead"]) {
                        cell.textLabel.text = [NSString stringWithFormat:@"All Unread %@ Articles", folder.name];
                    } else {
                        cell.textLabel.text = [NSString stringWithFormat:@"All %@ Articles", folder.name];
                    }
                } else {
//                    NSLog(@"Unread count: %d", feed.unreadCountValue);
                    cell.countBadge.value = feed.unreadCountValue;
                    cell.textLabel.text = feed.title;
                }
            }
            cell.backgroundColor = [UIColor clearColor];
            cell.delegate = self;
        }
    }
    @catch (NSException *exception) {
        //
    }
    @finally {
        //
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    OCFeedCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[OCFeedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        UIView * selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
        [selectedBackgroundView setBackgroundColor:[UIColor colorWithRed:0.87f green:0.87f blue:0.87f alpha:1.0f]]; // set color here
        [cell setSelectedBackgroundView:selectedBackgroundView];
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.tag = indexPath.row;
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return (indexPath.section > 0);
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSIndexPath *indexPathTemp = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
        if (indexPath.section == 1) {
            [[OCNewsHelper sharedHelper] deleteFolderOffline:[self.foldersFetchedResultsController objectAtIndexPath:indexPathTemp]];
        } else if (indexPath.section == 2) {
            [[OCNewsHelper sharedHelper] deleteFeedOffline:[self.feedsFetchedResultsController objectAtIndexPath:indexPathTemp]];
        }
    }
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    //
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.detailViewController.folderId = 0;
    currentIndex = indexPath.row;
    NSIndexPath *indexPathTemp = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    if (self.tableView.isEditing) {
        //[self showRenameForIndex:indexPath.row];
    } else {
        Folder *folder;
        Feed *feed;
        switch (indexPath.section) {
            case 0:
                @try {
                    [self.mm_drawerController closeDrawerAnimated:YES completion:nil];
                    feed = [self.specialFetchedResultsController objectAtIndexPath:indexPathTemp];
                    if (self.folderId > 0) {
                        self.detailViewController.folderId = self.folderId;
                    }
                    self.detailViewController.feed = feed;
                }
                @catch (NSException *exception) {
                    //
                }
                break;
            case 1:
                @try {
                    OCFeedListController *folderController = [self.storyboard instantiateViewControllerWithIdentifier:@"feed_list"];
                    folder = [self.foldersFetchedResultsController objectAtIndexPath:indexPathTemp];
                    folderController.folderId = folder.myIdValue;
//                    self.folderId = folder.myIdValue;
                    folderController.navigationItem.title = folder.name;
//                    folderController.navigationItem.leftBarButtonItem = folderController.backBarButtonItem;
                    [folderController updatePredicate];
                    folderController.detailViewController = self.detailViewController;
                    [self.navigationController pushViewController:folderController animated:YES];
                    [folderController drawerOpened:nil];
                    [self drawerClosed:nil];
                }
                @catch (NSException *exception) {
                    //
                }
                break;
            case 2:
                @try {
                    [self.mm_drawerController closeDrawerAnimated:YES completion:nil];
                    feed = [self.feedsFetchedResultsController objectAtIndexPath:indexPathTemp];
                    self.detailViewController.feed = feed;
                    
                }
                @catch (NSException *exception) {
                    //
                }
                break;
                
            default:
                break;
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Delete";
}

- (void)tableView:(UITableView *)tableView moreOptionButtonPressedInRowAtIndexPath:(NSIndexPath *)indexPath {
    NSIndexPath *indexPathTemp = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    if ((indexPath.section == 1)) {
        Folder *folder = [self.foldersFetchedResultsController objectAtIndexPath:indexPathTemp];
        currentRenameId = folder.myId;
        [[self.renameFolderAlertView textFieldAtIndex:0] setText:folder.name];
        [self.renameFolderAlertView show];
    } else if (indexPath.section == 2) {
        Feed *feed = [self.feedsFetchedResultsController objectAtIndexPath:indexPathTemp];
        NSLog(@"Feed title: %@", feed.title);
        NSLog(@"Feed title: %@", feed.title);
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle: nil];
        UINavigationController *navController = [storyboard instantiateViewControllerWithIdentifier: @"feedextra"];
        OCFeedSettingsController *settingsController = (OCFeedSettingsController*)navController.topViewController;
        [settingsController loadView];
        settingsController.feed = feed;
        settingsController.delegate = self;
        [self.mm_drawerController presentViewController:navController animated:YES completion:nil];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForMoreOptionButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"More";
}
/*
-(UIColor *)tableView:(UITableView *)tableView backgroundColorForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [UIColor colorWithRed:0.18f green:0.67f blue:0.84f alpha:1.0f];
}
*/

#pragma mark - Actions

- (void)showMenu:(UIBarButtonItem *)sender event:(UIEvent *)event {
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* settingsAction = [UIAlertAction actionWithTitle:@"Settings"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              [self doSettings:action];
                                                              
                                                          }];
    
    [alert addAction:settingsAction];
 
    UIAlertAction* addFolderAction = [UIAlertAction actionWithTitle:@"Add Folder"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               [self.addFolderAlertView show];
                                                               
                                                           }];
    
    [alert addAction:addFolderAction];

    UIAlertAction* addFeedAction = [UIAlertAction actionWithTitle:@"Add Feed"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                [self.addFeedAlertView show];
                                                                
                                                            }];
    
    [alert addAction:addFeedAction];

    NSString *hideReadTitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideRead"] ? @"Show Read" : @"Hide Read";
    UIAlertAction* hideReadAction = [UIAlertAction actionWithTitle:hideReadTitle
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              [self doHideRead];
                                                              
                                                          }];
    
    [alert addAction:hideReadAction];

if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    alert.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover)
    {
        popover.barButtonItem = self.addBarButtonItem;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
}
    [self.mm_drawerController presentViewController:alert animated:YES completion:nil];
    
    
    //    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    //        [self.gearActionSheet showFromBarButtonItem:sender animated:YES];
//    } else {
//        [self.gearActionSheet showInView:self.view];
//    }
}

- (UIAlertView*)addFolderAlertView {
    if (!addFolderAlertView) {
        addFolderAlertView = [[UIAlertView alloc] initWithTitle:@"Add New Folder" message:@"Enter the name of the folder to add." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add", nil];
        addFolderAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField * alertTextField = [addFolderAlertView textFieldAtIndex:0];
        alertTextField.keyboardType = UIKeyboardTypeDefault;
        alertTextField.placeholder = @"Folder name";
    }
    return addFolderAlertView;
}

- (UIAlertView*)renameFolderAlertView {
    if (!renameFolderAlertView) {
        renameFolderAlertView = [[UIAlertView alloc] initWithTitle:@"Rename Folder" message:@"Enter the new name of the folder." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Rename", nil];
        renameFolderAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField * alertTextField = [renameFolderAlertView textFieldAtIndex:0];
        alertTextField.keyboardType = UIKeyboardTypeDefault;
        alertTextField.placeholder = @"Folder name";
    }
    return renameFolderAlertView;
}

- (UIAlertView*)addFeedAlertView {
    if (!addFeedAlertView) {
        addFeedAlertView = [[UIAlertView alloc] initWithTitle:@"Add New Feed" message:@"Enter the url of the feed to add." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add",nil];
        addFeedAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField * alertTextField = [addFeedAlertView textFieldAtIndex:0];
        alertTextField.keyboardType = UIKeyboardTypeURL;
        alertTextField.placeholder = @"http://example.com/feed";
    }
    return addFeedAlertView;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
//
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView isEqual:self.addFolderAlertView]) {
        if (buttonIndex == 1) {
            [[OCNewsHelper sharedHelper] addFolderOffline:[[alertView textFieldAtIndex:0] text]];
        }
    }
    if ([alertView isEqual:self.renameFolderAlertView]) {
        if (buttonIndex == 1) {
            [[OCNewsHelper sharedHelper] renameFolderOfflineWithId:currentRenameId To:[[alertView textFieldAtIndex:0] text]];
        }
    }
    if ([alertView isEqual:self.addFeedAlertView]) {
        if (buttonIndex == 1) {
            [[OCNewsHelper sharedHelper] addFeedOffline:[[alertView textFieldAtIndex:0] text]];
        }
    }
}

- (void)doHideRead {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL hideRead = [prefs boolForKey:@"HideRead"];
    [prefs setBool:!hideRead forKey:@"HideRead"];
    [prefs synchronize];
    [[OCNewsHelper sharedHelper] renameFeedOfflineWithId:[NSNumber numberWithInt:-2] To:hideRead == YES ? @"All Articles" : @"All Unread Articles"];
}

- (IBAction)doSettings:(id)sender {
    UIStoryboard *storyboard;
    UINavigationController *nav;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    if ([sender isKindOfClass:[UIAlertAction class]]) {
        nav = [storyboard instantiateViewControllerWithIdentifier:@"login"];
        [nav.topViewController loadView];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    } else {
        OCLoginController *lc = [storyboard instantiateViewControllerWithIdentifier:@"server"];
        nav = [[UINavigationController alloc] initWithRootViewController:lc];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self.mm_drawerController.leftDrawerViewController presentViewController:nav animated:YES completion:nil];
}

- (IBAction)doRefresh:(id)sender {
    if (self.folderId == 0) {
        [[OCNewsHelper sharedHelper] sync:nil];
    } else {
        [[OCNewsHelper sharedHelper] updateFolderWithId:[NSNumber numberWithLong:self.folderId]];
    }
}

- (void) reloadRow:(NSIndexPath*)indexPath {
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    if (currentIndex >= 0) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }

}

//- (IBAction)handleTableviewSwipe:(UISwipeGestureRecognizer *)gestureRecognizer {
//    if (self.folderId > 0) {
//        [self doGoBack];
//    }
//}

- (void) feedSettingsUpdate:(OCFeedSettingsController *)settings {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.settingsPopover dismissPopoverAnimated:YES];
    }
    [self.tableView reloadData]; // reloadRowsAtIndexPaths:@[[self.feedsFetchedResultsController indexPathForObject:settings.feed]] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context {
    if([keyPath isEqual:@"HideRead"]) {
        [self updatePredicate];
    }
    if([keyPath isEqual:@"SyncInBackground"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SyncInBackground"]) {
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
        } else {
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
        }
    }
    if([keyPath isEqual:@"ShowFavicons"]) {
        int imageViewOffset = 14;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFavicons"]) {
            imageViewOffset = 36;
        }
        self.tableView.separatorInset = UIEdgeInsetsMake(0, imageViewOffset, 0, 0);
        [self.tableView reloadData];
    }
}

- (void)updatePredicate {
    [NSFetchedResultsController deleteCacheWithName:@"SpecialCache"];
    [NSFetchedResultsController deleteCacheWithName:@"FolderCache"];
    [NSFetchedResultsController deleteCacheWithName:@"FeedCache"];
    NSPredicate *predFolder = [NSPredicate predicateWithFormat:@"folderId == %@", [NSNumber numberWithLong:self.folderId]];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HideRead"]) {
        NSPredicate *pred1 = [NSPredicate predicateWithFormat:@"myId > 0"];
        NSPredicate *pred2 = [NSPredicate predicateWithFormat:@"unreadCount == 0"];
        NSArray *predArray = @[pred1, pred2];
        NSPredicate *pred3 = [NSCompoundPredicate andPredicateWithSubpredicates:predArray];
        NSPredicate *pred4 = [NSCompoundPredicate notPredicateWithSubpredicate:pred3];
        NSArray *predArray1 = @[predFolder, pred1, pred4];
        NSPredicate *pred5 = [NSCompoundPredicate andPredicateWithSubpredicates:predArray1];
        [[self.feedsFetchedResultsController fetchRequest] setPredicate:pred5];
    } else{
        NSPredicate *pred1 = [NSPredicate predicateWithFormat:@"myId > 0"];
        NSArray *predArray = @[predFolder, pred1];
        NSPredicate *pred3 = [NSCompoundPredicate andPredicateWithSubpredicates:predArray];
        [[self.feedsFetchedResultsController fetchRequest] setPredicate:pred3];
    }
    
    if (self.folderId > 0) {
        self.specialFetchedResultsController.fetchRequest.predicate = [NSPredicate predicateWithFormat:@"myId == -2"];
        self.foldersFetchedResultsController.fetchRequest.predicate = [NSPredicate predicateWithValue:NO];
    } else {
        self.specialFetchedResultsController.fetchRequest.predicate = [NSPredicate predicateWithFormat:@"myId < 0"];
        self.foldersFetchedResultsController.fetchRequest.predicate = nil;
    }
    
    NSError *error;
    if (![[self specialFetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    if (![[self foldersFetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    if (![[self feedsFetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    [self.tableView reloadData];
}

- (void)reachabilityChanged:(NSNotification *)n {
    NSNumber *s = n.userInfo[AFNetworkingReachabilityNotificationStatusItem];
    AFNetworkReachabilityStatus status = [s integerValue];
    
    if (status == AFNetworkReachabilityStatusNotReachable) {
        networkHasBeenUnreachable = YES;
        [TSMessage showNotificationInViewController:self.navigationController title:@"Unable to Reach Server" subtitle:@"Please check network connection and login." type:TSMessageNotificationTypeWarning];
    }
    if (status > AFNetworkReachabilityStatusNotReachable) {
        if (networkHasBeenUnreachable) {
            [TSMessage showNotificationInViewController:self.navigationController title:@"Server Reachable" subtitle:@"The network connection is working properly." type:TSMessageNotificationTypeSuccess];
            networkHasBeenUnreachable = NO;
        }
    }
}

- (void) didBecomeActive:(NSNotification *)n {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"Server"].length == 0) {
        [self doSettings:nil];
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SyncOnStart"]) {
            [[OCNewsHelper sharedHelper] performSelector:@selector(sync:) withObject:nil afterDelay:1.0f];
        }
        UIPasteboard *board = [UIPasteboard generalPasteboard];
        if (board.URL) {
            if (![board.URL.absoluteString isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"PreviousPasteboardURL"]]) {
                [[NSUserDefaults standardUserDefaults] setObject:board.URL.absoluteString forKey:@"PreviousPasteboardURL"];
                NSArray *feedURLStrings = [self.feedsFetchedResultsController.fetchedObjects valueForKey:@"url"];
                NSLog(@"URLs: %@", feedURLStrings);
                if ([feedURLStrings indexOfObject:[board.URL absoluteString]] == NSNotFound) {
                    NSString *message = [NSString stringWithFormat:@"Would you like to add the feed: '%@'?", [board.URL absoluteString]];
                    [TSMessage showNotificationInViewController:self.navigationController
                                                          title:@"Add Feed"
                                                       subtitle:message
                                                          image:nil
                                                           type:TSMessageNotificationTypeMessage
                                                       duration:TSMessageNotificationDurationAutomatic
                                                       callback:nil
                                                    buttonTitle:@"Add"
                                                 buttonCallback:^{
                                                 [[OCNewsHelper sharedHelper] addFeedOffline:[board.URL absoluteString]];
                                             }
                                                     atPosition:TSMessageNotificationPositionTop
                                            canBeDismissedByUser:YES];
                }
            }
        }
    }
}

- (void)drawerOpened:(NSNotification *)n {
    if ([self.navigationController.topViewController isEqual:self]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkSuccess:) name:@"NetworkSuccess" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkError:) name:@"NetworkError" object:nil];
    }
    self.tableView.scrollsToTop = YES;
}

- (void)drawerClosed:(NSNotification *)n {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NetworkSuccess" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NetworkError" object:nil];
    self.tableView.scrollsToTop = NO;
}

#pragma mark - Feeds maintenance

- (void) networkSuccess:(NSNotification *)n {
    [self.refreshControl endRefreshing];
    [self.detailViewController.refreshControl endRefreshing];
}

- (void)networkError:(NSNotification *)n {
    [self.refreshControl endRefreshing];
    [self.detailViewController.refreshControl endRefreshing];
    [TSMessage showNotificationInViewController:self.navigationController
                                          title:[n.userInfo objectForKey:@"Title"]
                                       subtitle:[n.userInfo objectForKey:@"Message"]
                                          image:nil
                                           type:TSMessageNotificationTypeError
                                       duration:TSMessageNotificationDurationEndless
                                       callback:nil
                                    buttonTitle:nil
                                 buttonCallback:nil
                                     atPosition:TSMessageNotificationPositionTop
                            canBeDismissedByUser:YES];
}

#pragma mark - Toolbar Buttons

- (UIBarButtonItem *)addBarButtonItem {
    
    if (!addBarButtonItem) {
        addBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear"] style:UIBarButtonItemStylePlain target:self action:@selector(showMenu:event:)];
        addBarButtonItem.imageInsets = UIEdgeInsetsMake(2.0f, 0.0f, -2.0f, 0.0f);
    }
    
    return addBarButtonItem;
}

- (UIBarButtonItem *)backBarButtonItem {
    if (!backBarButtonItem) {
        backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Feeds" style:UIBarButtonItemStylePlain target:self action:@selector(doGoBack)];
    }
    return backBarButtonItem;
}

- (UIRefreshControl *)feedRefreshControl {
    if (!feedRefreshControl) {
        feedRefreshControl = [[UIRefreshControl alloc] init];
        [feedRefreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    }    
    return feedRefreshControl;
}

- (UIPopoverController *) settingsPopover {
    if (!settingsPopover) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle: nil];
        settingsPopover = [[UIPopoverController alloc] initWithContentViewController:[storyboard instantiateViewControllerWithIdentifier: @"feedextra"]];
        [settingsPopover setPopoverContentSize:CGSizeMake(320, 220)];
    }
    return settingsPopover;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    NSLog(@"Section: %ld; Row: %ld", (long)indexPath.section, (long)indexPath.row);

    UITableView *tableView = self.tableView;
    if (newIndexPath != nil && controller == self.foldersFetchedResultsController) {
        newIndexPath = [NSIndexPath indexPathForRow:[newIndexPath row] inSection:1];
        //if ([tableView cellForRowAtIndexPath:newIndexPath] == nil) {
        //    type = NSFetchedResultsChangeInsert;
        //}
    }
    if (newIndexPath != nil && controller == self.feedsFetchedResultsController) {
        newIndexPath = [NSIndexPath indexPathForRow:[newIndexPath row] inSection:2];
        //if ([tableView cellForRowAtIndexPath:newIndexPath] == nil) {
        //    type = NSFetchedResultsChangeInsert;
        //}
    }
    if (indexPath != nil && controller == self.foldersFetchedResultsController) {
        indexPath = [NSIndexPath indexPathForRow:[indexPath row] inSection:1];
    }
    if (indexPath != nil && controller == self.feedsFetchedResultsController) {
        indexPath = [NSIndexPath indexPathForRow:[indexPath row] inSection:2];
    }

    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(OCFeedCell*)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray
                                               arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray
                                               arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}

@end

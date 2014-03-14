//
//  WAYMasterViewController.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WAYCommentsViewController;

#import <CoreData/CoreData.h>

@interface WAYPostsViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) WAYCommentsViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

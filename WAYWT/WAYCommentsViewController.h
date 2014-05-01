//
//  WAYDetailViewController.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WAYPost.h"

@interface WAYCommentsViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) WAYPost *post;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

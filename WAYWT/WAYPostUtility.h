//
//  WAYPostUtility.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface WAYPostUtility : NSObject


+ (void)syncPostsForSubreddit:(NSString*)subreddit context:(NSManagedObjectContext*)moc observer:(NSObject*)observer;

@end

//
//  WAYCommentUtility.m
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-04-21.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import "WAYCommentUtility.h"

@implementation WAYCommentUtility

+ (void)syncCommentsForPost:(WAYPost*)post context:(NSManagedObjectContext *)moc observer:(NSObject *)observer
{
    NSPersistentStoreCoordinator *mainThreadContextStoreCoordinator = [moc persistentStoreCoordinator];
    
    // Background thread for sync
    dispatch_queue_t request_queue = dispatch_queue_create("com.sobremesa.waywt.syncComments", NULL);
    
    dispatch_async(request_queue, ^{
        
        
        // Create a new managed object context
        // Set its persistent store coordinator
        NSManagedObjectContext *newMoc = [[NSManagedObjectContext alloc] init];
        [newMoc setPersistentStoreCoordinator:mainThreadContextStoreCoordinator];
        
        
        
        // Register for context save changes notification
        NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
        [notify addObserver:observer
                   selector:@selector(mergeChanges:)
                       name:NSManagedObjectContextDidSaveNotification
                     object:newMoc];
        
        
        NSString *urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/%@/comments/%@/z/.json?sort=confidence&limit=500&depth=1",
                               post.subreddit,
                               post.postId];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *newData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *responseString = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
        NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        
    });
}
@end

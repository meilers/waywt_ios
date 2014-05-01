//
//  WAYPostUtility.m
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import "WAYPostUtility.h"
#import "WAYPost.h"
#import "WAYApiClient.h"

static dispatch_semaphore_t _postSyncSemaphore;

enum PostType : NSUInteger {
    INVALID = 0,
    WAYWT = 1,
    OUTFIT_FEEDBACK = 2,
    RECENT_PURCHASES = 3
};

@implementation WAYPostUtility

+ (void)syncPostsForSubreddit:(NSString*)subreddit context:(NSManagedObjectContext*)moc observer:(NSObject*)observer
{
    
    __block NSString *t = @"";
    __block NSString *after = @"";
    
    __block int i = 0;
    
    NSPersistentStoreCoordinator *mainThreadContextStoreCoordinator = [moc persistentStoreCoordinator];
    
    // Background thread for sync
    dispatch_queue_t request_queue = dispatch_queue_create("com.sobremesa.waywt.syncPosts", NULL);
    
    dispatch_async(request_queue, ^{
        
        // The sync is a critical section
        dispatch_semaphore_wait(self.postSyncSemaphore, DISPATCH_TIME_FOREVER);
        
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
        
        
        // Core Data Results
        NSError *error = nil;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"WAYPost"];
        [request setSortDescriptors:[NSArray arrayWithObject:
                                     [NSSortDescriptor sortDescriptorWithKey:@"created" ascending:NO]]];
        
        NSArray *localPosts = [newMoc executeFetchRequest:request error:&error];
        NSMutableDictionary *localPostMap = [NSMutableDictionary dictionaryWithObjects:localPosts forKeys:[localPosts valueForKey:@"postId"]];
        

        
        /** START SYNCHRONIZE **/
        
        NSMutableDictionary *remotePostsSyncedMap = [[NSMutableDictionary alloc] init];

        
        // new
        while( after != nil && i < 1 )
        {
            
            NSString *urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/malefashionadvice/hot.json?t=%@&after=%@",
                                   t,
                                   after];
            NSURL *url = [NSURL URLWithString:urlString];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *newData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *responseString = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
            NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            
            
            NSDictionary *remoteData = [JSON objectForKey:@"data"];
            NSArray *remotePosts = [remoteData objectForKey:@"children"];
            
            
            
            for (NSDictionary *remotePostData in remotePosts) {
                
                
                NSDictionary *remotePost = [remotePostData objectForKey:@"data"];
                NSString *remotePostId = [remotePost objectForKey:@"id"];
                
                // check for duplicate posts
                if( [[remotePostsSyncedMap allKeys] containsObject:remotePostId] )
                    continue;
                                    
                // Insert
                if( ![[localPostMap allKeys] containsObject:remotePostId] )
                {
                    WAYPost *newPost = (WAYPost *)[NSEntityDescription insertNewObjectForEntityForName:@"WAYPost" inManagedObjectContext:newMoc];
                    newPost.postId = remotePostId;
                    newPost.author = [remotePost objectForKey:@"author"];
                    newPost.created = [remotePost objectForKey:@"created"];
                    newPost.title = [remotePost objectForKey:@"title"];
                    newPost.domain = [remotePost objectForKey:@"domain"];
                    newPost.permalink = [remotePost objectForKey:@"permalink"];
                    newPost.ups = [remotePost objectForKey:@"ups"];
                    newPost.downs = [remotePost objectForKey:@"downs"];
                    newPost.subreddit = subreddit;
                    newPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:newPost]];
                    
                    if( [newPost.type isEqualToNumber:[NSNumber numberWithInt:INVALID]] )
                        [newMoc deleteObject:newPost];
                }
                // Update
                else
                {
                    WAYPost *updatedPost = [localPostMap objectForKey:remotePostId];
                    updatedPost.postId = remotePostId;
                    updatedPost.author = [remotePost objectForKey:@"author"];
                    updatedPost.created = [remotePost objectForKey:@"created"];
                    updatedPost.title = [remotePost objectForKey:@"title"];
                    updatedPost.domain = [remotePost objectForKey:@"domain"];
                    updatedPost.permalink = [remotePost objectForKey:@"permalink"];
                    updatedPost.ups = [remotePost objectForKey:@"ups"];
                    updatedPost.downs = [remotePost objectForKey:@"downs"];
                    updatedPost.subreddit = subreddit;
                    updatedPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:updatedPost]];
                    
                    [newMoc refreshObject:updatedPost mergeChanges:true];
                    [localPostMap removeObjectForKey:remotePostId];
                }
                
                [remotePostsSyncedMap setObject:remotePost forKey:remotePostId];
            }
            
            after = [remoteData objectForKey:@"after"];
            ++i;
        }

        // today
        i = 0;
        t = @"today";
        after = @"";
        
        while( after != nil && i < 2 )
        {
            
            NSString *urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/malefashionadvice/top.json?t=%@&after=%@",
                                   t,
                                   after];
            NSURL *url = [NSURL URLWithString:urlString];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *newData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *responseString = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
            NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            
            
            NSDictionary *remoteData = [JSON objectForKey:@"data"];
            NSArray *remotePosts = [remoteData objectForKey:@"children"];
            
            
            
            for (NSDictionary *remotePostData in remotePosts) {
                
                NSDictionary *remotePost = [remotePostData objectForKey:@"data"];
                NSString *remotePostId = [remotePost objectForKey:@"id"];
                
                // check for duplicate posts
                if( [[remotePostsSyncedMap allKeys] containsObject:remotePostId] )
                    continue;
                
                // Insert
                if( ![[localPostMap allKeys] containsObject:remotePostId] )
                {
                    WAYPost *newPost = (WAYPost *)[NSEntityDescription insertNewObjectForEntityForName:@"WAYPost" inManagedObjectContext:newMoc];
                    newPost.postId = remotePostId;
                    newPost.author = [remotePost objectForKey:@"author"];
                    newPost.created = [remotePost objectForKey:@"created"];
                    newPost.title = [remotePost objectForKey:@"title"];
                    newPost.domain = [remotePost objectForKey:@"domain"];
                    newPost.permalink = [remotePost objectForKey:@"permalink"];
                    newPost.ups = [remotePost objectForKey:@"ups"];
                    newPost.downs = [remotePost objectForKey:@"downs"];
                    newPost.subreddit = subreddit;
                    newPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:newPost]];
                    
                    if( [newPost.type isEqualToNumber:[NSNumber numberWithInt:INVALID]] )
                        [newMoc deleteObject:newPost];
                }
                // Update
                else
                {
                    WAYPost *updatedPost = [localPostMap objectForKey:remotePostId];
                    updatedPost.postId = remotePostId;
                    updatedPost.author = [remotePost objectForKey:@"author"];
                    updatedPost.created = [remotePost objectForKey:@"created"];
                    updatedPost.title = [remotePost objectForKey:@"title"];
                    updatedPost.domain = [remotePost objectForKey:@"domain"];
                    updatedPost.permalink = [remotePost objectForKey:@"permalink"];
                    updatedPost.ups = [remotePost objectForKey:@"ups"];
                    updatedPost.downs = [remotePost objectForKey:@"downs"];
                    updatedPost.subreddit = subreddit;
                    updatedPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:updatedPost]];
                    
                    [newMoc refreshObject:updatedPost mergeChanges:true];
                    [localPostMap removeObjectForKey:remotePostId];
                }
                
                [remotePostsSyncedMap setObject:remotePost forKey:remotePostId];
            }
            
            after = [remoteData objectForKey:@"after"];
            ++i;
        }
        
        // week
        i = 0;
        t = @"week";
        after = @"";
        
        while( after != nil && i < 3 )
        {
            
            NSString *urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/malefashionadvice/top.json?t=%@&after=%@",
                                   t,
                                   after];
            NSURL *url = [NSURL URLWithString:urlString];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *newData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *responseString = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
            NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            
            
            NSDictionary *remoteData = [JSON objectForKey:@"data"];
            NSArray *remotePosts = [remoteData objectForKey:@"children"];
            
            
            
            for (NSDictionary *remotePostData in remotePosts) {
                
                NSDictionary *remotePost = [remotePostData objectForKey:@"data"];
                NSString *remotePostId = [remotePost objectForKey:@"id"];
                
                // check for duplicate posts
                if( [[remotePostsSyncedMap allKeys] containsObject:remotePostId] )
                    continue;
                
                // Insert
                if( ![[localPostMap allKeys] containsObject:remotePostId] )
                {
                    WAYPost *newPost = (WAYPost *)[NSEntityDescription insertNewObjectForEntityForName:@"WAYPost" inManagedObjectContext:newMoc];
                    newPost.postId = remotePostId;
                    newPost.author = [remotePost objectForKey:@"author"];
                    newPost.created = [remotePost objectForKey:@"created"];
                    newPost.title = [remotePost objectForKey:@"title"];
                    newPost.domain = [remotePost objectForKey:@"domain"];
                    newPost.permalink = [remotePost objectForKey:@"permalink"];
                    newPost.ups = [remotePost objectForKey:@"ups"];
                    newPost.downs = [remotePost objectForKey:@"downs"];
                    newPost.subreddit = subreddit;
                    newPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:newPost]];
                    
                    if( [newPost.type isEqualToNumber:[NSNumber numberWithInt:INVALID]] )
                        [newMoc deleteObject:newPost];
                }
                // Update
                else
                {
                    WAYPost *updatedPost = [localPostMap objectForKey:remotePostId];
                    updatedPost.postId = remotePostId;
                    updatedPost.author = [remotePost objectForKey:@"author"];
                    updatedPost.created = [remotePost objectForKey:@"created"];
                    updatedPost.title = [remotePost objectForKey:@"title"];
                    updatedPost.domain = [remotePost objectForKey:@"domain"];
                    updatedPost.permalink = [remotePost objectForKey:@"permalink"];
                    updatedPost.ups = [remotePost objectForKey:@"ups"];
                    updatedPost.downs = [remotePost objectForKey:@"downs"];
                    updatedPost.subreddit = subreddit;
                    updatedPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:updatedPost]];
                    
                    [newMoc refreshObject:updatedPost mergeChanges:true];
                    [localPostMap removeObjectForKey:remotePostId];
                }
                
                [remotePostsSyncedMap setObject:remotePost forKey:remotePostId];
            }
            
            after = [remoteData objectForKey:@"after"];
            ++i;
        }
        
        
        // month
        i = 0;
        t = @"month";
        after = @"";
        
        while( after != nil && i < 5 )
        {
            
            NSString *urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/malefashionadvice/top.json?t=%@&after=%@",
                                   t,
                                   after];
            NSURL *url = [NSURL URLWithString:urlString];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *newData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *responseString = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
            NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            
            
            NSDictionary *remoteData = [JSON objectForKey:@"data"];
            NSArray *remotePosts = [remoteData objectForKey:@"children"];
            
            
            
            for (NSDictionary *remotePostData in remotePosts) {
                
                NSDictionary *remotePost = [remotePostData objectForKey:@"data"];
                NSString *remotePostId = [remotePost objectForKey:@"id"];
                
                // check for duplicate posts
                if( [[remotePostsSyncedMap allKeys] containsObject:remotePostId] )
                    continue;
                
                // Insert
                if( ![[localPostMap allKeys] containsObject:remotePostId] )
                {
                    WAYPost *newPost = (WAYPost *)[NSEntityDescription insertNewObjectForEntityForName:@"WAYPost" inManagedObjectContext:newMoc];
                    newPost.postId = remotePostId;
                    newPost.author = [remotePost objectForKey:@"author"];
                    newPost.created = [remotePost objectForKey:@"created"];
                    newPost.title = [remotePost objectForKey:@"title"];
                    newPost.domain = [remotePost objectForKey:@"domain"];
                    newPost.permalink = [remotePost objectForKey:@"permalink"];
                    newPost.ups = [remotePost objectForKey:@"ups"];
                    newPost.downs = [remotePost objectForKey:@"downs"];
                    newPost.subreddit = subreddit;
                    newPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:newPost]];
                    
                    if( [newPost.type isEqualToNumber:[NSNumber numberWithInt:INVALID]] )
                        [newMoc deleteObject:newPost];
                }
                // Update
                else
                {
                    WAYPost *updatedPost = [localPostMap objectForKey:remotePostId];
                    updatedPost.postId = remotePostId;
                    updatedPost.author = [remotePost objectForKey:@"author"];
                    updatedPost.created = [remotePost objectForKey:@"created"];
                    updatedPost.title = [remotePost objectForKey:@"title"];
                    updatedPost.domain = [remotePost objectForKey:@"domain"];
                    updatedPost.permalink = [remotePost objectForKey:@"permalink"];
                    updatedPost.ups = [remotePost objectForKey:@"ups"];
                    updatedPost.downs = [remotePost objectForKey:@"downs"];
                    updatedPost.subreddit = subreddit;
                    updatedPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:updatedPost]];
                    
                    [newMoc refreshObject:updatedPost mergeChanges:true];
                    [localPostMap removeObjectForKey:remotePostId];
                }
                
                [remotePostsSyncedMap setObject:remotePost forKey:remotePostId];
            }
            
            after = [remoteData objectForKey:@"after"];
            ++i;
        }
        
        
        // Delete
        for (NSString *key in localPostMap)
        {
            [newMoc deleteObject:[localPostMap objectForKey:key]];
        }
        
        /** END SYNCHRONIZE **/
        
        if (![newMoc save:&error]) {
            NSLog(@"Could not save Core Data context. Error: %@, %@", error, [error userInfo]);
        }

        
        dispatch_semaphore_signal(self.postSyncSemaphore);
    });
    
}


+ (int)retrievePostTypeWithPost:(WAYPost*)post
{
	if( [post.subreddit isEqualToString:@"malefashionadvice"] )
    {
        if( ![post.domain isEqualToString:@"self.malefashionadvice"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
            return INVALID;
    }
    else if( [post.subreddit isEqualToString:@"TeenMFA"] )
    {
        if( ![post.domain isEqualToString:@"self.TeenMFA"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
            return INVALID;
    }
    else if( [post.subreddit isEqualToString:@"femalefashionadvice"] )
    {
        if( ![post.domain isEqualToString:@"self.femalefashionadvice"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
            return INVALID;
    }
    else if( [post.subreddit isEqualToString:@"TeenFFA"] )
    {
        if( ![post.domain isEqualToString:@"self.TeenFFA"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
            return INVALID;
    }
    
    if( [[post.title lowercaseString] rangeOfString:@"waywt"].location != NSNotFound)
        return WAYWT;
    else if( [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location != NSNotFound )
        return OUTFIT_FEEDBACK;
    else if( [[post.title lowercaseString] rangeOfString:@"recent purchases"].location != NSNotFound )
        return RECENT_PURCHASES;
    else
        return INVALID;
}

+ (dispatch_semaphore_t)postSyncSemaphore
{
    if (!_postSyncSemaphore) {
        _postSyncSemaphore = dispatch_semaphore_create(1);
    }
    return _postSyncSemaphore;
}

@end

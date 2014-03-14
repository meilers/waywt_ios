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

+ (void)fetchAndSyncPostsWithContext:(NSManagedObjectContext*)moc setObserver:(NSObject*)observer
{
    
    NSArray *keys;
    NSArray *objects;
    NSDictionary *params;
    
    NSString *t = @"week";
    NSString *after = @"";
    
    int i = 0;
    
    while( after != nil && i < 1 )
    {
        keys = [NSArray arrayWithObjects:@"t", @"after", nil];
        objects = [NSArray arrayWithObjects:t, after, nil];
        params = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
        
        [[WAYApiClient sharedClient] GET:@"/r/malefashionadvice/top.json" parameters:params success:^(NSURLSessionDataTask * __unused task, id JSON) {
            
            // Background thread for sync
            NSPersistentStoreCoordinator *mainThreadContextStoreCoordinator = [moc persistentStoreCoordinator];
            dispatch_queue_t request_queue = dispatch_queue_create("com.sobremesa.waywt.syncPosts", NULL);
            
            dispatch_async(request_queue, ^{
                
                // The sync is a critical section
                dispatch_semaphore_wait(self.postSyncSemaphore, DISPATCH_TIME_FOREVER);
                
                // Create a new managed object context
                // Set its persistent store coordinator
                NSManagedObjectContext *newMoc = [[NSManagedObjectContext alloc] init];
                [newMoc setPersistentStoreCoordinator:mainThreadContextStoreCoordinator];
                
                
                // Web Service Results
                NSDictionary *remoteData = [JSON objectForKey:@"data"];
                NSArray *remotePosts = [remoteData objectForKey:@"children"];
                
                
                // Core Data Results
                NSError *error = nil;
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"WAYPost"];
                [request setSortDescriptors:[NSArray arrayWithObject:
                                             [NSSortDescriptor sortDescriptorWithKey:@"created" ascending:NO]]];
                
                NSArray *localPosts = [newMoc executeFetchRequest:request error:&error];
                NSMutableDictionary *localPostMap = [NSMutableDictionary dictionaryWithObjects:localPosts forKeys:[localPosts valueForKey:@"postId"]];
                
                // Register for context save changes notification
                NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
                [notify addObserver:observer
                           selector:@selector(mergeChanges:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:newMoc];
                
                
                /** START SYNCHRONIZE **/
                
                for (NSDictionary *remotePostData in remotePosts) {
                    
                    NSDictionary *remotePost = [remotePostData objectForKey:@"data"];
                    NSString *remotePostId = [remotePost objectForKey:@"id"];
                    
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
                            newPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:newPost setIsMale:YES setIsTeen:NO]];
                            
//                            if( [newPost.type isEqualToNumber:[NSNumber numberWithInt:INVALID]] )
//                                [newMoc deleteObject:newPost];
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
                        updatedPost.type = [NSNumber numberWithInt:[self retrievePostTypeWithPost:updatedPost setIsMale:YES setIsTeen:NO]];
                        
                        [newMoc refreshObject:updatedPost mergeChanges:true];
                        [localPostMap removeObjectForKey:remotePostId];
                    }
                }
                
                // Delete
                for (NSString *key in localPostMap)
                {
                    [newMoc deleteObject:[localPostMap objectForKey:key]];
                }

                
                
                
                if (![newMoc save:&error]) {
                    NSLog(@"Could not save Core Data context. Error: %@, %@", error, [error userInfo]);
                }
                /** END SYNCHRONIZE **/
                
                dispatch_semaphore_signal(self.postSyncSemaphore);
                
            });
            
        } failure:^(NSURLSessionDataTask *__unused task, NSError *error) {
            NSLog(@"failure:");
        }];
        
        i = 1;
    }
    
//    
//    [[WAYApiClient sharedClient] GET:@"shops" parameters:nil success:^(NSURLSessionDataTask * __unused task, id JSON) {
//        
//        if ([JSON isFOAPIStatusOK]) {
//            
//            // Background thread for sync
//            NSPersistentStoreCoordinator *mainThreadContextStoreCoordinator = [moc persistentStoreCoordinator];
//            dispatch_queue_t request_queue = dispatch_queue_create("com.frankandoak.com.syncCategories", NULL);
//            
//            dispatch_async(request_queue, ^{
//                
//                
//                // The sync is a critical section
//                dispatch_semaphore_wait(self.categorySyncSemaphore, DISPATCH_TIME_FOREVER);
//                
//                // Create a new managed object context
//                // Set its persistent store coordinator
//                NSManagedObjectContext *newMoc = [[NSManagedObjectContext alloc] init];
//                [newMoc setPersistentStoreCoordinator:mainThreadContextStoreCoordinator];
//                
//                
//                // Web Service Results
//                NSDictionary *responseDict = [JSON FOAPIResponse];
//                NSArray *storeList = [responseDict objectForKey:@"stores"];
//                NSArray *subshopList = [responseDict objectForKey:@"subshops"];
//                
//                // Core Data Results
//                NSError *error = nil;
//                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"MAOCategory"];
//                [request setSortDescriptors:[NSArray arrayWithObject:
//                                             [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]]];
//                
//                NSArray *categories = [newMoc executeFetchRequest:request error:&error];
//                NSMutableDictionary *categorytMap = [NSMutableDictionary dictionaryWithObjects:categories forKeys:[categories valueForKey:@"categoryId"]];
//                
//                
//                
//                
//                // Register for context save changes notification
//                NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
//                [notify addObserver:observer
//                           selector:@selector(mergeChanges:)
//                               name:NSManagedObjectContextDidSaveNotification
//                             object:newMoc];
//                
//                
//                /** START SYNCHRONIZE **/
//                for (NSDictionary *catDict in storeList) {
//                    
//                    NSNumber *catId = [catDict objectForKey:@"store_id"];
//                    
//                    // Insert
//                    if( ![[categorytMap allKeys] containsObject:catId] )
//                    {
//                        MAOCategory *newCat = (MAOCategory *)[NSEntityDescription insertNewObjectForEntityForName:@"MAOCategory" inManagedObjectContext:newMoc];
//                        newCat.categoryId = [catDict objectForKey:@"store_id"];
//                        newCat.name = [catDict objectForKey:@"store_name"];
//                        newCat.imageUrl = [catDict objectForKey:@"store_image_url"];
//                        newCat.isStore = [NSNumber numberWithInt:1];
//                        newCat.timestamp = [[NSDate alloc] init];
//                        
//                    }
//                    // Update
//                    else
//                    {
//                        MAOCategory *updatedCat = [categorytMap objectForKey:catId];
//                        updatedCat.categoryId = [catDict objectForKey:@"store_id"];
//                        updatedCat.name = [catDict objectForKey:@"store_name"];
//                        updatedCat.imageUrl = [catDict objectForKey:@"store_image_url"];
//                        updatedCat.timestamp = [[NSDate alloc] init];
//                        updatedCat.isStore = [NSNumber numberWithInt:1];
//                        
//                        [newMoc refreshObject:updatedCat mergeChanges:true];
//                        [categorytMap removeObjectForKey:catId];
//                    }
//                }
//                
//                for (NSDictionary *catDict in subshopList) {
//                    
//                    NSNumber *catId = [catDict objectForKey:@"subshop_id"];
//                    
//                    // Insert
//                    if( ![[categorytMap allKeys] containsObject:catId] )
//                    {
//                        MAOCategory *newCat = (MAOCategory *)[NSEntityDescription insertNewObjectForEntityForName:@"MAOCategory" inManagedObjectContext:newMoc];
//                        newCat.categoryId = [catDict objectForKey:@"subshop_id"];
//                        newCat.name = [catDict objectForKey:@"subshop_title"];
//                        newCat.imageUrl = [catDict objectForKey:@"subshop_image_url"];
//                        newCat.isStore = newCat.isStore = [NSNumber numberWithInt:0];
//                        newCat.timestamp = [[NSDate alloc] init];
//                        
//                    }
//                    // Update
//                    else
//                    {
//                        MAOCategory *updatedCat = [categorytMap objectForKey:catId];
//                        updatedCat.categoryId = [catDict objectForKey:@"subshop_id"];
//                        updatedCat.name = [catDict objectForKey:@"subshop_title"];
//                        updatedCat.imageUrl = [catDict objectForKey:@"subshop_image_url"];
//                        updatedCat.isStore = [NSNumber numberWithInt:0];
//                        updatedCat.timestamp = [[NSDate alloc] init];
//                        
//                        [newMoc refreshObject:updatedCat mergeChanges:true];
//                        [categorytMap removeObjectForKey:catId];
//                    }
//                }
//                
//                // Delete
//                for (NSString *key in categorytMap)
//                {
//                    [newMoc deleteObject:[categorytMap objectForKey:key]];
//                }
//                
//                if (![newMoc save:&error]) {
//                    NSLog(@"Could not save Core Data context. Error: %@, %@", error, [error userInfo]);
//                }
//                /** END SYNCHRONIZE **/
//                
//                dispatch_semaphore_signal(self.categorySyncSemaphore);
//                
//            });
//            
//            
//        }
//    } failure:^(NSURLSessionDataTask *__unused task, NSError *error) {
//        
//    }];
}


+ (int)retrievePostTypeWithPost:(WAYPost*)post setIsMale:(BOOL)isMale setIsTeen:(BOOL)isTeen
{
	if( isMale )
    {
        if( !isTeen )
        {
            if( ![post.domain isEqualToString:@"self.malefashionadvice"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
                return INVALID;
        }
        else
        {
            if( ![post.domain isEqualToString:@"self.TeenMFA"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
                return INVALID;
        }
    }
    else
    {
        if( !isTeen )
        {
            if( ![post.domain isEqualToString:@"self.femalefashionadvice"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
                return INVALID;
        }
        else
        {
            if( ![post.domain isEqualToString:@"self.TeenFFA"] || [[post.title lowercaseString] rangeOfString:@"announcement"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"phone"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"interest"].location != NSNotFound || [[post.title lowercaseString] rangeOfString:@"top"].location != NSNotFound || ([[post.title lowercaseString] rangeOfString:@"waywt"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"outfit feedback"].location == NSNotFound && [[post.title lowercaseString] rangeOfString:@"recent purchases"].location == NSNotFound) )
                return INVALID;
        }
    }
    
    if( [post.title rangeOfString:@"waywt"].location != NSNotFound)
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

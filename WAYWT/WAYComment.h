//
//  WAYComment.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class WAYPost;

@interface WAYComment : NSManagedObject

@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSString * bodyHtml;
@property (nonatomic, retain) NSString * commentId;
@property (nonatomic, retain) NSNumber * created;
@property (nonatomic, retain) NSNumber * downs;
@property (nonatomic, retain) NSNumber * likes;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * ups;
@property (nonatomic, retain) WAYPost *parentPost;

@end

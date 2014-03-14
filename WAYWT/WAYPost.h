//
//  WAYPost.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-13.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface WAYPost : NSManagedObject

@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSNumber * created;
@property (nonatomic, retain) NSNumber * downs;
@property (nonatomic, retain) NSNumber * isMale;
@property (nonatomic, retain) NSNumber * isTeen;
@property (nonatomic, retain) NSString * permalink;
@property (nonatomic, retain) NSString * postId;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) NSNumber * ups;
@property (nonatomic, retain) NSString * domain;

@end

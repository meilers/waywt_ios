//
//  WAYCommentUtility.h
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-04-21.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WAYPost.h"

@interface WAYCommentUtility : NSObject

+ (void)syncCommentsForPost:(WAYPost*)post context:(NSManagedObjectContext *)moc observer:(NSObject *)observer;

@end

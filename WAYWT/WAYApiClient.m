//
//  WAYApiClient.m
//  WAYWT
//
//  Created by Michael J. Eilers Smith on 2014-03-09.
//  Copyright (c) 2014 Michael J. Eilers Smith. All rights reserved.
//

#import "WAYApiClient.h"

static NSString * const ApiBaseURLString = @"http://www.reddit.com";

@implementation WAYApiClient

+ (instancetype)sharedClient {
    static WAYApiClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[WAYApiClient alloc] initWithBaseURL:[NSURL URLWithString:ApiBaseURLString]];
    });
    
    return _sharedClient;
}

@end


// AnalyticsRequest.h
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <Foundation/Foundation.h>

typedef void (^SWPAnalyticsRequestCompletionBlock)(void);


@interface SWPAnalyticsRequest : NSObject

@property (nonatomic, copy) SWPAnalyticsRequestCompletionBlock completion;
@property (nonatomic, readonly) NSURLRequest *urlRequest;
@property (nonatomic, readonly) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSData *responseData;
@property (nonatomic, readonly) id responseJSON;
@property (nonatomic, readonly) NSError *error;

+ (instancetype)startWithURLRequest:(NSURLRequest *)urlRequest
                         completion:(SWPAnalyticsRequestCompletionBlock)completion;

@end

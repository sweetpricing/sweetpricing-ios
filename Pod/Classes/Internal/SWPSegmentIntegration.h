// SegmentioIntegration.h
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <Foundation/Foundation.h>
#import "SWPIntegration.h"

extern NSString *const SWPSegmentDidSendRequestNotification;
extern NSString *const SWPSegmentRequestDidSucceedNotification;
extern NSString *const SWPSegmentRequestDidFailNotification;


@interface SWPSegmentIntegration : NSObject <SWPIntegration>

@property (nonatomic, copy) NSString *anonymousId;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) NSURL *apiURL;

- (id)initWithAnalytics:(SWPAnalytics *)analytics;

@end

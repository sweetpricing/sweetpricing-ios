// SweetpricingIntegration.h
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <Foundation/Foundation.h>
#import "SWPIntegration.h"

extern NSString *const SWPSweetpricingDidSendRequestNotification;
extern NSString *const SWPSweetpricingRequestDidSucceedNotification;
extern NSString *const SWPSweetpricingRequestDidFailNotification;


@interface SWPSweetpricingIntegration : NSObject <SWPIntegration>

@property (nonatomic, copy) NSString *anonymousId;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) NSURL *apiURL;

- (id)initWithAnalytics:(SWPAnalytics *)analytics;

@end

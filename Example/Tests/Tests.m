//
//  AnalyticsTests.m
//  AnalyticsTests
//
//  Created by Prateek Srivastava on 11/02/2015.
//  Copyright (c) 2015 Prateek Srivastava. All rights reserved.
//  Modified work Copyright (c) 2016 Sweet Pricing Ltd.
//

// https://github.com/Specta/Specta
#import <Analytics/SWPAnalytics.h>
#import <Specta/Specta.h>
#import <Foundation/Foundation.h>

SpecBegin(Analytics);

describe(@"analytics", ^{
    __block SWPAnalytics *analytics = nil;

    beforeEach(^{
        SWPAnalyticsConfiguration *configuration = [SWPAnalyticsConfiguration configurationWithWriteKey:@"MlTmISmburwl2nN9o3NFpGfElujcfb0q"];
        [SWPAnalytics setupWithConfiguration:configuration];
        analytics = [SWPAnalytics sharedAnalytics];
    });

    it(@"initialized correctly", ^{
        expect(analytics.configuration.flushAt).to.equal(20);
        expect(analytics.configuration.writeKey).to.equal(@"MlTmISmburwl2nN9o3NFpGfElujcfb0q");
        expect(analytics.configuration.shouldUseLocationServices).to.equal(@NO);
        expect(analytics.configuration.enableAdvertisingTracking).to.equal(@YES);
    });
});

SpecEnd

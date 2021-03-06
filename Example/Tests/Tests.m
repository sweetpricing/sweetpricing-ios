//
//  AnalyticsTests.m
//  AnalyticsTests
//
//  Created by Prateek Srivastava on 11/02/2015.
//  Copyright (c) 2015 Prateek Srivastava. All rights reserved.
//  Modified work Copyright (c) 2016 Sweet Pricing Ltd.
//

// https://github.com/Specta/Specta
#import <DynamicPricing/SWPDynamicPricing.h>
#import <Specta/Specta.h>
#import <Foundation/Foundation.h>

SpecBegin(Analytics);

describe(@"analytics", ^{
    __block SWPDynamicPricing *dynamicPricing = nil;

    beforeEach(^{
        SWPDynamicPricingConfiguration *configuration = [SWPDynamicPricingConfiguration configurationWithAppKey:@"98b30d00aae1d61245698547b81d5692"];
        [SWPDynamicPricing setupWithConfiguration:configuration];
        dynamicPricing = [SWPDynamicPricing sharedDynamicPricing];
    });

    it(@"initialized correctly", ^{
        expect(dynamicPricing.configuration.flushAt).to.equal(20);
        expect(dynamicPricing.configuration.appKey).to.equal(@"98b30d00aae1d61245698547b81d5692");
        expect(dynamicPricing.configuration.shouldUseLocationServices).to.equal(@NO);
        expect(dynamicPricing.configuration.enableAdvertisingTracking).to.equal(@YES);
    });
});

SpecEnd

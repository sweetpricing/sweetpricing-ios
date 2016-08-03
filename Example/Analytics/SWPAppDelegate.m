//
//  SWPAppDelegate.m
//  Analytics
//
//  Created by Prateek Srivastava on 11/02/2015.
//  Copyright (c) 2015 Prateek Srivastava. All rights reserved.
//  Modified work Copyright (c) 2016 Sweet Pricing Ltd.
//

#import "SWPAppDelegate.h"
#import <DynamicPricing/SWPDynamicPricing.h>


@implementation SWPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [SWPDynamicPricing setupWithConfiguration:[SWPDynamicPricingConfiguration configurationWithAppKey:@"98b30d00aae1d61245698547b81d5692"]];
    [SWPDynamicPricing debug:YES];

    // Suppose we have an in-app store called 'Subscriptions' that has a
    // Sweet Pricing ID of '3'. And this store contains two products,
    // 1 Month (ID = 7) and 1 Year (ID = 8).
    int spStoreId = 3;
    int sp1MonthId = 7;
    int sp1YearId = 8;

    // (1) Use the fetchVariant method to ask Sweet Pricing for prices for
    // this in-app store.
    [[SWPDynamicPricing sharedDynamicPricing] fetchVariant:spStoreId completion:^(SWPVariant *variant, NSError *error) {
      // (2) Read the product IDs that Sweet Pricing has provided. If there was
      // an error (ie error is not nil), then fall back on hard-coded defaults.
      NSString *apple1MonthId = [variant skuForProductId:sp1MonthId withDefault:@"com.sweetpricing.default.1month"];
      NSString *apple1YearId = [variant skuForProductId:sp1YearId withDefault:@"com.sweetpricing.default.1year"];

      NSLog(@"1 Month Product ID is %@", apple1MonthId);
      NSLog(@"1 Year Product ID is %@", apple1YearId);

      // (3) Fetch the product information from Store Kit API. This will return
      // an array of all the products that you requested. Turn that data into
      // an array to be passed to trackViewStore.
      NSArray *products = @[@{
        @"price" : [NSDecimalNumber decimalNumberWithString:@"9.99"],
        @"currencyCode" : [[NSLocale localeWithLocaleIdentifier:@"en_US"] objectForKey:NSLocaleCurrencyCode],
        @"productId": apple1MonthId
      }, @{
        @"price" : [NSDecimalNumber decimalNumberWithString:@"29.99"],
        @"currencyCode" : [[NSLocale localeWithLocaleIdentifier:@"en_US"] objectForKey:NSLocaleCurrencyCode],
        @"productId": apple1YearId
      }];

      // (4) When the user views the store, track the event in Sweet Pricing.
      [[SWPDynamicPricing sharedDynamicPricing] trackViewStore:variant products:products];

      // (5) When the user makes a purchase, track the event using
      // trackPurchase. Sweet Pricing will associate the purchase will the
      // last price shown to the user (as tracked with trackViewStore).
      [[SWPDynamicPricing sharedDynamicPricing] trackPurchase:apple1MonthId];
    }];

    // Override point for customization after application launch.
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end

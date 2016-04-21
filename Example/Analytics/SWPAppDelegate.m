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

    // We get an entire product group worth of App Store IAP IDs.
    // These are the integer identifiers created by Sweet Pricing.
    int productGroupId = 16;
    int productId = 87;

    // When we need to obtain the App Store product ID, send a request to
    // fetchVariant to get pricing data for a particular product group.
    [[SWPDynamicPricing sharedDynamicPricing] fetchVariant:productGroupId completion:^(SWPVariant *variant, NSError *error) {
      // The error argument is nil if there is no error.
      NSLog(@"Variant ID is %@", [variant id]);

      // Even if there is an error, a \SWPVariant object is returned.
      // If there was a problem getting pricing info, the method will fallback
      // on a default product ID.
      NSString *appStoreId = [variant skuForProductId:productId withDefault:@"com.sweetpricing.default.sku"];
      NSLog(@"Product SKU is %@", appStoreId);

      // When the user views this variant (typically when you load it),
      // you need to track the view.
      [[SWPDynamicPricing sharedDynamicPricing] trackViewVariant:variant];
      [[SWPDynamicPricing sharedDynamicPricing] trackPurchase:appStoreId];
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

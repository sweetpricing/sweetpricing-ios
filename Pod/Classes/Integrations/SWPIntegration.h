#import <Foundation/Foundation.h>
#import "SWPIdentifyPayload.h"
#import "SWPTrackPayload.h"
#import "SWPIdentifyPayload.h"

@protocol SWPIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[SWPDynamicPricing sharedInstance] identify:someUserId];
// 2. [[SWPDynamicPricing sharedInstance] identify:someUserId traits:someTraits];
// 3. [[SWPDynamicPricing sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(SWPIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[SWPDynamicPricing sharedInstance] track:someEvent];
// 2. [[SWPDynamicPricing sharedInstance] track:someEvent properties:someProperties];
// 3. [[SWPDynamicPricing sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(SWPTrackPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

@end

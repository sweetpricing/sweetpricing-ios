#import <Foundation/Foundation.h>
#import "SWPIdentifyPayload.h"
#import "SWPTrackPayload.h"
#import "SWPScreenPayload.h"
#import "SWPIdentifyPayload.h"
#import "SWPGroupPayload.h"

@protocol SWPIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[SWPAnalytics sharedInstance] identify:someUserId];
// 2. [[SWPAnalytics sharedInstance] identify:someUserId traits:someTraits];
// 3. [[SWPAnalytics sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(SWPIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[SWPAnalytics sharedInstance] track:someEvent];
// 2. [[SWPAnalytics sharedInstance] track:someEvent properties:someProperties];
// 3. [[SWPAnalytics sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(SWPTrackPayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[SWPAnalytics sharedInstance] screen:someEvent];
// 2. [[SWPAnalytics sharedInstance] screen:someEvent properties:someProperties];
// 3. [[SWPAnalytics sharedInstance] screen:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/screen/
- (void)screen:(SWPScreenPayload *)payload;

// Group will be called when the user calls either of the following:
// 1. [[SWPAnalytics sharedInstance] group:someGroupId];
// 2. [[SWPAnalytics sharedInstance] group:someGroupId traits:];
// 3. [[SWPAnalytics sharedInstance] group:someGroupId traits:someGroupTraits options:someOptions];
// @see https://segment.com/docs/spec/group/
- (void)group:(SWPGroupPayload *)payload;

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

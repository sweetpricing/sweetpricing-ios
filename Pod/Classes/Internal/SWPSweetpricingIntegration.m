// SweetpricingioIntegration.h
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#include <sys/sysctl.h>

#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "SWPDynamicPricing.h"
#import "SWPAnalyticsUtils.h"
#import "SWPAnalyticsRequest.h"
#import "SWPSweetpricingIntegration.h"
#import "SWPBluetooth.h"
#import "SWPReachability.h"
#import "SWPLocation.h"
#import "SWPVariant.h"
#import <iAd/iAd.h>

NSString *const SWPSweetpricingDidSendRequestNotification = @"SweetpricingDidSendRequest";
NSString *const SWPSweetpricingRequestDidSucceedNotification = @"SweetpricingRequestDidSucceed";
NSString *const SWPSweetpricingRequestDidFailNotification = @"SweetpricingRequestDidFail";

NSString *const SWPAdvertisingClassIdentifier = @"ASIdentifierManager";
NSString *const SWPADClientClass = @"ADClient";

NSString *const SWPUserIdKey = @"SWPUserId";
NSString *const SWPAnonymousIdKey = @"SWPAnonymousId";
NSString *const SWPQueueKey = @"SWPQueue";
NSString *const SWPTraitsKey = @"SWPTraits";

static NSString *GenerateUUIDString()
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return UUIDString;
}

static NSString *GetDeviceModel()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char result[size];
    sysctlbyname("hw.machine", result, &size, NULL, 0);
    NSString *results = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    return results;
}

static BOOL GetAdTrackingEnabled()
{
    BOOL result = NO;
    Class advertisingManager = NSClassFromString(SWPAdvertisingClassIdentifier);
    SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
    id sharedManager = ((id (*)(id, SEL))[advertisingManager methodForSelector:sharedManagerSelector])(advertisingManager, sharedManagerSelector);
    SEL adTrackingEnabledSEL = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
    result = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:adTrackingEnabledSEL])(sharedManager, adTrackingEnabledSEL);
    return result;
}


@interface SWPSweetpricingIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSDictionary *context;
@property (nonatomic, strong) NSArray *batch;
@property (nonatomic, strong) SWPAnalyticsRequest *request;
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
@property (nonatomic, strong) SWPBluetooth *bluetooth;
@property (nonatomic, strong) SWPReachability *reachability;
@property (nonatomic, strong) SWPLocation *location;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableDictionary *traits;
@property (nonatomic, assign) SWPDynamicPricing *analytics;
@property (nonatomic, assign) SWPDynamicPricingConfiguration *configuration;

@end


@implementation SWPSweetpricingIntegration

- (id)initWithAnalytics:(SWPDynamicPricing *)analytics
{
    if (self = [super init]) {
        self.configuration = [analytics configuration];
        self.apiURL = [NSURL URLWithString:@"https://api.sweetpricing.com/v1/events"];
        self.variantRequestURL = [NSURL URLWithString:@"https://api.sweetpricing.com/v1/variant"];
        self.anonymousId = [self getAnonymousId:NO];
        self.userId = [self getUserId];
        self.bluetooth = [[SWPBluetooth alloc] init];
        self.reachability = [SWPReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.context = [self staticContext];
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(flush) userInfo:nil repeats:YES];
        self.serialQueue = swp_dispatch_queue_create_specific("com.sweetpricing.dynamicpricing.sweetpricing", DISPATCH_QUEUE_SERIAL);
        self.flushTaskID = UIBackgroundTaskInvalid;
        self.analytics = analytics;
    }
    return self;
}

- (NSDictionary *)staticContext
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    dict[@"library"] = @{
        @"name" : @"sweetpricing-ios",
        @"version" : [SWPDynamicPricing version]
    };

    NSMutableDictionary *infoDictionary = [[[NSBundle mainBundle] infoDictionary] mutableCopy];
    [infoDictionary addEntriesFromDictionary:[[NSBundle mainBundle] localizedInfoDictionary]];
    if (infoDictionary.count) {
        dict[@"app"] = @{
            @"name" : infoDictionary[@"CFBundleDisplayName"] ?: @"",
            @"version" : infoDictionary[@"CFBundleShortVersionString"] ?: @"",
            @"build" : infoDictionary[@"CFBundleVersion"] ?: @"",
            @"namespace" : [[NSBundle mainBundle] bundleIdentifier] ?: @"",
        };
    }

    UIDevice *device = [UIDevice currentDevice];

    dict[@"device"] = ({
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"manufacturer"] = @"Apple";
        dict[@"model"] = GetDeviceModel();
        dict[@"id"] = [[device identifierForVendor] UUIDString];
        if (NSClassFromString(SWPAdvertisingClassIdentifier)) {
            dict[@"adTrackingEnabled"] = @(GetAdTrackingEnabled());
        }
        if (self.configuration.enableAdvertisingTracking) {
            NSString *idfa = SWPIDFA();
            if (idfa.length) dict[@"advertisingId"] = idfa;
        }
        dict;
    });

    dict[@"os"] = @{
        @"name" : device.systemName,
        @"version" : device.systemVersion
    };

    CTCarrier *carrier = [[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];
    if (carrier.carrierName.length)
        dict[@"network"] = @{ @"carrier" : carrier.carrierName };

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    dict[@"screen"] = @{
        @"width" : @(screenSize.width),
        @"height" : @(screenSize.height)
    };

#if !(TARGET_IPHONE_SIMULATOR)
    Class adClient = NSClassFromString(SWPADClientClass);
    if (adClient) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sharedClient = [adClient performSelector:NSSelectorFromString(@"sharedClient")];
#pragma clang diagnostic pop
        void (^completionHandler)(BOOL iad) = ^(BOOL iad) {
            if (iad) {
                dict[@"referrer"] = @{ @"type" : @"iad" };
            }
        };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [sharedClient performSelector:NSSelectorFromString(@"determineAppInstallationAttributionWithCompletionHandler:")
                           withObject:completionHandler];
#pragma clang diagnostic pop
    }
#endif

    return dict;
}

- (NSDictionary *)liveContext
{
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];

    [context addEntriesFromDictionary:self.context];

    context[@"locale"] = [NSString stringWithFormat:
                                       @"%@-%@",
                                       [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode],
                                       [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]];

    context[@"timezone"] = [[NSTimeZone localTimeZone] name];

    context[@"network"] = ({
        NSMutableDictionary *network = [[NSMutableDictionary alloc] init];

        if (self.bluetooth.hasKnownState)
            network[@"bluetooth"] = @(self.bluetooth.isEnabled);

        if (self.reachability.isReachable) {
            network[@"wifi"] = @(self.reachability.isReachableViaWiFi);
            network[@"cellular"] = @(self.reachability.isReachableViaWWAN);
        }

        network;
    });

    self.location = !self.location ? [self.configuration shouldUseLocationServices] ? [SWPLocation new] : nil : self.location;
    [self.location startUpdatingLocation];
    if (self.location.hasKnownLocation)
        context[@"location"] = self.location.locationDictionary;

    context[@"traits"] = ({
        NSMutableDictionary *traits = [[NSMutableDictionary alloc] initWithDictionary:[self traits]];

        if (self.location.hasKnownLocation)
            traits[@"address"] = self.location.addressDictionary;

        traits;
    });

    return [context copy];
}

- (void)dispatchBackground:(void (^)(void))block
{
    swp_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    swp_dispatch_specific_sync(_serialQueue, block);
}

- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    self.flushTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundTask];
    }];
}

- (void)endBackgroundTask
{
    [self dispatchBackgroundAndWait:^{
        if (self.flushTaskID != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.flushTaskID];
            self.flushTaskID = UIBackgroundTaskInvalid;
        }
    }];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.appKey];
}

- (void)saveUserId:(NSString *)userId
{
    [self dispatchBackground:^{
        self.userId = userId;
        [[NSUserDefaults standardUserDefaults] setValue:userId forKey:SWPUserIdKey];
        [self.userId writeToURL:self.userIDURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }];
}

- (void)saveAnonymousId:(NSString *)anonymousId
{
    [self dispatchBackground:^{
        self.anonymousId = anonymousId;
        [[NSUserDefaults standardUserDefaults] setValue:anonymousId forKey:SWPAnonymousIdKey];
        [self.anonymousId writeToURL:self.anonymousIDURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }];
}

- (void)addTraits:(NSDictionary *)traits
{
    [self dispatchBackground:^{
        [self.traits addEntriesFromDictionary:traits];
        [[NSUserDefaults standardUserDefaults] setObject:[self.traits copy] forKey:SWPTraitsKey];
        [[self.traits copy] writeToURL:self.traitsURL atomically:YES];
    }];
}

#pragma mark - Analytics API

- (void)identify:(SWPIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        [self saveUserId:payload.userId];
        [self addTraits:payload.traits];
        if (payload.anonymousId) {
            [self saveAnonymousId:payload.anonymousId];
        }
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.traits forKey:@"traits"];

    [self enqueueAction:@"identify" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)track:(SWPTrackPayload *)payload
{
    SWPLog(@"sweetpricing integration received payload %@", payload);

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"event"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [self enqueueAction:@"track" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)fetchVariant:(SWPVariantRequestPayload *)payload completion:(SWPIntegrationFetchVariantCompletionBlock) completion
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    [dictionary setValue:[NSNumber numberWithInteger:payload.productGroupId] forKey:@"productGroupId"];
    dictionary[@"timestamp"] = iso8601FormattedString([NSDate date]);
    dictionary[@"type"] = @"variantRequest";
    dictionary[@"messageId"] = GenerateUUIDString();
    [dictionary setObject:self.configuration.appKey forKey:@"appKey"];

    [self dispatchBackground:^{
      // attach userId and anonymousId inside the dispatch_async in case
      // they've changed (see identify function)

      [dictionary setValue:self.userId forKey:@"userId"];
      [dictionary setValue:self.anonymousId forKey:@"anonymousId"];
      [dictionary setValue:[self integrationsDictionary:payload.integrations] forKey:@"integrations"];

      NSDictionary *defaultContext = [self liveContext];
      NSDictionary *customContext = payload.context;
      NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:customContext.count + defaultContext.count];
      [context addEntriesFromDictionary:defaultContext];
      [context addEntriesFromDictionary:customContext]; // let the custom context override ours
      [dictionary setValue:[context copy] forKey:@"context"];

      NSData *body = nil;
      __block NSError *error = nil;
      SWPVariant *defaultVariant = [[SWPVariant alloc] initWithDictionary:[NSDictionary dictionary]];

      body = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];

      if (error != nil) {
        return completion(defaultVariant, error);
      }

      NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.variantRequestURL];
      [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
      [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
      [urlRequest setHTTPMethod:@"POST"];
      [urlRequest setHTTPBody:body];

      SWPLog(@"%@ Sending fetch variant request.", self);

      __block SWPAnalyticsRequest *variantRequest = [SWPAnalyticsRequest startWithURLRequest:urlRequest
                                             completion:^{
                                                 if (variantRequest.error != nil) {
                                                   SWPLog(@"%@ SP Fetch Variant request has error: %@", self, self.request.error);
                                                   error = variantRequest.error;
                                                   completion(defaultVariant, error);
                                                 } else {
                                                   SWPLog(@"%@ SP Fetch Variant success!", self);
                                                   SWPVariant *variant = [[SWPVariant alloc] initWithDictionary:variantRequest.responseJSON];
                                                   completion(variant, error);
                                                 }
                                             }];
    }];
}

- (void)registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken options:(NSDictionary *)options
{
    NSCParameterAssert(deviceToken != nil);

    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *token = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [token appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    [self.context[@"device"] setObject:[token copy] forKey:@"token"];
}

#pragma mark - Queueing

- (NSDictionary *)integrationsDictionary:(NSDictionary *)integrations
{
    NSMutableDictionary *dict = [integrations ?: @{} mutableCopy];
    for (NSString *integration in self.analytics.bundledIntegrations) {
        dict[integration] = @NO;
    }
    return [dict copy];
}

- (void)enqueueAction:(NSString *)action dictionary:(NSMutableDictionary *)payload context:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    // attach these parts of the payload outside since they are all synchronous
    // and the timestamp will be more accurate.
    payload[@"type"] = action;
    payload[@"timestamp"] = iso8601FormattedString([NSDate date]);
    payload[@"messageId"] = GenerateUUIDString();

    [self dispatchBackground:^{
        // attach userId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        // Do not override the userId for an 'alias' action. This value is set in [alias:] already.
        if (![action isEqualToString:@"alias"]) {
            [payload setValue:self.userId forKey:@"userId"];
        }
        [payload setValue:self.anonymousId forKey:@"anonymousId"];

        [payload setValue:[self integrationsDictionary:integrations] forKey:@"integrations"];

        NSDictionary *defaultContext = [self liveContext];
        NSDictionary *customContext = context;
        NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:customContext.count + defaultContext.count];
        [context addEntriesFromDictionary:defaultContext];
        [context addEntriesFromDictionary:customContext]; // let the custom context override ours
        [payload setValue:[context copy] forKey:@"context"];

        SWPLog(@"%@ Enqueueing action: %@", self, payload);
        [self queuePayload:[payload copy]];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];

    }
    @catch (NSException *exception) {
        SWPLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            SWPLog(@"%@ No queued API calls to flush.", self);
            return;
        } else if (self.request != nil) {
            SWPLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        } else if ([self.queue count] >= maxBatchSize) {
            self.batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
        } else {
            self.batch = [NSArray arrayWithArray:self.queue];
        }

        SWPLog(@"%@ Flushing %lu of %lu queued API calls.", self, (unsigned long)self.batch.count, (unsigned long)self.queue.count);

        NSMutableDictionary *payloadDictionary = [[NSMutableDictionary alloc] init];
        [payloadDictionary setObject:self.configuration.appKey forKey:@"appKey"];
        [payloadDictionary setObject:iso8601FormattedString([NSDate date]) forKey:@"sentAt"];
        [payloadDictionary setObject:self.context forKey:@"context"];
        [payloadDictionary setObject:self.batch forKey:@"batch"];

        SWPLog(@"Flushing payload %@", payloadDictionary);

        NSError *error = nil;
        NSException *exception = nil;
        NSData *payload = nil;
        @try {
            payload = [NSJSONSerialization dataWithJSONObject:payloadDictionary options:0 error:&error];
        }
        @catch (NSException *exc) {
            exception = exc;
        }
        if (error || exception) {
            SWPLog(@"%@ Error serializing JSON: %@", self, error);
        } else {
            [self sendData:payload];
        }
    }];
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        SWPLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.request == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:SWPUserIdKey];
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:SWPAnonymousIdKey];
        [[NSUserDefaults standardUserDefaults] setValue:@[] forKey:SWPQueueKey];
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:SWPTraitsKey];
        [[NSFileManager defaultManager] removeItemAtURL:self.userIDURL error:NULL];
        [[NSFileManager defaultManager] removeItemAtURL:self.traitsURL error:NULL];
        [[NSFileManager defaultManager] removeItemAtURL:self.queueURL error:NULL];
        self.userId = nil;
        self.traits = [NSMutableDictionary dictionary];
        self.queue = [NSMutableArray array];
        self.anonymousId = [self getAnonymousId:YES];
        self.request.completion = nil;
        self.request = nil;
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
        SWPLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSData *)data
{
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.apiURL];
    [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:data];

    SWPLog(@"%@ Sending batch API request.", self);
    self.request = [SWPAnalyticsRequest startWithURLRequest:urlRequest
                                                 completion:^{
                                                     [self dispatchBackground:^{
                                                         if (self.request.error) {
                                                             SWPLog(@"%@ API request had an error: %@", self, self.request.error);
                                                             [self notifyForName:SWPSweetpricingRequestDidFailNotification userInfo:self.batch];
                                                         } else {
                                                             SWPLog(@"%@ API request success 200", self);
                                                             [self.queue removeObjectsInArray:self.batch];
                                                             [self persistQueue];
                                                             [self notifyForName:SWPSweetpricingRequestDidSucceedNotification userInfo:self.batch];
                                                         }

                                                         self.batch = nil;
                                                         self.request = nil;
                                                         [self endBackgroundTask];
                                                     }];
                                                 }];
    [self notifyForName:SWPSweetpricingDidSendRequestNotification userInfo:self.batch];
}

- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)

            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
        _queue = ([[[NSUserDefaults standardUserDefaults] objectForKey:SWPQueueKey] mutableCopy] ?: [NSMutableArray arrayWithContentsOfURL:self.queueURL]) ?: [[NSMutableArray alloc] init];
    }
    return _queue;
}

- (NSMutableDictionary *)traits
{
    if (!_traits) {
        _traits = ([[[NSUserDefaults standardUserDefaults] objectForKey:SWPTraitsKey] mutableCopy] ?: [NSMutableDictionary dictionaryWithContentsOfURL:self.traitsURL]) ?: [[NSMutableDictionary alloc] init];
    }
    return _traits;
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (NSURL *)userIDURL
{
    return SWPAnalyticsURLForFilename(@"sweetpricing.userId");
}

- (NSURL *)anonymousIDURL
{
    return SWPAnalyticsURLForFilename(@"sweetpricing.anonymousId");
}

- (NSURL *)queueURL
{
    return SWPAnalyticsURLForFilename(@"sweetpricing.queue.plist");
}

- (NSURL *)traitsURL
{
    return SWPAnalyticsURLForFilename(@"sweetpricing.traits.plist");
}

- (void)persistQueue
{
    [[NSUserDefaults standardUserDefaults] setValue:[self.queue copy] forKey:SWPQueueKey];
    [[self.queue copy] writeToURL:self.queueURL atomically:YES];
}


- (NSString *)getAnonymousId:(BOOL)reset
{
    // We've chosen to generate a UUID rather than use the UDID (deprecated in iOS 5),
    // identifierForVendor (iOS6 and later, can't be changed on logout),
    // or MAC address (blocked in iOS 7). For more info see https://segment.io/libraries/ios#ids
    NSURL *url = self.anonymousIDURL;
    NSString *anonymousId = [[NSUserDefaults standardUserDefaults] valueForKey:SWPAnonymousIdKey] ?: [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
    if (!anonymousId || reset) {
        anonymousId = GenerateUUIDString();
        SWPLog(@"New anonymousId: %@", anonymousId);
        [[NSUserDefaults standardUserDefaults] setObject:anonymousId forKey:SWPAnonymousIdKey];
        [anonymousId writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return anonymousId;
}

- (NSString *)getUserId
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:SWPUserIdKey] ?: [[NSString alloc] initWithContentsOfURL:self.userIDURL encoding:NSUTF8StringEncoding error:NULL];
}

@end

// Analytics.m
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <UIKit/UIKit.h>
#import "SWPAnalyticsUtils.h"
#import "SWPAnalyticsRequest.h"
#import "SWPDynamicPricing.h"

#import "SWPIntegrationFactory.h"
#import "SWPIntegration.h"
#import <objc/runtime.h>
#import "SWPSweetpricingIntegrationFactory.h"

static SWPDynamicPricing *__sharedInstance = nil;


@interface SWPDynamicPricingConfiguration ()

@property (nonatomic, copy, readwrite) NSString *appKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;

@end


@implementation SWPDynamicPricingConfiguration

+ (instancetype)configurationWithAppKey:(NSString *)appKey
{
    return [[SWPDynamicPricingConfiguration alloc] initWithAppKey:appKey];
}

- (instancetype)initWithAppKey:(NSString *)appKey
{
    if (self = [self init]) {
        self.appKey = appKey;
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.shouldUseLocationServices = NO;
        self.enableAdvertisingTracking = YES;
        self.flushAt = 20;
        _factories = [NSMutableArray array];
        [_factories addObject:[SWPSweetpricingIntegrationFactory instance]];
    }
    return self;
}

- (void)use:(id<SWPIntegrationFactory>)factory
{
    [self.factories addObject:factory];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"appKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

@end


@interface SWPDynamicPricing ()

@property (nonatomic, strong) SWPDynamicPricingConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSArray *factories;
@property (nonatomic, strong) NSMutableDictionary *integrations;
@property (nonatomic, strong) NSMutableDictionary *registeredIntegrations;
@property (nonatomic) volatile BOOL initialized;

@end


@implementation SWPDynamicPricing

+ (void)setupWithConfiguration:(SWPDynamicPricingConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(SWPDynamicPricingConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.configuration = configuration;
        self.enabled = YES;
        self.serialQueue = seg_dispatch_queue_create_specific("com.sweetpricing.dynamicpricing", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        self.factories = [configuration.factories copy];
        self.integrations = [NSMutableDictionary dictionaryWithCapacity:self.factories.count];
        self.registeredIntegrations = [NSMutableDictionary dictionaryWithCapacity:self.factories.count];
        self.configuration = configuration;

        for (id<SWPIntegrationFactory> factory in self.factories) {
            NSString *key = [factory key];
            id<SWPIntegration> integration = [factory createWithSettings:nil forAnalytics:self];
            if (integration != nil) {
                self.integrations[key] = integration;
                self.registeredIntegrations[key] = @NO;
            }
        }

        // Attach to application state change hooks
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        // Pass through for application state change events
        for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification,
                                  UIApplicationDidFinishLaunchingNotification,
                                  UIApplicationWillEnterForegroundNotification,
                                  UIApplicationWillTerminateNotification,
                                  UIApplicationWillResignActiveNotification,
                                  UIApplicationDidBecomeActiveNotification ]) {
            [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:nil];
        }
    }
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - NSNotificationCenter Callback

- (void)handleAppStateNotification:(NSNotification *)note
{
    SWPLog(@"Application state change notification: %@", note.name);
    static NSDictionary *selectorMapping;
    static dispatch_once_t selectorMappingOnce;
    dispatch_once(&selectorMappingOnce, ^{
        selectorMapping = @{
                            UIApplicationDidFinishLaunchingNotification :
                                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
                            UIApplicationDidEnterBackgroundNotification :
                                NSStringFromSelector(@selector(applicationDidEnterBackground)),
                            UIApplicationWillEnterForegroundNotification :
                                NSStringFromSelector(@selector(applicationWillEnterForeground)),
                            UIApplicationWillTerminateNotification :
                                NSStringFromSelector(@selector(applicationWillTerminate)),
                            UIApplicationWillResignActiveNotification :
                                NSStringFromSelector(@selector(applicationWillResignActive)),
                            UIApplicationDidBecomeActiveNotification :
                                NSStringFromSelector(@selector(applicationDidBecomeActive))
                            };
    });
    SEL selector = NSSelectorFromString(selectorMapping[note.name]);
    if (selector) {
        [self callIntegrationsWithSelector:selector arguments:nil options:nil sync:true];
    }
}

#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - Analytics API

#pragma mark - Identify

- (void)identify:(NSString *)userId
{
    [self identify:userId traits:nil options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits
{
    [self identify:userId traits:traits options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    NSCParameterAssert(userId.length > 0 || traits.count > 0);

    SWPIdentifyPayload *payload = [[SWPIdentifyPayload alloc] initWithUserId:userId
                                                                 anonymousId:[options objectForKey:@"anonymousId"]
                                                                      traits:SWPCoerceDictionary(traits)
                                                                     context:SWPCoerceDictionary([options objectForKey:@"context"])
                                                                integrations:[options objectForKey:@"integrations"]];

    [self callIntegrationsWithSelector:NSSelectorFromString(@"identify:")
                             arguments:@[ payload ]
                               options:options
                                  sync:false];
}

#pragma mark - Track

- (void)track:(NSString *)event
{
    [self track:event properties:nil options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self track:event properties:properties options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCParameterAssert(event.length > 0);

    SWPTrackPayload *payload = [[SWPTrackPayload alloc] initWithEvent:event
                                                           properties:SWPCoerceDictionary(properties)
                                                              context:SWPCoerceDictionary([options objectForKey:@"context"])
                                                         integrations:[options objectForKey:@"integrations"]];

    [self callIntegrationsWithSelector:NSSelectorFromString(@"track:")
                             arguments:@[ payload ]
                               options:options
                                  sync:false];
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ userInfo ] options:nil sync:true];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ error ] options:nil sync:true];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);

    [self callIntegrationsWithSelector:_cmd arguments:@[ deviceToken ] options:nil sync:true];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ identifier, userInfo ] options:nil sync:true];
}

- (void)reset
{
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

- (void)flush
{
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

- (void)enable
{
    _enabled = YES;
}

- (void)disable
{
    _enabled = NO;
}

#pragma mark - Class Methods

+ (instancetype)sharedDynamicPricing
{
    NSCParameterAssert(__sharedInstance != nil);
    return __sharedInstance;
}

+ (void)debug:(BOOL)showDebugLogs
{
    SWPSetShowDebugLogs(showDebugLogs);
}

+ (NSString *)version
{
    return @"0.0.1";
}

#pragma mark - Private

- (BOOL)isIntegration:(NSString *)key enabledInOptions:(NSDictionary *)options
{
    if ([@"Sweetpricing" isEqualToString:key]) {
        return YES;
    }
    if (options[key]) {
        return [options[key] boolValue];
    } else if (options[@"All"]) {
        return [options[@"All"] boolValue];
    } else if (options[@"all"]) {
        return [options[@"all"] boolValue];
    }
    return YES;
}

- (void)forwardSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    if (!_enabled)
        return;

    // If the event has opted in for syncrhonous delivery, this may be called on any thread.
    // Only allow one to be delivered at a time.
    @synchronized(self)
    {
        [self.integrations enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<SWPIntegration> integration, BOOL *stop) {
            [self invokeIntegration:integration key:key selector:selector arguments:arguments options:options];
        }];
    }
}

- (void)invokeIntegration:(id<SWPIntegration>)integration key:(NSString *)key selector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    if (![integration respondsToSelector:selector]) {
        SWPLog(@"Not sending call to %@ because it doesn't respond to %@.", key, NSStringFromSelector(selector));
        return;
    }

    if (![self isIntegration:key enabledInOptions:options[@"integrations"]]) {
        SWPLog(@"Not sending call to %@ because it is disabled in options.", key);
        return;
    }

    NSString *eventType = NSStringFromSelector(selector);

    SWPLog(@"Running: %@ with arguments %@ on integration: %@", eventType, arguments, key);
    NSInvocation *invocation = [self invocationForSelector:selector arguments:arguments];
    [invocation invokeWithTarget:integration];
}

- (NSInvocation *)invocationForSelector:(SEL)selector arguments:(NSArray *)arguments
{
    struct objc_method_description description = protocol_getMethodDescription(@protocol(SWPIntegration), selector, NO, YES);

    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:description.types];

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    for (int i = 0; i < arguments.count; i++) {
        id argument = (arguments[i] == [NSNull null]) ? nil : arguments[i];
        [invocation setArgument:&argument atIndex:i + 2];
    }
    return invocation;
}

- (void)queueSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSArray *obj = @[ NSStringFromSelector(selector), arguments ?: @[], options ?: @{} ];
    SWPLog(@"Queueing: %@", obj);
    [_messageQueue addObject:obj];
}

- (void)flushMessageQueue
{
    if (_messageQueue.count != 0) {
        for (NSArray *arr in _messageQueue)
            [self forwardSelector:NSSelectorFromString(arr[0]) arguments:arr[1] options:arr[2]];
        [_messageQueue removeAllObjects];
    }
}

- (void)callIntegrationsWithSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options sync:(BOOL)sync
{
    if (sync) {
        [self forwardSelector:selector arguments:arguments options:options];
        return;
    }

    seg_dispatch_specific_async(_serialQueue, ^{
        [self flushMessageQueue];
        [self forwardSelector:selector arguments:arguments options:options];
    });
}

- (NSDictionary *)bundledIntegrations
{
    return [self.registeredIntegrations copy];
}

@end

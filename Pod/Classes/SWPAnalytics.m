// Analytics.m
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <UIKit/UIKit.h>
#import "SWPAnalyticsUtils.h"
#import "SWPAnalyticsRequest.h"
#import "SWPAnalytics.h"

#import "SWPIntegrationFactory.h"
#import "SWPIntegration.h"
#import <objc/runtime.h>
#import "SWPSegmentIntegrationFactory.h"

static SWPAnalytics *__sharedInstance = nil;
NSString *SWPAnalyticsIntegrationDidStart = @"io.segment.analytics.integration.did.start";


@interface SWPAnalyticsConfiguration ()

@property (nonatomic, copy, readwrite) NSString *writeKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;

@end


@implementation SWPAnalyticsConfiguration

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey
{
    return [[SWPAnalyticsConfiguration alloc] initWithWriteKey:writeKey];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey
{
    if (self = [self init]) {
        self.writeKey = writeKey;
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
        [_factories addObject:[SWPSegmentIntegrationFactory instance]];
    }
    return self;
}

- (void)use:(id<SWPIntegrationFactory>)factory
{
    [self.factories addObject:factory];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"writeKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

@end


@interface SWPAnalytics ()

@property (nonatomic, strong) NSDictionary *cachedSettings;
@property (nonatomic, strong) SWPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) SWPAnalyticsRequest *settingsRequest;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSArray *factories;
@property (nonatomic, strong) NSMutableDictionary *integrations;
@property (nonatomic, strong) NSMutableDictionary *registeredIntegrations;
@property (nonatomic) volatile BOOL initialized;

@end


@implementation SWPAnalytics

@synthesize cachedSettings = _cachedSettings;

+ (void)setupWithConfiguration:(SWPAnalyticsConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(SWPAnalyticsConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.configuration = configuration;
        self.enabled = YES;
        self.serialQueue = seg_dispatch_queue_create_specific("io.segment.analytics", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        self.factories = [configuration.factories copy];
        self.integrations = [NSMutableDictionary dictionaryWithCapacity:self.factories.count];
        self.registeredIntegrations = [NSMutableDictionary dictionaryWithCapacity:self.factories.count];
        self.configuration = configuration;

        // Update settings on each integration immediately
        [self refreshSettings];

        // Attach to application state change hooks
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        // Update settings on foreground
        [nc addObserver:self selector:@selector(onAppForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

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


- (void)onAppForeground:(NSNotification *)note
{
    [self refreshSettings];
}

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

#pragma mark - Screen

- (void)screen:(NSString *)screenTitle
{
    [self screen:screenTitle properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties
{
    [self screen:screenTitle properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCParameterAssert(screenTitle.length > 0);

    SWPScreenPayload *payload = [[SWPScreenPayload alloc] initWithName:screenTitle
                                                            properties:SWPCoerceDictionary(properties)
                                                               context:SWPCoerceDictionary([options objectForKey:@"context"])
                                                          integrations:[options objectForKey:@"integrations"]];

    [self callIntegrationsWithSelector:NSSelectorFromString(@"screen:")
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

#pragma mark - Analytics Settings

- (NSDictionary *)cachedSettings
{
    if (!_cachedSettings)
        _cachedSettings = [[NSDictionary alloc] initWithContentsOfURL:[self settingsURL]] ?: @{};
    return _cachedSettings;
}

- (void)setCachedSettings:(NSDictionary *)settings
{
    _cachedSettings = [settings copy];
    NSURL *settingsURL = [self settingsURL];
    if (!_cachedSettings) {
        // [@{} writeToURL:settingsURL atomically:YES];
        return;
    }
    [_cachedSettings writeToURL:settingsURL atomically:YES];

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [self updateIntegrationsWithSettings:settings[@"integrations"]];
    });
}

- (void)updateIntegrationsWithSettings:(NSDictionary *)projectSettings
{
    for (id<SWPIntegrationFactory> factory in self.factories) {
        NSString *key = [factory key];
        NSDictionary *integrationSettings = [projectSettings objectForKey:key];
        if (integrationSettings) {
            id<SWPIntegration> integration = [factory createWithSettings:integrationSettings forAnalytics:self];
            if (integration != nil) {
                self.integrations[key] = integration;
                self.registeredIntegrations[key] = @NO;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SWPAnalyticsIntegrationDidStart object:key userInfo:nil];
        } else {
            SWPLog(@"No settings for %@. Skipping.", key);
        }
    }

    seg_dispatch_specific_async(_serialQueue, ^{
        [self flushMessageQueue];
        self.initialized = true;
    });
}

- (void)refreshSettings
{
    if (_settingsRequest)
        return;

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://cdn.segment.com/v1/projects/%@/settings", self.configuration.writeKey]]];
    [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [urlRequest setHTTPMethod:@"GET"];

    SWPLog(@"%@ Sending API settings request: %@", self, urlRequest);

    _settingsRequest = [SWPAnalyticsRequest startWithURLRequest:urlRequest
                                                     completion:^{
                                                         seg_dispatch_specific_async(_serialQueue, ^{
                                                             SWPLog(@"%@ Received API settings response: %@", self, _settingsRequest.responseJSON);

                                                             if (_settingsRequest.error == nil) {
                                                                 [self setCachedSettings:_settingsRequest.responseJSON];
                                                             }

                                                             _settingsRequest = nil;
                                                         });
                                                     }];
}

#pragma mark - Class Methods

+ (instancetype)sharedAnalytics
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
    return @"3.0.7";
}

#pragma mark - Private

- (BOOL)isIntegration:(NSString *)key enabledInOptions:(NSDictionary *)options
{
    if ([@"Segment.io" isEqualToString:key]) {
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

- (BOOL)isTrackEvent:(NSString *)event enabledForIntegration:(NSString *)key inPlan:(NSDictionary *)plan
{
    if (plan[@"track"][event]) {
        if ([plan[@"track"][event][@"enabled"] boolValue]) {
            return [self isIntegration:key enabledInOptions:plan[@"track"][event][@"integrations"]];
        } else {
            return NO;
        }
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
    if ([eventType hasPrefix:@"track:"]) {
        BOOL enabled = [self isTrackEvent:arguments[0] enabledForIntegration:key inPlan:self.cachedSettings[@"plan"]];
        if (!enabled) {
            SWPLog(@"Not sending call to %@ because it is disabled in plan.", key);
            return;
        }
    }

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
    if (sync && self.initialized) {
        [self forwardSelector:selector arguments:arguments options:options];
        return;
    }

    seg_dispatch_specific_async(_serialQueue, ^{
        if (self.initialized) {
            [self flushMessageQueue];
            [self forwardSelector:selector arguments:arguments options:options];
        } else {
            [self queueSelector:selector arguments:arguments options:options];
        }
    });
}

- (NSURL *)settingsURL
{
    return SWPAnalyticsURLForFilename(@"analytics.settings.v2.plist");
}

- (NSDictionary *)bundledIntegrations
{
    return [self.registeredIntegrations copy];
}

@end


@implementation SWPAnalytics (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

+ (void)initializeWithWriteKey:(NSString *)writeKey
{
    [self setupWithConfiguration:[SWPAnalyticsConfiguration configurationWithWriteKey:writeKey]];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey
{
    return [self initWithConfiguration:[SWPAnalyticsConfiguration configurationWithWriteKey:writeKey]];
}

- (void)registerPushDeviceToken:(NSData *)deviceToken
{
    [self registeredForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [self registeredForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)registerForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken options:(NSDictionary *)options
{
    [self registeredForRemoteNotificationsWithDeviceToken:deviceToken];
}

#pragma clang diagnostic pop

@end

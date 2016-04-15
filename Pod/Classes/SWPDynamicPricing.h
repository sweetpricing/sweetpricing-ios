#import <Foundation/Foundation.h>
#import "SWPIntegrationFactory.h"

@protocol SWPIntegrationFactory;

/**
 * This object provides a set of properties to control various policies of the analytics client. Other than `writeKey`, these properties can be changed at any time.
 */
@interface SWPDynamicPricingConfiguration : NSObject

/**
 * Creates and returns a configuration with default settings and the given write key.
 *
 * @param appKey Your project's write key from segment.io.
 */
+ (instancetype)configurationWithAppKey:(NSString *)appKey;

/**
 * Your project's write key from segment.io.
 *
 * @see +configurationWithAppKey:
 */
@property (nonatomic, copy, readonly) NSString *appKey;

/**
 * Whether the analytics client should use location services. If `YES` and the host app hasn't asked for permission to use location services then the user will be presented with an alert view asking to do so. `NO` by default.
 */
@property (nonatomic, assign) BOOL shouldUseLocationServices;

/**
 * Whether the analytics client should track advertisting info. `YES` by default.
 */
@property (nonatomic, assign) BOOL enableAdvertisingTracking;

/**
 * The number of queued events that the analytics client should flush at. Setting this to `1` will not queue any events and will use more battery. `20` by default.
 */
@property (nonatomic, assign) NSUInteger flushAt;


/**
 * Register a factory that can be used to create an integration.
 */
- (void)use:(id<SWPIntegrationFactory>)factory;

@end

/**
 * This object provides an API for recording analytics.
 */
@interface SWPDynamicPricing : NSObject

/**
 * Used by the analytics client to configure various options.
 */
@property (nonatomic, strong, readonly) SWPDynamicPricingConfiguration *configuration;

/**
 * Setup this analytics client instance.
 *
 * @param configuration The configuration used to setup the client.
 */
- (instancetype)initWithConfiguration:(SWPDynamicPricingConfiguration *)configuration;

/**
 * Setup the analytics client.
 *
 * @param configuration The configuration used to setup the client.
 */
+ (void)setupWithConfiguration:(SWPDynamicPricingConfiguration *)configuration;

/**
 * Enabled/disables debug logging to trace your data going through the SDK.
 *
 * @param showDebugLogs `YES` to enable logging, `NO` otherwise. `NO` by default.
 */
+ (void)debug:(BOOL)showDebugLogs;

/**
 * Returns the shared analytics client.
 *
 * @see -setupWithConfiguration:
 */
+ (instancetype)sharedDynamicPricing;

/*!
 @method

 @abstract
 Associate a user with their unique ID and record traits about them.

 @param userId        A database ID (or email address) for this user. If you don't have a userId
 but want to record traits, you should pass nil. For more information on how we
 generate the UUID and Apple's policies on IDs, see https://segment.io/libraries/ios#ids

 @param traits        A dictionary of traits you know about the user. Things like: email, name, plan, etc.

 @param options       A dictionary of options, such as the `@"anonymousId"` key. If no anonymous ID is specified one will be generated for you.

 @discussion
 When you learn more about who your user is, you can record that information with identify.

 */
- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options;
- (void)identify:(NSString *)userId;
- (void)identify:(NSString *)userId traits:(NSDictionary *)traits;


/*!
 @method

 @abstract
 Record the actions your users perform.

 @param event         The name of the event you're tracking. We recommend using human-readable names
 like `Played a Song` or `Updated Status`.

 @param properties    A dictionary of properties for the event. If the event was 'Added to Shopping Cart', it might
 have properties like price, productType, etc.

 @discussion
 When a user performs an action in your app, you'll want to track that action for later analysis. Use the event name to say what the user did, and properties to specify any interesting details of the action.

 */
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;
- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options;

// todo: docs
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

/*!
 @method

 @abstract
 Trigger an upload of all queued events.

 @discussion
 This is useful when you want to force all messages queued on the device to be uploaded. Please note that not all integrations
 respond to this method.
 */
- (void)flush;

/*!
 @method

 @abstract
 Reset any user state that is cached on the device.

 @discussion
 This is useful when a user logs out and you want to clear the identity. It will clear any
 traits or userId's cached on the device.
 */
- (void)reset;

/*!
 @method

 @abstract
 Enable the sending of analytics data. Enabled by default.

 @discussion
 Occasionally used in conjunction with disable user opt-out handling.
 */
- (void)enable;


/*!
 @method

 @abstract
 Completely disable the sending of any analytics data.

 @discussion
 If have a way for users to actively or passively (sometimes based on location) opt-out of
 analytics data collection, you can use this method to turn off all data collection.
 */
- (void)disable;


/**
 * Version of the library.
 */
+ (NSString *)version;

/**
 * Returns a dictionary of integrations that are bundled. This is an internal Segment API, and may be removed at any time
 * without notice.
 */
- (NSDictionary *)bundledIntegrations;

/** Returns the configuration used to create the analytics client. */
- (SWPDynamicPricingConfiguration *)configuration;

@end

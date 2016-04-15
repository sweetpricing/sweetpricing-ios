#import <Foundation/Foundation.h>
#import "SWPIntegration.h"
#import "SWPDynamicPricing.h"

@class SWPDynamicPricing;

@protocol SWPIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<SWPIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(SWPDynamicPricing *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

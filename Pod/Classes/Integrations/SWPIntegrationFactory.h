#import <Foundation/Foundation.h>
#import "SWPIntegration.h"
#import "SWPAnalytics.h"

@class SWPAnalytics;

@protocol SWPIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<SWPIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(SWPAnalytics *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

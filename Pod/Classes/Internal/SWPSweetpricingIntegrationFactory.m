#import "SWPSweetpricingIntegrationFactory.h"
#import "SWPSweetpricingIntegration.h"


@implementation SWPSweetpricingIntegrationFactory

+ (id)instance
{
    static dispatch_once_t once;
    static SWPSweetpricingIntegrationFactory *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    return self;
}

- (id<SWPIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(SWPAnalytics *)analytics
{
    return [[SWPSweetpricingIntegration alloc] initWithAnalytics:analytics];
}

- (NSString *)key
{
    return @"Sweetpricing";
}

@end

#import "SWPSegmentIntegrationFactory.h"
#import "SWPSegmentIntegration.h"


@implementation SWPSegmentIntegrationFactory

+ (id)instance
{
    static dispatch_once_t once;
    static SWPSegmentIntegrationFactory *sharedInstance;
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
    return [[SWPSegmentIntegration alloc] initWithAnalytics:analytics];
}

- (NSString *)key
{
    return @"Segment.io";
}

@end

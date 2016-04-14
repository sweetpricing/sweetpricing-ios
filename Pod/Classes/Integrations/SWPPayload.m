#import "SWPPayload.h"


@implementation SWPPayload

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    if (self = [super init]) {
        _context = [context copy];
        _integrations = [integrations copy];
    }
    return self;
}

@end

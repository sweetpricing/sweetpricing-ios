#import "SWPVariantRequestPayload.h"


@implementation SWPVariantRequestPayload


- (instancetype)initWithProductGroupId:(NSInteger)productGroupId
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _productGroupId = productGroupId;
        _properties = [properties copy];
    }
    return self;
}

@end

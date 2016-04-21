#import <Foundation/Foundation.h>
#import "SWPPayload.h"


@interface SWPVariantRequestPayload : SWPPayload

@property (nonatomic, readonly) NSInteger productGroupId;

@property (nonatomic, readonly) NSDictionary *properties;

- (instancetype)initWithProductGroupId:(NSInteger)productGroupId
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

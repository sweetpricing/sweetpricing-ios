#import <Foundation/Foundation.h>
#import "SWPPayload.h"


@interface SWPScreenPayload : SWPPayload

@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) NSString *category;

@property (nonatomic, readonly) NSDictionary *properties;

- (instancetype)initWithName:(NSString *)name
                  properties:(NSDictionary *)properties
                     context:(NSDictionary *)context
                integrations:(NSDictionary *)integrations;

@end

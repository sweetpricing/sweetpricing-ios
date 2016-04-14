#import <Foundation/Foundation.h>
#import "SWPPayload.h"


@interface SWPTrackPayload : SWPPayload

@property (nonatomic, readonly) NSString *event;

@property (nonatomic, readonly) NSDictionary *properties;

- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

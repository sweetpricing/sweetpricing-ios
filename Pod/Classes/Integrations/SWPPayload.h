#import <Foundation/Foundation.h>


@interface SWPPayload : NSObject

@property (nonatomic, readonly) NSDictionary *context;
@property (nonatomic, readonly) NSDictionary *integrations;

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations;

@end

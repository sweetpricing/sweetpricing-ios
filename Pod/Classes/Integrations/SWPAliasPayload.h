#import <Foundation/Foundation.h>
#import "SWPPayload.h"


@interface SWPAliasPayload : SWPPayload

@property (nonatomic, readonly) NSString *theNewId;

- (instancetype)initWithNewId:(NSString *)newId
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

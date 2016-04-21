#import "SWPVariant.h"
#import "SWPAnalyticsUtils.h"

@implementation SWPVariant

- (id)initWithDictionary:(NSDictionary *)variantDictionary
{
    if (self = [super init]) {
      _id = variantDictionary[@"id"];
      _skus = variantDictionary[@"skus"];
    }
    return self;
}

- (NSString *)skuForProductId:(NSInteger)productId withDefault:(NSString *)defaultSku
{
  if (self.skus == nil) {
    return defaultSku;
  }

  NSString *productIdStr = [@(productId) stringValue];
  NSString *sku = self.skus[productIdStr];

  if (sku == nil) {
    return defaultSku;
  }

  return sku;
}

@end

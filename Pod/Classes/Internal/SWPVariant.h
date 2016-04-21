//
//  SIOVariant.h
//  Analytics
//
//  Created by Travis Jeffery on 4/23/14.
//  Copyright (c) 2014 Segment.io. All rights reserved.
//  Modified work Copyright (c) 2016 Sweet Pricing Ltd.
//

#import <Foundation/Foundation.h>


@interface SWPVariant : NSObject

@property (nonatomic, readonly) NSNumber *id;
@property (nonatomic, readonly) NSDictionary *skus;

- (id)initWithDictionary:(NSDictionary *) variantDictionary;
- (NSString *)skuForProductId:(NSInteger)productId withDefault:(NSString *)defaultSku;

@end

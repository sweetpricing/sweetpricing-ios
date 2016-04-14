//
//  SIOBluetooth.m
//  Analytics
//
//  Created by Travis Jeffery on 4/23/14.
//  Copyright (c) 2014 Segment.io. All rights reserved.
//  Modified work Copyright (c) 2016 Sweet Pricing Ltd.
//

#import "SWPBluetooth.h"
#import <CoreBluetooth/CoreBluetooth.h>

const NSString *SWPCentralManagerClass = @"CBCentralManager";


@interface SWPBluetooth () <CBCentralManagerDelegate>

@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) dispatch_queue_t queue;

@end


@implementation SWPBluetooth

- (id)init
{
    if (self = [super init]) {
        _queue = dispatch_queue_create("com.sweetpricing.bluetooth.queue", NULL);
        _manager = [[CBCentralManager alloc] initWithDelegate:self
                                                        queue:_queue
                                                      options:@{ CBCentralManagerOptionShowPowerAlertKey : @NO }];
    }
    return self;
}

- (BOOL)hasKnownState
{
    return _manager && (_manager.state != CBCentralManagerStateUnknown);
}

- (BOOL)isEnabled
{
    return _manager.state == CBCentralManagerStatePoweredOn;
}

- (void)centralManagerDidUpdateState:(id)central {}

@end

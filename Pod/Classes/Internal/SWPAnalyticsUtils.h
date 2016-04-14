// AnalyticsUtils.h
// Copyright (c) 2014 Segment.io. All rights reserved.
// Modified work Copyright (c) 2016 Sweet Pricing Ltd.

#import <Foundation/Foundation.h>

NSURL *SWPAnalyticsURLForFilename(NSString *filename);

// Date Utils
NSString *iso8601FormattedString(NSDate *date);

// Async Utils
dispatch_queue_t seg_dispatch_queue_create_specific(const char *label,
                                                    dispatch_queue_attr_t attr);
BOOL seg_dispatch_is_on_specific_queue(dispatch_queue_t queue);
void seg_dispatch_specific(dispatch_queue_t queue, dispatch_block_t block,
                           BOOL waitForCompletion);
void seg_dispatch_specific_async(dispatch_queue_t queue,
                                 dispatch_block_t block);
void seg_dispatch_specific_sync(dispatch_queue_t queue, dispatch_block_t block);

// Logging

void SWPSetShowDebugLogs(BOOL showDebugLogs);
void SWPLog(NSString *format, ...);

// JSON Utils

NSDictionary *SWPCoerceDictionary(NSDictionary *dict);

NSString *SWPIDFA(void);

NSString *SWPEventNameForScreenTitle(NSString *title);

//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"

/// 通过文件名和行号来标识调用点
@interface KWCallSite : NSObject

#pragma mark - Initializing

- (id)initWithFilename:(NSString *)aFilename lineNumber:(NSUInteger)aLineNumber;

+ (id)callSiteWithFilename:(NSString *)aFilename lineNumber:(NSUInteger)aLineNumber;

#pragma mark - Properties

@property (nonatomic, readonly, copy) NSString *filename;
@property (nonatomic, readonly) NSUInteger lineNumber;

#pragma mark - Identifying and Comparing

- (BOOL)isEqualToCallSite:(KWCallSite *)aCallSite;

@end

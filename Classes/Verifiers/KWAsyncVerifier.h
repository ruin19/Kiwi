//
//  KWAsyncVerifier.h
//  iOSFalconCore
//
//  Created by Luke Redpath on 13/01/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KWMatchVerifier.h"
#import "KWProbe.h"

#define kKW_DEFAULT_PROBE_TIMEOUT 1.0

@class KWAsyncMatcherProbe;

/// 设置一个超时时间，每隔0.1秒判断一次matcher。
/// 并不是真正的异步，会阻塞当前测试代码。
/// receiveXXX, bePostedXXX判断表达式看起来像异步的，只不过是把他们放到exampleWillEnd时候执行判断而已。
@interface KWAsyncVerifier : KWMatchVerifier

@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) BOOL shouldWait;

+ (id)asyncVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite matcherFactory:(KWMatcherFactory *)aMatcherFactory reporter:(id<KWReporting>)aReporter probeTimeout:(NSTimeInterval)probeTimeout shouldWait:(BOOL)shouldWait;
- (void)verifyWithProbe:(KWAsyncMatcherProbe *)aProbe;

@end


/// 封装了matcher和结果
@interface KWAsyncMatcherProbe : NSObject <KWProbe>

@property (nonatomic, assign) BOOL matchResult;
@property (nonatomic, readonly) id<KWMatching> matcher;

- (id)initWithMatcher:(id<KWMatching>)aMatcher;

@end

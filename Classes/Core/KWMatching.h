//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"

@protocol KWMatching<NSObject>

#pragma mark - Initializing

- (id)initWithSubject:(id)anObject;

#pragma mark - Getting Matcher Strings

+ (NSArray *)matcherStrings;

#pragma mark - Getting Matcher Compatability

+ (BOOL)canMatchSubject:(id)anObject;

#pragma mark - Matching

@optional

- (BOOL)isNilMatcher;
// 实现shouldBeEvaluatedAtEndOfExample并返回YES的matcher，会被放到exampleWillEnd的时候执行
- (BOOL)shouldBeEvaluatedAtEndOfExample;
- (BOOL)willEvaluateMultipleTimes;
- (void)setWillEvaluateMultipleTimes:(BOOL)shouldEvaluateMultipleTimes;
- (void)setWillEvaluateAgainstNegativeExpectation:(BOOL)willEvaluateAgainstNegativeExpectation;

@required

- (BOOL)evaluate;

#pragma mark - Getting Failure Messages

- (NSString *)failureMessageForShould;
- (NSString *)failureMessageForShouldNot;

@end

//
//  KWBeNilMatcher.m
//  iOSFalconCore
//
//  Created by Luke Redpath on 14/01/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "KWNilMatcher.h"
#import "KWExample.h"
#import "KWExampleSuiteBuilder.h"
#import "KWFormatter.h"
#import "KWMatchVerifier.h"
#import "KWVerifying.h"

@interface KWNilMatcher ()

@property (nonatomic, assign) BOOL expectsNil;

@end

@implementation KWNilMatcher

#pragma mark - Getting Matcher Strings

+ (NSArray *)matcherStrings {
    return @[@"beNil", @"beNil:", @"beNonNil", @"beNonNil:"];
}

#pragma mark - Matching

- (BOOL)isNilMatcher {
    return YES;
}

- (BOOL)evaluate {
    if (self.expectsNil) {
        return (self.subject == nil);
    } else {
        return (self.subject != nil);
    }
}

// These two methods gets invoked by be(Non)Nil macro in case the subject is nil
// (and therefore cannot have a verifier attached).

// 这两个方法解决nil对象调用shouldXXX, shouldNotXXX的问题。
// 此时verifier的subject是nil。而且verify不会正常收到beNil, beNonNil的forwardInvocation。
// 而是通过verifySubjectExpectingNil来主动调用beNil, beNonNil
+ (BOOL)verifyNilSubject {
    return [self verifySubjectExpectingNil:YES];
}

+ (BOOL)verifyNonNilSubject {
    return [self verifySubjectExpectingNil:NO];
}

#pragma mark Getting Failure Messages

- (NSString *)failureMessageForShould {
    if (self.expectsNil) {
        return [NSString stringWithFormat:@"expected subject to be nil, got %@",
                [KWFormatter formatObject:self.subject]];
    } else {
        return [NSString stringWithFormat:@"expected subject not to be nil"];
    }
}

- (NSString *)failureMessageForShouldNot {
    if (self.expectsNil) {
    return [NSString stringWithFormat:@"expected subject not to be nil"];
    } else {
        return [NSString stringWithFormat:@"expected subject to be nil, got %@",
                [KWFormatter formatObject:self.subject]];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"be %@nil", self.expectsNil ? @"" : @"non "];
}

- (void)beNil {
    self.expectsNil = YES;
}
- (void)beNil:(BOOL)workaroundArgument {
    self.expectsNil = YES;
}

- (void)beNonNil {
    self.expectsNil = NO;
}
- (void)beNonNil:(BOOL)workaroundArgument {
    self.expectsNil = NO;
}

#pragma mark - Internal Methods

+ (BOOL)verifySubjectExpectingNil:(BOOL)expectNil {
    KWExample *currentExample = [[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample];
    id<KWVerifying> verifier = currentExample.unresolvedVerifier;
    
    if (verifier && ![verifier subject] && [verifier isKindOfClass:[KWMatchVerifier class]]) {
        // ![verifier subject]表示nil对象调用shouldXXX或shouldNotXXX，verifier的正常的forwardInvocation不会走到了
        // 需要主动performSelector去调
        KWMatchVerifier *matchVerifier = (KWMatchVerifier *)verifier;
        if (expectNil) {
            [matchVerifier performSelector:@selector(beNil)];
        } else {
            [matchVerifier performSelector:@selector(beNonNil)];
        }
        // 完成判断表达式，可以清掉unresolvedVerifier
        currentExample.unresolvedVerifier = nil;
        return NO;
    }
    return YES;
}

@end

//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"

// This category is solely meant to coax Xcode into exposing the method names below during autocompletion.
// There is no implementation and this class definition must come before the macro definitions below.
@interface NSObject (KiwiVerifierMacroNames)

- (void)should;
- (void)shouldNot;
//废弃接口，应该使用[[obj should] beNil]
- (void)shouldBeNil DEPRECATED_ATTRIBUTE;
//废弃接口，应该使用[[obj shouldNot] beNil]
- (void)shouldNotBeNil DEPRECATED_ATTRIBUTE;
- (void)shouldEventually;
- (void)shouldNotEventually;
- (void)shouldEventuallyBeforeTimingOutAfter;
- (void)shouldNotEventuallyBeforeTimingOutAfter;

- (void)shouldAfterWait;
- (void)shouldNotAfterWait;
- (void)shouldAfterWaitOf;
- (void)shouldNotAfterWaitOf;

@end

#pragma mark - Support Macros

#define KW_THIS_CALLSITE [KWCallSite callSiteWithFilename:@__FILE__ lineNumber:__LINE__]
#define KW_ADD_EXIST_VERIFIER(expectationType) [KWSpec addExistVerifierWithExpectationType:expectationType callSite:KW_THIS_CALLSITE]
#define KW_ADD_MATCH_VERIFIER(expectationType) [KWSpec addMatchVerifierWithExpectationType:expectationType callSite:KW_THIS_CALLSITE]
#define KW_ADD_ASYNC_VERIFIER(expectationType, timeOut, wait) [KWSpec addAsyncVerifierWithExpectationType:expectationType callSite:KW_THIS_CALLSITE timeout:timeOut shouldWait:wait]

#pragma mark - Keywords

#ifndef KIWI_DISABLE_MATCHERS
// Kiwi macros used in specs for verifying expectations.
#define should attachToVerifier:KW_ADD_MATCH_VERIFIER(KWExpectationTypeShould)
#define shouldNot attachToVerifier:KW_ADD_MATCH_VERIFIER(KWExpectationTypeShouldNot)
// shouldBeNil和shouldNotBeNil是已废弃的接口，应当分别使用[[obj should] beNil]和[[obj shouldNot] beNil]替换
// shouldBeNil和shouldNotBeNil会创建KWExistVerifier，其功能仅判断是否为nil，另外其校验时机是在exampleWillEnd，可能会造成疑惑。
// [[obj should] beNil]和[[obj shouldNot] beNil] 则是创建KWMatchVerifier，再搭配具体的KWNilMatcher来做判断。
// 方案上跟其他的should和shouldNot判断是一致的，只是搭配具体的matcher即可。
#define shouldBeNil attachToVerifier:KW_ADD_EXIST_VERIFIER(KWExpectationTypeShouldNot)
#define shouldNotBeNil attachToVerifier:KW_ADD_EXIST_VERIFIER(KWExpectationTypeShould)

// 异步的这些接口（使用KW_ADD_ASYNC_VERIFIER的），都没有使用unresolvedVerifier来标记未匹配判断表达式的verifier
// 所以使用nil的对象来调用这些接口，可能有问题，不清楚是kiwi的bug还是设计如此
// 例如：NSString *str = nil; [[str shouldNotEventually] beNil]; 是返回成功的~
#define shouldEventually attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShould, kKW_DEFAULT_PROBE_TIMEOUT, NO)
#define shouldNotEventually attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShouldNot, kKW_DEFAULT_PROBE_TIMEOUT, NO)
#define shouldEventuallyBeforeTimingOutAfter(timeout) attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShould, timeout, NO)
#define shouldNotEventuallyBeforeTimingOutAfter(timeout) attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShouldNot, timeout, NO)

#define shouldAfterWait attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShould, kKW_DEFAULT_PROBE_TIMEOUT, YES)
#define shouldNotAfterWait attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShouldNot, kKW_DEFAULT_PROBE_TIMEOUT, YES)
#define shouldAfterWaitOf(timeout) attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShould, timeout, YES)
#define shouldNotAfterWaitOf(timeout) attachToVerifier:KW_ADD_ASYNC_VERIFIER(KWExpectationTypeShouldNot, timeout, YES)

// 这两个宏定义主要是解决nil对象接shouldXXX，shouldNotXXX的问题
#define beNil beNil:[KWNilMatcher verifyNilSubject]
#define beNonNil beNonNil:[KWNilMatcher verifyNonNilSubject]

// used to wrap a pointer to an object that will change in the future (used with shouldEventually)
// 目的通过block复制对象的指针地址，对象改变但指针地址不变，可以追踪到对象的变化
#define expectFutureValue(futureValue) [KWFutureObject futureObjectWithBlock:^{ return futureValue; }]

// `fail` triggers a failure report when called
#define fail(message, ...) [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] reportFailure:[KWFailure failureWithCallSite:KW_THIS_CALLSITE format:message, ##__VA_ARGS__]]

// used for message patterns to allow matching any value
#define kw_any() [KWAny any]
#endif

// If a gcc compatible compiler is available, use the statement and
// declarations in expression extension to provide a convenient catch-all macro
// to create KWValues.
#if defined(__GNUC__)
    #define theValue(expr) \
        ({ \
            __typeof__(expr) kiwiReservedPrefix_lVar = expr; \
            [KWValue valueWithBytes:&kiwiReservedPrefix_lVar objCType:@encode(__typeof__(expr))]; \
        })
#endif // #if defined(__GNUC__)

// Allows for comparision of pointer values in expectations
#define thePointerValue(expr) [NSValue valueWithPointer:(expr)]

// Example group declarations.
#define SPEC_BEGIN(name) \
    \
    @interface name : KWSpec \
    \
    @end \
    \
    @implementation name \
    \
    + (NSString *)file { return @__FILE__; } \
    \
    + (void)buildExampleGroups { \
        [super buildExampleGroups]; \
        \
        id _kw_test_case_class = self; \
        { \
            /* The shadow `self` must be declared inside a new scope to avoid compiler warnings. */ \
            /* The receiving class object delegates unrecognized selectors to the current example. */ \
            __unused name *self = _kw_test_case_class;

#define SPEC_END \
        } \
    } \
    \
    @end

// Test suite configuration declaration
#define CONFIG_START \
    @interface KWSuiteConfiguration : KWSuiteConfigurationBase \
    \
    @end \
    \
    @implementation KWSuiteConfiguration \
    \
    - (void)configureSuite {

#define CONFIG_END \
    } \
    \
    @end

// Used to ensure that shared examples are registered before any
// examples are evaluated. The name parameter is not used except
// to define a category. Therefore, it must be unique.
#define SHARED_EXAMPLES_BEGIN(name) \
    \
    @interface KWSharedExample (name) \
    \
    @end \
    \
    @implementation KWSharedExample (name) \
    \
    + (void)load { \

#define SHARED_EXAMPLES_END \
    } \
    \
    @end \

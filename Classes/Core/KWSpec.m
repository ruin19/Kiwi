//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWSpec.h"
#import "KWCallSite.h"
#import "KWExample.h"
#import "KWExampleSuiteBuilder.h"
#import "KWFailure.h"
#import "KWExampleSuite.h"

#import <objc/runtime.h>

@interface KWSpec()

@property (nonatomic, strong) KWExample *currentExample;

@end

@implementation KWSpec

/* Methods are only implemented by sub-classes */

+ (NSString *)file { return nil; }

+ (void)buildExampleGroups {}

- (NSString *)name {
    return [self description];
}

/* Use camel case to make method friendly names from example description. */

- (NSString *)description {
    KWExample *currentExample = self.currentExample ?: self.invocation.kw_example;
    return [NSString stringWithFormat:@"-[%@ %@]", NSStringFromClass([self class]), currentExample.selectorName];
}

#pragma mark - Getting Invocations

/// 功能：重写XCTestCase的类方法testInvocations，XCTest框架会调用这个方法来获取待测方法。
/// 背景：XCTest框架是如何知道调用哪些测试方法的？一是调用带'test'前缀的实例方法；二是调用testInvocations，获取待测的NSInvocation列表，再调用这些NSInvocation。
/// 直接在XCTest框架下写单测时，一般是采用方式一，如定义： '- (void)testXXX {}' 。
/// Kiwi写单测使用方式二，通过实现testInvocations方法来告诉框架调用哪些NSInvocation。
+ (NSArray *)testInvocations {
    SEL buildExampleGroups = @selector(buildExampleGroups);

    // 必须是KWSpec的子类并实现了buildExampleGroups方法才返回NSInvocation数组
    if ([self methodForSelector:buildExampleGroups] == [KWSpec methodForSelector:buildExampleGroups])
        return @[];

    KWExampleSuite *exampleSuite = [[KWExampleSuiteBuilder sharedExampleSuiteBuilder] buildExampleSuite:^{
        // buildExampleGroups是Kiwi单测起始宏SPEC_BEGIN里面定义的类方法，包在SPEC_BEGIN和SPEC_END之间的代码作为它的函数实现。
        [self buildExampleGroups];
    }];

    //为每一个example在运行时生成实例方法，封装到NSInvocation，最终返回NSInvocation数组。
    NSMutableArray *invocations = [NSMutableArray new];
    for (KWExample *example in exampleSuite) {
        SEL selector = [self addInstanceMethodForExample:example];
        NSInvocation *invocation = [self invocationForExample:example selector:selector];
        [invocations addObject:invocation];
    }

    return invocations;
}

/// 为每一个KWExample，在运行时创建一个对应的实例方法，使得XCTest框架可以调用。
/// @param example 每一个'it'或'pending'对应的example
+ (SEL)addInstanceMethodForExample:(KWExample *)example {
    // 每一个实例方法的实现都是runExample的实现，那怎么区分？可以到runExample方法看看~
    Method method = class_getInstanceMethod(self, @selector(runExample));
    SEL selector = NSSelectorFromString(example.selectorName);
    IMP implementation = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    class_addMethod(self, selector, implementation, types);
    return selector;
}

/// 创建NSInvocation，关键是把example绑定到NSInvocation上
/// @param example 一个it或pending对应的example
/// @param selector 实例方法名
+ (NSInvocation *)invocationForExample:(KWExample *)example selector:(SEL)selector {
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    //绑定example到invocation
    invocation.kw_example = example;
    invocation.selector = selector;
    return invocation;
}

#pragma mark - Message forwarding

/// 在一对SPEC_BEGIN和SPEC_END之间写的代码，其实都在类方法 + (void)buildExampleGroups {} 里面，而不是实例方法。
/// 也就是说此时self指向的是类，而不是实例。因此一些对self发送的消息，本来期望给到实例的，结果给到了类。比如'XCTAssert*'宏，就使用了self。
/// 因此这里做了一次转发，转给了当前的KWExample实例。但KWEXample实例也不能处理这个消息，它会进一步转发给它的delegate，也就是真正的XCTestCase的一个实例对象。
/// @param aSelector  接收到的未定义的方法名
+ (id)forwardingTargetForSelector:(SEL)aSelector {
    KWExample *example = [[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample];

    if ([example respondsToSelector:aSelector]) {
        return example;
    } else {
        return [super forwardingTargetForSelector:aSelector];
    }
}

+ (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) {
        return YES;
    }

    KWExample *example = [[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample];
    return [example respondsToSelector:aSelector];
}

#pragma mark - Running Specs

/// 每一个具体测试方法的实现
- (void)runExample {
    // 这句话是区分每一个测试方法的关键：invocation是父类XCTestCase的属性，表示当前执行的调用。
    // kw_example是动态绑定到invocation上面的，这里就可以知道当前执行的是哪一个example了
    self.currentExample = self.invocation.kw_example;

    @try {
        // 这里就是执行一个example的入口
        [self.currentExample runWithDelegate:self];
    } @catch (NSException *exception) {
        // 单测中抛的异常上报到XCTest框架
        [self recordFailureWithDescription:exception.description inFile:@"" atLine:0 expected:NO];
    }
    
    self.invocation.kw_example = nil;
}

#pragma mark - KWExampleGroupDelegate methods

- (void)example:(KWExample *)example didFailWithFailure:(KWFailure *)failure {
    [self recordFailureWithDescription:failure.message
                                inFile:failure.callSite.filename
                                atLine:failure.callSite.lineNumber
                              expected:NO];
}

#pragma mark - Verification proxies

+ (id)addVerifier:(id<KWVerifying>)aVerifier {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addVerifier:aVerifier];
}

+ (id)addExistVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addExistVerifierWithExpectationType:anExpectationType callSite:aCallSite];
}

+ (id)addMatchVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addMatchVerifierWithExpectationType:anExpectationType callSite:aCallSite];
}

+ (id)addAsyncVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite timeout:(NSTimeInterval)timeout shouldWait:(BOOL)shouldWait {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addAsyncVerifierWithExpectationType:anExpectationType callSite:aCallSite timeout:timeout shouldWait: shouldWait];
}

@end

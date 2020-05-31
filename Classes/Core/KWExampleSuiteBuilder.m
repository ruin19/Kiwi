//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWExampleSuiteBuilder.h"

#import "KWAfterAllNode.h"
#import "KWAfterEachNode.h"
#import "KWBeforeAllNode.h"
#import "KWBeforeEachNode.h"
#import "KWLetNode.h"
#import "KWCallSite.h"
#import "KWContextNode.h"
#import "KWExample.h"
#import "KWExampleSuite.h"
#import "KWItNode.h"
#import "KWPendingNode.h"
#import "KWRegisterMatchersNode.h"
#import "KWSymbolicator.h"

static NSString * const KWExampleSuiteBuilderException = @"KWExampleSuiteBuilderException";

@interface KWExampleSuiteBuilder()

#pragma mark - Building Example Groups

@property (nonatomic, strong) KWExampleSuite *currentExampleSuite;
@property (nonatomic, readonly) NSMutableArray *contextNodeStack;

@property (nonatomic, strong) NSMutableSet *suites;

@property (nonatomic, assign) BOOL focusedContextNode;
@property (nonatomic, assign) BOOL focusedItNode;

@end

@implementation KWExampleSuiteBuilder


#pragma mark - Initializing


- (id)init {
    self = [super init];
    if (self) {
        _contextNodeStack = [[NSMutableArray alloc] init];
        _suites = [[NSMutableSet alloc] init];
        [self focusWithURI:[[[NSProcessInfo processInfo] environment] objectForKey:@"KW_SPEC"]];
    }
    return self;
}


+ (id)sharedExampleSuiteBuilder {
    static KWExampleSuiteBuilder *sharedExampleSuiteBuilder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExampleSuiteBuilder = [self new];
    });

    return sharedExampleSuiteBuilder;
}

#pragma mark - Focus

- (void)focusWithURI:(NSString *)nodeUrl {
    NSArray *focusInfo = [nodeUrl componentsSeparatedByString:@":"];
    if (!focusInfo || focusInfo.count != 2)
        return;
    self.focusedCallSite = [KWCallSite callSiteWithFilename:focusInfo[0] lineNumber:[focusInfo[1] intValue]];
}

- (void)setFocusedCallSite:(KWCallSite *)aFocusedCallSite {
    _focusedCallSite = aFocusedCallSite;
    self.focusedItNode = NO;
    self.focusedContextNode = NO;
}

- (BOOL)isFocused {
    return self.focusedCallSite != nil;
}

- (BOOL)foundFocus {
    return self.focusedContextNode || self.focusedItNode;
}

#pragma mark - Building Example Groups

- (BOOL)isBuildingExampleSuite {
    return [self.contextNodeStack count] > 0;
}

/// 一对SPEC_BEGIN和SPEC_END产生一个KWExampleSuite。
/// KWExampleSuite是KWExample的集合。
/// KWExample则跟我们写的每一个'it'或'pending'一一对应。
/// 也就是说每写一个'it'或'pending'，都会生成一个KWExample，并放入KWExampleSuite中。
/// @param buildingBlock 封装了一对SPEC_BEGIN和SPEC_END之间的代码。
- (KWExampleSuite *)buildExampleSuite:(void (^)(void))buildingBlock
{
    // 创建根KWContextNode,后面也会看到我们写的每一个'describe'，'context'也是一个KWContextNode。
    // describe和context可以有多层的嵌套，context树描述了这个嵌套关系。
    KWContextNode *rootNode = [KWContextNode contextNodeWithCallSite:nil parentContext:nil description:nil];

    // 创建KWExampleSuite并持有rootNode。
    // KWExampleSuiteBuilder是一个单例，它同时持有多个suite，currentExampleSuite表示当前正在创建的suite。
    // 这也从侧面证明多个XCTestCase是串行执行的，否则这里就乱了。
    self.currentExampleSuite = [[KWExampleSuite alloc] initWithRootNode:rootNode];
    
    // KWExampleSuiteBuilder是一个全局单例，它持有多个suite
    [self.suites addObject:self.currentExampleSuite];

    // contextNodeStack是一个后进先出的堆，用于在构建context树和example集合的时候，指示当前context。
    // 操作方式：进堆 -> 构建 -> 出堆。
    [self.contextNodeStack addObject:rootNode];
    // 执行SPEC_BEGIN和SPEC_END之间的代码，即一些describe, context, beforeEach, it, afterEach等等函数。
    // 这些函数的定义在KWExample.m
    buildingBlock();
    [self.contextNodeStack removeAllObjects];
    
    return self.currentExampleSuite;
}

- (void)pushContextNodeWithCallSite:(KWCallSite *)aCallSite description:(NSString *)aDescription {

    // contextNodeStack的最后一个context标识了当前处于的那个describe或context。即父context。
    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    // 创建context节点，并且把上一步获得的context作为自己的父亲节点。
    KWContextNode *node = [KWContextNode contextNodeWithCallSite:aCallSite parentContext:contextNode description:aDescription];

    if (self.isFocused)
        node.isFocused = [self shouldFocusContextNodeWithCallSite:aCallSite parentNode:contextNode];

    // 父节点把新创建的节点添加为子节点
    [contextNode addContextNode:node];
    // 保存到堆，现在处于新节点了
    [self.contextNodeStack addObject:node];
}

- (BOOL)shouldFocusContextNodeWithCallSite:(KWCallSite *)aCallSite parentNode:(KWContextNode *)parentNode {
    if (parentNode.isFocused)
        return YES;

    if ([aCallSite isEqualToCallSite:self.focusedCallSite]) {
        self.focusedContextNode = YES;
        return YES;
    }
    return NO;
}

- (void)popContextNode {
    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    
    [self.currentExampleSuite markLastExampleAsLastInContext:contextNode];
    
    if ([self.contextNodeStack count] == 1) {
        [NSException raise:KWExampleSuiteBuilderException
                    format:@"there is no open context to pop"];
    }

    [self.contextNodeStack removeLastObject];
}

- (void)setRegisterMatchersNodeWithCallSite:(KWCallSite *)aCallSite namespacePrefix:(NSString *)aNamespacePrefix {
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    KWRegisterMatchersNode *registerMatchersNode = [KWRegisterMatchersNode registerMatchersNodeWithCallSite:aCallSite namespacePrefix:aNamespacePrefix];
    [contextNode addRegisterMatchersNode:registerMatchersNode];
}

- (void)setBeforeAllNodeWithCallSite:(KWCallSite *)aCallSite block:(void (^)(void))block {
    // 如果没有在describe或context里面，直接抛异常
    [self raiseIfExampleGroupNotStarted];

    // 获取当前所处的context
    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    // 创建一个BeforeAll节点，保存block
    KWBeforeAllNode *beforeAllNode = [KWBeforeAllNode beforeAllNodeWithCallSite:aCallSite block:block];
    // 把beforeAll节点交给当前所处的context节点保存
    [contextNode setBeforeAllNode:beforeAllNode];
}

- (void)setAfterAllNodeWithCallSite:(KWCallSite *)aCallSite block:(void (^)(void))block {
    // 参见setBeforeAllNodeWithCallSite，实现很类似
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    KWAfterAllNode *afterAllNode = [KWAfterAllNode afterAllNodeWithCallSite:aCallSite block:block];
    [contextNode setAfterAllNode:afterAllNode];
}

- (void)setBeforeEachNodeWithCallSite:(KWCallSite *)aCallSite block:(void (^)(void))block {
    // 参见setBeforeAllNodeWithCallSite，实现很类似
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    KWBeforeEachNode *beforeEachNode = [KWBeforeEachNode beforeEachNodeWithCallSite:aCallSite block:block];
    [contextNode setBeforeEachNode:beforeEachNode];
}

- (void)setAfterEachNodeWithCallSite:(KWCallSite *)aCallSite block:(void (^)(void))block {
    // 参见setBeforeAllNodeWithCallSite，实现很类似
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    KWAfterEachNode *afterEachNode = [KWAfterEachNode afterEachNodeWithCallSite:aCallSite block:block];
    [contextNode setAfterEachNode:afterEachNode];
}

- (void)addLetNodeWithCallSite:(KWCallSite *)aCallSite objectRef:(__autoreleasing id *)anObjectRef symbolName:(NSString *)aSymbolName block:(id (^)(void))block {
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    [contextNode addLetNode:[KWLetNode letNodeWithSymbolName:aSymbolName objectRef:anObjectRef block:block]];
}

- (void)addItNodeWithCallSite:(KWCallSite *)aCallSite description:(NSString *)aDescription block:(void (^)(void))block {
    // 如果没有在describe或context里面，直接抛异常
    [self raiseIfExampleGroupNotStarted];

    // 获取当前所处的context
    KWContextNode *contextNode = [self.contextNodeStack lastObject];

    if (self.isFocused && ![self shouldAddItNodeWithCallSite:aCallSite toContextNode:contextNode])
        return;

    // 创建it节点，把定义在it关键字内的block保存在it节点
    KWItNode* itNode = [KWItNode itNodeWithCallSite:aCallSite description:aDescription context:contextNode block:block];
    [contextNode addItNode:itNode];
    
    // 每一个it关键字都会创建一个KWExample，example持有itNode
    KWExample *example = [[KWExample alloc] initWithExampleNode:itNode];
    // KWExample放到当前正在构建的KWExampleSuite里。
    [self.currentExampleSuite addExample:example];
}

- (BOOL)shouldAddItNodeWithCallSite:(KWCallSite *)aCallSite toContextNode:(KWContextNode *)contextNode {
    if (contextNode.isFocused)
        return YES;

    if([aCallSite isEqualToCallSite:self.focusedCallSite]){
        self.focusedItNode = YES;
        return YES;
    }

    return NO;
}

- (void)addPendingNodeWithCallSite:(KWCallSite *)aCallSite description:(NSString *)aDescription {
    [self raiseIfExampleGroupNotStarted];

    KWContextNode *contextNode = [self.contextNodeStack lastObject];
    KWPendingNode *pendingNode = [KWPendingNode pendingNodeWithCallSite:aCallSite context:contextNode description:aDescription];
    [contextNode addPendingNode:pendingNode];
    // pending也会创建一个KWExample
    KWExample *example = [[KWExample alloc] initWithExampleNode:pendingNode];
    [self.currentExampleSuite addExample:example];
}

/// 如果contextNodeStack是空的，证明没有在describe或context里面
- (void)raiseIfExampleGroupNotStarted {
    if ([self.contextNodeStack count] == 0) {
        [NSException raise:KWExampleSuiteBuilderException
                    format:@"an example group has not been started"];
    }
}

@end

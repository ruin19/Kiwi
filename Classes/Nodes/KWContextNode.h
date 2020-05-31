//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"
#import "KWExampleNode.h"

@class KWAfterAllNode;
@class KWAfterEachNode;
@class KWBeforeAllNode;
@class KWBeforeEachNode;
@class KWCallSite;
@class KWLetNode;
@class KWItNode;
@class KWPendingNode;
@class KWRegisterMatchersNode;
@class KWExample;

@interface KWContextNode : NSObject<KWExampleNode>

#pragma mark - Initializing

- (id)initWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)node description:(NSString *)aDescription;

+ (id)contextNodeWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)contextNode description:(NSString *)aDescription;

#pragma mark -  Getting Call Sites

@property (nonatomic, weak, readonly) KWCallSite *callSite;

#pragma mark - Getting Descriptions

@property (readonly, copy) NSString *description;

#pragma mark - Managing Nodes

// 可见一个describe或context里面的beforeAll, afterAll, beforeEach, afterEach这些节点都是最多出现一次的。
// 但如果有子describe或子context，它们里面可以有自己的一个这些节点。
@property (nonatomic, strong) KWBeforeAllNode *beforeAllNode;
@property (nonatomic, strong) KWAfterAllNode *afterAllNode;
@property (nonatomic, strong) KWBeforeEachNode *beforeEachNode;
@property (nonatomic, strong) KWAfterEachNode *afterEachNode;

//context节点、it节点、pending节点都会存到nodes数组里
@property (nonatomic, readonly) NSArray *nodes;
@property (nonatomic, readonly) NSArray *registerMatchersNodes;
@property (nonatomic, readonly) NSArray *letNodes;

@property (nonatomic, readonly) KWContextNode *parentContext;

@property (nonatomic, assign) BOOL isFocused;

- (void)addContextNode:(KWContextNode *)aNode;
- (void)addLetNode:(KWLetNode *)aNode;
- (void)addRegisterMatchersNode:(KWRegisterMatchersNode *)aNode;
- (void)addItNode:(KWItNode *)aNode;
- (void)addPendingNode:(KWPendingNode *)aNode;

- (KWLetNode *)letNodeTree;

- (void)performExample:(KWExample *)example withBlock:(void (^)(void))exampleBlock;

#pragma mark - Accepting Visitors

- (void)acceptExampleNodeVisitor:(id<KWExampleNodeVisitor>)aVisitor;

@end

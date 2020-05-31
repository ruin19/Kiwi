//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWAfterAllNode.h"
#import "KWAfterEachNode.h"
#import "KWBeforeAllNode.h"
#import "KWBeforeEachNode.h"
#import "KWLetNode.h"
#import "KWCallSite.h"
#import "KWContextNode.h"
#import "KWExampleNodeVisitor.h"
#import "KWExample.h"
#import "KWFailure.h"
#import "KWRegisterMatchersNode.h"
#import "KWSymbolicator.h"

static NSString * const KWContextNodeException = @"KWContextNodeException";

@interface KWContextNode()

@property (nonatomic, assign) NSUInteger performedExampleCount;

@end

@implementation KWContextNode

@synthesize description = _description;

#pragma mark - Initializing

- (id)initWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)node description:(NSString *)aDescription {
    self = [super init];
    if (self) {
        _parentContext = node;
        _callSite = aCallSite;
        _description = [aDescription copy];
        _nodes = [NSMutableArray array];
        _registerMatchersNodes = [NSMutableArray array];
        _letNodes = [NSMutableArray array];
        _performedExampleCount = 0;
    }

    return self;
}

+ (id)contextNodeWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)contextNode description:(NSString *)aDescription {
    return [[self alloc] initWithCallSite:aCallSite parentContext:contextNode description:aDescription];
}

- (void)addContextNode:(KWContextNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)setBeforeEachNode:(KWBeforeEachNode *)aNode {
    // 一个describe或context里面只能有一个beforeEach
    [self raiseIfNodeAlreadyExists:self.beforeEachNode];
    _beforeEachNode = aNode;
}

- (void)setAfterEachNode:(KWAfterEachNode *)aNode {
    // 一个describe或context里面只能有一个afterEach
    [self raiseIfNodeAlreadyExists:self.afterEachNode];
    _afterEachNode = aNode;
}

- (void)addLetNode:(KWLetNode *)aNode {
    [(NSMutableArray *)self.letNodes addObject:aNode];
}

- (void)addRegisterMatchersNode:(KWRegisterMatchersNode *)aNode {
    [(NSMutableArray *)self.registerMatchersNodes addObject:aNode];
}

- (KWLetNode *)letNodeTree {
    KWLetNode *tree = [self.parentContext letNodeTree];
    for (KWLetNode *letNode in self.letNodes) {
        if (!tree) {
            tree = letNode;
        }
        else {
            [tree addLetNode:letNode];
        }
    }
    return tree;
}

- (void)addItNode:(KWItNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)addPendingNode:(KWPendingNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)performExample:(KWExample *)example withBlock:(void (^)(void))exampleBlock
{
    void (^innerExampleBlock)(void) = [exampleBlock copy];
    
    void (^outerExampleBlock)(void) = ^{
        @try {
            for (KWRegisterMatchersNode *registerNode in self.registerMatchersNodes) {
                [registerNode acceptExampleNodeVisitor:example];
            }

            // beforeAll在context内的所有example执行之前执行一次
            if (self.performedExampleCount == 0) {
                [self.beforeAllNode acceptExampleNodeVisitor:example];
            }

            // 执行let
            KWLetNode *letNodeTree = [self letNodeTree];
            [letNodeTree acceptExampleNodeVisitor:example];

            // 执行beforeEach
            [self.beforeEachNode acceptExampleNodeVisitor:example];

            // 执行example的block
            innerExampleBlock();

            // 执行afterEach
            [self.afterEachNode acceptExampleNodeVisitor:example];

            // afterAll在context内所有example执行之后执行一次
            if ([example isLastInContext:self]) {
                [self.afterAllNode acceptExampleNodeVisitor:example];
                [letNodeTree unlink];
            }

        } @catch (NSException *exception) {
            KWFailure *failure = [KWFailure failureWithCallSite:self.callSite format:@"%@ \"%@\" raised", [exception name], [exception reason]];
            [example reportFailure:failure];
        }
        
        self.performedExampleCount++;
    };
    // 如果有父context，需要把当前example交给父context去执行。
    // 因为父context内部可能定义了beforeAll, afterAll, beforeEach, afterEach等。
    // 当前example的执行要考虑在父context中的执行时机。
    if (self.parentContext == nil) {
        outerExampleBlock();
    }
    else {
        [self.parentContext performExample:example withBlock:outerExampleBlock];
    }
}

- (void)raiseIfNodeAlreadyExists:(id<KWExampleNode>)node {
    if (node) {
        [NSException raise:KWContextNodeException
                    format:@"A %@ already exists in this context.", NSStringFromClass([node class])];
    }
}

#pragma mark - Accepting Visitors

- (void)acceptExampleNodeVisitor:(id<KWExampleNodeVisitor>)aVisitor {
    [aVisitor visitContextNode:self];
}

@end

//
//  KWFutureObject.m
//  iOSFalconCore
//
//  Created by Luke Redpath on 13/01/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "KWFutureObject.h"

@interface KWFutureObject()

@property (nonatomic, strong) KWFutureObjectBlock block;

@end

@implementation KWFutureObject

+ (id)objectWithObjectPointer:(id __autoreleasing *)pointer {
  return [self futureObjectWithBlock:^{ return *pointer; }];
}

+ (id)futureObjectWithBlock:(KWFutureObjectBlock)block {
  return [[self alloc] initWithBlock:block];
}

- (id)initWithBlock:(KWFutureObjectBlock)aBlock {
    self = [super init];
    if (self) {
        _block = [aBlock copy];
  }
  return self;
}

- (id)object; {
    //执行block，返回futureValue
  return self.block();
}


@end

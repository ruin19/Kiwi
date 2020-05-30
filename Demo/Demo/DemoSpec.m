//
//  DemoSpec.m
//  Demo
//
//  Created by 卢寅 on 2020/5/30.
//  Copyright 2020 ___ORGANIZATIONNAME___. All rights reserved.
//

#import <Kiwi/Kiwi.h>

SPEC_BEGIN(DemoSpec)
{
    describe(@"aa", ^{
        context(@"bb", ^{
            it(@"it", ^{
                [[theValue(1) should] equal:theValue(1)];
            });
        });
    });
}

SPEC_END

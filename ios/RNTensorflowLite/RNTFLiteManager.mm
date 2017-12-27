//
//  RNTFLiteManager.m
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import "RNTFLiteManager.h"
#import "RNTFLiteView.h"

@implementation RNTFLiteManager

RCT_EXPORT_MODULE();

- (UIView *)view
{
  if (!self.camera) {
    self.camera = [[RNTFLiteView alloc] init];
  }
  
  return self.camera;
}

@end

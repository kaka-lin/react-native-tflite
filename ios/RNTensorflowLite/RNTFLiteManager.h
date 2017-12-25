//
//  RNTFLiteManager.h
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//
#import <React/RCTViewManager.h>
#import <AVFoundation/AVFoundation.h>

#import "RNTFLiteView.h"

@interface RNTFLiteManager : RCTViewManager<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) RNTFLiteView *camera;

@property (nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

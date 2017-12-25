//
//  RNTFLiteView.h
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface RNTFLiteView : UIView<AVCaptureVideoDataOutputSampleBufferDelegate> {
  AVCaptureVideoPreviewLayer *previewLayer;
  
  AVCaptureSession *session;
  AVCaptureVideoDataOutput *videoDataOutput;
  dispatch_queue_t videoDataOutputQueue;
}

@end

//
//  RNTFLiteView.h
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#include <vector>
#include "tensorflow/contrib/lite/kernels/register.h"
#include "tensorflow/contrib/lite/model.h"

@interface RNTFLiteView : UIView<AVCaptureVideoDataOutputSampleBufferDelegate> {
  UIView *view;
  UIView *previewView;
  
  AVCaptureVideoPreviewLayer *previewLayer;
  NSMutableArray *labelLayers;
  
  AVCaptureSession *session;
  AVCaptureVideoDataOutput *videoDataOutput;
  dispatch_queue_t videoDataOutputQueue;
  
  std::vector<std::string> labels;
  std::unique_ptr<tflite::FlatBufferModel> model;
  tflite::ops::builtin::BuiltinOpResolver resolver;
  std::unique_ptr<tflite::Interpreter> interpreter;
  
  NSMutableDictionary *oldPredictionValues;
  
  double total_latency;
  int total_count;
}
@property(strong, nonatomic) CATextLayer* predictionTextLayer;

@end

//
//  RNTFLiteView.m
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import "RNTFLiteView.h"

@implementation RNTFLiteView

// 從代碼實例化 UIView
- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    // Initialization code
    
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  NSError *error = nil;
  
  // 1. create the capture session
  session = [AVCaptureSession new];
  
  // 2. 設定畫面大小
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    session.sessionPreset = AVCaptureSessionPreset640x480;
  }
  else {
    session.sessionPreset =AVCaptureSessionPresetPhoto;
  }
  
  // 3. creat device
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  
  // 4. device input (將Device設成輸入端，可以想成輸入為Camera擷取的影像，輸出為我們設定的ImageView)
  AVCaptureDeviceInput *deviceInput =
  [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  
  if (error != nil) {
    NSLog(@"Failed to initialize AVCaptureDeviceInput. Note: This app doesn't work with simulator");
    assert(NO);
  }
  
  // 5. connect the device input
  if ([session canAddInput:deviceInput]) [session addInput:deviceInput];
  
  /* --------------- 至此已經可以成功擷取Camera的影像，只是缺少輸出沒辦法呈現出來 --------------- */
  
  // 6. create video data output
  videoDataOutput = [AVCaptureVideoDataOutput new];
  
  // 7. 設定輸出端的像素（Pixel）格式化，包含透明度的32位元
  //    CoreImage wants BGRA pixel format
  NSDictionary* rgbOutputSettings =
  [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  
  videoDataOutput.videoSettings = rgbOutputSettings;
  videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
  
  // 8. create the dispatch queue for handling capture session delegate method calls
  //    對輸出端的queue做設定
  videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
  [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
  
  // 9. connect the data output
  if ([session canAddOutput:videoDataOutput]) [session addOutput:videoDataOutput];
  [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
  
  // 補充： AVCaptureVideoPreviewLayer是CALayer的子類，可被用於自動顯示相機產生的即時圖像
  previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  previewLayer.backgroundColor = UIColor.blackColor.CGColor; // 更改 view 背景的顏色
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect]; // 將這個圖層屬性設定為resize
  
  
  [self.layer setMasksToBounds:YES];
  [previewLayer setFrame:[self.layer bounds]];
  [self.layer addSublayer:previewLayer];
  
  [session startRunning];
}

@end

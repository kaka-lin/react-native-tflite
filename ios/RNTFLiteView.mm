//
//  RNTFLiteView.m
//  RNTensorflowLite
//
//  Created by 林家豪 on 2017/12/25.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import "RNTFLiteView.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#include <sys/time.h>
#include <fstream>
#include <iostream>
#include <queue>

#include "tensorflow/contrib/lite/kernels/register.h"
#include "tensorflow/contrib/lite/model.h"
#include "tensorflow/contrib/lite/string_util.h"
#include "tensorflow/contrib/lite/tools/mutable_op_resolver.h"

#define LOG(x) std::cerr

// If you have your own model, modify this to the file name, and make sure
// you've added the file to your app resources too.
static NSString *model_file_name = @"mobilenet_quant_v1_224";
static NSString *model_file_type = @"tflite";

// If you have your own model, point this to the labels file.
static NSString *labels_file_name = @"labels";
static NSString *labels_file_type = @"txt";

// These dimensions need to match those the model was trained with.
static const int wanted_input_width = 224;
static const int wanted_input_height = 224;
static const int wanted_input_channels = 3;

static NSString *FilePathForResourceName(NSString *name, NSString *extension)
{
  NSString *file_path = [[NSBundle mainBundle] pathForResource:name ofType:extension];
  if (file_path == NULL) {
    LOG(FATAL) << "Couldn't find '" << [name UTF8String] << "." << [extension UTF8String]
    << "' in bundle.";
  }
  
  return file_path;
}

static void LoadLabels(NSString *file_name, NSString *file_type, std::vector<std::string> *label_strings)
{
  NSString *labels_path = FilePathForResourceName(file_name, file_type);
  if (!labels_path) {
    LOG(ERROR) << "Failed to find model proto at" << [file_name UTF8String]
    << [file_type UTF8String];
  }
  
  std::ifstream t;
  t.open([labels_path UTF8String]);
  std::string line;
  while (t) {
    std::getline(t, line);
    label_strings->push_back(line);
  }
  t.close();
}

// Returns the top N confidence values over threshold in the provided vector,
// sorted by confidence in descending order.
static void GetTopN(const uint8_t *prediction, const int prediction_size, const int num_results,
                    const float threshold, std::vector<std::pair<float, int>> *top_results)
{
  // Will contain top N results in ascending order
  // priority_queue: template <Type, Container, Founction>
  std::priority_queue<std::pair<float, int>, std::vector<std::pair<float, int>>,
  std::greater<std::pair<float, int>>>
  top_result_pq;
  
  const long count = prediction_size;
  
  for (int i = 0; i < count; ++i) {
    const float value = prediction[i] / 255.0;
    // Only add it if it beats the threshold and has a chance at being in
    // the top N.
    if (value < threshold) {
      continue;
    }
    
    top_result_pq.push(std::pair<float, int>(value, i));
    
    // If at capacity, kick the smallest value out.
    if (top_result_pq.size() > num_results) {
      top_result_pq.pop();
    }
  }
  
  // Copy to output vector and reverse into descending order.
  while (!top_result_pq.empty()) {
    top_results->push_back(top_result_pq.top());
    top_result_pq.pop();
  }
  std::reverse(top_results->begin(), top_results->end());
}

@implementation RNTFLiteView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [view setBackgroundColor:[UIColor blackColor]];
    [self addSubview:view];
    
    CGRect viewRect = CGRectMake(0, 0, 375, 621);
    previewView = [[UIView alloc] initWithFrame:viewRect];
    [previewView setBackgroundColor:[UIColor whiteColor]];
    [view addSubview:previewView];
  }
  
  return self;
}

- (instancetype)init
{
  self = [super init];
  labelLayers = [[NSMutableArray alloc] init];
  oldPredictionValues = [[NSMutableDictionary alloc] init];
  
  NSString *graph_path = FilePathForResourceName(model_file_name, model_file_type);
  model = tflite::FlatBufferModel::BuildFromFile([graph_path UTF8String]);
  if (!model) {
    LOG(FATAL) << "Failed to mmap model " << graph_path;
  }
  LOG(INFO) << "Loaded model " << graph_path;
  model->error_reporter();
  LOG(INFO) << "resolved reporter";
  
  tflite::ops::builtin::BuiltinOpResolver resolver;
  LoadLabels(labels_file_name, labels_file_type, &labels);
  
  tflite::InterpreterBuilder(*model, resolver)(&interpreter);
  if (!interpreter) {
    LOG(FATAL) << "Failed to construct interpreter";
  }
  if (interpreter->AllocateTensors() != kTfLiteOk) {
    LOG(FATAL) << "Failed to allocate tensors!";
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  [self setupAVCapture];
}

- (void)setupAVCapture
{
  NSError *error = nil;
  
  session = [AVCaptureSession new];
  
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    session.sessionPreset = AVCaptureSessionPreset640x480;
  }
  else {
    session.sessionPreset = AVCaptureSessionPresetPhoto;
  }
  
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

  AVCaptureDeviceInput *deviceInput =
  [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  
  if (error != nil) {
    NSLog(@"Failed to initialize AVCaptureDeviceInput. Note: This app doesn't work with simulator");
    assert(NO);
  }
  
  if ([session canAddInput:deviceInput]) [session addInput:deviceInput];
  
  videoDataOutput = [AVCaptureVideoDataOutput new];
  
  NSDictionary* rgbOutputSettings =
  [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  
  videoDataOutput.videoSettings = rgbOutputSettings;
  videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
  
  videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
  [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
  
  if ([session canAddOutput:videoDataOutput]) [session addOutput:videoDataOutput];
  [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
  
  previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  previewLayer.backgroundColor = UIColor.blackColor.CGColor;
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
  
  CALayer *rootLayer = previewView.layer;
  [rootLayer setMasksToBounds:YES];
  [previewLayer setFrame:[rootLayer bounds]];
  [rootLayer addSublayer:previewLayer];
  
  [session startRunning];
}

- (void)teardownAVCapture
{
  [previewLayer removeFromSuperlayer];
}

// Provides the delegate a captured image in a processed format (such as JPEG)
// captureOutput:didOutputSampleBuffer:fromConnection: Notifies the delegate that a new video frame was written.
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CFRetain(pixelBuffer);
  [self runModelOnFrame:pixelBuffer];
  CFRelease(pixelBuffer);
}

- (void)runModelOnFrame:(CVPixelBufferRef)pixelBuffer
{
  assert(pixelBuffer != NULL);
  
  OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  
  int doReverseChannels;
  if (kCVPixelFormatType_32ARGB == sourcePixelFormat) {
    doReverseChannels = 1;
  } else if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
    doReverseChannels = 0;
  } else {
    assert(false); // Unknown source format
  }
  
  /* CVPixelBufferGetBytesPerRow
   * The number of bytes per row of the image data.
   * For planar buffers, this function returns a rowBytes value
   * such that bytesPerRow * height covers the entire image, including all planes.
   * 返回多個通道的寬度和 -> BGRA, 4個通道 -> 640 x 4 = 2560
   */
  const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer); // 2560
  const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer); // 640
  const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer); // 480
  
  CVPixelBufferLockFlags unlockFlags = kNilOptions;
  CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
  
  unsigned char *sourceBaseAddr = (unsigned char*)(CVPixelBufferGetBaseAddress(pixelBuffer));
  
  int image_height;
  unsigned char *sourceStartAddr;
  
  if (fullHeight <= image_width) {
    image_height = fullHeight;
    sourceStartAddr = sourceBaseAddr;
  } else {
    image_height = image_width;
    const int marginY = ((fullHeight - image_width) / 2);
    sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
  }
  
  const int image_channels = 4;
  assert(image_channels >= wanted_input_channels);
  uint8_t *in = sourceStartAddr;
  
  // TensorFlow Lite has a new mobile-optimized interpreter, which has the key goals of keeping apps lean and fast.
  int input = interpreter->inputs()[0];
  uint8_t *out = interpreter->typed_tensor<uint8_t>(input);
  
  for (int y = 0; y < wanted_input_height; ++y) {
    uint8_t *out_row = out + (y * wanted_input_width * wanted_input_channels);
    for (int x = 0; x < wanted_input_width; ++x) {
      const int in_x = (y * image_width) / wanted_input_width;
      const int in_y = (x * image_height) / wanted_input_height;
      uint8_t *in_pixel = in + (in_y * image_width * image_channels) + (in_x * image_channels);
      uint8_t *out_pixel = out_row + (x * wanted_input_channels);
      for (int c = 0; c < wanted_input_channels; ++c) {
        out_pixel[c] = in_pixel[c];
      }
    }
  }
  
  double startTimestamp = [[NSDate new] timeIntervalSince1970];
  if (interpreter->Invoke() != kTfLiteOk) {
    LOG(FATAL) << "Failed to invoke!";
  }
  double endTimestamp = [[NSDate new] timeIntervalSince1970];
  total_latency += (endTimestamp - startTimestamp);
  total_count += 1;
  NSLog(@"Time: %.4lf, avg: %.4lf, count: %d", endTimestamp - startTimestamp,
        total_latency / total_count, total_count);
  
  const int output_size = 1000;
  const int kNumResults = 5;
  const float kThreshold = 0.1f;
  
  std::vector<std::pair<float, int>> top_results;
  
  uint8_t *output = interpreter->typed_output_tensor<uint8_t>(0);
  GetTopN(output, output_size, kNumResults, kThreshold, &top_results);
  
  NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
  for (const auto &result : top_results) {
    const float confidence = result.first;
    const int index = result.second;
    NSString *labelObject = [NSString stringWithUTF8String:labels[index].c_str()];
    NSNumber *valueObject = [NSNumber numberWithFloat:confidence];
    [newValues setObject:valueObject forKey:labelObject];
  }
  
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    [self setPredictionValues:newValues];
  });
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)setPredictionValues:(NSDictionary *)newValues
{
  const float decayValue = 0.75f;
  const float updateValue = 0.25f;
  const float minimumThreshold = 0.01f;
  
  NSMutableDictionary* decayedPredictionValues = [[NSMutableDictionary alloc] init];
  for (NSString *label in oldPredictionValues) {
    NSNumber *oldPredictionValueObject = [oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float decayedPredictionValue = (oldPredictionValue * decayValue);
    if (decayedPredictionValue > minimumThreshold) {
      NSNumber *decayedPredictionValueObject = [NSNumber numberWithFloat:decayedPredictionValue];
      [decayedPredictionValues setObject:decayedPredictionValueObject forKey:label];
    }
  }
  oldPredictionValues = decayedPredictionValues;
  
  for (NSString *label in newValues) {
    NSNumber *newPredictionValueObject = [newValues objectForKey:label];
    NSNumber *oldPredictionValueObject = [oldPredictionValues objectForKey:label];
    if (!oldPredictionValueObject) {
      oldPredictionValueObject = [NSNumber numberWithFloat:0.0f];
    }
    const float newPredictionValue = [newPredictionValueObject floatValue];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float updatedPredictionValue = (oldPredictionValue + (newPredictionValue * updateValue));
    NSNumber *updatedPredictionValueObject = [NSNumber numberWithFloat:updatedPredictionValue];
    [oldPredictionValues setObject:updatedPredictionValueObject forKey:label];
  }
  
  NSArray *candidateLabels = [NSMutableArray array];
  for (NSString *label in oldPredictionValues) {
    NSNumber *oldPredictionValueObject = [oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    if (oldPredictionValue > 0.05f) {
      NSDictionary *entry = @{@"label" : label, @"value" : oldPredictionValueObject};
      candidateLabels = [candidateLabels arrayByAddingObject:entry];
    }
  }
  
  NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO];
  NSArray *sortedLabels =
  [candidateLabels sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
  
  const float leftMargin = 10.0f;
  const float topMargin = 10.0f;
  
  const float valueWidth = 48.0f;
  const float valueHeight = 18.0f;
  
  const float labelWidth = 246.0f;
  const float labelHeight = 18.0f;
  
  const float labelMarginX = 5.0f;
  const float labelMarginY = 5.0f;
  
  [self removeAllLabelLayers];
  
  int labelCount = 0;
  for (NSDictionary *entry in sortedLabels) {
    NSString *label = [entry objectForKey:@"label"];
    NSNumber *valueObject = [entry objectForKey:@"value"];
    const float value = [valueObject floatValue];
    const float originY = topMargin + ((labelHeight + labelMarginY) * labelCount);
    const int valuePercentage = (int)roundf(value * 100.0f);
    
    const float valueOriginX = leftMargin;
    NSString *valueText = [NSString stringWithFormat:@"%d%%", valuePercentage];
    
    [self addLabelLayerWithText:valueText
                        originX:valueOriginX
                        originY:originY
                          width:valueWidth
                         height:valueHeight
                      alignment:kCAAlignmentRight];
    
    const float labelOriginX = (leftMargin + valueWidth + labelMarginX);
    
    [self addLabelLayerWithText:[label capitalizedString]
                        originX:labelOriginX
                        originY:originY
                          width:labelWidth
                         height:labelHeight
                      alignment:kCAAlignmentLeft];
    
    labelCount += 1;
    if (labelCount > 4) {
      break;
    }
  }
  
}

- (void)removeAllLabelLayers {
  for (CATextLayer *layer in labelLayers) {
    [layer removeFromSuperlayer];
  }
  [labelLayers removeAllObjects];
  return;
}

- (void)addLabelLayerWithText:(NSString*)text
                      originX:(float)originX
                      originY:(float)originY
                        width:(float)width
                       height:(float)height
                    alignment:(NSString*)alignment {
  CFTypeRef font = (CFTypeRef) @"Menlo-Regular";
  const float fontSize = 15.0;
  const float marginSizeX = 5.0f;
  const float marginSizeY = 2.0f;
  
  const CGRect backgroundBounds = CGRectMake(originX, originY, width, height);
  const CGRect textBounds = CGRectMake((originX + marginSizeX), (originY + marginSizeY),
                                       (width - (marginSizeX * 2)), (height - (marginSizeY * 2)));
  
  CATextLayer *background = [CATextLayer layer];
  [background setBackgroundColor:[UIColor blackColor].CGColor];
  [background setOpacity:0.5f];
  [background setFrame:backgroundBounds];
  background.cornerRadius = 5.0f;
  
  [view.layer addSublayer:background];
  [labelLayers addObject:background];
  
  CATextLayer *layer = [CATextLayer layer];
  [layer setForegroundColor:[UIColor whiteColor].CGColor];
  [layer setFrame:textBounds];
  [layer setAlignmentMode:alignment];
  [layer setWrapped:YES];
  [layer setFont:font];
  [layer setFontSize:fontSize];
  layer.contentsScale = [[UIScreen mainScreen] scale];
  [layer setString:text];
  
  [view.layer addSublayer:layer];
  [labelLayers addObject:layer];
  
}
@end


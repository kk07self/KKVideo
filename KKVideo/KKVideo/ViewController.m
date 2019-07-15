//
//  ViewController.m
//  KKVideo
//
//  Created by tutu on 2019/7/15.
//  Copyright © 2019 KK. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"

@interface ViewController ()

/**
 相机
 */
@property (nonatomic, strong) GPUImageVideoCamera *camera;

/**
 预览视图
 */
@property (nonatomic, strong) GPUImageView *filterView;

/**
 pipeline
 */
@property (nonatomic, strong) GPUImageFilterPipeline *pipeline;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    _camera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _camera.horizontallyMirrorFrontFacingCamera = YES;
    
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_filterView];
    
    
    // 添加预览视图
//    [_camera addTarget:_filterView];
    [_camera startCameraCapture];
    
    // 添加滤镜
    GPUImageBrightnessFilter *bright = [[GPUImageBrightnessFilter alloc] init];
    bright.brightness = 0.5;
    [_camera addTarget:bright];
//
//    // 黑白
    GPUImageGrayscaleFilter *exposure = [[GPUImageGrayscaleFilter alloc] init];
//    [bright addTarget:exposure];
//    [exposure addTarget:_filterView];
    
    _pipeline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:nil input:_camera output:_filterView];
    [_pipeline addFilter:bright];
    [_pipeline addFilter:exposure];
}


@end

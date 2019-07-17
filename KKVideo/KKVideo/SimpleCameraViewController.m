//
//  ViewController.m
//  KKVideo
//
//  Created by tutu on 2019/7/15.
//  Copyright © 2019 KK. All rights reserved.
//

#import "SimpleCameraViewController.h"
#import "GPUImage.h"

@interface SimpleCameraViewController ()

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

/**
 back
 */
@property (nonatomic, strong) UIButton *back;

/**
 writer
 */
@property (nonatomic, strong) GPUImageMovieWriter *writer;

@end

@implementation SimpleCameraViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _back = [[UIButton alloc] initWithFrame:CGRectMake(15, 25, 40, 35)];
    [_back setTitle:@"<" forState:UIControlStateNormal];
    [_back setBackgroundColor:[UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.6]];
    [_back setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:_back];
    [_back addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    
    _camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    _camera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _camera.horizontallyMirrorFrontFacingCamera = YES;
    
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
    [self.view insertSubview:_filterView atIndex:0];
    
    NSString *path = [NSString stringWithFormat:@"%@/test001.mp4",[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];
    _writer = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:path] size:self.view.bounds.size fileType:AVFileTypeMPEG4 outputSettings:nil];
    _writer.assetWriter.movieFragmentInterval = kCMTimeInvalid;
    [_camera addTarget:_writer];
    // 添加预览视图
    [_camera addTarget:_filterView];
    [_camera startCameraCapture];
    
    // 添加滤镜
//    GPUImageBrightnessFilter *bright = [[GPUImageBrightnessFilter alloc] init];
//    bright.brightness = 0.5;
//    [_camera addTarget:bright];
//
//    // 黑白
//    GPUImageGrayscaleFilter *exposure = [[GPUImageGrayscaleFilter alloc] init];
//    [bright addTarget:exposure];
//    [exposure addTarget:_filterView];
    
//    _pipeline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:nil input:_camera output:_filterView];
//    [_pipeline addFilter:bright];
//    [_pipeline addFilter:exposure];
}

- (void)back {
    [self.navigationController popViewControllerAnimated:YES];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (_writer.paused == NO) {
        [_writer startRecording];
    } else {
        _writer.paused = YES;
    }
}

@end

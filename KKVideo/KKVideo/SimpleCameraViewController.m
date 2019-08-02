//
//  ViewController.m
//  KKVideo
//
//  Created by tutu on 2019/7/15.
//  Copyright © 2019 KK. All rights reserved.
//

#import "SimpleCameraViewController.h"
#import "GPUImage.h"
#import "AudioFile/AudioFile.h"

#define kAudioFileDirectoryBase @"com.kk.07.self"
#define kAudioFileDocumentDirectory (NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0])


@interface SimpleCameraViewController ()<GPUImageVideoCameraDelegate>

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


/**
 已录制的地址
 */
@property (nonatomic, strong) NSMutableArray *recordPaths;

/**
 录制按钮
 */
@property (nonatomic, strong) UIButton *recordButton;

/**
 完成按钮
 */
@property (nonatomic, strong) UIButton *completedButton;

@end

@implementation SimpleCameraViewController

#pragma mark - 生命周期
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)dealloc {
    if (self.camera) {
        [self.camera stopCameraCapture];
        _camera = nil;
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[AudioFile audioFile] clearAllFile];
    
    _back = [[UIButton alloc] initWithFrame:CGRectMake(15, 25, 40, 35)];
    [_back setTitle:@"<" forState:UIControlStateNormal];
    [_back setBackgroundColor:[UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.6]];
    [_back setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:_back];
    [_back addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    
    _recordButton = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width * 0.5 - 40, 25, 80, 40)];
    [_recordButton setTitle:@"开始录制" forState:UIControlStateNormal];
    [_recordButton setTitle:@"结束录制" forState:UIControlStateSelected];
    [_recordButton setBackgroundColor:[UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.6]];
    [_recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:_recordButton];
    [_recordButton addTarget:self action:@selector(record:) forControlEvents:UIControlEventTouchUpInside];
    
    _completedButton = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 100, 25, 80, 40)];
    [_completedButton setTitle:@"完成录制" forState:UIControlStateNormal];
    [_completedButton setBackgroundColor:[UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.6]];
    [_completedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:_completedButton];
    [_completedButton addTarget:self action:@selector(completedRecord:) forControlEvents:UIControlEventTouchUpInside];
    
    _camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    _camera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _camera.horizontallyMirrorFrontFacingCamera = YES;
    [_camera addAudioInputsAndOutputs];
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
    [self.view insertSubview:_filterView atIndex:0];
    
    // 添加预览视图
    [_camera addTarget:_filterView];
    [_camera addTarget:self.writer];
    _camera.audioEncodingTarget = self.writer;
//    start = CACurrentMediaTime() * 1000;
//    NSLog(@"startTime--------: %f", start);
    [_camera startCameraCapture];
    
    // 添加后台、前台切换的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackFromFront) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterFrontFromBack) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // 添加滤镜
//    GPUImageBrightnessFilter *bright = [[GPUImageBrightnessFilter alloc] init];
////    bright.brightness = 0.5;
////    [_camera addTarget:bright];
////
////    // 黑白
//    GPUImageGrayscaleFilter *exposure = [[GPUImageGrayscaleFilter alloc] init];
////    [bright addTarget:exposure];
////    [exposure addTarget:_filterView];
//
//    _pipeline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:nil input:_camera output:_filterView];
//    [_pipeline addFilter:bright];
//    [_pipeline addFilter:exposure];
}


#pragma mark - actions
// 返回
- (void)back:(UIButton *)button {
    [self.navigationController popViewControllerAnimated:YES];
}


// 录制开始、结束控制
- (void)record:(UIButton *)button {
    button.selected = !button.selected;
    if (button.selected) {
        // 开始录制
        [_camera addTarget:self.writer];
        _camera.audioEncodingTarget = self.writer;
        if (_writer.assetWriter.status != AVAssetWriterStatusWriting) {
            [_writer startRecording];
        }
    } else {
        [self completedOneRecord:nil];
    }
}

// 录制完成
- (void)completedRecord:(UIButton *)button {
    [self completedOneRecord:^{
        [self completedRecord];
    }];
}


#pragma mark - 完成录制
// 完成一次录制
- (void)completedOneRecord:(void(^)(void))completed {
    
    if (!_writer && _writer.assetWriter.status != AVAssetWriterStatusWriting) {
        if (completed) {
            completed();
        }
        return;
    }
    
    // 完成录制
    __weak typeof(self) weakSelf = self;
    [_writer finishRecordingWithCompletionHandler:^{
        NSLog(@"录制一段成功");
        [weakSelf.camera removeTarget:weakSelf.writer];
        weakSelf.writer = nil;
        if (completed) {
            completed();
        }
    }];
}

- (void)completedRecord {
    NSDictionary *optDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    //为视频类型的的Track
    AVMutableCompositionTrack *compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (NSInteger i = self.recordPaths.count - 1; i >= 0; i--) {
        NSString *obj = self.recordPaths[i];
        AVAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:obj] options:optDict];
        if (asset == nil) {
            NSLog(@"%@ --- null",obj);
            break;
        }
        //由于没有计算当前CMTime的起始位置，现在插入0的位置,所以合并出来的视频是后添加在前面，可以计算一下时间，插入到指定位置
        //CMTimeRangeMake 指定起去始位置
        AVAssetTrack *vidioAssetTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, vidioAssetTrack.timeRange.duration);
        [compositionTrack insertTimeRange:timeRange ofTrack:[asset tracksWithMediaType:AVMediaTypeVideo].firstObject atTime:kCMTimeZero error:nil];
        [audioTrack insertTimeRange:timeRange ofTrack:[asset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
    }
    
    NSString *filePath = [NSString stringWithFormat:@"%@/%@/video-com.mp4", kAudioFileDocumentDirectory,kAudioFileDirectoryBase];
    AVAssetExportSession *exporterSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    exporterSession.outputFileType = AVFileTypeMPEG4;
    exporterSession.outputURL = [NSURL fileURLWithPath:filePath]; //如果文件已存在，将造成导出失败
    exporterSession.shouldOptimizeForNetworkUse = YES; //用于互联网传输
    NSLog(@"Completed: %f", [[NSDate date] timeIntervalSince1970]);
    [exporterSession exportAsynchronouslyWithCompletionHandler:^{
        switch (exporterSession.status) {
            case AVAssetExportSessionStatusUnknown:
                NSLog(@"exporter Unknow");
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"exporter Canceled");
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"exporter Failed");
                break;
            case AVAssetExportSessionStatusWaiting:
                NSLog(@"exporter Waiting");
                NSLog(@"Waiting: %@", [NSDate date]);
                break;
            case AVAssetExportSessionStatusExporting:
                NSLog(@"exporter Exporting");
                NSLog(@"exporting: %@", [NSDate date]);
                break;
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"exporter Completed");
                NSLog(@"Completed: %f", [[NSDate date] timeIntervalSince1970]);
                break;
        }
    }];
}


#pragma mark - 前后台切换
- (void)enterBackFromFront {
    // 完成录制
    if (_writer && _writer.assetWriter.status == AVAssetWriterStatusWriting) {
        __weak typeof(self) weakSelf = self;
        _recordButton.selected = NO;
        [self completedOneRecord:^{
            [weakSelf.camera stopCameraCapture];
        }];
    } else {
        [self.camera stopCameraCapture];
    }
}

- (void)enterFrontFromBack {
    [_camera startCameraCapture];
}



#pragma mark - getter setter
- (GPUImageMovieWriter *)writer {
    if (!_writer) {
        NSString *path = [NSString stringWithFormat:@"%@/%@/video-%02ld.mp4", kAudioFileDocumentDirectory,kAudioFileDirectoryBase, self.recordPaths.count];
        [self.recordPaths addObject:path];
        NSLog(@"-------%ld", self.recordPaths.count);
        NSLog(@"-------%@", path);
        _writer = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:path] size:[self videoSize] fileType:AVFileTypeMPEG4 outputSettings:nil];
        _writer.assetWriter.movieFragmentInterval = kCMTimeInvalid;
    }
    return _writer;
}

- (CGSize)videoSize {
    return CGSizeMake(720, 1280);
}

- (NSMutableArray *)recordPaths {
    if (!_recordPaths) {
        _recordPaths = [NSMutableArray array];
    }
    return _recordPaths;
}

@end

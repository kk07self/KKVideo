//
//  AVPlayerViewController.m
//  KKVideo
//
//  Created by kk on 2019/7/29.
//  Copyright © 2019 KK. All rights reserved.
//

#import "AVPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface AVPlayerViewController ()<AVAudioPlayerDelegate>

/**
 musics
 */
@property (nonatomic, strong) NSArray *musics;

/**
 players
 */
@property (nonatomic, strong) NSMutableArray<AVAudioPlayer *> *audioPlayers;

@end

@implementation AVPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    _musics = @[@"City Sunshine",@"Eye of Forgiveness",@"Lovely Piano Song",@"Motions",@"Pickled Pink",@"Rush"];
//    _audioPlayers = [NSMutableArray arrayWithCapacity:10];
//    for (int i = 0; i < 20; i++) {
//        NSString *path = [[NSBundle mainBundle] pathForResource:_musics[i%6] ofType:@"mp3"];
//
//        NSURL *url = [NSURL fileURLWithPath:path];
//        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
//        [_audioPlayers addObject:player];
////        player.numberOfLoops = 1;
//        player.delegate = self;
//        [player prepareToPlay];
//        NSLog(@"----时长：%f", player.duration);
//    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    for (AVAudioPlayer *player in _audioPlayers) {
//        if (player.isPlaying) {
//            [player pause];
//        }
//    }
//    [_audioPlayers.firstObject play];
    
    //Obj-c
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *optDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVMutableComposition *composition = [AVMutableComposition composition];
    //为视频类型的的Track
    AVMutableCompositionTrack *compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < 10; i++) {
        AVAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:[NSString stringWithFormat:@"video-%02d", i] ofType:@"mp4"]] options:optDict];
        
        AVAssetTrack *vidioAssetTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        CMTime duration = vidioAssetTrack.timeRange.duration;
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, duration);
        CMTime beforeDuration = composition.duration;
        [compositionTrack insertTimeRange:timeRange ofTrack:vidioAssetTrack atTime:beforeDuration error:nil];
//        [audioTrack insertTimeRange:timeRange ofTrack:[asset tracksWithMediaType:AVMediaTypeAudio][0] atTime:beforeDuration error:nil];
    }
 
    
    
    
//    AVAsset *secondAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:@"video-01" ofType:@"mp4"]] options:optDict];
//    AVAsset *thirdAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:@"video-02" ofType:@"mp4"]] options:optDict];
//    AVAsset *fouthdAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:@"video-03" ofType:@"mp4"]] options:optDict];
//    AVAsset *fifthdAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:@"video-04" ofType:@"mp4"]] options:optDict];
//    AVAsset *sixAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:[mainBundle pathForResource:@"video-05" ofType:@"mp4"]] options:optDict];
//
//
//
//    //由于没有计算当前CMTime的起始位置，现在插入0的位置,所以合并出来的视频是后添加在前面，可以计算一下时间，插入到指定位置
//    //CMTimeRangeMake 指定起去始位置
//    CMTimeRange firstTimeRange = CMTimeRangeMake(kCMTimeZero, firstAsset.duration);
//    CMTimeRange secondTimeRange = CMTimeRangeMake(kCMTimeZero, secondAsset.duration);
//    CMTimeRange thirdTimeRange = CMTimeRangeMake(kCMTimeZero, thirdAsset.duration);
//    CMTimeRange fouthTimeRange = CMTimeRangeMake(kCMTimeZero, fouthdAsset.duration);
//    CMTimeRange fifthTimeRange = CMTimeRangeMake(kCMTimeZero, fifthdAsset.duration);
//    CMTimeRange sixthTimeRange = CMTimeRangeMake(kCMTimeZero, sixAsset.duration);
//
//    [compositionTrack insertTimeRange:firstTimeRange ofTrack:[firstAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
//    [compositionTrack insertTimeRange:secondTimeRange ofTrack:[secondAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
//    [compositionTrack insertTimeRange:thirdTimeRange ofTrack:[thirdAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
//    [compositionTrack insertTimeRange:fouthTimeRange ofTrack:[fouthdAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
//    [compositionTrack insertTimeRange:fifthTimeRange ofTrack:[fifthdAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];
//    [compositionTrack insertTimeRange:sixthTimeRange ofTrack:[sixAsset tracksWithMediaType:AVMediaTypeVideo][0] atTime:kCMTimeZero error:nil];

    //只合并视频，导出后声音会消失，所以需要把声音插入到混淆器中
    //添加音频,添加本地其他音乐也可以,与视频一致
//
//    [audioTrack insertTimeRange:secondTimeRange ofTrack:[firstAsset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
//    [audioTrack insertTimeRange:firstTimeRange ofTrack:[firstAsset tracksWithMediaType:AVMediaTypeAudio][0] atTime:kCMTimeZero error:nil];
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *filePath = [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"com-%ld.mp4", (NSInteger)[[NSDate date] timeIntervalSince1970]]];
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

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSInteger index = [_audioPlayers indexOfObject:player];
    NSLog(@"----已播放：%ld", index);
    [_audioPlayers[(index+1)%_audioPlayers.count] play];
}

@end

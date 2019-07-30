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
    
    _musics = @[@"City Sunshine",@"Eye of Forgiveness",@"Lovely Piano Song",@"Motions",@"Pickled Pink",@"Rush"];
    _audioPlayers = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 20; i++) {
        NSString *path = [[NSBundle mainBundle] pathForResource:_musics[i%6] ofType:@"mp3"];
        
        NSURL *url = [NSURL fileURLWithPath:path];
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        [_audioPlayers addObject:player];
//        player.numberOfLoops = 1;
        player.delegate = self;
        [player prepareToPlay];
        NSLog(@"----时长：%f", player.duration);
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (AVAudioPlayer *player in _audioPlayers) {
        if (player.isPlaying) {
            [player pause];
        }
    }
    [_audioPlayers.firstObject play];
    
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSInteger index = [_audioPlayers indexOfObject:player];
    NSLog(@"----已播放：%ld", index);
    [_audioPlayers[(index+1)%_audioPlayers.count] play];
}

@end

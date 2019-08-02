//
//  RecordMovieWriter.m
//  KKVideo
//
//  Created by kk on 2019/8/2.
//  Copyright © 2019 KK. All rights reserved.
//

#import "RecordMovieWriter.h"

@interface RecordMovieWriter()

/**
 是否可以音频写入
 */
@property (nonatomic, assign) BOOL allowAudioInput;

@end

@implementation RecordMovieWriter

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;
{
    if (!_allowAudioInput) {
        return;
    }
}

@end

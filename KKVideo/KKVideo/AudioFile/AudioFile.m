//
//  AudioFile.m
//  01-AudioRecord
//
//  Created by tutu on 2019/6/18.
//  Copyright © 2019 KK. All rights reserved.
//

#import "AudioFile.h"

#define kAudioFileDirectoryBase @"com.kk.07.self"
#define kAudioFileDocumentDirectory (NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0])

@interface AudioFile()

/**
 文件夹
 */
@property (nonatomic, strong) NSString *directoryPath;

/**
 fileHandles
 */
@property (nonatomic, strong) NSMutableDictionary *fileHandles;

@end

static AudioFile *_audioFile;

@implementation AudioFile

+ (AudioFile *)audioFile {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _audioFile = [[AudioFile alloc] init];
        [_audioFile clearNoDataFile];
    });
    return _audioFile;
}

- (void)clearNoDataFile {
    NSMutableArray *needClearFiles = [NSMutableArray arrayWithCapacity:10];
    [[self allAudioFiles] enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSData *data = [NSData dataWithContentsOfFile:obj];
        if (data == nil || data.length == 0) {
            [needClearFiles addObject:obj];
        }
    }];
    
    [needClearFiles enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [NSFileManager.defaultManager removeItemAtPath:obj error:nil];
    }];
}

- (void)clearAllFile {
    [[self allAudioFiles] enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [NSFileManager.defaultManager removeItemAtPath:obj error:nil];
    }];
}


#pragma mark - 文件操作

- (BOOL)checkAudioFile:(NSString *)audioFile {
    if ([NSFileManager.defaultManager fileExistsAtPath:audioFile]) {
        return YES;
    }
    return NO;
}

- (BOOL)checkAudioFileWithFileName:(NSString *)fileName {
    return [self checkAudioFileWithFileName:[NSString stringWithFormat:@"%@/%@", self.directoryPath, fileName]];
}


- (NSString *)createAudioFile:(NSString *)fileName {
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", self.directoryPath, fileName];
    if (![NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        [NSFileManager.defaultManager createFileAtPath:filePath contents:NULL attributes:NULL];
    }
    return filePath;
}

- (NSString *)fileNameFromAudioFile:(NSString *)audioFile {
    return [[audioFile componentsSeparatedByString:@"/"] lastObject];
}

- (NSFileHandle *)createFileHandleWithFileName:(NSString *)fileName {
    return [self createFileHandleWithAudioFilePath:[self createAudioFile:fileName]];
}

- (NSFileHandle *)createFileHandleWithAudioFilePath:(NSString *)audioFile {
    if (audioFile == nil) {
        return nil;
    }
    NSFileHandle *fileHandle = [self.fileHandles objectForKey:audioFile];
    if (!fileHandle) {
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
        [self.fileHandles setObject:fileHandle forKey:audioFile];
    }
    return fileHandle;
}


- (NSInteger)countOfFileType:(NSString *)fileType {
    __block NSInteger count = 0;
    [[self allAudioFiles] enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj containsString:fileType]) {
            count += 1;
        }
    }];
    return count;
}


- (NSString *)directoryPath {
    if (!_directoryPath) {
        _directoryPath = [NSString stringWithFormat:@"%@/%@", kAudioFileDocumentDirectory, kAudioFileDirectoryBase];
        if (![NSFileManager.defaultManager fileExistsAtPath:_directoryPath]) {
            [NSFileManager.defaultManager createDirectoryAtPath:_directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _directoryPath;
}



- (NSArray *)allAudioFiles {
    NSArray *fileNames = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:fileNames.count];
    [fileNames enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [files addObject:[self createAudioFile:obj]];
    }];
    return files;
}

- (NSMutableDictionary *)fileHandles {
    if (!_fileHandles) {
        _fileHandles = [NSMutableDictionary dictionary];
    }
    return _fileHandles;
}

@end

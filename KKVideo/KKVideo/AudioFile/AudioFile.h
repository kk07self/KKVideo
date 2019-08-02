//
//  AudioFile.h
//  01-AudioRecord
//
//  Created by tutu on 2019/6/18.
//  Copyright © 2019 KK. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioFile : NSObject


/**
 audioFile 单例管理器

 @return 单例
 */
+ (AudioFile *)audioFile;


/**
 清除没有数据的文件
 */
- (void)clearNoDataFile;

- (void)clearAllFile;

/**
 查看是否已经有改文件路径

 @param audioFile 音频文件路径
 @return 是否有
 */
- (BOOL)checkAudioFile:(NSString *)audioFile;


/**
 查看当前目录下是否有该文件

 @param fileName 文件名
 @return 是否有
 */
- (BOOL)checkAudioFileWithFileName:(NSString *)fileName;

/**
 创建一个文件路径

 @param fileName 文件名称
 @return 文件全路径
 */
- (NSString *)createAudioFile:(NSString *)fileName;


/**
 根据文件全路径获取文件名

 @param audioFile 文件全路径
 @return 文件名
 */
- (NSString *)fileNameFromAudioFile:(NSString *)audioFile;


/**
 创建文件操作器

 @param audioFile 文件全路径
 @return 文件操作器
 */
- (NSFileHandle *)createFileHandleWithAudioFilePath:(NSString *)audioFile;


/**
 创建文件操作器

 @param fileName 文件名称
 @return 文件操作器
 */
- (NSFileHandle *)createFileHandleWithFileName:(NSString *)fileName;



/**
 获取指定文件类型的文件数量

 @param fileType 文件类型
 @return 此类型的文件数量
 */
- (NSInteger)countOfFileType:(NSString *)fileType;


/**
 获取文件夹下所有的文件路径列表

 @return 文件路径列表
 */
- (NSArray *)allAudioFiles;

@end

NS_ASSUME_NONNULL_END

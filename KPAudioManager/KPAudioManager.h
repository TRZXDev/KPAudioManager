//
//  KPAudioManager.h
//  TRZX
//
//  Created by 移动微 on 17/1/4.
//  Copyright © 2017年 Tiancaila. All rights reserved.
//

#import <Foundation/Foundation.h>
#define kRecordAudioFile @"myAnswerRecord.mp3"
#import <UIKit/UIKit.h>

/**
 音频播放
 */
typedef void(^PlayingBlock)();

/**
 音频结束
 */
typedef void(^PlayEndBlock)();

/**
 监测语音输入力度

 @param power 力度数值
 */
typedef void(^AudioPowerBlock)(CGFloat power,NSString *timeStr);


/**
 音频录制结束

 @param recordTime 录制时间
 */
typedef void(^RecordEndBlock)(NSString *recordTime);

/**
 投融在线 音频管理者 : 主要提供 音频的录制和播放
 */
@interface KPAudioManager : NSObject

+(KPAudioManager *) sharedInstance;

#pragma mark - 音频录制
/**
 开始音频录制
 */
+(void)recordingStartAudioPower:(AudioPowerBlock)audioPower RecordEnd:(RecordEndBlock)recordEnd;

/**
 停止音频录制
 */
+(void)recordingStop;

/**
 重新录制
 */
+(void)recordingAgain;

/**
 录制音频的本地地址

 @return 本地音频路径
 */
+(NSString *)recordingLocalURL;


#pragma mark - 音频播放
/**
 语音播放

 @param url          URL地址     如果需要播放录制好的本地音频请传入:KPAudioLocalURL
 @param playingBlock 播放中Block
 */
+(void) audioPlayWithURL:(NSString *)url PlayingBlock:(PlayingBlock)playingBlock PlayEndBlock:(PlayEndBlock)playEndBlock;

/**
 停止语音播放
 */
+(void) audioStop;

/**
 暂停语音播放
 */
+(void) audioPause;

/**
 恢复语音播放
 */
+(void) audioResume;

@end

/**
 播放结束通知
 */
//extern NSString *const KPlayerEnd;
/**
 本地录制好的 URL 地址
 */
extern NSString *const KPAudioLocalURL;
extern NSString *const kKPAudioStartPlay;

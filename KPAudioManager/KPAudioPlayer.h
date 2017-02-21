//
//  KPAudioPlayer.h
//  KPAudioTest
//
//  Created by 移动微 on 17/1/13.
//  Copyright © 2017年 移动微. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "KPAudioBasicInfo.h"
//// 音频播放器的几种状态
//typedef NS_ENUM(NSInteger , KPAudioPlayerState){
//    KPAudioPlayerStateBuffering = 1,            // 缓冲
//    KPAudioPlayerStatePlaying   = 2,            // 播放中
//    KPAudioPlayerStateStopped   = 3,            // 停止
//    KPAudioPlayerStatePause     = 4,            // 暂停
//};

/// 播放器状态
typedef NS_ENUM(NSInteger , KPAudioPlayerStatus){
    KPAudioPlayerStatusNon ,                // 空
    KPAudioPlayerStatusLoadSongInfo,        // 正在加载
    KPAudioPlayerStatusReadyToPlay,         // 准备
    KPAudioPlayerStatusPlay,                // 播放中
    KPAudioPlayerStatusPause,               // 暂停  --  可以继续
    KPAudioPlayerStatusStop,                // 停止  --  无法继续
};

/// 播放模式
typedef NS_ENUM(NSInteger , KPAudioPlayerModel){
    KPAudioPlayerModelNormal,                       // 正常播放
    KPAudioPlayerModelRepeatSingle,                 // 单曲循环
};


/**
 音频播放器
 */
@interface KPAudioPlayer : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) KPAudioPlayerStatus status;
@property (nonatomic, readonly) CGFloat             loadedProgress;     //缓冲进度
/**
 视频总时间
 */
@property (nonatomic, readonly) CGFloat             playDuration;
/**
 已播放时长
 */
@property (nonatomic, readonly) CGFloat             playTime;
/**
 缓冲时长
 */
@property (nonatomic, readonly) CGFloat             tmpTime;

/**
 当前播放时间
 */
@property (nonatomic, readonly) CGFloat             current;
/**
 播放进度 进度 0 ~ 1
 */
@property (nonatomic, readonly) CGFloat             progress;
/**
 强引用控制器 防止被销毁
 */
@property (nonatomic, readonly) UIViewController    *currentViewController;
/**
 当前控制器的编号, 防止控制器重复加载
 */
@property (nonatomic, readonly) NSString            *currentIdentify;

@property (nonatomic, readonly) AVPlayer            *player;

@property (nonatomic)           BOOL                stopWhenAppDidEnterBackground; // default is YES

@property (nonatomic, copy) void (^playEndConsul)();

/**
 播放

 @param url 音频地址URL
 */
- (void)playWithURL:(NSURL *)url;
//- (void)seekToTime:(CGFloat)seconds;

- (void)play:(NSURL *)audioURL callBack:(void (^)(CGFloat tmpProgress , CGFloat playProgress))callBack;


/**
 下一个音频
 */
- (void)next;

/**
 上一个音频
 */
- (void)previous;

/**
 恢复
 */
- (void)resume;

/**
 暂停 - 可继续
 */
- (void)pause;

/**
 停止 - 无法继续
 */
- (void)stop;

/**
 重播
 */
- (void)rebroadcast;

/**
 设置歌曲状态改变时的回调
 */
- (void)setStateChangeCallBack:(void (^)(KPAudioPlayerStatus state))callBack;

/**
 获取歌曲缓冲文件夹大小

 @return 返回值大小单位 : KB
 */
- (CGFloat)getAudioDirSize;

/**
 清空歌曲缓冲文件夹
 */
- (void)clearAudioDir;

@end


//MARK: - 常驻后台
/*
 *  原理：1. 向系统申请3分钟后台权限
 *       2. 3分钟快到期时，播放一段极短的空白音乐
 *       3. 播放结束之后，又有了3分钟的后台权限
 *
 *  备注：1. 其他音乐类App在播放时，无法被我们的空白音乐打断。如果3分钟内音乐未结束，我们的App会被真正挂起
 *       2. 其他音乐未播放时，我们的空白音乐有可能调起 - AVAudioSession进行控制
 */
@interface KPBackgroundTask : NSObject

/**
 需要在 - func applicationDidEnterBackground(application: UIApplication) 方法中调用
 */
- (void)fire;

@end

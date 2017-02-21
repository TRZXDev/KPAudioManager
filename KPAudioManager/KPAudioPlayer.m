//
//  KPAudioPlayer.m
//  KPAudioTest
//
//  Created by 移动微 on 17/1/13.
//  Copyright © 2017年 移动微. All rights reserved.
//
/// TODO : 断电下载 , 线程优化 , 支持流音频播放
#import "KPAudioPlayer.h"
#import "KPAudioRequestTask.h"
#import "KPRequestLoader.h"
#import "KPAudioBasicInfo.h"
#import "KPRequestLoader.h"
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

#define IOS_VERSION  ([[[UIDevice currentDevice] systemVersion] floatValue])
NSString *const kKPAudioPlayerStateChangedNotification      = @"kKPAudioPlayerStateChangedNotification";
NSString *const kKPAudioPlayerProgressChangedNotification   = @"kKPAudioPlayerProgressChangedNotification";
NSString *const kKPAudioPlayerLoadProgressChangedNotification = @"kKPAudioPlayerLoadProgressChangedNotification";

// OBJC_Associate KEY
NSString *const kPlayerItemKVOSwich = @"kPlayerItemKVOSwich";


/// 状态管理block
typedef void(^statusManagerBlock)(KPAudioPlayerStatus status);

typedef void(^playEndConsul)();

typedef void(^progressCallBack)(CGFloat tmpProgress , CGFloat playProgress);

@interface KPAudioPlayer ()
/**
 获取当前 URL
 */
@property (nonatomic, strong)   NSURL                               *currentURL;

@property (nonatomic, strong)   NSMutableArray <NSURL *>            *audioURLList;
/**
 当前下标
 */
@property (nonatomic, assign)   NSUInteger                          currentIndex;

@property (nonatomic, assign)   CGFloat                             tmpTime;

@property (nonatomic, strong)   AVPlayer                            *player;

@property (nonatomic, strong)   UIViewController                    *currentViewController;

@property (nonatomic, strong)   AVPlayerItem                        *currentItem;

@property (nonatomic, copy)     NSString                            *currentIdentify;

@property (nonatomic, assign)   KPAudioPlayerStatus                 status;

@property (nonatomic, strong)   NSMutableArray <statusManagerBlock> *stateChangeHandlerArray;

@property (nonatomic, assign)   CGFloat                             progress;

@property (nonatomic, assign)   CGFloat                             playDuration;

@property (nonatomic, assign)   CGFloat                             playTime;

@property (nonatomic, assign)   BOOL                                isLocationAudio;

@property (nonatomic, strong)   KPRequestLoader                     *resourceLoader;

@property (nonatomic, strong)   NSObject                            *playerStatusObserver;

@property (nonatomic, strong)   AVURLAsset                          *currentAsset;

//@property (nonatomic, strong)   KPAudioBasicInfo                    *audioInfo;

@property (nonatomic, copy)     progressCallBack                    progressCallBack;

@property (nonatomic, assign)   KPAudioPlayerModel                  playerModel;

@end

@implementation KPAudioPlayer

+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    static KPAudioPlayer *instance;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.playerModel = KPAudioPlayerModelNormal;
    }
    return self;
}

#pragma mark - Public Mehtod
/**
 播放语音
 */
- (void)playWithURL:(NSURL *)url{
    if (!url) {
        return;
    }
    
    NSInteger index = [self getIndexOfAudio:url];
    if (index) {
        self.currentIndex = index;
    }else{
        [self putAudioToArray:url];
        self.currentIndex = 0;
    }
    
    [self playAudioWithCurrentIndex];
//    [self configNowPlayingCenter];
    [self configAudioSession];
    [self configBreakObserver];
}

- (void)play:(NSURL *)audioURL callBack:(void (^)(CGFloat tmpProgress , CGFloat playProgress))callBack{
    [self playWithURL:audioURL];
    self.progressCallBack = callBack;
}

/**
 播放下一个音频
 */
- (void)next{
    self.currentIndex = [self getNextIndex];
    [self playAudioWithCurrentIndex];
}

/**
 上一个音频
 */
- (void)previous{
    self.currentIndex = [self getPreviousIndex];
    [self playAudioWithCurrentIndex];
}

/**
 恢复
 */
- (void)resume{
    self.player.rate = 0;
//    [self configNowPlayingCenter];
}

/**
 暂停 - 可继续
 */
- (void)pause{
    self.player.rate = 0;
//    [self configNowPlayingCenter];
}

/**
 停止 - 无法继续
 */
- (void)stop{
    [self endPlay];
//    self.audioInfo = nil;
//    [self configNowPlayingCenter];
}

/**
 重播
 */
- (void)rebroadcast{
    if (self.status == KPAudioPlayerStatusPlay) {
        [self.player seekToTime:kCMTimeZero];
    }
}

/**
 设置歌曲状态改变时的回调
 */
- (void)setStateChangeCallBack:(void (^)(KPAudioPlayerStatus state))callBack{
    id block = callBack;
    if (self.stateChangeHandlerArray != nil) {
        [self.stateChangeHandlerArray addObject:block];
    }else{
        self.stateChangeHandlerArray = [NSMutableArray array];
        [self.stateChangeHandlerArray addObject:block];
    }
}

/**
 获取歌曲缓冲文件夹大小
 
 @return 返回值大小单位 : KB
 */
- (CGFloat)getAudioDirSize{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    CGFloat size = 0;
    if ([fileManager contentsOfDirectoryAtPath:[KPAudioBasicInfo streamAudioConfig_audioDicPath]  error:nil]) {
        NSArray<NSString *> *fileArray = [fileManager contentsOfDirectoryAtPath:[KPAudioBasicInfo streamAudioConfig_audioDicPath]  error:nil];
        for (NSString *component in fileArray) {
            if ([component containsString:@"temp.mp3"]) {
                NSString *fullPath = [NSString stringWithFormat:@"%@/%@",[KPAudioBasicInfo streamAudioConfig_audioDicPath],component];
                if ([fileManager fileExistsAtPath:fullPath]) {
                    NSDictionary *fileAttributeDic = [fileManager attributesOfItemAtPath:fullPath error:nil];
                    CGFloat fileSize = [fileAttributeDic[@"NSFileSize"] floatValue] ? : 0;
                    size += (fileSize / 1024);
                }
            }
        }
    }
    
    return size;
}

/**
 清空歌曲缓冲文件夹
 */
- (void)clearAudioDir{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager contentsOfDirectoryAtPath:[KPAudioBasicInfo streamAudioConfig_audioDicPath]  error:nil]) {
        return ;
    }
    
    NSArray *fileArray = [fileManager contentsOfDirectoryAtPath:[KPAudioBasicInfo streamAudioConfig_audioDicPath]  error:nil];
    for (NSString *component in fileArray) {
        if ([component containsString:@"temp.mp3"]) {
            NSString *fullPath = [NSString stringWithFormat:@"%@/%@",[KPAudioBasicInfo streamAudioConfig_audioDicPath],component];
            if ([fileManager fileExistsAtPath:fullPath]) {
                @try {
                    [fileManager removeItemAtPath:fullPath error:nil];
                } @catch (NSException *exception) {
                    NSLog(@"音频数据移除失败 路径 : %@",fullPath);
                }
            }
        }
    }
}

#pragma mark - Private Mehtod
/**
 获取下一音频下标
 */
- (NSInteger)getNextIndex{
    if (self.audioURLList.count > 0) {
        if (self.currentIndex + 1 < self.audioURLList.count) {
            return self.currentIndex + 1;
        }else{
            return 0;
        }
    }else{
        return 0;
    }
}

/**
 获取上一个音频下标
 */
- (NSInteger)getPreviousIndex{
    NSInteger previousIndex = self.currentIndex - 1;
    if (previousIndex >= 0) {
        return previousIndex;
    } else {
        return self.audioURLList.count ? : 1;
    }
}

/**
 从头开始播放音频
 */
- (void)replayAudioList{
    if (self.audioURLList.count == 0) {
        return ;
    }
    self.currentIndex = 0;
    [self playAudioWithCurrentIndex];
}

/**
 播放当前音乐
 */
- (void)playAudioWithCurrentIndex{
    if (self.currentURL == nil) {
        return;
    }
    
    // 结束上一首
    [self endPlay];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:[self getPlayerItemWithURL:self.currentURL]];
    
    self.player = player;
    [self observePlayingItem];
}

/**
 设置Player

 @param audioURL 音频URL
 */
- (void)setupPlayerWithURL:(NSURL *)audioURL{
    AVPlayerItem *songItem = [self getPlayerItemWithURL:audioURL];
    self.player = [AVPlayer playerWithPlayerItem:songItem];
}

/**
 播放
 */
- (void)playerPlay{
    [self.player play];
}

/**
 结束上一首
 */
- (void)endPlay{
    
    
//    if (self || self.player == nil) {
//        return;
//    }
    [self.player pause];
    self.status = KPAudioPlayerStatusStop;
    self.player.rate = 0;
    [self removeObserForPlayingItem];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [self.resourceLoader cancel];
    [self.currentAsset.resourceLoader setDelegate:nil queue:nil];
    self.progressCallBack = nil;
    self.resourceLoader = nil;
    [self resourceLoader];
//    [[KPRequestLoader alloc] init];
    self.playDuration = 0;
    self.playTime = 0;
    if(self.playEndConsul){
        self.playEndConsul();
    }
    self.player = nil;
    
    self.currentViewController = nil;
    self.currentIdentify = nil;
}

/**
 插入音频文件URL到数组
 */
- (void)putAudioToArray:(NSURL *)audioURL{
    if (self.audioURLList == nil) {
        self.audioURLList = [NSMutableArray array];
    }
    [self.audioURLList insertObject:audioURL atIndex:0];
}

/**
 根据音频url获取数组中的下标

 @param audioURL 音频URL
 */
- (NSInteger)getIndexOfAudio:(NSURL *)audioURL{
    if (![self.audioURLList containsObject:audioURL]) {
        return 0;
    }
    NSInteger index = [self.audioURLList indexOfObject:audioURL];
    return index;
}

//- (void)configNowPlayingCenter{
//    
//    NSMutableDictionary *info = [NSMutableDictionary dictionary];
//    if (self.audioInfo) {
//        [info setValue:self.audioInfo.title forKey:MPMediaItemPropertyTitle];
//        [info setValue:self.audioInfo.artist forKey:MPMediaItemPropertyArtist];
//        // 设置播放图片
//        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.audioInfo.converImage];
//        // 设置屏幕界面
//        [info setValue:artwork forKey:MPMediaItemPropertyArtwork];
//    }
//    // 当前播放时间
//    [info setValue:@(self.playTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
//    // 播放比率 速度
//    [info setValue:@(self.player.rate) forKey:MPNowPlayingInfoPropertyDefaultPlaybackRate];
//    // 总时长
//    [info setValue:@(self.playDuration) forKey:MPMediaItemPropertyPlaybackDuration];
//    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
//}

/// 获取本地文件
- (NSURL *)getlocationFilePath:(NSURL *)url{
    if ([url.absoluteString containsString:@"file://"]) {
        return url;
    }else{
        NSString *fileName = [url lastPathComponent];
        NSString *path = [NSString stringWithFormat:@"%@/%@",[KPAudioBasicInfo streamAudioConfig_audioDicPath],fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSURL *url= [[NSURL alloc] initFileURLWithPath:path];
            return url;
        }else{
            return nil;
        }
    }
}

/**
 用URL获取PlayerItem
 
 @param audioURL 音频URL
 */
- (AVPlayerItem *)getPlayerItemWithURL:(NSURL *)audioURL{
    if ([self getlocationFilePath:audioURL]) {
        // 本地音频
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[self getlocationFilePath:audioURL]];
        self.isLocationAudio = YES;
        return item;
    } else {
        // 不是本地音频
        NSURL *playURL = [self.resourceLoader getSchemeAudioURL:audioURL]; // 转换协议头
        AVURLAsset *asset = [AVURLAsset assetWithURL:playURL];
        self.isLocationAudio = NO;
        self.currentAsset = asset;
        self.status = KPAudioPlayerStatusLoadSongInfo;
        [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
        return item;
    }
}

#pragma mark - Observer for palyer status
/**
  KVO
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    // 1.判断是否是 AVPlayerItem
    if (![object isKindOfClass:[AVPlayerItem class]]){
        return;
    }
    
    AVPlayerItem *item = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"status"]) {
        if (item.status == AVPlayerItemStatusReadyToPlay) {
            self.status = KPAudioPlayerStatusReadyToPlay;
            [self playerPlay];
        }else if(item.status == AVPlayerItemStatusFailed){
            [self stop];
        }
    }else if([keyPath isEqualToString:@"loadedTimeRanges"]){
        NSArray<NSValue *> *array = item.loadedTimeRanges;
        if (!array.firstObject) {
            return;
        }
        // 缓冲时间范围
        CMTimeRange timeRange = array.firstObject.CMTimeRangeValue;
        // 当前缓冲长度
        CGFloat totalBuffer =  CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
        self.tmpTime = totalBuffer;
        
        CGFloat tmpProgress = self.tmpTime / self.playDuration;
        if (self.progressCallBack) {
            self.progressCallBack(tmpProgress,0);
        }
    }
}

/**
 观察播放中的对象
 */
- (void)observePlayingItem{
    
    if (self.player.currentItem == nil) {
        return ;
    }
    AVPlayerItem *currentItem = self.player.currentItem;
    
    // 监听player播放情况
    __weak __typeof(self) weakSelf = self;
    self.playerStatusObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) usingBlock:^(CMTime time) {
        
        // 获取当前播放时间
        weakSelf.status = KPAudioPlayerStatusPlay;
        CGFloat currentTime = CMTimeGetSeconds(time);
        CGFloat totalTime = CMTimeGetSeconds(currentItem.duration);
        weakSelf.playDuration = totalTime;
        weakSelf.playTime = currentTime;
        CGFloat tmpProgress = weakSelf.isLocationAudio ? 1 : 0; // 本地播放中 , 则返回tmp 进度
        if (weakSelf.progressCallBack) {
            weakSelf.progressCallBack(tmpProgress, weakSelf.progress);
        }
        if (totalTime - currentTime < 0.1) {
            [weakSelf dealForEnded];
        }
    }];
    
    // KVO监听正在播放的对象状态变化
    [currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options: NSKeyValueObservingOptionNew context:nil];
    objc_setAssociatedObject(currentItem, (__bridge const void *)(kPlayerItemKVOSwich), @(YES), OBJC_ASSOCIATION_ASSIGN);
}

- (void)removeObserForPlayingItem{
    if (!self.player.currentItem) {
        return;
    }
    
    if (self.playerStatusObserver != nil) {
//        [self.player removeTimeObserver:self.playerStatusObserver];
        self.playerStatusObserver = nil;
    }
    if (objc_getAssociatedObject(self.player.currentItem, (__bridge const void *)kPlayerItemKVOSwich)) {
        id objc = objc_getAssociatedObject(self.player.currentItem, (__bridge const void *)kPlayerItemKVOSwich);
        if ([objc boolValue]) {
            [self.player.currentItem removeObserver:self forKeyPath:@"status"];
            [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        }
    }
    if (self.player.currentItem) {
        objc_setAssociatedObject(self.player.currentItem, (__bridge const void *)(kPlayerItemKVOSwich), @(NO), OBJC_ASSOCIATION_ASSIGN);
    }
}

/**
 结束播放状态
 */
- (void)dealForEnded{
    switch (self.playerModel) {
        case KPAudioPlayerModelNormal:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self endPlay];
            });
        }
            break;
        case KPAudioPlayerModelRepeatSingle:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rebroadcast];
            });
        }
            break;
        default:
            break;
    }
}

#pragma mark - For AVAudioSession
/**
 配置音频会话
 */
- (void)configAudioSession{
    @try {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    } @catch (NSException *exception) {
        NSLog(@"KPAudiohPlayer 音频启动后台模式失败 : %@",exception);
    }
}

/**
 监听打断
 */
- (void)configBreakObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
}

/**
 来电打断
 */
- (void)handleInterruption:(NSNotification *)noti{
    if (![noti.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        return ;
    }
    
    NSDictionary *info = noti.userInfo;
    NSInteger typeNumber = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    //AVAudioSessionInterruptionType
    switch (typeNumber) {
        case AVAudioSessionInterruptionTypeBegan:{
            [self pause];
        }
            break;
        case AVAudioSessionInterruptionTypeEnded:{
            [self resume];
        }
            break;
        default:
            break;
    }
}

/**
 拔出耳机等设备变更操作
 */
- (void)handleRouteChange:(NSNotification *)noti{
    
    if (![noti.name isEqualToString:AVAudioSessionRouteChangeNotification]) {
        return ;
    }
    NSDictionary *info = noti.userInfo;
    NSInteger typeNumber = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    //AVAudioSessionRouteChangeReason
    switch (typeNumber) {
        case AVAudioSessionRouteChangeReasonUnknown:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonOverride:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:{
            
        }
            break;
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:{
            
        }
            break;
        default:
            break;
    }
}

#pragma mark - Properties Getter
- (NSURL *)currentURL{
    if (self.currentIndex < self.audioURLList.count) {
        return self.audioURLList[self.currentIndex];
    }
    return nil;
}

- (AVPlayerItem *)currentItem{
    if (self.currentURL) {
        _currentItem = [self getPlayerItemWithURL:self.currentURL];
        return _currentItem;
    }
    return nil;
}

- (KPRequestLoader *)resourceLoader{
    if (!_resourceLoader) {
        _resourceLoader = [[KPRequestLoader alloc] init];
        
        __weak __typeof(self) weakSelf = self;
        [_resourceLoader setDidFinishLoadingWithTask:^(KPAudioRequestTask *task) {
            NSLog(@"下载完成 : %@",task);
        }];
        
        [_resourceLoader setFinishLoadingHandler:^(KPAudioRequestTask *task, NSUInteger errorCode) {
           
        }];
        
        [_resourceLoader setDidFailLoadingWithTask:^(KPAudioRequestTask *task) {
            
            NSLog(@"下载失败 : %@",task);
        }];
        
        [_resourceLoader setDidReceiveAudioInfoHandler:^(KPAudioRequestTask *task, NSUInteger audioLength, NSString *mimeType) {
            
            NSLog(@"获取到信息 : %@ -- 音频长度 : %lu -- 音频类型 : %@",task , (unsigned long)audioLength,mimeType);
        }];
    }
    return _resourceLoader;
}

/// 播放进度
- (CGFloat)progress{
    if (self.playDuration > 0) {
        return self.playTime / self.playDuration;
    }else{
        return 0;
    }
}

#pragma mark - Properties Setter
/// 音频播放状态, 用于需要获取播放器状态的地方KVO
- (void)setStatus:(KPAudioPlayerStatus)status{
    if (_status != status) {
        _status = status;
        if (!self.stateChangeHandlerArray.count) {
            return;
        }
        for (statusManagerBlock block in self.stateChangeHandlerArray) {
            block(status);
        }
    }
}

/// 总时长
- (void)setPlayDuration:(CGFloat)playDuration{
    if (_playDuration != playDuration) {
        _playDuration = playDuration;
//        [self configNowPlayingCenter];
    }
}

@end

typedef void (^remainingBlock)(NSTimeInterval remainingTime);

//MARK: - 常驻后台
/*
 *  原理：1. 向系统申请3分钟后台权限
 *       2. 3分钟快到期时，播放一段极短的空白音乐
 *       3. 播放结束之后，又有了3分钟的后台权限
 *
 *  备注：1. 其他音乐类App在播放时，无法被我们的空白音乐打断。如果3分钟内音乐未结束，我们的App会被真正挂起
 *       2. 其他音乐未播放时，我们的空白音乐有可能调起 - AVAudioSession进行控制
 */
@implementation KPBackgroundTask

    static NSTimer *_counter;

    static UIBackgroundTaskIdentifier _taskId;

    static remainingBlock _remainingTimeHandler;

    static id _remainTimeRange;

    static double _remainTimaMax;

/**
 需要在 - func applicationDidEnterBackground(application: UIApplication) 方法中调用
 */
- (void)fire{
    
}

@end


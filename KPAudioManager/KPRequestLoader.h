//
//  KPRequestLoader.h
//  KPAudioTest
//
//  Created by 移动微 on 17/1/16.
//  Copyright © 2017年 移动微. All rights reserved.
//

/// 负责给播放器提供所需的音频片段, 已经联系KPAudioRequestTask向服务器索要数据
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class KPAudioRequestTask;
@interface KPRequestLoader : NSObject<AVAssetResourceLoaderDelegate>

@property (nonatomic, strong)   KPAudioRequestTask          *task;
/**
 下载结果回调
 */
@property (nonatomic, copy)     void(^finishLoadingHandler)(KPAudioRequestTask *task , NSUInteger errorCode);
/**
 下载完成
 */
@property (nonatomic, copy)     void(^didFinishLoadingWithTask)(KPAudioRequestTask *task);
/**
 下载失败
 */
@property (nonatomic, copy)     void(^didFailLoadingWithTask)(KPAudioRequestTask *task);
/**
 下载信息
 */
@property (nonatomic, copy)     void(^didReceiveAudioInfoHandler)(KPAudioRequestTask *task ,NSUInteger audioLength, NSString *mimeType);

- (NSURL *)getSchemeAudioURL:(NSURL *)url;


/**
 结束下载任务
 */
- (void)cancel;



@end

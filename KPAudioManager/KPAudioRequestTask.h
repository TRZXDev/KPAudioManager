//
//  KPAudioRequestTask.h
//  KPAudioTest
//
//  Created by 移动微 on 17/1/12.
//  Copyright © 2017年 移动微. All rights reserved.
//


/// 这个 Task 的功能是从网络请求数据, 并把数据保存到本地的一个临时文件夹, 网络请求结束的时候, 如果数据完整, 则把数据缓存到指定的路径, 不完整就删除
#import <AVFoundation/AVFoundation.h>

@class KPAudioRequestTask;
//@protocol KPAudioRequestTaskDelegate <NSObject>
//
//
//@end

@interface KPAudioRequestTask : NSObject

@property (nonatomic, strong ,readonly) NSURL                   *url;
@property (nonatomic, readonly)         NSUInteger              offset;
@property (nonatomic, strong)           NSMutableArray          *taskArray;
@property (nonatomic, readonly)         NSUInteger              audioLength;
@property (nonatomic, readonly)         NSUInteger              downLoadingOffset;
@property (nonatomic, strong, readonly) NSString                *mimeType;
@property (nonatomic, assign)           BOOL                    isFinishLoad;
/**
 获取到信息
 */
@property (nonatomic, copy)             void(^receiveAudioInfoHandler)(KPAudioRequestTask *task ,NSUInteger audioLength, NSString *mimeType);
/**
 获取到数据
 */
@property (nonatomic, copy)             void(^receiveAudioDataHandler)(KPAudioRequestTask *task);
/**
 获取信息结束
 */
@property (nonatomic, copy)             void(^receiveAudioFinishHanlder)(KPAudioRequestTask *task);
/**
 获取信息失败
 */
@property (nonatomic, copy)             void(^receiveAudioFailHandler)(KPAudioRequestTask *task , NSError *error);

- (void)setURL:(NSURL *)url offset:(NSUInteger)offset;
//
//- (void)setURL:(NSURL *)url offset:(NSUInteger)offset;
//
- (void)cancel;
//
//- (void)continueLoading;
//
//- (void)clearData;

@end

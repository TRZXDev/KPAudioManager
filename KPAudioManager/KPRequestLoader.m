//
//  KPRequestLoader.m
//  KPAudioTest
//
//  Created by 移动微 on 17/1/16.
//  Copyright © 2017年 移动微. All rights reserved.
//

#import "KPRequestLoader.h"
#import "KPAudioRequestTask.h"
#import "KPAudioBasicInfo.h"
#import <MobileCoreServices/MobileCoreServices.h>


@interface KPRequestLoader ()
/**
 存播放器请求的数据
 */
@property (nonatomic, strong) NSMutableArray *pendingRequset;

@property (nonatomic, copy)   NSString       *audioPath;

@end

@implementation KPRequestLoader

- (instancetype)init{
    self = [super init];
    if (self) {
        _pendingRequset = [NSMutableArray array];
//        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
//        _audioPath = [document stringByAppendingPathComponent:@"temp.mp4"];
    }
    return self;
}

#pragma mark - AVAssetResourceLoaderDelegate
/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 *
 */
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    [self.pendingRequset addObject:loadingRequest];
    [self dealWithLoadingRequest:loadingRequest];
    NSLog(@"----%@", loadingRequest);
    return YES;
}

/**
 播放器关闭了下载请求
 播放器关闭一个旧请求，都会发起一到多个新请求，除非已经播放完毕了
 
 - parameter resourceLoader: 资源管理器
 - parameter loadingRequest: 待关请求
 */
- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (!self.pendingRequset.count) {
        return;
    }
    
    if (![self.pendingRequset indexOfObject:loadingRequest]) {
        return;
    }
    NSUInteger index = [self.pendingRequset indexOfObject:loadingRequest];
    [self.pendingRequset removeObjectAtIndex:index];
}

#pragma mark - KPRequestLoader
- (void)dealWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, NSUIntegerMax);
    
    if (self.task) {
        KPAudioRequestTask *task = self.task;
        if (task.downLoadingOffset > 0) { // 如果该请求正在加载
            [self processPendingRequests];
        }
        //  处理往回拖 & 拖到的位置大于已缓存位置的情况
        BOOL loadLastRequest = range.location < task.offset;// 往回拖
        // 拖到的位置过大 , 比已缓存的位置还大300
        BOOL tmpResourceIsNotEnoughToLoad = task.offset + task.downLoadingOffset + 1024 * 300 < range.location;
        if (loadLastRequest || tmpResourceIsNotEnoughToLoad) {
            [self.task setURL:interceptedURL offset:range.location];
        }
    }else{
        self.task = [[KPAudioRequestTask alloc] init];
        __weak __typeof(self) weakSelf = self;
        [self.task setReceiveAudioDataHandler:^(KPAudioRequestTask *task) {
            [weakSelf processPendingRequests];
        }];
        [self.task setReceiveAudioFinishHanlder:^(KPAudioRequestTask *task) {
            if (weakSelf.finishLoadingHandler) {
                weakSelf.finishLoadingHandler(task,0);
            }
        }];
        [self.task setReceiveAudioFailHandler:^(KPAudioRequestTask *task, NSError *error) {
            if (weakSelf.finishLoadingHandler) {
                weakSelf.finishLoadingHandler(task,error.code);
            }
        }];
        [self.task setReceiveAudioInfoHandler:^(KPAudioRequestTask *task ,NSUInteger audioLength, NSString *mimeType) {
            if (weakSelf.didReceiveAudioInfoHandler) {
                weakSelf.didReceiveAudioInfoHandler(task,audioLength,mimeType);
            }
        }];
        
        
        
        [self.task setURL:interceptedURL offset:0];
    }
}

/**
 处理加载中的请求
 */
- (void)processPendingRequests
{
    NSMutableArray *requestsCompleted = [NSMutableArray array];  //请求完成的数组
    //每次下载一块数据都是一次请求，把这些请求放到数组，遍历数组
    for (int i = 0 ; i < self.pendingRequset.count; i++) {
        if ([self.pendingRequset[i] isKindOfClass:[AVAssetResourceLoadingRequest class]]) {
            AVAssetResourceLoadingRequest *loadingRequest = self.pendingRequset[i];
            [self fillInContentInformation:loadingRequest.contentInformationRequest]; //对每次请求加上长度，文件类型等信息
            
            BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest]; //判断此次请求的数据是否处理完全
            
            if (didRespondCompletely) {
                
                [requestsCompleted addObject:loadingRequest];  //如果完整，把此次请求放进 请求完成的数组
                [loadingRequest finishLoading];
            }
        }
    }
    //  剔除掉已经完成了的请求
    [self.pendingRequset removeObjectsInArray:requestsCompleted];   //在所有请求的数组中移除已经完成的
}

/**
 设置请求信息
 */
- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest{
    if (self.task == nil) {
        return ;
    }
    KPAudioRequestTask *task = self.task;
    NSString *mimeType = task.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = (__bridge NSString * _Nullable)(CFBridgingRetain((__bridge id _Nullable)(contentType)));
    contentInformationRequest.contentLength = task.audioLength;
}

/**
 响应播放器请求
 
 返回值: 是否能完整的响应该请求 - 给播放器足够的数据
 */
- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest{
    
    if (dataRequest == nil) {
        return YES;
    }
    
    if (self.task == nil) {
        return NO;
    }
    KPAudioRequestTask *task = self.task;
    long long startOffset = dataRequest.requestedOffset;
    
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    
    //  如果请求的位置 + 已缓冲了的长度 比新请求的其实位置小 - 隔了一段
    if ((task.offset + task.downLoadingOffset) < startOffset){
        return NO;
    } else if (startOffset < task.offset){ //  播放器要的起始位置，在下载器下载的起始位置之前
        return NO;
    }else {
        // 取出缓存文件
        NSData *fileData = nil;
        fileData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[KPAudioBasicInfo streamAudioConfig_tempPath]] options:NSDataReadingMappedIfSafe error:nil];
        //  可以拿到的从startOffset之后的长度
        NSUInteger unreadBytes = task.downLoadingOffset - ((NSInteger)startOffset - task.offset);
        //  应该能拿到的字节数
        NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
        //  应该从本地拿的数据范围
        NSRange fetchRange = NSMakeRange(startOffset - task.offset, numberOfBytesToRespondWith);
        //  拿到响应数据
        if (!fileData.length) {
            return NO;
        }
        NSData *responseData = [fileData subdataWithRange:fetchRange];
        //  响应请求
        [dataRequest respondWithData:responseData];
        //  请求结束位置
        CGFloat endOffset = startOffset + dataRequest.requestedLength;
        //  是否获取到完整数据
        BOOL didRespondFully = task.offset + task.downLoadingOffset >= endOffset;
        
        return didRespondFully;
    }
}

#pragma mark - KPRequestLoder
- (NSURL *)getSchemeAudioURL:(NSURL *)url{
    if (!url) {
        return nil;
    }
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    return [components URL];
}

- (void)cancel{
    // 1.结束task下载任务
    [self.task cancel];
    self.task = nil;
    
    if (!self.pendingRequset.count) {
        return;
    }
    // 2.停止数据请求
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequset) {
        [loadingRequest finishLoading];
    }
}

//#pragma mark - KPAudioRequestTaskDelegate
//
//- (void)task:(KPAudioRequestTask *)task didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType{
//    
//    NSLog(@"下载了, %lu",(unsigned long)ideoLength);
//}
//
//- (void)didReceiveVideoDataWithTask:(KPAudioRequestTask *)task3{
//    [self processPendingRequests];
//}
//
//- (void)didFinishLoadingWithTask:(KPAudioRequestTask *)task
//{
//    if (self.didFinishLoadingWithTask) {
//        self.didFinishLoadingWithTask(self.task);
//    }
//}
//
//- (void)didFailLoadingWithTask:(KPAudioRequestTask *)task WithError:(NSInteger)errorCode{
//    if (self.didFailLoadingWithTask) {
//        self.didFailLoadingWithTask(self.task);
//    }
//}
@end

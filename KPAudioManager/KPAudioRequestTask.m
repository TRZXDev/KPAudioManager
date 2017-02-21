//
//  KPAudioRequestTask.m
//  KPAudioTest
//
//  Created by 移动微 on 17/1/12.
//  Copyright © 2017年 移动微. All rights reserved.
//

#import "KPAudioRequestTask.h"
#import <Foundation/Foundation.h>
#import "KPAudioBasicInfo.h"

@interface KPAudioRequestTask ()<NSURLConnectionDataDelegate>
/**
 下载链接
 */
@property (nonatomic, strong) NSURLConnection           *connection;
/**
 文件下载句柄
 */
@property (nonatomic, strong) NSFileHandle             *fileHandle;
/**
 控制失败后是否重新下载
 */
@property (nonatomic, assign) BOOL                      once;

@property (nonatomic, strong) NSURL                     *url;

@property (nonatomic)         NSUInteger                offset;

@property (nonatomic)         NSUInteger                audioLength;

@property (nonatomic)         NSString                  *mimeType;

@property (nonatomic, strong) NSString                  *tempPath;

@property (nonatomic)         NSUInteger                downLoadingOffset;

@end

@implementation KPAudioRequestTask

- (instancetype)init
{
    self = [super init];
    if (self) {
        _taskArray = [NSMutableArray array];
//        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
//        _tempPath =  [document stringByAppendingPathComponent:@"temp.mp4"];
//        if ([[NSFileManager defaultManager] fileExistsAtPath:_tempPath]) {
//            [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
//            [[NSFileManager defaultManager] createFileAtPath:_tempPath contents:nil attributes:nil];
//            
//        } else {
//            [[NSFileManager defaultManager] createFileAtPath:_tempPath contents:nil attributes:nil];
//        }
        [self initialTmpFile];
    }
    return self;
}

- (void)updateFilePath:(NSURL *)url{
    [self initialTmpFile];
    NSLog(@"缓存文件路径 -- %@",[KPAudioBasicInfo streamAudioConfig_audioDicPath]);
}

- (void)initialTmpFile{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @try {
        [fileManager createDirectoryAtPath:[KPAudioBasicInfo streamAudioConfig_audioDicPath]  withIntermediateDirectories:YES attributes:nil error:nil];
    } @catch (NSException *exception) {
        NSLog(@"创建文件失败 : %@",exception);
    }
    if ([fileManager fileExistsAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath]]) {
        
        @try {
            [fileManager removeItemAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] error:nil];
        } @catch (NSException *exception) {
            NSLog(@"删除文件失败 : %@ (%@,%s)",exception,self,__func__);
        }
    }
    [fileManager createFileAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] contents:nil attributes:nil];
}



#pragma mark - Public funcs
/**
 连接服务器，请求数据（或拼range请求部分数据）（此方法中会将协议头修改为http）
 
 - parameter offset: 请求位置
 */
- (void)setURL:(NSURL *)url offset:(NSUInteger)offset{
    
    [self updateFilePath:url];
    
    self.url = url;
    self.offset = offset;

    //如果建立第二次请求，先移除原来文件，再创建新的
    if (self.taskArray.count >= 1) {
        @try {
            [[NSFileManager defaultManager] removeItemAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] error:nil];
            [[NSFileManager defaultManager] createFileAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] contents:nil attributes:nil];
        } @catch (NSException *exception) {
            NSLog(@"操作文件错误 %s",__func__);
        }
    }
    
    // 初始化已下载文件长度
    _downLoadingOffset = 0;
    
    //  把stream://xxx的头换成http://的头
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO] ;
    actualURLComponents.scheme = @"http";
    if (actualURLComponents.URL == nil) {
        return;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:actualURLComponents.URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
//    [request setHTTPMethod:@"POST"];//POST请求
    // 若非从头下载, 且音频长度已知且大于零 , 则下载offset到audioLength的范围 (拼request参数)
    if (offset > 0 && self.audioLength > 0) {
        NSString *value = [NSString stringWithFormat:@"bytes=%lu-%lu",(unsigned long)offset,(unsigned long)self.audioLength - 1];
        [request addValue:value forHTTPHeaderField:@"Range"];
    }
    [self.connection cancel];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [self.connection start];
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    self.isFinishLoad = NO;
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    //  解析头部数据
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *dic = [httpResponse allHeaderFields];
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    // 拿到真实长度
    NSUInteger audiolength = 0;
    if ([length integerValue] == 0) {
        audiolength = (NSUInteger)httpResponse.expectedContentLength;
    }else{
        audiolength = [length integerValue];
    }
    
    self.audioLength = audiolength;
    
    //TODO: 此处需要修改为真实数据格式 - 从字典中取
    self.mimeType = @"audio/mp3";
    // 回调
    if (self.receiveAudioInfoHandler) {
        self.receiveAudioInfoHandler(self,self.audioLength,self.mimeType);
    }
    // 连接加入到任务数组中
    [self.taskArray addObject:connection];
    // 初始化文件传输句柄
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath]];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    // 寻址到文件末尾
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
    self.downLoadingOffset += data.length;
    
    if (self.receiveAudioDataHandler) {
        self.receiveAudioDataHandler(self);
    }
    
    //  这里用子线程有问题...
//    id queue = dispatch_queue_create(@"com.azen.taskConnect", DISPATCH_QUEUE_SERIAL);
    
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    
    if (self.taskArray.count < 2) {
        [self tmpPersistence];
    }
    
    if (self.receiveAudioFinishHanlder) {
        self.receiveAudioFinishHanlder(self);
    }
}

- (void)tmpPersistence{
    self.isFinishLoad = YES;
    NSString *fileName = self.url.lastPathComponent;
    
    NSString *movePath = [NSString stringWithFormat:@"%@/%@",[KPAudioBasicInfo streamAudioConfig_audioDicPath],fileName?:@"undefine.mp3"];
    @try {
        [[NSFileManager defaultManager] removeItemAtPath:movePath error:nil];
    } @catch (NSException *exception) {
        NSLog(@"删除文件失败 : %@",exception);
    }
    
    BOOL isSuccessful = YES;
    
    @try {
        [[NSFileManager defaultManager] copyItemAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] toPath:movePath error:nil];
    } @catch (NSException *exception) {
        isSuccessful = NO;
        NSLog(@"tmp文件持久化失败");
    }
    if (isSuccessful) {
        NSLog(@"文件持久化成功!路径:%@",movePath);
    }
}

//网络中断：-1005
//无网络连接：-1009
//请求超时：-1001
//服务器内部错误：-1004
//找不到服务器：-1003
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (error.code == -1001 && !_once) {      //网络超时，重连一次
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self continueLoading];
        });
    }
    if (error.code == -1009) {
        NSLog(@"无网络连接");
    }
    if (self.receiveAudioFailHandler) {
        self.receiveAudioFailHandler(self,error);
    }
}

#pragma mark - Private functions
/**
 断线重连
 */
- (void)continueLoading{
    if (self.url == nil) {
        return ;
    }
    
    _once = YES;
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:_url resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = @"http";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
//    [request setHTTPMethod:@"POST"];//POST请求
    [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)_downLoadingOffset, (unsigned long)self.audioLength - 1] forHTTPHeaderField:@"Range"];
    
    
    [self.connection cancel];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [self.connection start];
}

- (void)cancel{
    // 1.断开连接
    [self.connection cancel];
    // 2.关闭文件写入句柄
    [self.fileHandle closeFile];
    // 3.移除缓存
    if ([[NSFileManager defaultManager] fileExistsAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[KPAudioBasicInfo streamAudioConfig_tempPath] error:nil];
    }
}

@end

//
//  KPAudioBasicInfo.m
//  KPAudioTest
//
//  Created by 移动微 on 17/1/23.
//  Copyright © 2017年 移动微. All rights reserved.
//

#import "KPAudioBasicInfo.h"

@implementation KPAudioBasicInfo

+ (instancetype)initWithTitle:(NSString *)title Artist:(NSString *)artist ConverImage:(UIImage *)converImage{
    KPAudioBasicInfo *basicInfo = [[KPAudioBasicInfo alloc] init];
    basicInfo.title = title;
    basicInfo.artist = artist;
    basicInfo.converImage = converImage;
    return basicInfo;
}


+ (NSString *)streamAudioConfig_audioDicPath{
    NSString *userPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    return [NSString stringWithFormat:@"%@/streamAudio",userPath];
}

+ (NSString *)streamAudioConfig_tempPath{
    return [NSString stringWithFormat:@"%@/temp.mp3",self.streamAudioConfig_audioDicPath];
}

@end

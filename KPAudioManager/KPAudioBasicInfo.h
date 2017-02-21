//
//  KPAudioBasicInfo.h
//  KPAudioTest
//
//  Created by 移动微 on 17/1/23.
//  Copyright © 2017年 移动微. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface KPAudioBasicInfo : NSObject

@property (nonatomic, copy)   NSString        *title;

@property (nonatomic, copy)   NSString        *artist;

@property (nonatomic, copy)   UIImage         *converImage;

+ (instancetype)initWithTitle:(NSString *)title Artist:(NSString *)artist ConverImage:(UIImage *)converImage;

+ (NSString *)streamAudioConfig_audioDicPath;

+ (NSString *)streamAudioConfig_tempPath;

@end

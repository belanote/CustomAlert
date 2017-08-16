//
//  MSCustomAlert.h
//  hi7_client
//
//  Created by Desmond on 2017/4/13.
//  Copyright © 2017年 Beijing ShowMe Network Technology Co., Ltd.,. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MSCustomAlert : UIView


/**
 自定义Alert 初始化方法，初始化后 调用show方法;
 如果customeView中有 输入控件，点击 背景 和 customview 时会先 resignFirstResponder

 @param customView 自定义view
 @param dismissWhenTouchBackground YES时 点击背景dismiss 否则背景不响应dismiss方法

 */
- (instancetype)initWithCustomView:(UIView *)customView dismissWhenTouchedBackground:(BOOL)dismissWhenTouchBackground;

- (void)show;


/**
 alert Dismiss方法
 customView中如果有按钮点击后需要Dismiss 则调用该方法

 @param completion alert 消失后的回调，如需在alert消失后处理数据可以写在回调里
 */
- (void)dismissWithCompletion:(void(^)(void))completion;



@end

//
//  MSCustomAlert.m
//  hi7_client
//
//  Created by Desmond on 2017/4/13.
//  Copyright © 2017年 Beijing ShowMe Network Technology Co., Ltd.,. All rights reserved.
//

#import "MSCustomAlert.h"
#import <Accelerate/Accelerate.h>


#define MSColor(r, g, b) [UIColor colorWithRed:(r/255.0) green:(g/255.0) blue:(b/255.0) alpha:1.0]
#define MSCustomAlertViewWidth 280
#define MSCustomAlertViewHeight 174
#define MSCustomAlertViewMaxHeight 440
#define MSCustomAlertMargin 8
#define MSCustomAlertButtonHeight 44
#define MSCustomAlertViewTitleLabelHeight 50
#define MSCustomAlertViewTitleFont [UIFont boldSystemFontOfSize:20]
#define MSCustomAlertViewContentColor MSColor(102, 102, 102)
#define MSCustomAlertViewContentFont [UIFont systemFontOfSize:16]
#define MSCustomAlertViewContentHeight (MSCustomAlertViewHeight - MSCustomAlertViewTitleLabelHeight - MSCustomAlertButtonHeight - MSCustomAlertMargin * 2)
@class MSCustomAlertController;

@protocol MSCustomAlertControllerDelegate <NSObject>

@optional
- (void)coverViewTouched;

@end

@interface MSCustomAlert () <MSCustomAlertControllerDelegate>

@property (nonatomic, copy)     NSString *title;
@property (nonatomic, copy)     NSString *message;
@property (nonatomic, strong)   NSArray *buttons;
@property (nonatomic, strong)   NSArray *clicks;
@property (nonatomic, weak)     MSCustomAlertController *vc;
@property (nonatomic, strong)   UIImageView *screenShotView;
@property (nonatomic, weak)     UIView *customView;
@property (nonatomic, getter=isCustomAlert)                 BOOL customAlert;
@property (nonatomic, getter=isDismissWhenTouchBackground)  BOOL dismissWhenTouchBackground;
@property (nonatomic, getter=isAlertReady)                  BOOL alertReady;


@end

@interface MSAlertSingle : NSObject

@property (nonatomic, strong)   UIWindow *backgroundWindow;
@property (nonatomic, weak)     UIWindow *oldKeyWindow;
@property (nonatomic, strong)   NSMutableArray *alertStack;
@property (nonatomic, strong)   MSCustomAlert *previousAlert;

@end
@implementation MSAlertSingle

+ (instancetype)shareSingle{
    static MSAlertSingle *shareSingleInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        shareSingleInstance = [MSAlertSingle new];
    });
    return shareSingleInstance;
}

- (UIWindow *)backgroundWindow{
    if (!_backgroundWindow) {
        _backgroundWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _backgroundWindow.windowLevel = UIWindowLevelAlert;
    }
    return _backgroundWindow;
}

- (NSMutableArray *)alertStack{
    if (!_alertStack) {
        _alertStack = [NSMutableArray array];
    }
    return _alertStack;
}

@end

@interface MSCustomAlertController : UIViewController

@property (nonatomic, strong)   UIImageView *screenShotView;
@property (nonatomic, strong)   UIButton *coverView;
@property (nonatomic, weak)     MSCustomAlert *alertView;
@property (nonatomic, weak)     id <MSCustomAlertControllerDelegate> delegate;

@end

@implementation MSCustomAlertController

- (void)viewDidLoad{
    [super viewDidLoad];
    
//    [self addScreenShot];
    [self addCoverView];
    [self.view addSubview:self.alertView];
}
- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}
- (void)addScreenShot{
    UIWindow *screenWindow = [UIApplication sharedApplication].windows.firstObject;
    UIGraphicsBeginImageContext(screenWindow.frame.size);
    [screenWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImage *originalImage = nil;
    originalImage = viewImage;
    
    
    CGFloat blurRadius = 1;
    UIColor *tintColor = [UIColor clearColor];
    CGFloat saturationDeltaFactor = 1;
    UIImage *maskImage = nil;
    
    CGRect imageRect = { CGPointZero, originalImage.size };
    UIImage *effectImage = originalImage;
    
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturationChange = fabs(saturationDeltaFactor - 1.) > __FLT_EPSILON__;
    if (hasBlur || hasSaturationChange) {
        UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectInContext = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectInContext, 1.0, -1.0);
        CGContextTranslateCTM(effectInContext, 0, -originalImage.size.height);
        CGContextDrawImage(effectInContext, imageRect, originalImage.CGImage);
        
        vImage_Buffer effectInBuffer;
        effectInBuffer.data	 = CGBitmapContextGetData(effectInContext);
        effectInBuffer.width	= CGBitmapContextGetWidth(effectInContext);
        effectInBuffer.height   = CGBitmapContextGetHeight(effectInContext);
        effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
        vImage_Buffer effectOutBuffer;
        effectOutBuffer.data	 = CGBitmapContextGetData(effectOutContext);
        effectOutBuffer.width	= CGBitmapContextGetWidth(effectOutContext);
        effectOutBuffer.height   = CGBitmapContextGetHeight(effectOutContext);
        effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);
        
        if (hasBlur) {
            CGFloat inputRadius = blurRadius * [[UIScreen mainScreen] scale];
            uint32_t radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
            if (radius % 2 != 1) {
                radius += 1;
            }
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
        }
        BOOL effectImageBuffersAreSwapped = NO;
        if (hasSaturationChange) {
            CGFloat s = saturationDeltaFactor;
            CGFloat floatingPointSaturationMatrix[] = {
                0.0722f + 0.9278f * s,  0.0722f - 0.0722f * s,  0.0722f - 0.0722f * s,  0,
                0.7152f - 0.7152f * s,  0.7152f + 0.2848f * s,  0.7152f - 0.7152f * s,  0,
                0.2126f - 0.2126f * s,  0.2126f - 0.2126f * s,  0.2126f + 0.7873f * s,  0,
                0,					0,					0,  1,
            };
            const int32_t divisor = 256;
            NSUInteger matrixSize = sizeof(floatingPointSaturationMatrix)/sizeof(floatingPointSaturationMatrix[0]);
            int16_t saturationMatrix[matrixSize];
            for (NSUInteger i = 0; i < matrixSize; ++i) {
                saturationMatrix[i] = (int16_t)roundf(floatingPointSaturationMatrix[i] * divisor);
            }
            if (hasBlur) {
                vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
                effectImageBuffersAreSwapped = YES;
            }
            else {
                vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
            }
        }
        if (!effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef outputContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(outputContext, 1.0, -1.0);
    CGContextTranslateCTM(outputContext, 0, -originalImage.size.height);
    
    CGContextDrawImage(outputContext, imageRect, originalImage.CGImage);
    
    if (hasBlur) {
        CGContextSaveGState(outputContext);
        if (maskImage) {
            CGContextClipToMask(outputContext, imageRect, maskImage.CGImage);
        }
        CGContextDrawImage(outputContext, imageRect, effectImage.CGImage);
        CGContextRestoreGState(outputContext);
    }
    
    if (tintColor) {
        CGContextSaveGState(outputContext);
        CGContextSetFillColorWithColor(outputContext, tintColor.CGColor);
        CGContextFillRect(outputContext, imageRect);
        CGContextRestoreGState(outputContext);
    }
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.screenShotView = [[UIImageView alloc] initWithImage:outputImage];
    
    [self.view addSubview:self.screenShotView];
}

- (void)addCoverView{
    self.coverView = [[UIButton alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.coverView.backgroundColor = MSColor(5, 0, 10);
    [self.coverView addTarget:self action:@selector(coverViewClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.coverView];
}

- (void)coverViewClick{
    if ([self.delegate respondsToSelector:@selector(coverViewTouched)]) {
        [self.delegate coverViewTouched];
    }
}

- (void)showAlert{
    self.alertView.alertReady = NO;
    
    CGFloat duration = 0.3;
    
    for (UIButton *btn in self.alertView.subviews) {
        btn.userInteractionEnabled = NO;
    }
    
    self.screenShotView.alpha = 0;
    self.coverView.alpha = 0;
    self.alertView.alpha = 0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.screenShotView.alpha = 1;
        self.coverView.alpha = 0.7;
        self.alertView.alpha = 1.0;
    } completion:^(BOOL finished) {
        for (UIButton *btn in self.alertView.subviews) {
            btn.userInteractionEnabled = YES;
        }
        self.alertView.alertReady = YES;
    }];

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    animation.values = @[@(0.8), @(1.05), @(1.1), @(1)];
    animation.keyTimes = @[@(0), @(0.3), @(0.5), @(1.0)];
    animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    animation.duration = duration;
    [self.alertView.layer addAnimation:animation forKey:@"bouce"];
}

- (void)hideAlertWithCompletion:(void(^)(void))completion{

    
    self.alertView.alertReady = NO;
    
    CGFloat duration = 0.2;
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.coverView.alpha = 0;
        self.screenShotView.alpha = 0;
        self.alertView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.screenShotView removeFromSuperview];
        if (completion) {
            completion();
        }
    }];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.alertView.transform = CGAffineTransformMakeScale(0.4, 0.4);
    } completion:^(BOOL finished) {
        self.alertView.transform = CGAffineTransformMakeScale(1, 1);
    }];
}

@end

@implementation MSCustomAlert
- (NSArray *)buttons{
    if (!_buttons) {
        _buttons = [NSArray array];
    }
    return _buttons;
}

- (NSArray *)clicks{
    if (!_clicks) {
        _clicks = [NSArray array];
    }
    return _clicks;
}

- (instancetype)initWithCustomView:(UIView *)customView dismissWhenTouchedBackground:(BOOL)dismissWhenTouchBackground{
    if (self = [super initWithFrame:customView.bounds]) {
        self.customView = customView;
        [self addSubview:customView];
        self.center = CGPointMake(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2);
        self.customAlert = YES;
        self.dismissWhenTouchBackground = dismissWhenTouchBackground;
        self.customView.userInteractionEnabled = YES;
        
        [self.customView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentViewTouched:)]];
    }
    return self;
}

- (void)show{
    [[MSAlertSingle shareSingle].alertStack addObject:self];
    
    [self showAlert];
}

- (void)dismissWithCompletion:(void(^)(void))completion{
    [self dismissAlertWithCompletion:^{
        if (completion) {
            completion();
        }
    }];
}

- (void)showAlert{

        [self showAlertHandle];
}

- (void)showAlertHandle{
    UIWindow *keywindow = [UIApplication sharedApplication].keyWindow;
    if (keywindow != [MSAlertSingle shareSingle].backgroundWindow) {
       [MSAlertSingle shareSingle].oldKeyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    MSCustomAlertController *vc = [[MSCustomAlertController alloc] init];
    vc.delegate = self;
    vc.alertView = self;
    self.vc = vc;
    
    [MSAlertSingle shareSingle].backgroundWindow.frame = [UIScreen mainScreen].bounds;
    [[MSAlertSingle shareSingle].backgroundWindow makeKeyAndVisible];
    [MSAlertSingle shareSingle].backgroundWindow.rootViewController = self.vc;
    
    [self.vc showAlert];
}

- (void)coverViewTouched{
    if (self.isDismissWhenTouchBackground) {
        [self dismissAlertWithCompletion:nil];
    }
}
- (void)contentViewTouched:(UITapGestureRecognizer *)gesture
{
    [self findFirstResSubview:self.customView];
}
- (BOOL)findFirstResSubview:(UIView *)view
{
    for (id obj in view.subviews) {
        if ([obj isKindOfClass:[UITextView class]]) {
            UITextView *textview = (UITextView *)obj;
            if ([textview isFirstResponder]) {
                [textview resignFirstResponder];
                return YES;
            }
        }
        if ([obj isKindOfClass:[UITextField class]]) {
            UITextField *textview = (UITextField *)obj;
            if ([textview isFirstResponder]) {
                [textview resignFirstResponder];
                return YES;
            }
        }
        if ([self findFirstResSubview:obj]) {
            return YES;
        }
    }
    return NO;
}

- (void)dismissAlertWithCompletion:(void(^)(void))completion{
    if ([self findFirstResSubview:self.customView]) {
        return;
    }
    [self.vc hideAlertWithCompletion:^{
        [self stackHandle];
        
        if (completion) {
            completion();
        }
        
        NSInteger count = [MSAlertSingle shareSingle].alertStack.count;
        if (count > 0) {
            MSCustomAlert *lastAlert = [MSAlertSingle shareSingle].alertStack.lastObject;
            [lastAlert showAlert];
        }
    }];
}

- (void)stackHandle{
    [[MSAlertSingle shareSingle].alertStack removeObject:self];
    
    NSInteger count = [MSAlertSingle shareSingle].alertStack.count;
    if (count == 0) {
        [self toggleKeyWindow];
    }
}

- (void)toggleKeyWindow{
    [[MSAlertSingle shareSingle].oldKeyWindow makeKeyAndVisible];
    [MSAlertSingle shareSingle].backgroundWindow.rootViewController = nil;
    [MSAlertSingle shareSingle].backgroundWindow.frame = CGRectZero;
    
}

- (UIImage *)resizeImage:(UIImage *)image{
    return [image stretchableImageWithLeftCapWidth:image.size.width / 2 topCapHeight:image.size.height / 2];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end

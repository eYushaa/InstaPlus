#import "InstantsManager.h"
#import "InstaLocalization.h"

@interface InstantsManager ()
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIButton *instantPickerButton;
@property (nonatomic, weak) UIViewController *currentVC;
@end

@implementation InstantsManager

+ (instancetype)sharedManager {
    static InstantsManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)presentImagePickerWithCroppingFromViewController:(UIViewController *)presentingVC {
    self.currentVC = presentingVC;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES; // Kırpma (Crop) ekranını aktif et!
    picker.delegate = self;
    [presentingVC presentViewController:picker animated:YES completion:nil];
}

- (void)showInstantPickerButton {
    BOOL isEnabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"instantsButtonEnabled"]) {
        isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"instantsButtonEnabled"];
    }
    if (!isEnabled) {
        [self hideInstantPickerButton];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) {
                keyWindow = w;
                break;
            }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        if (!self.instantPickerButton) {
            CGFloat btnSize = 50;
            self.instantPickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.instantPickerButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - btnSize - 20,
                                                        [UIScreen mainScreen].bounds.size.height - 180,
                                                        btnSize, btnSize);
            self.instantPickerButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.85];
            self.instantPickerButton.layer.cornerRadius = btnSize / 2.0;
            self.instantPickerButton.layer.borderWidth = 2.0;
            self.instantPickerButton.layer.borderColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.9].CGColor;
            
            [self.instantPickerButton setTitle:@"🖼️" forState:UIControlStateNormal];
            self.instantPickerButton.titleLabel.font = [UIFont systemFontOfSize:24];
            [self.instantPickerButton addTarget:self action:@selector(instantPickerTapped) forControlEvents:UIControlEventTouchUpInside];
            
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [self.instantPickerButton addGestureRecognizer:pan];
        }
        
        if (self.instantPickerButton.superview != keyWindow) {
            [self.instantPickerButton removeFromSuperview];
            [keyWindow addSubview:self.instantPickerButton];
        }
        [keyWindow bringSubviewToFront:self.instantPickerButton];
        self.instantPickerButton.hidden = NO;
        self.instantPickerButton.alpha = 1.0;
    });
}

- (void)hideInstantPickerButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.instantPickerButton) {
            [UIView animateWithDuration:0.2 animations:^{
                self.instantPickerButton.alpha = 0.0;
            } completion:^(BOOL finished) {
                self.instantPickerButton.hidden = YES;
            }];
        }
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    if (!button) return;
    
    CGPoint translation = [gesture translationInView:button.superview];
    button.center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:button.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint newCenter = button.center;
        CGFloat halfW = button.bounds.size.width / 2.0;
        CGFloat halfH = button.bounds.size.height / 2.0;
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        
        if (newCenter.x < halfW) newCenter.x = halfW + 10;
        if (newCenter.x > screenSize.width - halfW) newCenter.x = screenSize.width - halfW - 10;
        if (newCenter.y < halfH) newCenter.y = halfH + 50;
        if (newCenter.y > screenSize.height - halfH) newCenter.y = screenSize.height - halfH - 30;
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            button.center = newCenter;
        } completion:nil];
    }
}

- (void)instantPickerTapped {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    [self presentImagePickerWithCroppingFromViewController:topVC];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    // Önce kırpılmış (Edited) resmi al, yoksa orjinal resmi al
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (!image) {
        image = info[UIImagePickerControllerOriginalImage];
    }
    
    if (image) {
        self.selectedImage = image;
        [self applyImageToInstantCameraPreview:image];
        [self showToast:L(@"instant_photo_placed")];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)applyImageToInstantCameraPreview:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        // Ekrana Şipşak kadrajına uygun olacak şekilde seçilen resmi canlı preview olarak overlay et
        UIImageView *previewOverlay = (UIImageView *)[keyWindow viewWithTag:998877];
        if (!previewOverlay) {
            previewOverlay = [[UIImageView alloc] initWithFrame:keyWindow.bounds];
            previewOverlay.tag = 998877;
            previewOverlay.contentMode = UIViewContentModeScaleAspectFit;
            previewOverlay.clipsToBounds = YES;
            // Arka planı hafif saydam yapalım ki alttaki butonlar seçilebilsin
            previewOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
            
            // Kullanıcı alttaki çekim (shutter) butonuna basabilsin diye tıklamaları geçir
            previewOverlay.userInteractionEnabled = NO;
        }
        previewOverlay.image = image;
        [keyWindow addSubview:previewOverlay];
        [keyWindow bringSubviewToFront:previewOverlay];
        
        // İptal Butonu
        UIButton *cancelBtn = (UIButton *)[keyWindow viewWithTag:998878];
        if (!cancelBtn) {
            cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            cancelBtn.tag = 998878;
            cancelBtn.frame = CGRectMake(20, 60, 40, 40);
            cancelBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
            cancelBtn.layer.cornerRadius = 20;
            [cancelBtn setTitle:@"✕" forState:UIControlStateNormal];
            cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
            [cancelBtn addTarget:self action:@selector(removePreviewOverlayAction:) forControlEvents:UIControlEventTouchUpInside];
        }
        [keyWindow addSubview:cancelBtn];
        [keyWindow bringSubviewToFront:cancelBtn];
    });
}

- (void)removePreviewOverlayAction:(UIButton *)sender {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [keyWindow viewWithTag:998877];
    if (overlay) [overlay removeFromSuperview];
    if (sender) [sender removeFromSuperview];
    
    [self clearPendingInstantImage];
    [self showToast:L(@"returned_to_camera")];
}

- (UIImage *)pendingInstantImage {
    return self.selectedImage;
}

- (void)clearPendingInstantImage {
    self.selectedImage = nil;
}

- (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        UILabel *toast = [[UILabel alloc] init];
        toast.text = message;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.4 alpha:0.95];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        toast.layer.cornerRadius = 18;
        toast.clipsToBounds = YES;
        
        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: toast.font}];
        CGFloat width = textSize.width + 36;
        toast.frame = CGRectMake((keyWindow.bounds.size.width - width) / 2.0,
                                 keyWindow.bounds.size.height - 120,
                                 width, 36);
        
        [keyWindow addSubview:toast];
        [keyWindow bringSubviewToFront:toast];
        
        toast.alpha = 0.0;
        [UIView animateWithDuration:0.3 animations:^{
            toast.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{
                toast.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

@end

#import "DMMediaOverlayManager.h"
#import "MediaExtractor.h"
#import "LocalPhotoManager.h"

@interface DMMediaOverlayManager ()
@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation DMMediaOverlayManager

+ (instancetype)sharedManager {
    static DMMediaOverlayManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)showOverlayIfNeeded {
    BOOL isEnabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"saveButtonEnabled"]) {
        isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"saveButtonEnabled"];
    }
    if (!isEnabled) {
        [self hideOverlay];
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
        
        if (!self.saveButton) {
            [self setupSaveButton];
        }
        
        if (self.saveButton.superview != keyWindow) {
            [self.saveButton removeFromSuperview];
            [keyWindow addSubview:self.saveButton];
        }
        [keyWindow bringSubviewToFront:self.saveButton];
        
        self.saveButton.hidden = NO;
        self.saveButton.alpha = 1.0;
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.saveButton) {
            [UIView animateWithDuration:0.2 animations:^{
                self.saveButton.alpha = 0.0;
            } completion:^(BOOL finished) {
                self.saveButton.hidden = YES;
            }];
        }
    });
}

- (void)setupSaveButton {
    CGFloat btnSize = 48;
    CGRect frame = CGRectMake([UIScreen mainScreen].bounds.size.width - btnSize - 16,
                              100,
                              btnSize, btnSize);
    
    self.saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.saveButton.frame = frame;
    self.saveButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.88];
    
    self.saveButton.layer.cornerRadius = btnSize / 2.0;
    self.saveButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.saveButton.layer.shadowOpacity = 0.4;
    self.saveButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.saveButton.layer.shadowRadius = 5;
    self.saveButton.layer.borderWidth = 1.5;
    self.saveButton.layer.borderColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.85].CGColor;
    
    [self.saveButton setTitle:@"📥" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont systemFontOfSize:22];
    
    [self.saveButton addTarget:self action:@selector(saveButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.saveButton addGestureRecognizer:pan];
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

- (void)saveButtonTapped {
    [self saveCurrentActiveMediaWithToast:YES];
}

- (BOOL)saveCurrentActiveMediaWithToast:(BOOL)showToast {
    NSString *username = [self detectActiveUsername];
    NSError *error = nil;
    
    NSMutableString *debugLog = [NSMutableString string];
    [debugLog appendFormat:@"Username detected: %@\n", username];
    
    // 1. Önce Video URL var mı
    NSURL *videoURL = [MediaExtractor extractActiveVideoURLFromScreenWithLog:debugLog];
    if (videoURL) {
        NSUInteger urlHash = [videoURL.absoluteString hash];
        NSString *mediaKey = [NSString stringWithFormat:@"%@_vid_%lu", username, (unsigned long)urlHash];
        
        BOOL alreadySaved = [[LocalPhotoManager sharedManager] isMediaAlreadySaved:mediaKey];
        if (alreadySaved) {
            if (showToast) [self showToast:[NSString stringWithFormat:@"(Zaten Kayıtlı) Video @%@ klasöründe!", username]];
            // Ekranda video var ve daha önce kaydedilmiş. Kesinlikle fotoğraf taramasına düşme!
            return YES;
        }
        
        BOOL success = [[LocalPhotoManager sharedManager] saveVideoFromURL:videoURL forUsername:username error:&error];
        if (success) {
            if (showToast) [self showToast:[NSString stringWithFormat:@"✓ Video @%@ klasörüne kaydedildi!", username]];
            return YES;
        }
        // Ekranda video tespit edildiyse video olarak işlenmiştir, fotoğrafa düşme!
        if (showToast) [self showAlertWithTitle:@"İndirme Hatası" message:[NSString stringWithFormat:@"Video URL bulundu ancak indirilemedi. Hata: %@", error.localizedDescription ?: @"Bilinmiyor"]];
        return NO;
    }
    
    // 2. Ekranda video bulunamadıysa (veya URL çekilemediyse) Görsel/Fotoğraf olarak kaydet
    [debugLog appendFormat:@"Falling back to image extraction...\n"];
    UIImage *capturedMedia = [MediaExtractor extractLargestImageFromScreen];
    if (capturedMedia) {
        NSData *imageData = UIImageJPEGRepresentation(capturedMedia, 0.95);
        if (!imageData || imageData.length == 0) return NO;
        
        NSString *mediaKey = [NSString stringWithFormat:@"%@_img_%lu_%ldx%ld", username, (unsigned long)imageData.length, (long)capturedMedia.size.width, (long)capturedMedia.size.height];
        
        BOOL alreadySaved = [[LocalPhotoManager sharedManager] isMediaAlreadySaved:mediaKey];
        if (alreadySaved) {
            return YES;
        }
        
        BOOL success = [[LocalPhotoManager sharedManager] saveImage:capturedMedia forUsername:username error:&error];
        if (success) {
            if (showToast) [self showToast:[NSString stringWithFormat:@"✓ Fotoğraf @%@ klasörüne kaydedildi!", username]];
            return YES;
        }
    }
    
    if (showToast) [self showAlertWithTitle:@"Hata (Log)" message:debugLog];
    return NO;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        UIViewController *topVC = keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC topViewController];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Logu Kopyala" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIPasteboard generalPasteboard] setString:msg];
        }]];
        
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

- (BOOL)isValidUsername:(NSString *)text {
    if (!text || text.length < 2 || text.length > 30) return NO;
    
    NSString *clean = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ \t\n\r"]];
    NSString *lower = clean.lowercaseString;
    
    // Filtrelenecek buton / Arayüz sabit kelimeleri
    NSArray *blacklist = @[
        @"live", @"block", @"reply", @"share", @"send", @"follow", @"following",
        @"requested", @"posts", @"followers", @"likes", @"comments", @"reels",
        @"stories", @"story", @"message", @"messages", @"chat", @"chats", @"cancel",
        @"done", @"edit", @"more", @"options", @"back", @"close", @"settings",
        @"profile", @"info", @"report", @"mute", @"search", @"home", @"explore",
        @"instagram", @"new instant", @"instant", @"view", @"active", @"today",
        @"yesterday", @"audio", @"original", @"video", @"photo", @"media", @"camera",
        @"remix", @"music", @"use", @"template", @"like", @"comment", @"views", @"play", 
        @"pause", @"save", @"download", @"add", @"new", @"shop", @"menu", @"see", 
        @"translate", @"translation", @"sponsored", @"ad", @"ads", @"promoted", @"suggested",
        @"direct", @"inbox", @"notifications", @"activity", @"details"
    ];
    
    for (NSString *bad in blacklist) {
        if ([lower containsString:bad]) {
            return NO;
        }
    }
    
    // Metrik kontrolü (örneğin "123", "12.3K", "1,234", "1.2M" gibi beğeni veya izlenme sayılarını reddet)
    NSRegularExpression *metricRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9.,]+[KkMm]?$" options:0 error:nil];
    if ([metricRegex numberOfMatchesInString:clean options:0 range:NSMakeRange(0, clean.length)] > 0) {
        return NO;
    }
    
    // Karakter kontrolü (Harf, Rakam, Nokta, Altçizgi)
    NSCharacterSet *invalidChars = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."] invertedSet];
    if ([clean rangeOfCharacterFromSet:invalidChars].location != NSNotFound) {
        return NO;
    }
    
    return YES;
}

static void traverseLabelsInView(UIView *view, UIWindow *keyWindow, NSString * __strong *detectedUser) {
    if (*detectedUser) return;
    
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CGPoint globalPos = [label convertPoint:CGPointZero toView:keyWindow];
        
        BOOL isTop = globalPos.y < 250;
        BOOL isBottom = globalPos.y > (keyWindow.bounds.size.height - 400);
        
        if ((isTop || isBottom) && label.text.length > 1 && label.text.length < 32) {
            NSString *text = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([text hasPrefix:@"@"]) {
                text = [text substringFromIndex:1];
            }
            
            DMMediaOverlayManager *manager = [DMMediaOverlayManager sharedManager];
            if ([manager isValidUsername:text]) {
                *detectedUser = text;
                return;
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        traverseLabelsInView(subview, keyWindow, detectedUser);
    }
}

- (NSString *)detectActiveUsername {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    // 1. Önce aktif ViewController başlıklarını tara
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController];
    }
    
    NSString *vcTitle = topVC.navigationItem.title ? topVC.navigationItem.title : topVC.title;
    if (vcTitle.length > 1) {
        if ([vcTitle hasPrefix:@"@"]) vcTitle = [vcTitle substringFromIndex:1];
        if ([self isValidUsername:vcTitle]) {
            return vcTitle;
        }
    }
    
    // 2. Ekrandaki etiketleri tara
    NSString *detectedUser = nil;
    if (keyWindow) {
        traverseLabelsInView(keyWindow, keyWindow, &detectedUser);
    }
    
    if (detectedUser.length > 0) {
        return detectedUser;
    }
    
    return @"Instagram_User";
}

- (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        UILabel *toast = [[UILabel alloc] init];
        toast.text = message;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.92];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
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
            [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{
                toast.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

@end

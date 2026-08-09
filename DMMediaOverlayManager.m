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
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"media_download_button_enabled"]) {
        isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"media_download_button_enabled"];
    } else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"saveButtonEnabled"]) {
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
    NSMutableString *debugLog = [NSMutableString string];
    
    // 1. Get Context from Extractor
    NSDictionary *ctx = [MediaExtractor extractActiveMediaContextFromScreenWithLog:debugLog];
    
    NSString *username = nil;
    if (ctx && ctx[@"username"]) {
        username = ctx[@"username"];
    } else {
        username = [self detectActiveUsername];
    }
    
    if (!username || username.length == 0) {
        username = @"Unknown_User";
    }
    
    // 2. VIDEO EXTRACTION
    if (ctx && [ctx[@"type"] isEqualToString:@"video"]) {
        if (ctx[@"url"]) {
            NSURL *videoURL = ctx[@"url"];
            NSLog(@"[InstaPlus] Starting VIDEO download from URL: %@", videoURL.absoluteString);

            if (showToast) [self showToast:@"Video İndiriliyor... Lütfen bekleyin."];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *bgError = nil;
                BOOL success = [[LocalPhotoManager sharedManager] saveVideoFromURL:videoURL forUsername:username error:&bgError];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        NSLog(@"[InstaPlus] Video download SUCCESS");
                        if (showToast) [self showToast:[NSString stringWithFormat:@"Video @%@ klasörüne kaydedildi!", username]];
                    } else {
                        NSLog(@"[InstaPlus] Video download FAILED: %@", bgError);
                        [self showAlertWithTitle:@"İndirme Hatası" message:[NSString stringWithFormat:@"Video kaydedilemedi.\nHata: %@\n\nLOG:\n%@", bgError.localizedDescription ?: @"Bilinmiyor", debugLog]];
                    }
                });
            });
            return YES;
        } else {
            // Explicitly detected video, but URL extraction failed. DO NOT SAVE PHOTO SCREENSHOT!
            [self showAlertWithTitle:@"Video URL Bulunamadı" message:[NSString stringWithFormat:@"Ekrandaki medya Video olarak tespit edildi ancak indirme adresi alınamadı.\n\nLOG:\n%@", debugLog]];
            return NO;
        }
    }
    
    // 3. PHOTO EXTRACTION
    UIImage *capturedMedia = nil;
    if (ctx && [ctx[@"type"] isEqualToString:@"photo"]) {
        NSLog(@"[InstaPlus] Detected PHOTO extraction");
        if (ctx[@"url"]) {
            NSURL *photoURL = ctx[@"url"];
            NSData *data = [NSData dataWithContentsOfURL:photoURL];
            if (data && data.length > 5000) {
                capturedMedia = [UIImage imageWithData:data];
            }
        }
        if (!capturedMedia && ctx[@"image"]) {
            capturedMedia = ctx[@"image"];
        }
    }
    
    // Fallback ONLY IF NOT explicit video
    if (!capturedMedia && (!ctx || ![ctx[@"type"] isEqualToString:@"video"])) {
        [debugLog appendFormat:@"Falling back to generic screen image extraction...\n"];
        capturedMedia = [MediaExtractor extractLargestImageFromScreen];
    }

    if (capturedMedia) {
        NSError *error = nil;
        BOOL success = [[LocalPhotoManager sharedManager] saveImage:capturedMedia forUsername:username error:&error];
        if (success) {
            if (showToast) [self showToast:[NSString stringWithFormat:@"Fotoğraf @%@ klasörüne kaydedildi!", username]];
            return YES;
        } else {
            [self showAlertWithTitle:@"Kaydetme Hatası" message:[NSString stringWithFormat:@"Fotoğraf kaydedilemedi: %@", error.localizedDescription]];
        }
    }
    
    [self showAlertWithTitle:@"Hata (Log)" message:debugLog];
    return NO;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        UIView *old = [keyWindow viewWithTag:99998888];
        if (old) [old removeFromSuperview];
        
        UIView *overlay = [[UIView alloc] initWithFrame:keyWindow.bounds];
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        overlay.tag = 99998888;
        
        CGFloat cardW = MIN(keyWindow.bounds.size.width - 60, 320);
        CGFloat cardH = 270;
        CGRect cardFrame = CGRectMake((keyWindow.bounds.size.width - cardW) / 2.0, (keyWindow.bounds.size.height - cardH) / 2.0, cardW, cardH);
        
        UIView *box = [[UIView alloc] initWithFrame:cardFrame];
        box.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:0.98];
        box.layer.cornerRadius = 16;
        box.layer.shadowColor = [UIColor blackColor].CGColor;
        box.layer.shadowOpacity = 0.5;
        box.layer.shadowOffset = CGSizeMake(0, 4);
        box.layer.shadowRadius = 8;
        box.clipsToBounds = YES;
        
        [overlay addSubview:box];
        
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 14, cardW - 30, 24)];
        titleLbl.text = title;
        titleLbl.font = [UIFont boldSystemFontOfSize:17];
        titleLbl.textColor = [UIColor whiteColor];
        titleLbl.textAlignment = NSTextAlignmentCenter;
        [box addSubview:titleLbl];
        
        UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(12, 44, cardW - 24, cardH - 100)];
        tv.text = msg;
        tv.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        tv.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        tv.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.8];
        tv.layer.cornerRadius = 8;
        tv.editable = NO;
        [box addSubview:tv];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(0, cardH - 46, cardW, 46);
        [closeBtn setTitle:@"Tamam" forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [closeBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        closeBtn.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        [closeBtn addTarget:self action:@selector(dismissCustomAlert:) forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:closeBtn];
        
        [keyWindow addSubview:overlay];
    });
}

- (void)dismissCustomAlert:(UIButton *)sender {
    UIView *box = sender.superview;
    UIView *overlay = box.superview;
    if (overlay.tag == 99998888) {
        [overlay removeFromSuperview];
    }
}

- (BOOL)isValidUsername:(NSString *)text {
    if (!text || text.length < 2 || text.length > 30) return NO;
    if ([text containsString:@" "] || [text containsString:@"\n"]) return NO;
    
    NSString *clean = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ \t\n\r"]];
    NSString *lower = clean.lowercaseString;
    
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
        @"direct", @"inbox", @"notifications", @"activity", @"details", @"interested", @"kaydet"
    ];
    
    for (NSString *bad in blacklist) {
        if ([lower containsString:bad]) {
            return NO;
        }
    }
    
    NSRegularExpression *metricRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9.,]+[KkMmHhDdWwYySsXx]?$" options:0 error:nil];
    if ([metricRegex numberOfMatchesInString:clean options:0 range:NSMakeRange(0, clean.length)] > 0) {
        return NO;
    }
    
    NSCharacterSet *invalidChars = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."] invertedSet];
    if ([clean rangeOfCharacterFromSet:invalidChars].location != NSNotFound) {
        return NO;
    }
    
    return YES;
}

static void traverseLabelsInViewForUsername(UIView *view, UIWindow *keyWindow, NSString * __strong *detectedUser, CGFloat *minDist) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CGPoint globalPos = [label convertPoint:CGPointZero toView:keyWindow];
        
        BOOL isTop = globalPos.y < 350;
        BOOL isBottom = globalPos.y > (keyWindow.bounds.size.height - 400);
        
        if ((isTop || isBottom) && label.text.length > 1 && label.text.length < 32) {
            NSString *text = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([text hasPrefix:@"@"]) {
                text = [text substringFromIndex:1];
            }
            
            DMMediaOverlayManager *manager = [DMMediaOverlayManager sharedManager];
            if ([manager isValidUsername:text]) {
                CGFloat screenCenterY = keyWindow.bounds.size.height / 2.0;
                CGFloat dist = fabs(globalPos.y - screenCenterY);
                if (dist < *minDist) {
                    *minDist = dist;
                    *detectedUser = text;
                }
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        traverseLabelsInViewForUsername(subview, keyWindow, detectedUser, minDist);
    }
}

- (NSString *)detectActiveUsername {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
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
    
    NSString *detectedUser = nil;
    if (keyWindow) {
        CGFloat minDist = CGFLOAT_MAX;
        traverseLabelsInViewForUsername(keyWindow, keyWindow, &detectedUser, &minDist);
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

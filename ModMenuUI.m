#import "ModMenuUI.h"
#import "VoiceGalleryViewController.h"
#import "RVCSettingsViewController.h"
#import <objc/runtime.h>

static UIView *modMenuView = nil;
static NSArray *settingsArray = nil;

void ShowFloatingModMenu(void) {
    [ModMenuUI showFloatingModMenu];
}

@implementation ModMenuUI

+ (void)initialize {
    if (self == [ModMenuUI class]) {
        settingsArray = @[
            @{@"key": @"adBlockerEnabled", @"title": @"Reklam Engelleyici", @"default": @YES},
            @{@"key": @"screenshot_protection", @"title": @"Anti-Screenshot", @"default": @YES},
            @{@"key": @"no_seen_receipt", @"title": @"Görüldü Gizle", @"default": @YES},
            @{@"key": @"disable_typing_status", @"title": @"Yazıyor Gizle", @"default": @YES},
            @{@"key": @"keep_deleted_message", @"title": @"Silinenleri Tut", @"default": @YES},
            @{@"key": @"disable_view_once_limitations", @"title": @"Tek İzlemelikleri Sınırsız Yap", @"default": @YES},
            @{@"key": @"auto_save_visual_messages", @"title": @"Tek İzlemelikleri Oto-Kaydet", @"default": @YES},
            @{@"key": @"like_confirm", @"title": @"Beğeni Onayı", @"default": @NO},
            @{@"key": @"follow_confirm", @"title": @"Takip Onayı", @"default": @NO},
            @{@"key": @"call_confirm", @"title": @"Arama Onayı", @"default": @YES},
            @{@"key": @"rvc_enabled", @"title": @"RVC Ses Değiştirici", @"default": @NO},
            @{@"key": @"voice_gallery_button_enabled", @"title": @"Ses Galerisi Butonu", @"default": @NO},
            @{@"key": @"media_download_button_enabled", @"title": @"Medya İndirme Butonu", @"default": @YES},
            @{@"key": @"instantsButtonEnabled", @"title": @"Şipşak Butonu", @"default": @YES}
        ];
    }
}

+ (void)switchChanged:(UISwitch *)sender {
    if (sender.tag >= 0 && sender.tag < settingsArray.count) {
        NSString *key = settingsArray[sender.tag][@"key"];
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if ([key isEqualToString:@"voice_gallery_button_enabled"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Class managerClass = NSClassFromString(@"FloatingVoiceButtonManager");
                if (managerClass) {
                    id shared = [managerClass performSelector:@selector(sharedManager)];
                    [shared performSelector:@selector(updateVisibility)];
                }
            });
        } else if ([key isEqualToString:@"instantsButtonEnabled"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!sender.on) {
                    Class instantsClass = NSClassFromString(@"InstantsManager");
                    if (instantsClass) {
                        id shared = [instantsClass performSelector:@selector(sharedManager)];
                        [shared performSelector:@selector(hideInstantPickerButton)];
                    }
                }
            });
        } else if ([key isEqualToString:@"media_download_button_enabled"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Class managerClass = NSClassFromString(@"FloatingButtonManager");
                if (managerClass) {
                    id shared = [managerClass performSelector:@selector(sharedManager)];
                    [shared performSelector:@selector(updateVisibility)];
                }
            });
        }
    }
}

+ (void)closeMenu {
    if (modMenuView) {
        [UIView animateWithDuration:0.3 animations:^{
            modMenuView.alpha = 0.0;
            modMenuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        }];
    }
}

+ (void)openVoiceGallery {
    [self closeMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [VoiceGalleryViewController showOverlay];
    });
}

+ (void)openInternalGallery {
    [self closeMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow) return;
        
        UIViewController *root = keyWindow.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        
        Class galleryClass = NSClassFromString(@"GalleryListViewController");
        if (galleryClass) {
            UITableViewController *galleryVC = [[galleryClass alloc] initWithStyle:UITableViewStylePlain];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:galleryVC];
            [root presentViewController:nav animated:YES completion:nil];
        }
    });
}

+ (void)openRVCSettings {
    [self closeMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow) return;
        
        UIViewController *root = keyWindow.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        
        [RVCSettingsViewController showSettings];
    });
}

+ (void)showFloatingModMenu {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow) return;
    
    if (modMenuView) {
        if (modMenuView.alpha == 0.0) {
            [UIView animateWithDuration:0.3 animations:^{
                modMenuView.alpha = 1.0;
                modMenuView.transform = CGAffineTransformIdentity;
            }];
            [keyWindow bringSubviewToFront:modMenuView];
        }
        return;
    }
    
    modMenuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 520)];
    modMenuView.center = keyWindow.center;
    modMenuView.backgroundColor = [UIColor clearColor];
    modMenuView.alpha = 0.0;
    modMenuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    
    UIVisualEffectView *menuBlurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    menuBlurView.frame = modMenuView.bounds;
    menuBlurView.layer.cornerRadius = 24;
    menuBlurView.clipsToBounds = YES;
    menuBlurView.layer.borderWidth = 1.5;
    menuBlurView.layer.borderColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:0.5].CGColor;
    [modMenuView addSubview:menuBlurView];
    
    modMenuView.layer.shadowColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:0.6].CGColor;
    modMenuView.layer.shadowOffset = CGSizeZero;
    modMenuView.layer.shadowOpacity = 0.5;
    modMenuView.layer.shadowRadius = 15;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 30)];
    titleLabel.text = @"InstaPlus VIP Mod";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [modMenuView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, 280, 20)];
    subLabel.text = @"GELİŞMİŞ GİZLİLİK VE MEDYA SİSTEMİ";
    subLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    subLabel.textColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [modMenuView addSubview:subLabel];
    
    UIView *separatorLine = [[UIView alloc] initWithFrame:CGRectMake(25, 75, 270, 1)];
    separatorLine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    [modMenuView addSubview:separatorLine];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 85, 320, 350)];
    [modMenuView addSubview:scrollView];
    
    CGFloat currentY = 5;
    for (int i = 0; i < settingsArray.count; i++) {
        NSDictionary *dict = settingsArray[i];
        UILabel *swLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, currentY, 200, 35)];
        swLabel.text = dict[@"title"];
        swLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        swLabel.textColor = [UIColor whiteColor];
        [scrollView addSubview:swLabel];
        
        if ([dict[@"key"] isEqualToString:@"rvc_enabled"]) {
            UIButton *settingsGear = [UIButton buttonWithType:UIButtonTypeSystem];
            settingsGear.frame = CGRectMake(195, currentY, 35, 35);
            [settingsGear setTitle:@"⚙️" forState:UIControlStateNormal];
            settingsGear.titleLabel.font = [UIFont systemFontOfSize:18];
            [settingsGear addTarget:self action:@selector(openRVCSettings) forControlEvents:UIControlEventTouchUpInside];
            [scrollView addSubview:settingsGear];
        }
        
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(240, currentY + 2.5, 0, 0)];
        sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
        sw.transform = CGAffineTransformMakeScale(0.8, 0.8);
        if ([[NSUserDefaults standardUserDefaults] objectForKey:dict[@"key"]]) {
            sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:dict[@"key"]];
        } else {
            sw.on = [dict[@"default"] boolValue];
        }
        
        sw.tag = i;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [scrollView addSubview:sw];
        
        currentY += 45;
    }
    
    scrollView.contentSize = CGSizeMake(320, currentY + 10);
    
    UIButton *galleryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    galleryBtn.frame = CGRectMake(20, 450, 135, 45);
    galleryBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.8 alpha:1.0];
    galleryBtn.layer.cornerRadius = 12;
    [galleryBtn setTitle:@"Dahili Galeri" forState:UIControlStateNormal];
    [galleryBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    galleryBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [galleryBtn addTarget:self action:@selector(openInternalGallery) forControlEvents:UIControlEventTouchUpInside];
    [modMenuView addSubview:galleryBtn];
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(165, 450, 135, 45);
    saveBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
    saveBtn.layer.cornerRadius = 12;
    [saveBtn setTitle:@"Kaydet" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [saveBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [modMenuView addSubview:saveBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(280, 20, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.5] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [modMenuView addSubview:closeBtn];
    
    [keyWindow addSubview:modMenuView];
    
    [UIView animateWithDuration:0.3 animations:^{
        modMenuView.alpha = 1.0;
        modMenuView.transform = CGAffineTransformIdentity;
    }];
}

+ (BOOL)isMenuVisible {
    return (modMenuView != nil && modMenuView.alpha > 0.0);
}

@end

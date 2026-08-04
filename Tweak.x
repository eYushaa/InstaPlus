#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "FloatingButtonManager.h"
#import "FloatingVoiceButtonManager.h"
#import "DMMediaOverlayManager.h"
#import "InstantsManager.h"

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloatingButtonManager sharedManager] attachToWindow:self];
        [[FloatingVoiceButtonManager sharedManager] attachToWindow:self];
    });
}

%end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    NSString *vcClass = NSStringFromClass([self class]);
    NSString *title = self.title ? self.title : (self.navigationItem.title ? self.navigationItem.title : @"");
    
    // "It's time to update Instagram / Beta update expired" uyarısını otomatik kapat/engelle
    if ([vcClass containsString:@"Update"] || [vcClass containsString:@"ForceUpdate"] || [vcClass containsString:@"BetaExpiry"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    
    // 1. Şipşak (New Instant) Kamera Ekranı Tespiti -> 🖼️ Galeriden Seç & Kırp Butonunu Göster
    BOOL isCameraVC = [vcClass containsString:@"Instant"] || 
                      [vcClass containsString:@"Camera"] || 
                      [vcClass containsString:@"QuickCam"] ||
                      [vcClass containsString:@"StoryCreation"] ||
                      [vcClass containsString:@"Capture"] ||
                      [vcClass containsString:@"VisualMessageDraft"] ||
                      [title.lowercaseString containsString:@"instant"];
                      
    if (isCameraVC) {
        [[InstantsManager sharedManager] showInstantPickerButton];
    } else {
        UIViewController *parent = self.parentViewController;
        BOOL parentIsCamera = NO;
        while (parent) {
            NSString *pClass = NSStringFromClass([parent class]);
            if ([pClass containsString:@"Camera"] || 
                [pClass containsString:@"Instant"] || 
                [pClass containsString:@"QuickCam"] || 
                [pClass containsString:@"StoryCreation"] || 
                [pClass containsString:@"Capture"] || 
                [pClass containsString:@"VisualMessageDraft"]) {
                parentIsCamera = YES;
                break;
            }
            parent = parent.parentViewController;
        }
        
        if (!parentIsCamera) {
            [[InstantsManager sharedManager] hideInstantPickerButton];
        }
    }
    
    // 2. DM Tek Gösterimlik Görsel/Video, Story, Post ve Reels Ekranlarında Kaydet İkonunu (📥) Göster
    if ([vcClass containsString:@"Direct"] || 
        [vcClass containsString:@"Visual"] || 
        [vcClass containsString:@"Story"] || 
        [vcClass containsString:@"Reel"] || 
        [vcClass containsString:@"Feed"] || 
        [vcClass containsString:@"Post"] || 
        [vcClass containsString:@"Viewer"] || 
        [vcClass containsString:@"Media"] ||
        [vcClass containsString:@"Photo"] ||
        [vcClass containsString:@"Video"]) {
        
        [[DMMediaOverlayManager sharedManager] showOverlayIfNeeded];
        
        // Otomatik kaydetme SADECE tek gösterimlik izleyici ekranında (VisualMessageViewer) çalışsın (Normal chat içinde çalışmasın!)
        if ([vcClass containsString:@"VisualMessageViewer"] || [vcClass containsString:@"DirectVisualMessageViewer"] || [vcClass containsString:@"VisualMessageViewController"]) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"auto_save_visual_messages"]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[DMMediaOverlayManager sharedManager] saveCurrentActiveMediaWithToast:YES];
                });
            }
        }
    }
}

%end

// 3. Screenshot (Ekran Görüntüsü ve Ekran Kaydı) Bildirimi Engelleyici Hook'lar (SCInsta Anti-SS)
%hook UIApplication
- (void)userDidTakeScreenshotNotification:(NSNotification *)notification {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) {
        NSLog(@"[InstaPlus] Screenshot notification intercepted and blocked!");
        return;
    }
    %orig;
}
%end

%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) {
        if ([aName isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
            [aName containsString:@"Screenshot"] ||
            [aName containsString:@"ScreenCapture"]) {
            NSLog(@"[InstaPlus] Blocked screenshot notification post!");
            return;
        }
    }
    %orig;
}
%end

%hook IGStoryViewerContainerView
- (void)setShouldBlockScreenshot:(BOOL)arg1 viewModel:(id)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

%hook IGDirectVisualMessageViewerSession
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return nil;
    return %orig;
}
%end

%hook IGDirectVisualMessageReplayService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return nil;
    return %orig;
}
%end

%hook IGDirectVisualMessageReportService
- (id)visualMessageViewerController:(id)arg1 didDetectScreenshotForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return nil;
    return %orig;
}
%end

%hook IGDirectVisualMessageScreenshotSafetyLogger
- (id)initWithUserSession:(id)arg1 entryPoint:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) {
        NSLog(@"[InstaPlus] Disable visual message screenshot safety logger");
        return nil;
    }
    return %orig;
}
%end

%hook IGScreenshotObserver
- (id)initForController:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return nil;
    return %orig;
}
%end

%hook IGScreenshotObserverDelegate
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

%hook IGDirectMediaViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

%hook IGStoryViewerViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

%hook IGSundialFeedViewController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

%hook IGDirectVisualMessageViewerController
- (void)screenshotObserverDidSeeScreenshotTaken:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
- (void)screenshotObserverDidSeeActiveScreenCapture:(id)arg1 event:(NSInteger)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"screenshot_protection"]) return;
    %orig;
}
%end

// Beta / Update Uyarısı Engelleyici Kancalar
%hook IGForceUpdateViewController
- (void)viewDidLoad {
    // Görünümün yüklenmesini engelle
}
%end

%hook IGAppAppeals
+ (BOOL)isAppExpired {
    return NO;
}
%end

// Global variables for storing the most recent video URL, media object, and playback timestamp
NSURL *gLastPlayingVideoURL = nil;
id gLastPlayingMediaObject = nil;
NSTimeInterval gLastPlayingVideoTime = 0;

static void updateLastPlayingMedia(id media, NSURL *url) {
    if (media) {
        gLastPlayingMediaObject = media;
    }
    if (url) {
        NSString *str = url.absoluteString.lowercaseString;
        if ([str hasPrefix:@"http"] && ![str containsString:@"oil_"]) {
            gLastPlayingVideoURL = url;
        }
    }
    if (media || url) {
        gLastPlayingVideoTime = [NSDate timeIntervalSinceReferenceDate];
    }
}

%hook AVPlayer
- (void)play {
    %orig;
    @try {
        AVPlayerItem *item = self.currentItem;
        if ([item.asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)item.asset URL];
            updateLastPlayingMedia(nil, url);
        }
    } @catch (NSException *e) {}
}

- (void)setRate:(float)rate {
    %orig;
    if (rate > 0.01) {
        @try {
            AVPlayerItem *item = self.currentItem;
            if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                NSURL *url = [(AVURLAsset *)item.asset URL];
                updateLastPlayingMedia(nil, url);
            }
        } @catch (NSException *e) {}
    }
}
%end

%hook FNFPlayer
- (void)play {
    %orig;
    @try {
        id s = (id)self;
        id asset = [s valueForKey:@"asset"];
        if (!asset) asset = [s valueForKey:@"representation"];
        if (asset) {
            id url = [asset valueForKey:@"url"];
            if ([url isKindOfClass:[NSURL class]]) updateLastPlayingMedia(nil, (NSURL *)url);
            else if ([url isKindOfClass:[NSString class]]) updateLastPlayingMedia(nil, [NSURL URLWithString:(NSString *)url]);
        }
    } @catch (NSException *e) {}
}

- (void)setRate:(float)rate {
    %orig;
    if (rate > 0.01) {
        @try {
            id s = (id)self;
            id asset = [s valueForKey:@"asset"];
            if (!asset) asset = [s valueForKey:@"representation"];
            if (asset) {
                id url = [asset valueForKey:@"url"];
                if ([url isKindOfClass:[NSURL class]]) updateLastPlayingMedia(nil, (NSURL *)url);
                else if ([url isKindOfClass:[NSString class]]) updateLastPlayingMedia(nil, [NSURL URLWithString:(NSString *)url]);
            }
        } @catch (NSException *e) {}
    }
}
%end

%hook IGFNFVideoPlayer
- (void)play {
    %orig;
    @try {
        id s = (id)self;
        id media = [s valueForKey:@"media"];
        if (!media) media = [s valueForKey:@"video"];
        id url = nil;
        if (media) {
            id u = [media valueForKey:@"videoURL"];
            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
        }
        updateLastPlayingMedia(media, url);
    } @catch (NSException *e) {}
}
%end

%hook IGVideoPlayer
- (void)play {
    %orig;
    @try {
        id s = (id)self;
        id media = [s valueForKey:@"media"];
        if (!media) media = [s valueForKey:@"video"];
        id url = nil;
        if (media) {
            id u = [media valueForKey:@"videoURL"];
            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
        }
        updateLastPlayingMedia(media, url);
    } @catch (NSException *e) {}
}
%end

%hook IGDirectVisualMessageViewerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    @try {
        id s = (id)self;
        id item = nil;
        @try {
            id ds = [s valueForKey:@"_dataSource"] ?: [s valueForKey:@"dataSource"];
            if (ds) {
                id msg = [ds valueForKey:@"_currentMessage"] ?: [ds valueForKey:@"currentMessage"];
                if (msg) {
                    item = [msg valueForKey:@"rawVideo"] ?: [msg valueForKey:@"video"] ?: [msg valueForKey:@"rawPhoto"] ?: [msg valueForKey:@"photo"];
                }
            }
        } @catch(NSException *ex) {}
        if (!item) {
            item = [s valueForKey:@"currentMedia"] ?: [s valueForKey:@"currentVisualMessage"] ?: [s valueForKey:@"media"] ?: [s valueForKey:@"item"] ?: [s valueForKey:@"currentItem"];
        }
        id url = nil;
        if (item) {
            id u = [item valueForKey:@"videoURL"] ?: [item valueForKey:@"url"];
            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
        }
        updateLastPlayingMedia(item ?: self, url);
    } @catch(NSException *e) {}
}
%end

%hook IGDirectVisualMessageViewerController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    @try {
        id s = (id)self;
        id item = nil;
        @try {
            id ds = [s valueForKey:@"_dataSource"] ?: [s valueForKey:@"dataSource"];
            if (ds) {
                id msg = [ds valueForKey:@"_currentMessage"] ?: [ds valueForKey:@"currentMessage"];
                if (msg) {
                    item = [msg valueForKey:@"rawVideo"] ?: [msg valueForKey:@"video"] ?: [msg valueForKey:@"rawPhoto"] ?: [msg valueForKey:@"photo"];
                }
            }
        } @catch(NSException *ex) {}
        if (!item) {
            item = [s valueForKey:@"currentMedia"] ?: [s valueForKey:@"currentVisualMessage"] ?: [s valueForKey:@"media"] ?: [s valueForKey:@"item"] ?: [s valueForKey:@"currentItem"];
        }
        id url = nil;
        if (item) {
            id u = [item valueForKey:@"videoURL"] ?: [item valueForKey:@"url"];
            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
        }
        updateLastPlayingMedia(item ?: self, url);
    } @catch(NSException *e) {}
}
%end

%hook IGDirectVisualMessagePlayer
- (void)play {
    %orig;
    @try {
        id s = (id)self;
        id media = [s valueForKey:@"media"];
        if (!media) media = [s valueForKey:@"video"];
        if (!media) media = [s valueForKey:@"item"];
        id url = nil;
        if (media) {
            id u = [media valueForKey:@"videoURL"];
            if (!u) u = [media valueForKey:@"url"];
            if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
        }
        updateLastPlayingMedia(media, url);
    } @catch(NSException *e) {}
}
%end

%hook IGDirectVideoCell
- (void)configureWithViewModel:(id)viewModel {
    %orig;
    @try {
        if (viewModel) {
            id video = [viewModel valueForKey:@"video"];
            id url = nil;
            if (video) {
                id u = [video valueForKey:@"videoURL"];
                if ([u isKindOfClass:[NSURL class]]) url = (NSURL *)u;
            }
            updateLastPlayingMedia(video ?: viewModel, url);
        }
    } @catch(NSException *e) {}
}
%end

// ============================================================================
// SCInsta ENTEGRASYONU: GİZLİLİK VE GİZLİ MOD (STEALTH HOOKS)
// ============================================================================

%hook IGStorySeenStateUploader
- (id)initWithUserSessionPK:(id)arg1 networker:(id)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"no_seen_receipt"]) {
        NSLog(@"[InstaPlus] Story seen receipt prevented");
        return nil;
    }
    return %orig;
}
- (id)networker {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"no_seen_receipt"]) {
        return nil;
    }
    return %orig;
}
%end

%hook IGDirectThreadViewListAdapterDataSource
- (BOOL)shouldUpdateLastSeenMessage {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"no_seen_receipt"]) {
        return NO;
    }
    return %orig;
}
%end

%hook IGDirectTypingStatusService
- (void)updateOutgoingStatusIsActive:(_Bool)active threadKey:(id)key threadMetadata:(id)metadata typingStatusType:(long long)type {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_typing_status"]) return;
    %orig(active, key, metadata, type);
}
%end

%hook IGDirectRealtimeIrisThreadDelta
+ (id)removeItemWithMessageId:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return nil;
    }
    return %orig(arg1);
}
+ (id)removeMessageWithMessageId:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return nil;
    }
    return %orig(arg1);
}
%end

%hook IGDirectMessageUpdate
+ (id)removeMessageWithMessageId:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return nil;
    }
    return %orig(arg1);
}
%end

%hook IGDirectPublishedMessageSet
- (id)removeMessageWithClientContext:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return self;
    }
    return %orig(arg1);
}
- (id)removeMessageWithServerId:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return self;
    }
    return %orig(arg1);
}
%end

%hook IGDirectThread
- (void)removeMessage:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return;
    }
    %orig(arg1);
}
- (void)removeMessageWithId:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return;
    }
    %orig(arg1);
}
%end

%hook IGDirectCache
- (void)removeMessageWithId:(id)arg1 fromThreadId:(id)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return;
    }
    %orig(arg1, arg2);
}
- (void)removeMessageWithServerId:(id)arg1 fromThreadId:(id)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"keep_deleted_message"]) {
        return;
    }
    %orig(arg1, arg2);
}
%end

%hook IGDirectVisualMessage
- (NSInteger)viewMode {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_view_once_limitations"]) {
        return 1; // Sınırsız / Tekrar Oynatılabilir (Replayable)
    }
    return %orig;
}
%end

%hook IGDirectVisualMessageViewerEventHandler
- (void)visualMessageViewerController:(id)arg1 didBeginPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_view_once_limitations"]) {
        return; // Sunucuya izlendi bildirimi gitmesini engelle
    }
    %orig;
}
- (void)visualMessageViewerController:(id)arg1 didEndPlaybackForVisualMessage:(id)arg2 atIndex:(NSInteger)arg3 mediaCurrentTime:(CGFloat)arg4 forNavType:(NSInteger)arg5 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_view_once_limitations"]) {
        return; // Sunucuya bitti/silinsin bildirimi gitmesini engelle
    }
    %orig;
}
%end

%hook IGDirectVisualMessageActionSummary
- (BOOL)isSeen {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_view_once_limitations"]) {
        return NO;
    }
    return %orig;
}
- (BOOL)isExpired {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disable_view_once_limitations"]) {
        return NO;
    }
    return %orig;
}
%end

// ============================================================================
// SCInsta ENTEGRASYONU: REKLAM VE SPONSORLU İÇERİK ENGELLEME
// ============================================================================

static NSArray *removeSponsoredFeedItems(NSArray *objs) {
    if (!objs) return nil;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"adBlockerEnabled"]) {
        return objs;
    }
    NSMutableArray *filtered = [NSMutableArray array];
    for (id obj in objs) {
        if ([obj isKindOfClass:objc_getClass("IGFeedItem")]) {
            @try {
                id sponsored = [obj valueForKey:@"isSponsored"];
                id sponsoredApp = [obj valueForKey:@"isSponsoredApp"];
                if (([sponsored respondsToSelector:@selector(boolValue)] && [sponsored boolValue]) ||
                    ([sponsoredApp respondsToSelector:@selector(boolValue)] && [sponsoredApp boolValue])) {
                    continue;
                }
            } @catch(NSException *e) {}
        } else if ([obj isKindOfClass:objc_getClass("IGAdItem")]) {
            continue;
        } else if ([obj isKindOfClass:objc_getClass("IGDiscoveryGridItem")]) {
            @try {
                if ([[(id)obj model] isKindOfClass:objc_getClass("IGAdItem")]) continue;
            } @catch(NSException *e) {}
        }
        [filtered addObject:obj];
    }
    return [filtered copy];
}

%hook IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    return removeSponsoredFeedItems(%orig);
}
%end

%hook IGExploreListKitDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    return removeSponsoredFeedItems(%orig);
}
%end

%hook IGStoryAdPool
- (id)initWithUserSession:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"adBlockerEnabled"]) {
        return nil;
    }
    return %orig;
}
%end

%hook IGStoryAdsManager
- (id)initWithUserSession:(id)arg1 storyViewerLoggingContext:(id)arg2 storyFullscreenSectionLoggingContext:(id)arg3 viewController:(id)arg4 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"adBlockerEnabled"]) {
        return nil;
    }
    return %orig;
}
%end

%hook IGStoryAdsFetcher
- (id)initWithUserSession:(id)arg1 delegate:(id)arg2 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"adBlockerEnabled"]) {
        return nil;
    }
    return %orig;
}
%end

// ============================================================================
// SCInsta ENTEGRASYONU: ONAY VE ETKİLEŞİM GÜVENLİĞİ (CONFIRMATION HOOKS)
// ============================================================================

static void showActionConfirmationAlert(NSString *actionTitle, void (^onConfirm)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *root = keyWindow.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Onay Gerekiyor"
                                                                       message:[NSString stringWithFormat:@"'%@' işlemini gerçekleştirmek istediğinize emin misiniz?", actionTitle]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Evet" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (onConfirm) onConfirm();
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"İptal" style:UIAlertActionStyleCancel handler:nil]];
        if (root) [root presentViewController:alert animated:YES completion:nil];
    });
}

%hook IGUFIButtonBarView
- (void)_onLikeButtonPressed:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"like_confirm"]) {
        showActionConfirmationAlert(@"Gönderi Beğenme", ^{ %orig; });
    } else {
        %orig;
    }
}
%end

%hook IGFeedPhotoView
- (void)_onDoubleTap:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"like_confirm"]) {
        showActionConfirmationAlert(@"Çift Tıkla Beğenme", ^{ %orig; });
    } else {
        %orig;
    }
}
%end

%hook IGFollowController
- (void)_didPressFollowButton {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"follow_confirm"]) {
        showActionConfirmationAlert(@"Kullanıcıyı Takip Etme", ^{ %orig; });
    } else {
        %orig;
    }
}
%end

%hook IGDirectThreadCallButtonsCoordinator
- (void)_didTapAudioButton:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"call_confirm"]) {
        showActionConfirmationAlert(@"Sesli Arama Başlatma", ^{ %orig; });
    } else {
        %orig;
    }
}
- (void)_didTapVideoButton:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"call_confirm"]) {
        showActionConfirmationAlert(@"Görüntülü Arama Başlatma", ^{ %orig; });
    } else {
        %orig;
    }
}
%end

// ============================================================================
// SCInsta ENTEGRASYONU: FAKE CAMERA (ŞİPŞAK) HOOKS
// ============================================================================

static void clearInstantImageAfterDelay(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[InstantsManager sharedManager] clearPendingInstantImage];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIView *previewOverlay = [keyWindow viewWithTag:998877];
        if (previewOverlay) {
            [previewOverlay removeFromSuperview];
        }
        UIView *cancelBtn = [keyWindow viewWithTag:998878];
        if (cancelBtn) {
            [cancelBtn removeFromSuperview];
        }
    });
}

%hook AVCapturePhoto

- (NSData *)fileDataRepresentation {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        clearInstantImageAfterDelay();
        return UIImageJPEGRepresentation(pending, 0.95);
    }
    return %orig;
}

- (CGImageRef)CGImageRepresentation {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        clearInstantImageAfterDelay();
        return pending.CGImage;
    }
    return %orig;
}

%end

// Modern Instagram UIImage spoofing
%hook UIImage

+ (UIImage *)imageWithCGImage:(CGImageRef)cgImage {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        CGFloat w = CGImageGetWidth(cgImage);
        CGFloat h = CGImageGetHeight(cgImage);
        if (w > 200 && h > 200) {
            clearInstantImageAfterDelay();
            return pending;
        }
    }
    return %orig;
}

+ (UIImage *)imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        CGFloat w = CGImageGetWidth(cgImage);
        CGFloat h = CGImageGetHeight(cgImage);
        if (w > 200 && h > 200) {
            clearInstantImageAfterDelay();
            return pending;
        }
    }
    return %orig;
}

+ (UIImage *)imageWithData:(NSData *)data {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending && data.length > 30000) {
        clearInstantImageAfterDelay();
        return pending;
    }
    return %orig;
}

+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending && data.length > 30000) {
        clearInstantImageAfterDelay();
        return pending;
    }
    return %orig;
}

- (instancetype)initWithData:(NSData *)data {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending && data.length > 30000) {
        clearInstantImageAfterDelay();
        return pending;
    }
    return %orig;
}

- (instancetype)initWithCGImage:(CGImageRef)cgImage {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        CGFloat w = CGImageGetWidth(cgImage);
        if (w > 200) {
            clearInstantImageAfterDelay();
            return pending;
        }
    }
    return %orig;
}

- (instancetype)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        CGFloat w = CGImageGetWidth(cgImage);
        if (w > 200) {
            clearInstantImageAfterDelay();
            return pending;
        }
    }
    return %orig;
}

%end

%hook IGSampleBuffer

- (id)image {
    UIImage *pending = [[InstantsManager sharedManager] pendingInstantImage];
    if (pending) {
        clearInstantImageAfterDelay();
        return pending;
    }
    return %orig;
}

%end

%hook AVCaptureSession

- (void)startRunning {
    %orig;
    [[InstantsManager sharedManager] showInstantPickerButton];
}

- (void)stopRunning {
    %orig;
    [[InstantsManager sharedManager] hideInstantPickerButton];
}

%end


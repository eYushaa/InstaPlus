#import "FloatingButtonManager.h"


@interface FloatingButtonManager ()
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, weak) UIWindow *currentWindow;
@end

@implementation FloatingButtonManager

+ (instancetype)sharedManager {
    static FloatingButtonManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window || ![window isKindOfClass:[UIWindow class]]) return;
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self attachToWindow:window];
        });
        return;
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    // Sadece tam ekran olan ana pencereleri hedefle
    if (window.bounds.size.width < screenBounds.size.width || window.bounds.size.height < screenBounds.size.height) {
        return;
    }
    
    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"Keyboard"] || 
        [windowClass containsString:@"StatusBar"] || 
        [windowClass containsString:@"Alert"] || 
        [windowClass containsString:@"Transition"] || 
        [windowClass containsString:@"Effects"]) {
        return;
    }
    
    // Auto-hide on Main Feed (Ana Akis) because of multiple posts overlapping.
    // The user will use the 3-dots menu for the Main Feed.
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController];
    }
    
    NSString *vcClass = NSStringFromClass([topVC class]);
    BOOL isMainFeed = [vcClass containsString:@"MainFeed"] || [vcClass isEqualToString:@"IGFeedViewController"];
    
    if (self.floatingButton) {
        if (isMainFeed) {
            self.floatingButton.hidden = YES;
        } else {
            self.floatingButton.hidden = NO;
        }
    }
    
    if (isMainFeed) {
        return;
    }
    
    self.currentWindow = window;
    
    if (!self.floatingButton) {
        [self setupFloatingButton];
    }
    
    self.floatingButton.hidden = NO;
    
    if (self.floatingButton.superview != window) {
        [self.floatingButton removeFromSuperview];
        [window addSubview:self.floatingButton];
    }
    [window bringSubviewToFront:self.floatingButton];
}

- (void)updateVisibility {
    if (self.floatingButton) {
        // Evaluate visibility again
        if (self.currentWindow) {
            UIViewController *topVC = self.currentWindow.rootViewController;
            while (topVC.presentedViewController) {
                topVC = topVC.presentedViewController;
            }
            if ([topVC isKindOfClass:[UINavigationController class]]) {
                topVC = [(UINavigationController *)topVC topViewController];
            }
            NSString *vcClass = NSStringFromClass([topVC class]);
            if ([vcClass containsString:@"MainFeed"] || [vcClass isEqualToString:@"IGFeedViewController"]) {
                self.floatingButton.hidden = YES;
                return;
            }
        }
        self.floatingButton.hidden = NO;
    }
}

- (void)setupFloatingButton {
    CGFloat buttonSize = 56;
    CGRect frame = CGRectMake([UIScreen mainScreen].bounds.size.width - buttonSize - 20,
                              [UIScreen mainScreen].bounds.size.height - buttonSize - 100,
                              buttonSize, buttonSize);
    
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = frame;
    
    // Şık ve %100 Güvenli Dark Mode Tasarımı (Memory Leak / Crash yapmaz)
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.92];
    self.floatingButton.layer.cornerRadius = buttonSize / 2.0;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.65 alpha:1.0].CGColor;
    
    // Gölgelendirme
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOpacity = 0.35;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.floatingButton.layer.shadowRadius = 6.0;
    
    // Başlık ve İkon
    [self.floatingButton setTitle:@"✦" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightMedium];
    
    // Etkileşimler
    [self.floatingButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];
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

- (void)buttonTapped {
    extern void ShowFloatingModMenu(void);
    ShowFloatingModMenu();
}

@end

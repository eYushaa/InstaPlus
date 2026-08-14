#import "FloatingVoiceButtonManager.h"
#import "VoiceGalleryViewController.h"

@interface FloatingVoiceButtonManager ()
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, weak) UIWindow *currentWindow;
@end

@implementation FloatingVoiceButtonManager

+ (instancetype)sharedManager {
    static FloatingVoiceButtonManager *sharedManager = nil;
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
    
    self.currentWindow = window;
    
    if (!self.floatingButton) {
        [self setupFloatingButton];
    }
    
    if (self.floatingButton.superview != window) {
        [self.floatingButton removeFromSuperview];
        [window addSubview:self.floatingButton];
    }
    [window bringSubviewToFront:self.floatingButton];
    [self updateVisibility];
}

- (void)setupFloatingButton {
    CGFloat buttonSize = 52;
    CGRect frame = CGRectMake(20,
                              [UIScreen mainScreen].bounds.size.height - buttonSize - 120,
                              buttonSize, buttonSize);
    
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = frame;
    
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.92];
    self.floatingButton.layer.cornerRadius = buttonSize / 2.0;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0].CGColor;
    
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOpacity = 0.4;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.floatingButton.layer.shadowRadius = 6.0;
    
    [self.floatingButton setTitle:@"🎵" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:22];
    
    [self.floatingButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];
}

- (void)updateVisibility {
    BOOL enabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"voice_gallery_button_enabled"]) {
        enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"voice_gallery_button_enabled"];
    }
    self.floatingButton.hidden = !enabled;
}

- (void)buttonTapped {
    [self toggleVoiceGallery];
}

- (void)toggleVoiceGallery {
    if ([VoiceGalleryViewController isPresented]) {
        [VoiceGalleryViewController dismissCurrentOverlay];
    } else {
        [VoiceGalleryViewController showOverlay];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    if (!button) return;
    
    CGPoint translation = [gesture translationInView:button.superview];
    button.center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:button.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint newCenter = button.center;
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat margin = button.bounds.size.width / 2.0 + 10;
        
        if (newCenter.x < screenWidth / 2.0) {
            newCenter.x = margin;
        } else {
            newCenter.x = screenWidth - margin;
        }
        
        if (newCenter.y < 80) newCenter.y = 80;
        if (newCenter.y > screenHeight - 80) newCenter.y = screenHeight - 80;
        
        [UIView animateWithDuration:0.3 animations:^{
            button.center = newCenter;
        }];
    }
}

@end

#import <UIKit/UIKit.h>

@interface FloatingVoiceButtonManager : NSObject
+ (instancetype)sharedManager;
- (void)attachToWindow:(UIWindow *)window;
- (void)updateVisibility;
- (void)toggleVoiceGallery;
@end

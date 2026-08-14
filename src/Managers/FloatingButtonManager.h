#import <UIKit/UIKit.h>

@interface FloatingButtonManager : NSObject
+ (instancetype)sharedManager;
- (void)attachToWindow:(UIWindow *)window;
- (void)updateVisibility;
@end

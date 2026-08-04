#import <UIKit/UIKit.h>

@interface DMMediaOverlayManager : NSObject

+ (instancetype)sharedManager;
- (void)showOverlayIfNeeded;
- (void)hideOverlay;
- (BOOL)saveCurrentActiveMediaWithToast:(BOOL)showToast;
- (NSString *)detectActiveUsername;

@end

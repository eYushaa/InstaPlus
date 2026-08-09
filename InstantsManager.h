#import <UIKit/UIKit.h>

@interface InstantsManager : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

+ (instancetype)sharedManager;
- (void)presentImagePickerWithCroppingFromViewController:(UIViewController *)presentingVC;
- (void)showInstantPickerButton;
- (void)hideInstantPickerButton;
- (UIImage *)pendingInstantImage;
- (void)clearPendingInstantImage;

@end

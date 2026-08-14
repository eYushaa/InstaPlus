#import <UIKit/UIKit.h>

@interface VoiceGalleryViewController : UIViewController
+ (void)showOverlay;
+ (BOOL)isPresented;
+ (void)dismissCurrentOverlay;
@end

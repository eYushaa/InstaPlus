#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MediaExtractor : NSObject

// Ekrandaki en büyük UIImageView'ı bulup içindeki resmi alır
+ (UIImage *)extractLargestImageFromScreen;

// Ekrandaki aktif AVPlayerLayer / AVPlayer'dan oynatılan video URL'sini çıkarır
+ (NSURL *)extractActiveVideoURLFromScreen;
+ (NSURL *)extractActiveVideoURLFromScreenWithLog:(NSMutableString *)log;
+ (NSDictionary *)extractActiveMediaContextFromScreen;
+ (NSDictionary *)extractActiveMediaContextFromScreenWithLog:(NSMutableString *)log;
+ (NSDictionary *)extractMediaContextFromView:(UIView *)view withLog:(NSMutableString *)log;

// Exposed for Tweak.x to deeply extract URL from highly nested Instagram objects
+ (NSURL *)deepExtractURLFromObject:(id)obj;
+ (void)clearGlobalVideoCache;

@end

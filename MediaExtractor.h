#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MediaExtractor : NSObject

// Ekrandaki en büyük UIImageView'ı bulup içindeki resmi alır
+ (UIImage *)extractLargestImageFromScreen;

// Ekrandaki aktif AVPlayerLayer / AVPlayer'dan oynatılan video URL'sini çıkarır
+ (NSURL *)extractActiveVideoURLFromScreen;
+ (NSURL *)extractActiveVideoURLFromScreenWithLog:(NSMutableString *)log;

@end

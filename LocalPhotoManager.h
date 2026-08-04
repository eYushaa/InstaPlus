#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LocalPhotoManager : NSObject

+ (instancetype)sharedManager;

// Medyayı Documents/InstaPlus_Gallery/<username>/ dizinine kaydeder (Fotoğraf veya Video)
- (BOOL)saveImage:(UIImage *)image forUsername:(NSString *)username error:(NSError **)error;
- (BOOL)saveVideoFromURL:(NSURL *)videoURL forUsername:(NSString *)username error:(NSError **)error;

// Çift kaydetmeyi (mükerrer kayıt) önlemek için medya anahtarı kontrolü
- (BOOL)isMediaAlreadySaved:(NSString *)key;
- (void)addSavedMediaKey:(NSString *)key;

// InstaPlus_Gallery altındaki klasör (kullanıcı) isimlerini döner
- (NSArray<NSString *> *)getSavedUsernames;

// Belirli bir kullanıcıya ait tüm dosyaların yollarını döner
- (NSArray<NSString *> *)getImagesForUsername:(NSString *)username;
- (NSArray<NSString *> *)getMediaForUsername:(NSString *)username;

// Kullanıcı klasörünü ve tüm içeriğini siler
- (BOOL)deleteGalleryForUsername:(NSString *)username error:(NSError **)error;

@end

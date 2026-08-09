#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface C2MMediaItem : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, strong) NSString *senderName;
@property (nonatomic, strong) NSString *senderId;
@end

@interface C2MUserFolder : NSObject
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *folderPath;
@property (nonatomic, strong) NSArray<C2MMediaItem *> *mediaItems;
@end

@interface C2MLocalStorage : NSObject

+ (instancetype)shared;
- (NSString *)baseDirectory;
- (NSString *)getVoicesFolder;
- (NSString *)folderPathForUserId:(NSString *)userId displayName:(NSString *)displayName;

// Kayıt metodları
- (void)saveImage:(UIImage *)image fromVC:(UIViewController *)vc completion:(void(^_Nullable)(BOOL ok, NSString *_Nullable summary))completion;
- (void)saveVideoAtURL:(NSURL *)videoURL fromVC:(UIViewController *)vc completion:(void(^_Nullable)(BOOL ok, NSString *_Nullable summary))completion;
- (NSDictionary *)extractUserInfoFromVC:(UIViewController *)vc allowUIFallback:(BOOL)allowUIFallback;

// Galeri için okuma
- (NSArray<C2MUserFolder *> *)getAllUserFolders;
- (void)deleteMediaItem:(C2MMediaItem *)item inFolder:(C2MUserFolder *)folder completion:(void(^_Nullable)(BOOL ok))completion;
- (void)deleteAllMediaForUser:(C2MUserFolder *)folder completion:(void(^_Nullable)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END

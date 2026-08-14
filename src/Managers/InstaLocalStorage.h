#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InstaMediaItem : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, strong) NSString *senderName;
@property (nonatomic, strong) NSString *senderId;
@end

@interface InstaUserFolder : NSObject
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *folderPath;
@property (nonatomic, strong) NSArray<InstaMediaItem *> *mediaItems;
@end

@interface InstaLocalStorage : NSObject

+ (instancetype)shared;
- (NSString *)baseDirectory;
- (NSString *)getVoicesFolder;
- (NSString *)folderPathForUserId:(NSString *)userId displayName:(NSString *)displayName;

@end

NS_ASSUME_NONNULL_END

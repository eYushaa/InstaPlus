#import "InstaLocalStorage.h"

NSString *globalSelectedVoicePath = nil;

@implementation InstaMediaItem
@end

@implementation InstaUserFolder
@end

@implementation InstaLocalStorage

static InstaLocalStorage *sharedInstance = nil;
static dispatch_once_t sharedOnceToken;

+ (instancetype)shared {
    dispatch_once(&sharedOnceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSString *)baseDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    NSString *dir = [docs stringByAppendingPathComponent:@"InstaGallery"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (NSString *)getVoicesFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    NSString *voicesFolder = [docs stringByAppendingPathComponent:@"Insta_Voices"];
    
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:voicesFolder isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:voicesFolder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return voicesFolder;
}

- (NSString *)folderPathForUserId:(NSString *)userId displayName:(NSString *)displayName {
    NSString *folderName = displayName.length > 0 ? displayName : (userId.length > 0 ? userId : @"General");
    folderName = [folderName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    folderName = [folderName stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
    
    NSString *path = [[self baseDirectory] stringByAppendingPathComponent:folderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

@end

#import "LocalPhotoManager.h"
#import <Photos/Photos.h>
@implementation LocalPhotoManager

static NSMutableSet *gSavedMediaKeys = nil;

+ (instancetype)sharedManager {
    static LocalPhotoManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)baseGalleryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    return [documentsDirectory stringByAppendingPathComponent:@"InstaPlus_Gallery"];
}

- (BOOL)saveImage:(UIImage *)image forUsername:(NSString *)username error:(NSError **)error {
    if (!image || !username || username.length == 0) return NO;
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.95);
    if (!imageData || imageData.length == 0) return NO;
    
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:userFolderPath]) {
        [fm createDirectoryAtPath:userFolderPath withIntermediateDirectories:YES attributes:nil error:error];
    }
    
    NSString *fileName = [NSString stringWithFormat:@"photo_%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [userFolderPath stringByAppendingPathComponent:fileName];
    
    BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:error];
    return success;
}

static NSURL *cleanVideoURL(NSURL *url) {
    if (!url) return nil;
    if ([url isFileURL]) return url;
    
    NSString *urlStr = url.absoluteString;
    // DO NOT strip parameters if the URL has a signature, otherwise 403 Forbidden
    if ([urlStr containsString:@"_nc_ht="] || [urlStr containsString:@"efg="] || [urlStr containsString:@"_nc_cat="]) {
        return url;
    }
    
    BOOL hasRangeParams = [urlStr containsString:@"bytestart="] || 
                         [urlStr containsString:@"byteend="] || 
                         [urlStr containsString:@"bytestart"] || 
                         [urlStr containsString:@"range="] || 
                         [urlStr containsString:@"seg-"];
                         
    if (hasRangeParams) {
        NSURLComponents *components = [NSURLComponents componentsWithString:urlStr];
        NSMutableArray<NSURLQueryItem *> *filteredItems = [NSMutableArray array];
        for (NSURLQueryItem *item in components.queryItems) {
            NSString *lowerName = item.name.lowercaseString;
            if (![lowerName containsString:@"bytestart"] && 
                ![lowerName containsString:@"byteend"] && 
                ![lowerName isEqualToString:@"range"]) {
                [filteredItems addObject:item];
            }
        }
        components.queryItems = filteredItems;
        if (components.URL) return components.URL;
    }
    return url;
}


static NSString *gLastSavedVideoURLString = nil;
static NSTimeInterval gLastSavedVideoTime = 0;

- (BOOL)saveVideoFromURL:(NSURL *)videoURL forUsername:(NSString *)username error:(NSError **)error {
    if (!videoURL || !username || username.length == 0) return NO;
    
    videoURL = cleanVideoURL(videoURL);
    NSString *urlKey = videoURL.absoluteString;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (gLastSavedVideoURLString && [gLastSavedVideoURLString isEqualToString:urlKey] && (now - gLastSavedVideoTime < 5.0)) {
        NSLog(@"[InstaPlus] Deduplication: video already saved within last 5s. Skipping duplicate save.");
        return YES;
    }
    
    gLastSavedVideoURLString = urlKey;
    gLastSavedVideoTime = now;
    
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:userFolderPath]) {
        [fm createDirectoryAtPath:userFolderPath withIntermediateDirectories:YES attributes:nil error:error];
    }
    
    NSString *fileName = [NSString stringWithFormat:@"video_%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [userFolderPath stringByAppendingPathComponent:fileName];
    
    BOOL success = NO;
    if ([videoURL isFileURL]) {
        NSLog(@"[InstaPlus] saveVideoFromURL: isFileURL: %@", videoURL.absoluteString);
        success = [fm copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:filePath] error:error];
    } else {
        NSLog(@"[InstaPlus] saveVideoFromURL: starting download for URL: %@", videoURL.absoluteString);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:videoURL];
        
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSData *downloadedData = nil;
        __block NSError *downloadError = nil;
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable err) {
            downloadedData = data;
            downloadError = err;
            dispatch_semaphore_signal(semaphore);
        }];
        [task resume];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        
        if (downloadedData && downloadedData.length > 10000) {
            NSLog(@"[InstaPlus] saveVideoFromURL: Download finished. Size: %lu bytes", (unsigned long)downloadedData.length);
            success = [downloadedData writeToFile:filePath options:NSDataWritingAtomic error:error];
        } else {
            NSLog(@"[InstaPlus] saveVideoFromURL: Download failed or size too small. Error: %@", downloadError);
            if (error && downloadError) *error = downloadError;
        }
    }
    
    return success;
}

- (NSArray<NSString *> *)getSavedUsernames {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *basePath = [self baseGalleryPath];
    
    if (![fm fileExistsAtPath:basePath]) {
        return @[];
    }
    
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:basePath error:&error];
    if (error) return @[];
    
    NSMutableArray *usernames = [NSMutableArray array];
    for (NSString *item in contents) {
        BOOL isDir = NO;
        NSString *fullPath = [basePath stringByAppendingPathComponent:item];
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [usernames addObject:item];
        }
    }
    
    return usernames;
}

- (NSArray<NSString *> *)getImagesForUsername:(NSString *)username {
    return [self getMediaForUsername:username];
}

- (NSArray<NSString *> *)getMediaForUsername:(NSString *)username {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    
    if (![fm fileExistsAtPath:userFolderPath]) {
        return @[];
    }
    
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:userFolderPath error:&error];
    if (error) return @[];
    
    NSMutableArray *mediaPaths = [NSMutableArray array];
    for (NSString *item in contents) {
        NSString *fullPath = [userFolderPath stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            NSString *lower = item.lowercaseString;
            if ([lower hasSuffix:@".jpg"] || [lower hasSuffix:@".jpeg"] || [lower hasSuffix:@".png"] || [lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
                [mediaPaths addObject:fullPath];
            }
        }
    }
    
    // Sort by modification date (newest first)
    [mediaPaths sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
        NSDictionary *attrs1 = [fm attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attrs2 = [fm attributesOfItemAtPath:path2 error:nil];
        NSDate *date1 = attrs1[NSFileModificationDate];
        NSDate *date2 = attrs2[NSFileModificationDate];
        return [date2 compare:date1]; // descending
    }];
    
    return mediaPaths;
}

- (NSArray<NSString *> *)getAllMedia {
    NSMutableArray *allMedia = [NSMutableArray array];
    NSArray *usernames = [self getSavedUsernames];
    for (NSString *un in usernames) {
        [allMedia addObjectsFromArray:[self getMediaForUsername:un]];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [allMedia sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
        NSDictionary *attrs1 = [fm attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attrs2 = [fm attributesOfItemAtPath:path2 error:nil];
        NSDate *date1 = attrs1[NSFileModificationDate];
        NSDate *date2 = attrs2[NSFileModificationDate];
        return [date2 compare:date1];
    }];
    
    return allMedia;
}

- (BOOL)deleteMediaAtPath:(NSString *)path error:(NSError **)error {
    if (!path) return NO;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (BOOL)deleteGalleryForUsername:(NSString *)username error:(NSError **)error {
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:userFolderPath]) {
        return [fm removeItemAtPath:userFolderPath error:error];
    }
    return YES;
}

@end

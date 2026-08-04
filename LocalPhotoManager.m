#import "LocalPhotoManager.h"

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

- (BOOL)isMediaAlreadySaved:(NSString *)key {
    if (!key || key.length == 0) return NO;
    @synchronized (self) {
        if (!gSavedMediaKeys) {
            NSArray *persisted = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"InstaPlus_SavedMediaKeys"];
            if (persisted) gSavedMediaKeys = [NSMutableSet setWithArray:persisted];
            else gSavedMediaKeys = [NSMutableSet set];
        }
        return [gSavedMediaKeys containsObject:key];
    }
}

- (void)addSavedMediaKey:(NSString *)key {
    if (!key || key.length == 0) return;
    @synchronized (self) {
        if (!gSavedMediaKeys) gSavedMediaKeys = [NSMutableSet set];
        [gSavedMediaKeys addObject:key];
        
        if (gSavedMediaKeys.count > 600) {
            NSArray *all = [gSavedMediaKeys allObjects];
            gSavedMediaKeys = [NSMutableSet setWithArray:[all subarrayWithRange:NSMakeRange(all.count - 400, 400)]];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:[gSavedMediaKeys allObjects] forKey:@"InstaPlus_SavedMediaKeys"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (BOOL)saveImage:(UIImage *)image forUsername:(NSString *)username error:(NSError **)error {
    if (!image || !username || username.length == 0) return NO;
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.95);
    if (!imageData || imageData.length == 0) return NO;
    
    NSString *mediaKey = [NSString stringWithFormat:@"%@_img_%lu_%ldx%ld", username, (unsigned long)imageData.length, (long)image.size.width, (long)image.size.height];
    if ([self isMediaAlreadySaved:mediaKey]) {
        return YES; // Mükerrer kayıt engellendi
    }
    
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:userFolderPath]) {
        [fm createDirectoryAtPath:userFolderPath withIntermediateDirectories:YES attributes:nil error:error];
    }
    
    NSString *fileName = [NSString stringWithFormat:@"photo_%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [userFolderPath stringByAppendingPathComponent:fileName];
    
    BOOL success = [imageData writeToFile:filePath options:NSDataWritingAtomic error:error];
    if (success) {
        [self addSavedMediaKey:mediaKey];
    }
    return success;
}

static NSURL *cleanVideoURL(NSURL *url) {
    if (!url) return nil;
    if ([url isFileURL]) return url;
    
    NSString *urlStr = url.absoluteString;
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

- (BOOL)saveVideoFromURL:(NSURL *)videoURL forUsername:(NSString *)username error:(NSError **)error {
    if (!videoURL || !username || username.length == 0) return NO;
    
    videoURL = cleanVideoURL(videoURL);
    NSUInteger urlHash = [videoURL.absoluteString hash];
    NSString *mediaKey = [NSString stringWithFormat:@"%@_vid_%lu", username, (unsigned long)urlHash];
    if ([self isMediaAlreadySaved:mediaKey]) {
        return YES; // Mükerrer kayıt engellendi
    }
    
    NSString *userFolderPath = [[self baseGalleryPath] stringByAppendingPathComponent:username];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:userFolderPath]) {
        [fm createDirectoryAtPath:userFolderPath withIntermediateDirectories:YES attributes:nil error:error];
    }
    
    NSString *fileName = [NSString stringWithFormat:@"video_%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [userFolderPath stringByAppendingPathComponent:fileName];
    
    BOOL success = NO;
    if ([videoURL isFileURL]) {
        success = [fm copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:filePath] error:error];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:videoURL];
        [request setValue:@"Instagram/200.0.0.0.0 (iPhone; iOS 15.0; Scale/3.00)" forHTTPHeaderField:@"User-Agent"];
        
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
        
        if (downloadedData && downloadedData.length > 50000) {
            success = [downloadedData writeToFile:filePath options:NSDataWritingAtomic error:error];
        } else {
            if (error && downloadError) *error = downloadError;
        }
    }
    
    if (success) {
        [self addSavedMediaKey:mediaKey];
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
        NSString *lower = item.lowercaseString;
        if ([lower hasSuffix:@".jpg"] || [lower hasSuffix:@".jpeg"] || [lower hasSuffix:@".png"] || [lower hasSuffix:@".mp4"]) {
            [mediaPaths addObject:fullPath];
        }
    }
    
    return mediaPaths;
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

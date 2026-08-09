#import "MediaExtractor.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@implementation MediaExtractor

extern NSURL *gLastPlayingVideoURL;
extern id gLastPlayingMediaObject;
extern NSTimeInterval gLastPlayingVideoTime;

+ (NSURL *)extractActiveVideoURLFromScreen {
    NSMutableString *dummyLog = [NSMutableString string];
    return [self extractActiveVideoURLFromScreenWithLog:dummyLog];
}

// ============================================================================
// HELPER: URL STRICTNESS CHECKS
// ============================================================================

static NSString *cleanPathFromURLString(NSString *str) {
    if (!str) return @"";
    NSRange qRange = [str rangeOfString:@"?"];
    if (qRange.location != NSNotFound) {
        return [str substringToIndex:qRange.location].lowercaseString;
    }
    return str.lowercaseString;
}

static BOOL isStrictVideoURL(NSString *str) __attribute__((unused));
static BOOL isStrictVideoURL(NSString *str) {
    if (!str || str.length == 0) return NO;
    if (![str hasPrefix:@"http"] && ![str hasPrefix:@"file:"]) return NO;
    
    NSString *cleanPath = cleanPathFromURLString(str);
    if ([cleanPath hasSuffix:@".jpg"] || [cleanPath hasSuffix:@".jpeg"] || [cleanPath hasSuffix:@".png"] || [cleanPath hasSuffix:@".webp"]) {
        return NO;
    }
    return YES;
}

static BOOL isStrictPhotoURL(NSString *str) {
    if (!str || str.length == 0 || ![str hasPrefix:@"http"]) return NO;
    NSString *cleanPath = cleanPathFromURLString(str);
    if ([cleanPath hasSuffix:@".mp4"] || [cleanPath hasSuffix:@".m4v"] || [cleanPath containsString:@"/t50."] || [cleanPath hasSuffix:@".m3u8"]) {
        return NO;
    }
    return YES;
}

// ============================================================================
// 1. CELL AREA DETECTION & MEDIA TYPE INFERENCE
// ============================================================================

static void determineBestCell(UIView *view, UIView * __strong *bestCell, CGFloat *maxArea) {
    if (!view || view.isHidden || view.alpha < 0.05) return;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    if ([view isKindOfClass:[UICollectionView class]] || [view isKindOfClass:[UITableView class]]) {
        NSArray *cells = nil;
        if ([view isKindOfClass:[UICollectionView class]]) cells = [(UICollectionView *)view visibleCells];
        else cells = [(UITableView *)view visibleCells];
        
        for (UIView *cell in cells) {
            CGRect cellFrame = [cell convertRect:cell.bounds toView:nil];
            CGRect intersect = CGRectIntersection(cellFrame, screenBounds);
            if (!CGRectIsNull(intersect)) {
                CGFloat area = intersect.size.width * intersect.size.height;
                if (area > *maxArea) {
                    *maxArea = area;
                    *bestCell = cell;
                }
            }
        }
    }
    
    for (UIView *sub in view.subviews) {
        determineBestCell(sub, bestCell, maxArea);
    }
}

static NSInteger detectMediaTypeFromCell(UIView *cell) {
    if (!cell) return 0;
    
    NSArray *modelProps = @[@"post", @"item", @"media", @"feedItem", @"viewModel", @"model", @"messageItem", @"sundialVideo"];
    for (NSString *prop in modelProps) {
        @try {
            id model = [cell valueForKey:prop];
            if (model) {
                NSArray *typeProps = @[@"mediaType", @"media_type"];
                for (NSString *tProp in typeProps) {
                    @try {
                        id typeVal = [model valueForKey:tProp];
                        if ([typeVal respondsToSelector:@selector(integerValue)]) {
                            NSInteger t = [typeVal integerValue];
                            if (t > 0) return t;
                        }
                    } @catch(NSException *e) {}
                }
            }
        } @catch(NSException *e) {}
    }
    
    for (UIView *sub in cell.subviews) {
        for (NSString *prop in modelProps) {
            @try {
                id model = [sub valueForKey:prop];
                if (model) {
                    NSArray *typeProps = @[@"mediaType", @"media_type"];
                    for (NSString *tProp in typeProps) {
                        @try {
                            id typeVal = [model valueForKey:tProp];
                            if ([typeVal respondsToSelector:@selector(integerValue)]) {
                                NSInteger t = [typeVal integerValue];
                                if (t > 0) return t;
                            }
                        } @catch(NSException *e) {}
                    }
                }
            } @catch(NSException *e) {}
        }
    }
    
    NSString *cls = NSStringFromClass([cell class]);
    if ([cls containsString:@"Video"] || [cls containsString:@"Sundial"] || [cls containsString:@"Reel"]) return 2;
    if ([cls containsString:@"Photo"] || [cls containsString:@"Image"]) return 1;
    if ([cls containsString:@"Carousel"]) return 8;
    
    return 0;
}

// ============================================================================
// 2. VIDEO EXTRACTION ENGINE
// ============================================================================

static NSURL *extractURLFromPlayerLayer(CALayer *layer, NSMutableString *log) {
    if (!layer) return nil;
    
    if ([layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
        AVPlayerItem *item = playerLayer.player.currentItem;
        if ([item.asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)item.asset URL];
            if (url && ([url.absoluteString hasPrefix:@"http"] || url.isFileURL)) {
                [log appendFormat:@"[PlayerLayer] Found AVURLAsset URL: %@\n", url.lastPathComponent];
                return url;
            }
        }
    }
    
    NSString *layerClass = NSStringFromClass([layer class]);
    if ([layerClass containsString:@"FNF"] || [layerClass containsString:@"Video"] || [layerClass containsString:@"Player"] || [layerClass containsString:@"AVPlayer"]) {
        NSArray *props = @[@"player", @"asset", @"representation", @"url", @"videoURL", @"currentURL", @"streamURL", @"video", @"media", @"videoSpec"];
        for (NSString *p in props) {
            @try {
                id val = [layer valueForKey:p];
                if ([val isKindOfClass:[NSURL class]]) {
                    NSURL *u = (NSURL *)val;
                    if ([u.absoluteString hasPrefix:@"http"] || u.isFileURL) return u;
                } else if ([val isKindOfClass:[NSString class]] && ([(NSString *)val hasPrefix:@"http"] || [(NSString *)val hasPrefix:@"file:"])) {
                    return [NSURL URLWithString:(NSString *)val];
                } else if (val) {
                    @try {
                        id subUrl = [val valueForKey:@"url"] ?: [val valueForKey:@"videoURL"];
                        if ([subUrl isKindOfClass:[NSURL class]]) return (NSURL *)subUrl;
                        else if ([subUrl isKindOfClass:[NSString class]]) return [NSURL URLWithString:(NSString *)subUrl];
                    } @catch(NSException *e) {}
                }
            } @catch(NSException *e) {}
        }
    }
    return nil;
}

static void traverseHierarchyForActivePlayer(UIView *view, NSURL * __strong *bestURL, CGFloat *minDist, NSMutableString *log) {
    if (!view || view.isHidden || view.alpha < 0.05) return;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGPoint screenCenter = CGPointMake(screenBounds.size.width / 2.0, screenBounds.size.height / 2.0);
    
    CGRect globalFrame = [view convertRect:view.bounds toView:nil];
    CGRect intersection = CGRectIntersection(globalFrame, screenBounds);
    
    if (!CGRectIsNull(intersection) && intersection.size.height > 100) {
        CGFloat viewCenterY = globalFrame.origin.y + globalFrame.size.height / 2.0;
        CGFloat dist = fabs(viewCenterY - screenCenter.y);
        
        NSMutableArray *layersToCheck = [NSMutableArray array];
        if (view.layer) [layersToCheck addObject:view.layer];
        if (view.layer.sublayers) [layersToCheck addObjectsFromArray:view.layer.sublayers];
        
        for (CALayer *layer in layersToCheck) {
            if ([layer isKindOfClass:[AVPlayerLayer class]]) {
                AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
                AVPlayer *player = playerLayer.player;
                BOOL isPlaying = (player && player.rate > 0.01);
                
                AVPlayerItem *item = player.currentItem;
                if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                    NSURL *url = [(AVURLAsset *)item.asset URL];
                    if (url && [url.absoluteString hasPrefix:@"http"]) {
                        CGFloat effectiveDist = isPlaying ? (dist * 0.1) : dist;
                        if (effectiveDist < *minDist) {
                            *minDist = effectiveDist;
                            *bestURL = url;
                            [log appendFormat:@"[PlayerLayer] Found playing AVURLAsset (dist: %.0f, playing: %d)\n", dist, isPlaying];
                        }
                    }
                }
            } else {
                NSURL *found = extractURLFromPlayerLayer(layer, log);
                if (found && dist < *minDist) {
                    *minDist = dist;
                    *bestURL = found;
                }
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        traverseHierarchyForActivePlayer(subview, bestURL, minDist, log);
    }
}

static NSURL *extractVideoURLFromObjectInternal(id obj, int depth, NSMutableSet *visitedObjects, NSMutableString *log) {
    if (!obj || depth > 5) return nil;
    if ([visitedObjects containsObject:obj]) return nil;
    [visitedObjects addObject:obj];
    
    @try {
        id urlsObj = [obj valueForKey:@"allVideoURLs"];
        if ([urlsObj isKindOfClass:[NSSet class]] && [(NSSet *)urlsObj count] > 0) {
            for (id u in (NSSet *)urlsObj) {
                if ([u isKindOfClass:[NSURL class]]) {
                    NSString *str = [(NSURL *)u absoluteString];
                    if (![str containsString:@".m3u8"]) {
                        return (NSURL *)u;
                    }
                }
            }
        }
        id sortedObj = [obj valueForKey:@"sortedVideoURLsBySize"];
        if ([sortedObj isKindOfClass:[NSArray class]] && [(NSArray *)sortedObj count] > 0) {
            id first = [(NSArray *)sortedObj firstObject];
            if ([first isKindOfClass:[NSDictionary class]]) {
                id u = first[@"url"];
                if ([u isKindOfClass:[NSString class]] && [(NSString *)u hasPrefix:@"http"]) {
                    return [NSURL URLWithString:(NSString *)u];
                }
            }
        }
    } @catch(NSException *e) {}

    NSArray *versionPropNames = @[@"videoVersions", @"video_versions", @"videoUrls", @"typed_video_urls", @"video_versions_dict"];
    for (NSString *propName in versionPropNames) {
        @try {
            id versions = [obj valueForKey:propName];
            if ([versions isKindOfClass:[NSArray class]] && [(NSArray *)versions count] > 0) {
                NSURL *bestURL = nil;
                NSInteger maxArea = -1;
                
                for (id ver in (NSArray *)versions) {
                    NSURL *candURL = nil;
                    NSInteger w = 0, h = 0;
                    
                    if ([ver isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *dict = (NSDictionary *)ver;
                        id u = dict[@"url"] ?: dict[@"videoURL"] ?: dict[@"src"];
                        if ([u isKindOfClass:[NSString class]]) candURL = [NSURL URLWithString:(NSString *)u];
                        else if ([u isKindOfClass:[NSURL class]]) candURL = (NSURL *)u;
                        w = [dict[@"width"] integerValue];
                        h = [dict[@"height"] integerValue];
                    } else {
                        @try {
                            id u = [ver valueForKey:@"url"] ?: [ver valueForKey:@"videoURL"];
                            if ([u isKindOfClass:[NSString class]]) candURL = [NSURL URLWithString:(NSString *)u];
                            else if ([u isKindOfClass:[NSURL class]]) candURL = (NSURL *)u;
                            w = [[ver valueForKey:@"width"] integerValue];
                            h = [[ver valueForKey:@"height"] integerValue];
                        } @catch(NSException *e) {}
                    }
                    
                    if (candURL) {
                        NSString *str = candURL.absoluteString;
                        BOOL isChunked = [str containsString:@".m3u8"];
                        if (!isChunked) {
                            NSInteger area = w * h;
                            if (area > maxArea) {
                                maxArea = area;
                                bestURL = candURL;
                            } else if (!bestURL) {
                                bestURL = candURL;
                            }
                        }
                    }
                }
                if (bestURL) return bestURL;
            }
        } @catch(NSException *e) {}
    }
    
    NSArray *subObjNames = @[
        @"video", @"media", @"feedItem", @"currentMedia", @"currentClipsItem", 
        @"currentItem", @"item", @"post", @"videoSpec", @"visualMessage",
        @"directVisualMessage", @"content", @"mediaContent", @"message",
        @"messageItem", @"currentVisualMessage", @"sundialVideo", @"model", @"viewModel"
    ];
    for (NSString *subName in subObjNames) {
        @try {
            id subObj = [obj valueForKey:subName];
            if (subObj && subObj != obj) {
                NSURL *found = extractVideoURLFromObjectInternal(subObj, depth + 1, visitedObjects, log);
                if (found) return found;
            }
        } @catch(NSException *e) {}
    }

    NSArray *urlPropNames = @[@"videoURL", @"videoUrl", @"mediaURL", @"playbackURL", @"video_url", @"hdVideoURL"];
    for (NSString *propName in urlPropNames) {
        @try {
            id val = [obj valueForKey:propName];
            if ([val isKindOfClass:[NSURL class]]) {
                NSString *str = [(NSURL *)val absoluteString];
                if ([str hasPrefix:@"http"]) {
                    return (NSURL *)val;
                }
            } else if ([val isKindOfClass:[NSString class]]) {
                NSString *str = (NSString *)val;
                if ([str hasPrefix:@"http"] && ([str containsString:@".mp4"] || [str containsString:@"/v/t"] || [str containsString:@"cdninstagram"])) {
                    return [NSURL URLWithString:str];
                }
            }
        } @catch(NSException *e) {}
    }

    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        for (id item in (id<NSFastEnumeration>)obj) {
            NSURL *found = extractVideoURLFromObjectInternal(item, depth + 1, visitedObjects, log);
            if (found) return found;
        }
    }

    return nil;
}

static NSURL *extractVideoURLFromObject(id obj, NSMutableString *log) {
    NSMutableSet *visited = [NSMutableSet set];
    return extractVideoURLFromObjectInternal(obj, 0, visited, log);
}

+ (NSURL *)deepExtractURLFromObject:(id)obj {
    NSMutableSet *visited = [NSMutableSet set];
    NSMutableString *dummyLog = [NSMutableString new];
    return extractVideoURLFromObjectInternal(obj, 0, visited, dummyLog);
}

static UIViewController *getTopViewController(UIViewController *rootViewController) {
    if (!rootViewController) {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) {
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
        }
        rootViewController = keyWindow.rootViewController;
    }
    
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)rootViewController;
        return getTopViewController(tabBarController.selectedViewController);
    } else if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return getTopViewController(navigationController.visibleViewController);
    } else if (rootViewController.presentedViewController) {
        return getTopViewController(rootViewController.presentedViewController);
    } else if (rootViewController.childViewControllers.count > 0) {
        return getTopViewController(rootViewController.childViewControllers.lastObject);
    }
    
    return rootViewController;
}

+ (NSURL *)extractActiveVideoURLFromScreenWithLog:(NSMutableString *)log {
    [log appendFormat:@"[MediaExtractor] Running 6-Step Video Engine...\n"];
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (gLastPlayingMediaObject && (now - gLastPlayingVideoTime < 120.0)) {
        NSURL *progURL = extractVideoURLFromObject(gLastPlayingMediaObject, log);
        if (progURL) {
            [log appendFormat:@"[Step 1] Found video URL from hook media object!\n"];
            return progURL;
        }
    }
    
    UIViewController *topVC = getTopViewController(nil);
    if (topVC) {
        NSURL *modelURL = extractVideoURLFromObject(topVC, log);
        if (modelURL) {
            [log appendFormat:@"[Step 2] Found video URL from Top VC!\n"];
            return modelURL;
        }
    }
    
    if (gLastPlayingVideoURL && (now - gLastPlayingVideoTime < 120.0)) {
        if (![gLastPlayingVideoURL isFileURL]) {
            [log appendFormat:@"[Step 3] Found video URL from hook live URL!\n"];
            return gLastPlayingVideoURL;
        }
    }
    
    if (keyWindow) {
        NSURL *playerURL = nil;
        CGFloat minDist = CGFLOAT_MAX;
        traverseHierarchyForActivePlayer(keyWindow, &playerURL, &minDist, log);
        if (playerURL && ![playerURL isFileURL]) {
            [log appendFormat:@"[Step 4] Found video URL from visible player layer!\n"];
            return playerURL;
        }
    }
    
    [log appendFormat:@"[Step 5] Scanning disk cache for full .mp4 video files...\n"];
    NSArray *searchPaths = @[
        NSTemporaryDirectory(),
        [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *newestVideoURL = nil;
    NSTimeInterval freshestAge = 30.0;
    
    for (NSString *basePath in searchPaths) {
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:basePath]
                                     includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsDirectoryKey, NSURLFileSizeKey]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                    errorHandler:nil];
        for (NSURL *fileURL in enumerator) {
            NSNumber *isDirectory;
            [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            if ([isDirectory boolValue]) continue;
            
            NSString *fileName = fileURL.lastPathComponent.lowercaseString;
            if ([fileName containsString:@"stream_"] || [fileName hasPrefix:@"chunk_"]) continue;
            
            if ([fileName hasSuffix:@".mp4"]) {
                NSDate *modDate;
                [fileURL getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:nil];
                if (!modDate) continue;
                
                NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:modDate];
                if (age < 30.0) {
                    NSNumber *fileSize;
                    [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
                    if (fileSize.longLongValue > 1500000) { 
                        if (age < freshestAge) {
                            freshestAge = age;
                            newestVideoURL = fileURL;
                        }
                    }
                }
            }
        }
    }
    
    if (newestVideoURL) {
        [log appendFormat:@"[Step 5] Found video file in disk cache!\n"];
        return newestVideoURL;
    }
    
    [log appendFormat:@"[VideoEngine] All video extraction steps returned nil.\n"];
    return nil;
}

// ============================================================================
// 3. HD PHOTO EXTRACTION ENGINE
// ============================================================================

static NSURL *extractPhotoURLFromObjectInternal(id obj, int depth, NSMutableSet *visitedObjects) {
    if (!obj || depth > 4) return nil;
    if ([visitedObjects containsObject:obj]) return nil;
    [visitedObjects addObject:obj];
    
    if ([obj isKindOfClass:[UIView class]]) {
        NSString *className = NSStringFromClass([obj class]);
        if ([className containsString:@"Profile"] || [className containsString:@"Avatar"] || 
            [className containsString:@"Icon"] || [className containsString:@"Button"] ||
            [className containsString:@"Badge"] || [className containsString:@"Header"]) {
            return nil;
        }
    }
    
    @try {
        id imageVersions = [obj valueForKey:@"imageVersions2"] ?: [obj valueForKey:@"image_versions2"];
        if (imageVersions) {
            id candidates = [imageVersions valueForKey:@"candidates"];
            if ([candidates isKindOfClass:[NSArray class]] && [(NSArray *)candidates count] > 0) {
                id bestCand = [(NSArray *)candidates firstObject];
                id u = [bestCand valueForKey:@"url"];
                NSString *str = nil;
                if ([u isKindOfClass:[NSString class]]) str = (NSString *)u;
                else if ([u isKindOfClass:[NSURL class]]) str = [(NSURL *)u absoluteString];
                if (str && isStrictPhotoURL(str)) return [NSURL URLWithString:str];
            }
        }
    } @catch(NSException *e) {}
    
    NSArray *urlPropNames = @[@"imageURL", @"imageUrl", @"photoURL", @"url"];
    for (NSString *propName in urlPropNames) {
        @try {
            id val = [obj valueForKey:propName];
            NSString *str = nil;
            if ([val isKindOfClass:[NSURL class]]) str = [(NSURL *)val absoluteString];
            else if ([val isKindOfClass:[NSString class]]) str = (NSString *)val;
            if (str && isStrictPhotoURL(str)) return [NSURL URLWithString:str];
        } @catch(NSException *e) {}
    }
    
    NSArray *subObjNames = @[@"media", @"feedItem", @"currentMedia", @"currentItem", @"item", @"post", @"visualMessage", @"directVisualMessage", @"content", @"mediaContent", @"message", @"messageItem", @"currentVisualMessage", @"viewModel", @"model", @"storyItem", @"carouselItem", @"sundialVideo"];
    for (NSString *subName in subObjNames) {
        @try {
            id subObj = [obj valueForKey:subName];
            if (subObj && subObj != obj) {
                NSURL *found = extractPhotoURLFromObjectInternal(subObj, depth + 1, visitedObjects);
                if (found) return found;
            }
        } @catch(NSException *e) {}
    }
    
    if ([obj isKindOfClass:[UIView class]]) {
        for (UIView *subview in [(UIView *)obj subviews]) {
            NSURL *found = extractPhotoURLFromObjectInternal(subview, depth + 1, visitedObjects);
            if (found) return found;
        }
    }

    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        for (id item in (id<NSFastEnumeration>)obj) {
            NSURL *found = extractPhotoURLFromObjectInternal(item, depth + 1, visitedObjects);
            if (found) return found;
        }
    }
    return nil;
}

static NSURL *extractPhotoURLFromObject(id obj) {
    NSMutableSet *visited = [NSMutableSet set];
    return extractPhotoURLFromObjectInternal(obj, 0, visited);
}

static void traverseViewHierarchy(UIView *view, UIImageView * __strong *largestImageView, CGFloat *maxArea) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (imageView.image) {
            CGFloat area = imageView.bounds.size.width * imageView.bounds.size.height;
            if (area > *maxArea && area > 10000) {
                *maxArea = area;
                *largestImageView = imageView;
            }
        }
    }
    for (UIView *subview in view.subviews) traverseViewHierarchy(subview, largestImageView, maxArea);
}

+ (UIImage *)extractLargestImageFromScreen {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) { keyWindow = window; break; }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return nil;
    
    UIImageView *largestImageView = nil;
    CGFloat maxArea = 0;
    traverseViewHierarchy(keyWindow, &largestImageView, &maxArea);
    if (largestImageView && largestImageView.image) return largestImageView.image;
    
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, YES, [UIScreen mainScreen].scale);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:NO];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snapshot;
}

// ============================================================================
// 4. MAIN ENTRY POINT: MEDIA TYPE INFERENCE + PRECISION EXTRACTION
// ============================================================================

+ (NSDictionary *)extractActiveMediaContextFromScreenWithLog:(NSMutableString *)log {
    [log appendFormat:@"[MediaExtractor] Starting Context Extraction...\n"];
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
    }
    
    CGFloat maxArea = 0;
    UIView *bestCell = nil;
    if (keyWindow) {
        determineBestCell(keyWindow, &bestCell, &maxArea);
    }
    
    BOOL isVideoCell = NO;
    BOOL isPhotoCell = NO;
    if (bestCell) {
        NSInteger mediaType = detectMediaTypeFromCell(bestCell);
        if (mediaType == 1 || mediaType == 8) {
            isPhotoCell = YES;
        } else if (mediaType == 2) {
            isVideoCell = YES;
        } else {
            NSString *cls = NSStringFromClass([bestCell class]);
            isVideoCell = [cls containsString:@"Video"] || [cls containsString:@"Sundial"] || [cls containsString:@"Reel"];
            isPhotoCell = [cls containsString:@"Photo"] || [cls containsString:@"Image"];
        }
        [log appendFormat:@"[MediaExtractor] Best Cell (Max Area) is %@. mediaType=%ld, VideoCell=%d, PhotoCell=%d\n", NSStringFromClass([bestCell class]), (long)mediaType, isVideoCell, isPhotoCell];
    }
    
    if (isVideoCell) {
        [log appendFormat:@"[MediaExtractor] Explicit VIDEO cell detected.\n"];
        
        NSURL *cellVideoURL = extractVideoURLFromObject(bestCell, log);
        if (cellVideoURL && isStrictVideoURL(cellVideoURL.absoluteString)) {
            [log appendFormat:@"[MediaExtractor] Success! Extracted VIDEO URL from best cell: %@\n", cellVideoURL.lastPathComponent];
            return @{@"type": @"video", @"url": cellVideoURL};
        }
        
        NSURL *globalVideoURL = [self extractActiveVideoURLFromScreenWithLog:log];
        if (globalVideoURL) {
            return @{@"type": @"video", @"url": globalVideoURL};
        }
        
        // Explicitly return type 'video' without URL so DMMediaOverlayManager shows alert log!
        return @{@"type": @"video"};
    } 
    else if (isPhotoCell) {
        [log appendFormat:@"[MediaExtractor] Explicit PHOTO cell detected.\n"];
        
        NSURL *photoURL = extractPhotoURLFromObject(bestCell);
        if (photoURL && isStrictPhotoURL(photoURL.absoluteString)) {
            [log appendFormat:@"[MediaExtractor] Success! Extracted PHOTO URL from best cell: %@\n", photoURL.lastPathComponent];
            return @{@"type": @"photo", @"url": photoURL};
        }
        
        NSURL *videoURL = extractVideoURLFromObject(bestCell, log);
        if (videoURL && isStrictVideoURL(videoURL.absoluteString)) {
            return @{@"type": @"video", @"url": videoURL};
        }
    } 
    else {
        [log appendFormat:@"[MediaExtractor] Unknown cell type. Trying both...\n"];
        
        NSURL *cellVideo = extractVideoURLFromObject(bestCell, log);
        if (cellVideo && isStrictVideoURL(cellVideo.absoluteString)) {
            return @{@"type": @"video", @"url": cellVideo};
        }
        
        NSURL *globalVideo = [self extractActiveVideoURLFromScreenWithLog:log];
        if (globalVideo) {
            return @{@"type": @"video", @"url": globalVideo};
        }

        NSURL *cellPhoto = extractPhotoURLFromObject(bestCell);
        if (cellPhoto && isStrictPhotoURL(cellPhoto.absoluteString)) {
            return @{@"type": @"photo", @"url": cellPhoto};
        }
    }
    
    UIImage *largestImage = [self extractLargestImageFromScreen];
    if (largestImage) {
        [log appendFormat:@"[MediaExtractor] Success! Extracted UI Image Screenshot\n"];
        return @{@"type": @"photo", @"image": largestImage};
    }
    
    return nil;
}

+ (NSDictionary *)extractActiveMediaContextFromScreen {
    NSMutableString *log = [NSMutableString string];
    return [self extractActiveMediaContextFromScreenWithLog:log];
}

@end

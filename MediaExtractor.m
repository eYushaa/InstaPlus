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

static BOOL isIgnoredCellClass(NSString *clsName) {
    if (!clsName) return YES;
    if ([clsName containsString:@"UFI"] || 
        [clsName containsString:@"Comment"] || 
        [clsName containsString:@"Header"] || 
        [clsName containsString:@"Caption"] || 
        [clsName containsString:@"Footer"] || 
        [clsName containsString:@"Action"] || 
        [clsName containsString:@"Icon"] || 
        [clsName containsString:@"Button"] || 
        [clsName containsString:@"Bar"] || 
        [clsName containsString:@"Text"] || 
        [clsName containsString:@"Avatar"] || 
        [clsName containsString:@"Profile"] || 
        [clsName containsString:@"Badge"] || 
        [clsName containsString:@"Title"] ||
        [clsName containsString:@"Container"] || 
        [clsName containsString:@"Wrapper"] ||
        [clsName containsString:@"Control"]) {
        return YES;
    }
    return NO;
}

static void determineBestCell(UIView *view, UIView * __strong *bestCell, CGFloat *maxArea) {
    if (!view || view.isHidden || view.alpha < 0.05) return;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    if ([view isKindOfClass:[UICollectionView class]] || [view isKindOfClass:[UITableView class]]) {
        NSArray *cells = nil;
        if ([view isKindOfClass:[UICollectionView class]]) cells = [(UICollectionView *)view visibleCells];
        else cells = [(UITableView *)view visibleCells];
        
        for (UIView *cell in cells) {
            NSString *clsName = NSStringFromClass([cell class]);
            if (isIgnoredCellClass(clsName)) continue;
            
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

static void findCellAtCenterRecursive(UIView *view, CGPoint center, UIView * __strong *bestCell, NSMutableString *log) {
    if (!view || view.isHidden || view.alpha < 0.05) return;
    
    NSString *clsName = NSStringFromClass([view class]);
    if (isIgnoredCellClass(clsName)) return;

    if ([view isKindOfClass:[UICollectionViewCell class]] || [view isKindOfClass:[UITableViewCell class]] || [clsName containsString:@"Cell"] || [clsName containsString:@"PhotoView"] || [clsName containsString:@"VideoView"]) {
        CGRect cellFrame = [view convertRect:view.bounds toView:nil];
        if (CGRectContainsPoint(cellFrame, center)) {
            *bestCell = view;
            [log appendFormat:@"[HitTest] Found deep cell: %@ at %@\n", clsName, NSStringFromCGRect(cellFrame)];
        }
    }
    
    for (UIView *sub in view.subviews) {
        findCellAtCenterRecursive(sub, center, bestCell, log);
    }
}

static UIView *findCenterMostCell(UIView *rootView, NSMutableString *log) {
    if (!rootView) return nil;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGPoint screenCenter = CGPointMake(screenBounds.size.width / 2.0, screenBounds.size.height / 2.0);
    
    NSMutableArray<UIView *> *allCells = [NSMutableArray array];
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:rootView];
    
    while (queue.count > 0) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        
        if (!v || v.isHidden || v.alpha < 0.05) continue;
        
        if ([v isKindOfClass:[UICollectionView class]]) {
            NSArray *visible = [(UICollectionView *)v visibleCells];
            for (UIView *c in visible) {
                if (c && !c.isHidden && c.alpha > 0.05) [allCells addObject:c];
            }
        } else if ([v isKindOfClass:[UITableView class]]) {
            NSArray *visible = [(UITableView *)v visibleCells];
            for (UIView *c in visible) {
                if (c && !c.isHidden && c.alpha > 0.05) [allCells addObject:c];
            }
        }
        
        if (v.subviews.count > 0) {
            [queue addObjectsFromArray:v.subviews];
        }
    }
    
    UIView *bestCell = nil;
    CGFloat minDistance = CGFLOAT_MAX;
    
    for (UIView *cell in allCells) {
        NSString *clsName = NSStringFromClass([cell class]);
        if (isIgnoredCellClass(clsName)) continue;
        
        CGRect cellFrame = [cell convertRect:cell.bounds toView:nil];
        CGRect intersect = CGRectIntersection(cellFrame, screenBounds);
        if (!CGRectIsNull(intersect) && intersect.size.height > 80) {
            CGFloat cellCenterY = cellFrame.origin.y + cellFrame.size.height / 2.0;
            CGFloat dist = fabs(cellCenterY - screenCenter.y);
            
            if ([clsName containsString:@"Photo"] || [clsName containsString:@"Video"] || [clsName containsString:@"Media"] || [clsName containsString:@"Page"]) {
                dist *= 0.8;
            }
            
            if (dist < minDistance) {
                minDistance = dist;
                bestCell = cell;
            }
        }
    }
    
    if (bestCell) {
        [log appendFormat:@"[CenterEngine] Picked center-most cell: %@ (dist: %.1f)\n", NSStringFromClass([bestCell class]), minDistance];
    }
    
    return bestCell;
}

static UIView *findBestCellFromHitTest(UIView *rootView, NSMutableString *log) {
    if (!rootView) return nil;
    
    // 1. Try Center-Distance Engine FIRST!
    UIView *bestCell = findCenterMostCell(rootView, log);
    
    // 2. Fallback to multi-point hitTest if Center-Distance Engine returned nil
    if (!bestCell) {
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGPoint testPoints[3] = {
            CGPointMake(screenBounds.size.width / 2.0, screenBounds.size.height * 0.40),
            CGPointMake(screenBounds.size.width / 2.0, screenBounds.size.height * 0.50),
            CGPointMake(screenBounds.size.width / 2.0, screenBounds.size.height * 0.30)
        };
        
        for (int i = 0; i < 3; i++) {
            findCellAtCenterRecursive(rootView, testPoints[i], &bestCell, log);
            if (bestCell) {
                NSString *cls = NSStringFromClass([bestCell class]);
                if ([cls containsString:@"Photo"] || [cls containsString:@"Video"] || [cls containsString:@"Media"] || [cls containsString:@"Page"]) {
                    break;
                }
            }
        }
    }
    
    if (!bestCell) {
        [log appendFormat:@"[HitTest] Multi-point search failed! Falling back to maxArea.\n"];
        CGFloat maxArea = 0;
        determineBestCell(rootView, &bestCell, &maxArea);
        [log appendFormat:@"[HitTest] Fallback picked: %@\n", NSStringFromClass([bestCell class])];
    } else {
        [log appendFormat:@"[HitTest] Final Picked Cell: %@\n", NSStringFromClass([bestCell class])];
    }
    return bestCell;
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

static NSURL *extractVideoURLFromObjectInternal(id obj, int depth, NSMutableSet *visitedObjects, NSMutableString *log, NSInteger carouselIndex) {
    if (!obj || depth > 5) return nil;
    if ([visitedObjects containsObject:obj]) return nil;
    [visitedObjects addObject:obj];
    
    @try {
        id carouselMedia = [obj valueForKey:@"carouselMedia"] ?: [obj valueForKey:@"carousel_media"];
        if (carouselMedia && [carouselMedia isKindOfClass:[NSArray class]] && [(NSArray *)carouselMedia count] > 0) {
            NSInteger useIndex = (carouselIndex >= 0 && carouselIndex < [(NSArray *)carouselMedia count]) ? carouselIndex : 0;
            id subItem = [(NSArray *)carouselMedia objectAtIndex:useIndex];
            if (subItem) {
                // Recursive call for the subItem with -1 so it doesn't loop
                NSURL *cand = extractVideoURLFromObjectInternal(subItem, depth + 1, visitedObjects, log, -1);
                if (cand) return cand;
            }
        }
    } @catch(NSException *e) {}
    
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

    NSArray *versionPropNames = @[@"videoVersions", @"video_versions", @"videoUrls", @"typed_video_urls", @"video_versions_dict", @"videoVersionDictionaries", @"_videoVersions", @"_videoVersionDictionaries"];
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
        @"messageItem", @"currentVisualMessage", @"sundialVideo", @"model", @"viewModel",
        @"dataSource", @"currentMessage", @"_currentMessage", @"_dataSource", @"rawVideo", @"rawPhoto"
    ];
    for (NSString *subName in subObjNames) {
        @try {
            id subObj = [obj valueForKey:subName];
            if (subObj && subObj != obj) {
                NSURL *found = extractVideoURLFromObjectInternal(subObj, depth + 1, visitedObjects, log, carouselIndex);
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

    // 4. Koleksiyonlar (NSArray / NSSet) kontrolü
    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        for (id item in (id<NSFastEnumeration>)obj) {
            NSURL *found = extractVideoURLFromObjectInternal(item, depth + 1, visitedObjects, log, carouselIndex);
            if (found) return found;
        }
    }

    // 5. UIView hiyerarşisinde aşağı in (Eğer model bir alt view'daysa)
    if ([obj isKindOfClass:[UIView class]]) {
        for (UIView *sub in [(UIView *)obj subviews]) {
            NSURL *found = extractVideoURLFromObjectInternal(sub, depth + 1, visitedObjects, log, carouselIndex);
            if (found) return found;
        }
    }

    return nil;
}

static NSURL *extractVideoURLFromObject(id obj, NSMutableString *log) {
    NSMutableSet *visited = [NSMutableSet set];
    NSInteger idx = -1;
    if ([obj isKindOfClass:[UIView class]]) {
        idx = calculateCarouselIndex((UIView *)obj);
    }
    return extractVideoURLFromObjectInternal(obj, 0, visited, log, idx);
}

+ (NSURL *)deepExtractURLFromObject:(id)obj {
    NSMutableSet *visited = [NSMutableSet set];
    NSMutableString *dummyLog = [NSMutableString new];
    return extractVideoURLFromObjectInternal(obj, 0, visited, dummyLog, -1);
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
    
    if (gLastPlayingMediaObject && (now - gLastPlayingVideoTime < 5.0)) {
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
    
    if (gLastPlayingVideoURL && (now - gLastPlayingVideoTime < 5.0)) {
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

+ (void)clearGlobalVideoCache {
    gLastPlayingVideoURL = nil;
    gLastPlayingMediaObject = nil;
    gLastPlayingVideoTime = 0;
}

static NSURL *extractPhotoURLFromObjectInternal(id obj, int depth, NSMutableSet *visitedObjects, NSInteger carouselIndex) {
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
        id carouselMedia = [obj valueForKey:@"carouselMedia"] ?: [obj valueForKey:@"carousel_media"];
        if (carouselMedia && [carouselMedia isKindOfClass:[NSArray class]] && [(NSArray *)carouselMedia count] > 0) {
            NSInteger useIndex = (carouselIndex >= 0 && carouselIndex < [(NSArray *)carouselMedia count]) ? carouselIndex : 0;
            id subItem = [(NSArray *)carouselMedia objectAtIndex:useIndex];
            if (subItem) {
                id imageVersions = [subItem valueForKey:@"imageVersions2"] ?: [subItem valueForKey:@"image_versions2"];
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
            }
        }
    } @catch(NSException *e) {}
    
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
    
    NSArray *subObjNames = @[@"photo", @"rawPhoto", @"imageSpec", @"photoSpec", @"image", @"media", @"feedItem", @"currentMedia", @"currentItem", @"item", @"post", @"visualMessage", @"directVisualMessage", @"content", @"mediaContent", @"message", @"messageItem", @"currentVisualMessage", @"viewModel", @"model", @"storyItem", @"carouselItem", @"sundialVideo", @"dataSource", @"currentMessage", @"_currentMessage", @"_dataSource", @"rawVideo"];
    for (NSString *subName in subObjNames) {
        @try {
            id subObj = [obj valueForKey:subName];
            if (subObj && subObj != obj) {
                NSURL *found = extractPhotoURLFromObjectInternal(subObj, depth + 1, visitedObjects, carouselIndex);
                if (found) return found;
            }
        } @catch(NSException *e) {}
    }
    
    if ([obj isKindOfClass:[UIView class]]) {
        for (UIView *subview in [(UIView *)obj subviews]) {
            NSURL *found = extractPhotoURLFromObjectInternal(subview, depth + 1, visitedObjects, carouselIndex);
            if (found) return found;
        }
    }

    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
        for (id item in (id<NSFastEnumeration>)obj) {
            NSURL *found = extractPhotoURLFromObjectInternal(item, depth + 1, visitedObjects, carouselIndex);
            if (found) return found;
        }
    }
    return nil;
}

static NSString *extractUsernameFromObject(id obj) {
    if (!obj) return nil;
    NSArray *userProps = @[@"user", @"owner", @"author"];
    for (NSString *uProp in userProps) {
        @try {
            id user = [obj valueForKey:uProp];
            if (user) {
                id username = [user valueForKey:@"username"];
                if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
                    return (NSString *)username;
                }
            }
        } @catch(NSException *e) {}
    }
    
    NSArray *modelProps = @[@"post", @"item", @"media", @"feedItem", @"viewModel", @"model", @"messageItem"];
    for (NSString *prop in modelProps) {
        @try {
            id model = [obj valueForKey:prop];
            if (model) {
                for (NSString *uProp in userProps) {
                    @try {
                        id user = [model valueForKey:uProp];
                        if (user) {
                            id username = [user valueForKey:@"username"];
                            if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
                                return (NSString *)username;
                            }
                        }
                    } @catch(NSException *e) {}
                }
            }
        } @catch(NSException *e) {}
    }
    return nil;
}

static NSInteger calculateCarouselIndex(UIView *cell) {
    if (!cell) return -1;
    
    UICollectionView *horizontalCV = nil;
    UIView *v = cell;
    
    // 1. Search UP for a horizontal collection view (if we are in a deep photo cell)
    while (v) {
        if ([v isKindOfClass:[UICollectionView class]]) {
            UICollectionView *tempCV = (UICollectionView *)v;
            if ([tempCV.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
                if ([(UICollectionViewFlowLayout *)tempCV.collectionViewLayout scrollDirection] == UICollectionViewScrollDirectionHorizontal) {
                    horizontalCV = tempCV;
                    break;
                }
            }
        }
        v = v.superview;
    }
    
    // 2. Search DOWN (shallow) for a horizontal collection view (if we are in IGFeedItemCell wrapper)
    if (!horizontalCV) {
        for (UIView *sub in cell.subviews) {
            if ([sub isKindOfClass:[UICollectionView class]]) {
                UICollectionView *tempCV = (UICollectionView *)sub;
                if ([tempCV.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
                    if ([(UICollectionViewFlowLayout *)tempCV.collectionViewLayout scrollDirection] == UICollectionViewScrollDirectionHorizontal) {
                        horizontalCV = tempCV;
                        break;
                    }
                }
            } else {
                for (UIView *sub2 in sub.subviews) {
                    if ([sub2 isKindOfClass:[UICollectionView class]]) {
                        UICollectionView *tempCV = (UICollectionView *)sub2;
                        if ([tempCV.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
                            if ([(UICollectionViewFlowLayout *)tempCV.collectionViewLayout scrollDirection] == UICollectionViewScrollDirectionHorizontal) {
                                horizontalCV = tempCV;
                                break;
                            }
                        }
                    }
                }
            }
            if (horizontalCV) break;
        }
    }
    
    if (horizontalCV) {
        CGFloat offsetX = horizontalCV.contentOffset.x;
        CGFloat width = horizontalCV.bounds.size.width;
        if (width > 0) {
            return (NSInteger)round(offsetX / width);
        }
    }
    return -1;
}

static NSURL *extractPhotoURLFromObject(id obj) {
    NSMutableSet *visited = [NSMutableSet set];
    NSInteger idx = -1;
    if ([obj isKindOfClass:[UIView class]]) {
        idx = calculateCarouselIndex((UIView *)obj);
    }
    return extractPhotoURLFromObjectInternal(obj, 0, visited, idx);
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
    
    UIView *bestCell = nil;
    if (keyWindow) {
        UIViewController *topVC = keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC topViewController];
        }
        
        NSString *topVCClass = NSStringFromClass([topVC class]);
        [log appendFormat:@"[MediaExtractor] Searching TopVC: %@\n", topVCClass];
        
        if ([topVCClass containsString:@"DirectVisualMessage"] || [topVCClass containsString:@"DMVisual"]) {
            NSURL *dmVideoURL = [self deepExtractURLFromObject:topVC];
            if (!dmVideoURL) {
                dmVideoURL = [self extractActiveVideoURLFromScreenWithLog:log];
            }
            if (dmVideoURL && isStrictVideoURL(dmVideoURL.absoluteString)) {
                [log appendFormat:@"[MediaExtractor] Success! Extracted DM VIDEO URL: %@\n", dmVideoURL.lastPathComponent];
                NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": dmVideoURL}];
                NSString *u = extractUsernameFromObject(topVC);
                if (u) ret[@"username"] = u;
                return ret;
            }
            
            NSURL *dmPhotoURL = extractPhotoURLFromObject(topVC);
            if (dmPhotoURL && isStrictPhotoURL(dmPhotoURL.absoluteString)) {
                [log appendFormat:@"[MediaExtractor] Success! Extracted DM PHOTO URL: %@\n", dmPhotoURL.lastPathComponent];
                NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo", @"url": dmPhotoURL}];
                NSString *u = extractUsernameFromObject(topVC);
                if (u) ret[@"username"] = u;
                return ret;
            }
        }
        
        UIView *searchView = topVC.view ? topVC.view : keyWindow;
        bestCell = findBestCellFromHitTest(searchView, log);
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
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": cellVideoURL}];
            NSString *u = extractUsernameFromObject(bestCell);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        NSURL *globalVideoURL = [self extractActiveVideoURLFromScreenWithLog:log];
        if (globalVideoURL) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": globalVideoURL}];
            NSString *u = extractUsernameFromObject(bestCell) ?: extractUsernameFromObject(gLastPlayingMediaObject);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        return @{@"type": @"video"};
    } 
    else if (isPhotoCell) {
        [log appendFormat:@"[MediaExtractor] Explicit PHOTO cell detected.\n"];
        
        NSURL *photoURL = extractPhotoURLFromObject(bestCell);
        if (photoURL && isStrictPhotoURL(photoURL.absoluteString)) {
            [log appendFormat:@"[MediaExtractor] Success! Extracted PHOTO URL from best cell: %@\n", photoURL.lastPathComponent];
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo", @"url": photoURL}];
            NSString *u = extractUsernameFromObject(bestCell);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        // Never fall back to video extraction if it's explicitly a photo cell!
        NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo"}];
        NSString *u = extractUsernameFromObject(bestCell);
        if (u) ret[@"username"] = u;
        return ret;
    } 
    else {
        [log appendFormat:@"[MediaExtractor] Unknown cell type. Trying both...\n"];
        
        NSURL *cellVideo = extractVideoURLFromObject(bestCell, log);
        if (cellVideo && isStrictVideoURL(cellVideo.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": cellVideo}];
            NSString *u = extractUsernameFromObject(bestCell);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        // MUST TRY PHOTO FIRST BEFORE FALLING BACK TO GLOBAL HIJACKED VIDEO
        NSURL *cellPhoto = extractPhotoURLFromObject(bestCell);
        if (cellPhoto && isStrictPhotoURL(cellPhoto.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo", @"url": cellPhoto}];
            NSString *u = extractUsernameFromObject(bestCell);
            if (u) ret[@"username"] = u;
            return ret;
        }
    }
    
    // 3. Fallback: Take a screenshot if everything fails
    
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

+ (NSDictionary *)extractMediaContextFromView:(UIView *)view withLog:(NSMutableString *)log {
    if (!view) return nil;
    
    BOOL isVideoCell = NO;
    BOOL isPhotoCell = NO;
    NSInteger mediaType = detectMediaTypeFromCell(view);
    if (mediaType == 1 || mediaType == 8) {
        isPhotoCell = YES;
    } else if (mediaType == 2) {
        isVideoCell = YES;
    } else {
        NSString *cls = NSStringFromClass([view class]);
        isVideoCell = [cls containsString:@"Video"] || [cls containsString:@"Sundial"] || [cls containsString:@"Reel"];
        isPhotoCell = [cls containsString:@"Photo"] || [cls containsString:@"Image"];
    }
    
    if (isVideoCell) {
        [log appendFormat:@"[MediaExtractor] Explicit VIDEO cell detected via LongPress.\n"];
        NSURL *cellVideoURL = extractVideoURLFromObject(view, log);
        if (cellVideoURL && isStrictVideoURL(cellVideoURL.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": cellVideoURL}];
            NSString *u = extractUsernameFromObject(view);
            if (u) ret[@"username"] = u;
            return ret;
        }
    } else if (isPhotoCell) {
        [log appendFormat:@"[MediaExtractor] Explicit PHOTO cell detected via LongPress.\n"];
        NSURL *photoURL = extractPhotoURLFromObject(view);
        if (photoURL && isStrictPhotoURL(photoURL.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo", @"url": photoURL}];
            NSString *u = extractUsernameFromObject(view);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        NSURL *videoURL = extractVideoURLFromObject(view, log);
        if (videoURL && isStrictVideoURL(videoURL.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": videoURL}];
            NSString *u = extractUsernameFromObject(view);
            if (u) ret[@"username"] = u;
            return ret;
        }
    } else {
        NSURL *cellVideo = extractVideoURLFromObject(view, log);
        if (cellVideo && isStrictVideoURL(cellVideo.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"video", @"url": cellVideo}];
            NSString *u = extractUsernameFromObject(view);
            if (u) ret[@"username"] = u;
            return ret;
        }
        
        NSURL *cellPhoto = extractPhotoURLFromObject(view);
        if (cellPhoto && isStrictPhotoURL(cellPhoto.absoluteString)) {
            NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{@"type": @"photo", @"url": cellPhoto}];
            NSString *u = extractUsernameFromObject(view);
            if (u) ret[@"username"] = u;
            return ret;
        }
    }
    return nil;
}

@end

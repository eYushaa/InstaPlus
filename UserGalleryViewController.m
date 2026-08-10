#import "UserGalleryViewController.h"
#import "LocalPhotoManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

@interface UserGalleryViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSArray<NSString *> *mediaPaths;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) BOOL isSelectionMode;
@property (nonatomic, strong) NSMutableSet<NSIndexPath *> *selectedIndexPaths;
@property (nonatomic, strong) UIToolbar *bottomToolbar;
@property (nonatomic, strong) UIBarButtonItem *deleteItem;
@property (nonatomic, strong) UIBarButtonItem *exportItem;
@property (nonatomic, strong) UIBarButtonItem *selectItem;
@property (nonatomic, strong) UIBarButtonItem *cancelItem;
@property (nonatomic, strong) UIBarButtonItem *selectAllItem;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) BOOL isSelectingWithPan;
@end

@interface SingleMediaViewController : UIViewController
@property (nonatomic, strong) NSString *mediaPath;
@property (nonatomic, copy) void (^onDelete)(NSString *path);
@end

@implementation SingleMediaViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    NSString *lower = self.mediaPath.lowercaseString;
    BOOL isVideo = [lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"];
    
    if (isVideo) {
        AVPlayer *player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:self.mediaPath]];
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        playerVC.player = player;
        playerVC.view.frame = self.view.bounds;
        playerVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addChildViewController:playerVC];
        [self.view addSubview:playerVC.view];
        [playerVC didMoveToParentViewController:self];
        [player play];
    } else {
        UIImageView *fullImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        fullImageView.contentMode = UIViewContentModeScaleAspectFit;
        fullImageView.image = [UIImage imageWithContentsOfFile:self.mediaPath];
        fullImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:fullImageView];
    }
    
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:@"Kapat" style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = closeBtn;
    
    UIBarButtonItem *delBtn = [[UIBarButtonItem alloc] initWithTitle:@"Sil" style:UIBarButtonItemStylePlain target:self action:@selector(deleteItem)];
    delBtn.tintColor = [UIColor redColor];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *exportBtn = [[UIBarButtonItem alloc] initWithTitle:@"Film Rulosuna Aktar" style:UIBarButtonItemStylePlain target:self action:@selector(exportItem)];
    
    self.toolbarItems = @[delBtn, flex, exportBtn];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)deleteItem {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sil" message:@"Bu medyayı silmek istediğinize emin misiniz?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"İptal" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Sil" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if (self.onDelete) {
            self.onDelete(self.mediaPath);
        }
        [self close];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportItem {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                NSString *lower = self.mediaPath.lowercaseString;
                if ([lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:self.mediaPath]];
                } else {
                    [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:self.mediaPath]];
                }
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Başarılı" message:@"Medya film rulosuna kaydedildi." preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
                        [self presentViewController:alert animated:YES completion:nil];
                    } else {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hata" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
                        [self presentViewController:alert animated:YES completion:nil];
                    }
                });
            }];
        }
    }];
}
@end

@implementation UserGalleryViewController

- (instancetype)initWithUsername:(NSString *)username {
    self = [super init];
    if (self) {
        _username = username;
        _isSelectionMode = NO;
        _selectedIndexPaths = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([self.username isEqualToString:@"Tümü"]) {
        self.title = @"Tüm Medyalar";
        self.mediaPaths = [[LocalPhotoManager sharedManager] getAllMedia];
    } else {
        self.title = [NSString stringWithFormat:@"@%@", self.username];
        self.mediaPaths = [[LocalPhotoManager sharedManager] getMediaForUsername:self.username];
    }
    
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
    
    [self setupNavigationBar];
    [self setupCollectionView];
    [self setupBottomToolbar];
}

- (void)setupNavigationBar {
    self.selectItem = [[UIBarButtonItem alloc] initWithTitle:@"Seç" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectionMode)];
    self.cancelItem = [[UIBarButtonItem alloc] initWithTitle:@"İptal" style:UIBarButtonItemStyleDone target:self action:@selector(toggleSelectionMode)];
    self.selectAllItem = [[UIBarButtonItem alloc] initWithTitle:@"Tümünü Seç" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllItems)];
    self.navigationItem.rightBarButtonItem = self.selectItem;
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat width = (self.view.bounds.size.width - 6) / 3;
    layout.itemSize = CGSizeMake(width, width);
    layout.minimumInteritemSpacing = 2;
    layout.minimumLineSpacing = 2;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.allowsMultipleSelection = YES;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"MediaCell"];
    [self.view addSubview:self.collectionView];
    
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGesture.delegate = self;
    [self.collectionView addGestureRecognizer:self.panGesture];
    self.panGesture.enabled = NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)setupBottomToolbar {
    self.bottomToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 83, self.view.bounds.size.width, 83)];
    self.bottomToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomToolbar.barStyle = UIBarStyleBlack;
    self.bottomToolbar.hidden = YES;
    
    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:@"Sil" style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedItems)];
    self.deleteItem.tintColor = [UIColor redColor];
    
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    self.exportItem = [[UIBarButtonItem alloc] initWithTitle:@"Film Rulosuna Aktar" style:UIBarButtonItemStylePlain target:self action:@selector(exportSelectedItems)];
    
    self.bottomToolbar.items = @[self.deleteItem, flexSpace, self.exportItem];
    [self.view addSubview:self.bottomToolbar];
}

- (void)toggleSelectionMode {
    self.isSelectionMode = !self.isSelectionMode;
    [self.selectedIndexPaths removeAllObjects];
    
    if (self.isSelectionMode) {
        self.navigationItem.rightBarButtonItem = self.cancelItem;
        self.navigationItem.leftBarButtonItem = self.selectAllItem;
        self.bottomToolbar.hidden = NO;
        self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 83, 0);
        self.panGesture.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem = self.selectItem;
        self.navigationItem.leftBarButtonItem = nil;
        self.bottomToolbar.hidden = YES;
        self.collectionView.contentInset = UIEdgeInsetsZero;
        self.panGesture.enabled = NO;
    }
    
    [self updateToolbarButtons];
    [self.collectionView reloadData];
}

- (void)updateToolbarButtons {
    BOOL hasSelection = self.selectedIndexPaths.count > 0;
    self.deleteItem.enabled = hasSelection;
    self.exportItem.enabled = hasSelection;
    if (self.isSelectionMode) {
        self.title = hasSelection ? [NSString stringWithFormat:@"%lu Seçili", (unsigned long)self.selectedIndexPaths.count] : @"Öğe Seçin";
        if (self.selectedIndexPaths.count == self.mediaPaths.count && self.mediaPaths.count > 0) {
            self.selectAllItem.title = @"Tümünü Bırak";
        } else {
            self.selectAllItem.title = @"Tümünü Seç";
        }
    } else {
        self.title = [self.username isEqualToString:@"Tümü"] ? @"Tüm Medyalar" : [NSString stringWithFormat:@"@%@", self.username];
    }
}

- (void)selectAllItems {
    if (self.selectedIndexPaths.count == self.mediaPaths.count) {
        [self.selectedIndexPaths removeAllObjects];
        self.selectAllItem.title = @"Tümünü Seç";
    } else {
        for (NSInteger i = 0; i < self.mediaPaths.count; i++) {
            [self.selectedIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }
        self.selectAllItem.title = @"Tümünü Bırak";
    }
    [self updateToolbarButtons];
    [self.collectionView reloadData];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (indexPath) {
            self.isSelectingWithPan = ![self.selectedIndexPaths containsObject:indexPath];
            if (self.isSelectingWithPan) {
                [self.selectedIndexPaths addObject:indexPath];
            } else {
                [self.selectedIndexPaths removeObject:indexPath];
            }
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            [self updateToolbarButtons];
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        if (indexPath) {
            BOOL currentlySelected = [self.selectedIndexPaths containsObject:indexPath];
            if (self.isSelectingWithPan && !currentlySelected) {
                [self.selectedIndexPaths addObject:indexPath];
                [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                [self updateToolbarButtons];
            } else if (!self.isSelectingWithPan && currentlySelected) {
                [self.selectedIndexPaths removeObject:indexPath];
                [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                [self updateToolbarButtons];
            }
        }
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.mediaPaths.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MediaCell" forIndexPath:indexPath];
    
    for (UIView *v in cell.contentView.subviews) {
        [v removeFromSuperview];
    }
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:cell.bounds];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    
    NSString *path = self.mediaPaths[indexPath.item];
    NSString *lower = path.lowercaseString;
    
    if ([lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
        imageView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        
        UILabel *playBadge = [[UILabel alloc] initWithFrame:CGRectMake(cell.bounds.size.width - 26, cell.bounds.size.height - 26, 22, 22)];
        playBadge.text = @"▶";
        playBadge.textColor = [UIColor whiteColor];
        playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        playBadge.font = [UIFont boldSystemFontOfSize:12];
        playBadge.textAlignment = NSTextAlignmentCenter;
        playBadge.layer.cornerRadius = 11;
        playBadge.clipsToBounds = YES;
        [imageView addSubview:playBadge];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
            AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            CMTime time = CMTimeMake(1, 2);
            CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
            if (imageRef) {
                UIImage *thumb = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UICollectionViewCell *currentCell = [collectionView cellForItemAtIndexPath:indexPath];
                    if (currentCell) {
                        for (UIView *v in currentCell.contentView.subviews) {
                            if ([v isKindOfClass:[UIImageView class]]) {
                                ((UIImageView *)v).image = thumb;
                                break;
                            }
                        }
                    }
                });
            }
        });
    } else {
        imageView.image = [UIImage imageWithContentsOfFile:path];
    }
    
    [cell.contentView addSubview:imageView];
    
    if (self.isSelectionMode) {
        BOOL isSelected = [self.selectedIndexPaths containsObject:indexPath];
        
        UIView *overlay = [[UIView alloc] initWithFrame:cell.bounds];
        overlay.backgroundColor = isSelected ? [UIColor colorWithWhite:0.0 alpha:0.3] : [UIColor clearColor];
        overlay.tag = 999;
        
        UIImageView *checkIcon = [[UIImageView alloc] initWithFrame:CGRectMake(cell.bounds.size.width - 28, 5, 24, 24)];
        if (isSelected) {
            if ([UIImage respondsToSelector:NSSelectorFromString(@"systemImageNamed:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                checkIcon.image = [UIImage performSelector:NSSelectorFromString(@"systemImageNamed:") withObject:@"checkmark.circle.fill"];
                UIColor *blue = [UIColor blueColor];
                if ([UIColor respondsToSelector:NSSelectorFromString(@"systemBlueColor")]) {
                    blue = [UIColor performSelector:NSSelectorFromString(@"systemBlueColor")];
                }
                checkIcon.tintColor = blue;
#pragma clang diagnostic pop
            } else {
                checkIcon.backgroundColor = [UIColor blueColor]; // Fallback
            }
            checkIcon.backgroundColor = [UIColor whiteColor];
            checkIcon.layer.cornerRadius = 12;
            checkIcon.clipsToBounds = YES;
        } else {
            if ([UIImage respondsToSelector:NSSelectorFromString(@"systemImageNamed:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                checkIcon.image = [UIImage performSelector:NSSelectorFromString(@"systemImageNamed:") withObject:@"circle"];
#pragma clang diagnostic pop
                checkIcon.tintColor = [UIColor whiteColor];
            } else {
                checkIcon.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
                checkIcon.layer.cornerRadius = 12;
            }
            checkIcon.layer.shadowColor = [UIColor blackColor].CGColor;
            checkIcon.layer.shadowOffset = CGSizeMake(0, 0);
            checkIcon.layer.shadowOpacity = 0.5;
            checkIcon.layer.shadowRadius = 2;
        }
        
        [overlay addSubview:checkIcon];
        [cell.contentView addSubview:overlay];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSelectionMode) {
        if ([self.selectedIndexPaths containsObject:indexPath]) {
            [self.selectedIndexPaths removeObject:indexPath];
        } else {
            [self.selectedIndexPaths addObject:indexPath];
        }
        [self updateToolbarButtons];
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
        return;
    }
    
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    NSString *path = self.mediaPaths[indexPath.item];
    
    SingleMediaViewController *singleVC = [[SingleMediaViewController alloc] init];
    singleVC.mediaPath = path;
    singleVC.onDelete = ^(NSString *deletedPath) {
        [[LocalPhotoManager sharedManager] deleteMediaAtPath:deletedPath error:nil];
        if ([self.username isEqualToString:@"Tümü"]) {
            self.mediaPaths = [[LocalPhotoManager sharedManager] getAllMedia];
        } else {
            self.mediaPaths = [[LocalPhotoManager sharedManager] getMediaForUsername:self.username];
        }
        [self.collectionView reloadData];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:singleVC];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.tintColor = [UIColor whiteColor];
    nav.toolbarHidden = NO;
    nav.toolbar.barStyle = UIBarStyleBlack;
    nav.toolbar.tintColor = [UIColor whiteColor];
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)deleteSelectedItems {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sil" message:[NSString stringWithFormat:@"%lu ögeyi silmek istediğinize emin misiniz?", (unsigned long)self.selectedIndexPaths.count] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"İptal" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Sil" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSMutableArray *pathsToDelete = [NSMutableArray array];
        for (NSIndexPath *ip in self.selectedIndexPaths) {
            [pathsToDelete addObject:self.mediaPaths[ip.item]];
        }
        
        for (NSString *path in pathsToDelete) {
            [[LocalPhotoManager sharedManager] deleteMediaAtPath:path error:nil];
        }
        
        [self toggleSelectionMode];
        if ([self.username isEqualToString:@"Tümü"]) {
            self.mediaPaths = [[LocalPhotoManager sharedManager] getAllMedia];
        } else {
            self.mediaPaths = [[LocalPhotoManager sharedManager] getMediaForUsername:self.username];
        }
        [self.collectionView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportSelectedItems {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            NSMutableArray *pathsToExport = [NSMutableArray array];
            for (NSIndexPath *ip in self.selectedIndexPaths) {
                [pathsToExport addObject:self.mediaPaths[ip.item]];
            }
            
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                for (NSString *path in pathsToExport) {
                    NSString *lower = path.lowercaseString;
                    if ([lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:path]];
                    } else {
                        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:path]];
                    }
                }
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Başarılı" message:@"Seçili ögeler film rulosuna kaydedildi." preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self toggleSelectionMode];
                        }]];
                        [self presentViewController:alert animated:YES completion:nil];
                    } else {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hata" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
                        [self presentViewController:alert animated:YES completion:nil];
                    }
                });
            }];
        }
    }];
}

@end

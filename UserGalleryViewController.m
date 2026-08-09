#import "UserGalleryViewController.h"
#import "LocalPhotoManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

@interface UserGalleryViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
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
        self.bottomToolbar.hidden = NO;
        self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 83, 0);
    } else {
        self.navigationItem.rightBarButtonItem = self.selectItem;
        self.bottomToolbar.hidden = YES;
        self.collectionView.contentInset = UIEdgeInsetsZero;
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
    } else {
        self.title = [self.username isEqualToString:@"Tümü"] ? @"Tüm Medyalar" : [NSString stringWithFormat:@"@%@", self.username];
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
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        CMTime time = CMTimeMake(1, 2);
        CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
        if (imageRef) {
            imageView.image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
        
        UILabel *playBadge = [[UILabel alloc] initWithFrame:CGRectMake(cell.bounds.size.width - 26, cell.bounds.size.height - 26, 22, 22)];
        playBadge.text = @"▶";
        playBadge.textColor = [UIColor whiteColor];
        playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        playBadge.font = [UIFont boldSystemFontOfSize:12];
        playBadge.textAlignment = NSTextAlignmentCenter;
        playBadge.layer.cornerRadius = 11;
        playBadge.clipsToBounds = YES;
        [imageView addSubview:playBadge];
    } else {
        imageView.image = [UIImage imageWithContentsOfFile:path];
    }
    
    [cell.contentView addSubview:imageView];
    
    if (self.isSelectionMode) {
        UIView *overlay = [[UIView alloc] initWithFrame:cell.bounds];
        overlay.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.4];
        overlay.hidden = ![self.selectedIndexPaths containsObject:indexPath];
        overlay.tag = 999;
        
        UILabel *check = [[UILabel alloc] initWithFrame:CGRectMake(cell.bounds.size.width - 30, 5, 25, 25)];
        check.text = @"✅";
        check.font = [UIFont systemFontOfSize:20];
        check.backgroundColor = [UIColor whiteColor];
        check.layer.cornerRadius = 12.5;
        check.clipsToBounds = YES;
        check.textAlignment = NSTextAlignmentCenter;
        [overlay addSubview:check];
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
    NSString *lower = path.lowercaseString;
    
    if ([lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
        NSURL *videoURL = [NSURL fileURLWithPath:path];
        AVPlayer *player = [AVPlayer playerWithURL:videoURL];
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        playerVC.player = player;
        [self presentViewController:playerVC animated:YES completion:^{
            [player play];
        }];
    } else {
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (!image) return;
        
        UIViewController *fullScreenVC = [[UIViewController alloc] init];
        fullScreenVC.view.backgroundColor = [UIColor blackColor];
        
        UIImageView *fullImageView = [[UIImageView alloc] initWithFrame:fullScreenVC.view.bounds];
        fullImageView.contentMode = UIViewContentModeScaleAspectFit;
        fullImageView.image = image;
        fullImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [fullScreenVC.view addSubview:fullImageView];
        
        fullImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFullScreen:)];
        [fullImageView addGestureRecognizer:tap];
        
        [self presentViewController:fullScreenVC animated:YES completion:nil];
    }
}

- (void)dismissFullScreen:(UITapGestureRecognizer *)gesture {
    UIViewController *vc = (UIViewController *)gesture.view.nextResponder.nextResponder;
    if ([vc isKindOfClass:[UIViewController class]]) {
        [vc dismissViewControllerAnimated:YES completion:nil];
    }
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

#import "UserGalleryViewController.h"
#import "LocalPhotoManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface UserGalleryViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSArray<NSString *> *mediaPaths;
@property (nonatomic, strong) UICollectionView *collectionView;
@end

@implementation UserGalleryViewController

- (instancetype)initWithUsername:(NSString *)username {
    self = [super init];
    if (self) {
        _username = username;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"@%@", self.username];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
    
    self.mediaPaths = [[LocalPhotoManager sharedManager] getMediaForUsername:self.username];
    
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
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"MediaCell"];
    [self.view addSubview:self.collectionView];
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
        // Video için ilk kareyi önizleme resmi olarak oluştur
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        CMTime time = CMTimeMake(1, 2);
        CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
        if (imageRef) {
            imageView.image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
        
        // Video Oynatma İkonu Overlay (▶)
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
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *path = self.mediaPaths[indexPath.item];
    NSString *lower = path.lowercaseString;
    
    if ([lower hasSuffix:@".mp4"] || [lower hasSuffix:@".mov"]) {
        // VİDEO OYNATMA: AVPlayerViewController ile tam ekran oynat!
        NSURL *videoURL = [NSURL fileURLWithPath:path];
        AVPlayer *player = [AVPlayer playerWithURL:videoURL];
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        playerVC.player = player;
        [self presentViewController:playerVC animated:YES completion:^{
            [player play];
        }];
    } else {
        // FOTOĞRAF GÖRÜNTÜLEME: Tam ekran fotoğraf
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

@end

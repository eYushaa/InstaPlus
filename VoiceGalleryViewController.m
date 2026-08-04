#import "VoiceGalleryViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@interface UIImage (System)
+ (UIImage *)systemImageNamed:(NSString *)name;
@end

@interface InstaLocalStorage : NSObject
+ (instancetype)shared;
- (NSString *)getVoicesFolder;
@end

extern NSString *globalSelectedVoicePath;

@interface VoiceGalleryViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, AVAudioPlayerDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSURL *> *currentItems;
@property (nonatomic, strong) NSArray<NSURL *> *filteredItems;
@property (nonatomic, strong) NSString *currentDirectoryPath;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSURL *currentlyPlayingURL;
@end

@implementation VoiceGalleryViewController {
    UIView *_containerView;
}

+ (void)showOverlay {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow) return;
    
    VoiceGalleryViewController *vc = [[VoiceGalleryViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
}

+ (BOOL)isPresented {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow) return NO;
    
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
        if ([root isKindOfClass:[VoiceGalleryViewController class]]) {
            return YES;
        }
    }
    return NO;
}

+ (void)dismissCurrentOverlay {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow) return;
    
    UIViewController *root = keyWindow.rootViewController;
    UIViewController *target = nil;
    while (root.presentedViewController) {
        root = root.presentedViewController;
        if ([root isKindOfClass:[VoiceGalleryViewController class]]) {
            target = root;
            break;
        }
    }
    
    if (target) {
        [target dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    
    // Tap gesture to dismiss keyboard or close gallery on backdrop tap
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    bgTap.cancelsTouchesInView = NO;
    bgTap.delegate = self;
    [self.view addGestureRecognizer:bgTap];
    
    // Container View
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    _containerView.center = self.view.center;
    _containerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_containerView];
    
    // Mod Menu Blur View
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = _containerView.bounds;
    blurView.layer.cornerRadius = 24;
    blurView.clipsToBounds = YES;
    blurView.layer.borderWidth = 1.5;
    blurView.layer.borderColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:0.5].CGColor;
    [_containerView addSubview:blurView];
    
    _containerView.layer.shadowColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:0.6].CGColor;
    _containerView.layer.shadowOffset = CGSizeZero;
    _containerView.layer.shadowOpacity = 0.5;
    _containerView.layer.shadowRadius = 15;
    
    // Top Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 25)];
    titleLabel.text = @"Ses Galerisi";
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, 280, 16)];
    subLabel.text = @"iF33lX VOICE MANAGER";
    subLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    subLabel.textColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:subLabel];
    
    // Search Bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, 75, 300, 36)];
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = @"Seslerde ara...";
    self.searchBar.tintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
    UITextField *searchTextField = [self.searchBar valueForKey:@"searchField"];
    if (searchTextField) {
        searchTextField.textColor = [UIColor whiteColor];
        searchTextField.font = [UIFont systemFontOfSize:13];
    }
    [_containerView addSubview:self.searchBar];
    
    UIView *separatorLine = [[UIView alloc] initWithFrame:CGRectMake(20, 120, 280, 1)];
    separatorLine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    [_containerView addSubview:separatorLine];
    
    // Table View
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 121, 320, 295) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"VoiceCell"];
    [_containerView addSubview:self.tableView];
    
    // Action Bar (Bottom Buttons)
    CGFloat btnW = (320 - 40) / 3;
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(10, 428, btnW, 38);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:0.25];
    closeBtn.layer.cornerRadius = 12;
    closeBtn.layer.borderWidth = 1.0;
    closeBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0].CGColor;
    [closeBtn setTitle:@"Kapat" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:closeBtn];
    
    UIButton *newFolderBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    newFolderBtn.frame = CGRectMake(20 + btnW, 428, btnW, 38);
    newFolderBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.6 blue:0.2 alpha:0.25];
    newFolderBtn.layer.cornerRadius = 12;
    newFolderBtn.layer.borderWidth = 1.0;
    newFolderBtn.layer.borderColor = [UIColor yellowColor].CGColor;
    [newFolderBtn setTitle:@"Yeni Klasör" forState:UIControlStateNormal];
    [newFolderBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    newFolderBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [newFolderBtn addTarget:self action:@selector(newFolderTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:newFolderBtn];
    
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addBtn.frame = CGRectMake(30 + btnW * 2, 428, btnW, 38);
    addBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.8 alpha:0.25];
    addBtn.layer.cornerRadius = 12;
    addBtn.layer.borderWidth = 1.0;
    addBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    [addBtn setTitle:@"Yeni Ses" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [addBtn addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:addBtn];
    
    // Long press to rename
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:lp];
    
    self.currentDirectoryPath = [[InstaLocalStorage shared] getVoicesFolder];
    [self loadVoices];
}

- (void)newFolderTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Yeni Klasör" message:@"Klasör adını girin." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Klasör Adı";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"İptal" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Oluştur" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name && name.length > 0) {
            NSString *folderPath = [self.currentDirectoryPath stringByAppendingPathComponent:name];
            [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
            [self loadVoices];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loadVoices {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:self.currentDirectoryPath] includingPropertiesForKeys:@[NSURLCreationDateKey, NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    NSMutableArray *directories = [NSMutableArray array];
    NSMutableArray *audioFiles = [NSMutableArray array];
    
    for (NSURL *url in files) {
        NSNumber *isDir = nil;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
        if ([isDir boolValue]) {
            [directories addObject:url];
        } else {
            NSString *ext = [[url pathExtension] lowercaseString];
            if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"mp3"] || [ext isEqualToString:@"wav"]) {
                [audioFiles addObject:url];
            }
        }
    }
    
    [directories sortUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        return [url1.lastPathComponent localizedCaseInsensitiveCompare:url2.lastPathComponent];
    }];
    
    [audioFiles sortUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        NSDate *date1;
        [url1 getResourceValue:&date1 forKey:NSURLCreationDateKey error:nil];
        NSDate *date2;
        [url2 getResourceValue:&date2 forKey:NSURLCreationDateKey error:nil];
        return [date2 compare:date1];
    }];
    
    NSMutableArray *combined = [NSMutableArray array];
    
    NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
    if (![self.currentDirectoryPath isEqualToString:rootFolder]) {
        [combined addObject:[NSURL fileURLWithPath:[self.currentDirectoryPath stringByDeletingLastPathComponent]]];
    }
    
    [combined addObjectsFromArray:directories];
    [combined addObjectsFromArray:audioFiles];
    
    self.currentItems = combined;
    [self filterItemsWithSearchText:self.searchBar.text];
}

- (void)filterItemsWithSearchText:(NSString *)searchText {
    if (!searchText || searchText.length == 0) {
        self.filteredItems = self.currentItems;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:rootFolder]
                                     includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   errorHandler:nil];
        
        for (NSURL *url in enumerator) {
            NSNumber *isDir = nil;
            [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
            
            // Arama yapıldığında doğrudan ses dosyaları çıksın, klasörler listelenmesin
            if ([isDir boolValue]) continue;
            
            NSString *ext = [[url pathExtension] lowercaseString];
            if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"mp3"] || [ext isEqualToString:@"wav"]) {
                NSString *name = [url lastPathComponent].stringByDeletingPathExtension;
                NSString *folderName = [url.URLByDeletingLastPathComponent lastPathComponent];
                
                BOOL matchesFile = ([name rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound);
                BOOL matchesFolder = ([folderName rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound);
                
                if (matchesFile || matchesFolder) {
                    [filtered addObject:url];
                }
            }
        }
        
        [filtered sortUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
            return [url1.lastPathComponent localizedCaseInsensitiveCompare:url2.lastPathComponent];
        }];
        
        self.filteredItems = filtered;
    }
    [self.tableView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterItemsWithSearchText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIButton class]] || [touch.view isKindOfClass:[UIControl class]]) {
        return NO;
    }
    return YES;
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    
    BOOL keyboardWasVisible = [self.searchBar isFirstResponder];
    if (keyboardWasVisible) {
        [self.searchBar resignFirstResponder];
    }
    
    if (_containerView && !CGRectContainsPoint(_containerView.frame, location)) {
        [self closeTapped];
    } else if (!keyboardWasVisible) {
        [self.view endEditing:YES];
    }
}

- (void)closeTapped {
    if (self.audioPlayer) {
        [self.audioPlayer stop];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addTapped {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio", @"public.mp3", @"com.apple.m4a-audio"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES; // ÇOKLU SES SEÇİMİ AKTİF
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (!urls || urls.count == 0) return;
    
    NSUInteger totalCount = urls.count;
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"Sesler Aktarılıyor" message:[NSString stringWithFormat:@"0/%lu ses işleniyor...", (unsigned long)totalCount] preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger i = 0; i < totalCount; i++) {
            NSURL *selectedUrl = urls[i];
            NSString *fileName = [selectedUrl lastPathComponent];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                progressAlert.message = [NSString stringWithFormat:@"%lu/%lu ses işleniyor:\n%@", (unsigned long)(i + 1), (unsigned long)totalCount, fileName];
            });
            
            BOOL accessing = [selectedUrl startAccessingSecurityScopedResource];
            
            __block NSData *fileData = nil;
            __block NSError *readError = nil;
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:selectedUrl options:NSFileCoordinatorReadingWithoutChanges error:&readError byAccessor:^(NSURL *newURL) {
                fileData = [NSData dataWithContentsOfURL:newURL];
            }];
            
            if (accessing) {
                [selectedUrl stopAccessingSecurityScopedResource];
            }
            
            if (!fileData || fileData.length == 0) {
                continue;
            }
            
            // Dosya adını uzantısız olarak ses başlığı yapıyoruz
            NSString *inputName = [selectedUrl lastPathComponent].stringByDeletingPathExtension;
            if (!inputName || inputName.length == 0) {
                inputName = [[NSUUID UUID] UUIDString];
            }
            
            inputName = [inputName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            inputName = [inputName stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
            
            NSString *destPath = [self.currentDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.m4a", inputName]];
            [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
            
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:selectedUrl options:nil];
            AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
            exportSession.outputURL = [NSURL fileURLWithPath:destPath];
            exportSession.outputFileType = AVFileTypeAppleM4A;
            
            dispatch_semaphore_t expSema = dispatch_semaphore_create(0);
            __block BOOL exportSuccess = NO;
            
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    exportSuccess = YES;
                }
                dispatch_semaphore_signal(expSema);
            }];
            
            dispatch_semaphore_wait(expSema, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
            
            if (!exportSuccess) {
                [fileData writeToFile:destPath atomically:YES];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self loadVoices];
            }];
        });
    });
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VoiceCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    
    cell.accessoryView = nil;
    cell.imageView.image = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    NSURL *fileUrl = self.filteredItems[indexPath.row];
    NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
    if (![self.currentDirectoryPath isEqualToString:rootFolder] && [fileUrl.path isEqualToString:[self.currentDirectoryPath stringByDeletingLastPathComponent]]) {
        cell.textLabel.text = @"Geri Dön";
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.turn.up.left"];
        cell.imageView.tintColor = [UIColor orangeColor];
        cell.textLabel.textColor = [UIColor orangeColor];
        return cell;
    }
    
    NSNumber *isDir = nil;
    [fileUrl getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
    
    if ([isDir boolValue]) {
        cell.textLabel.attributedText = nil;
        cell.textLabel.text = [NSString stringWithFormat:@"%@", fileUrl.lastPathComponent];
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
        cell.imageView.tintColor = [UIColor yellowColor];
        cell.textLabel.textColor = [UIColor yellowColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *fileName = [fileUrl.lastPathComponent stringByDeletingPathExtension];
        
        if (self.searchBar.text.length > 0) {
            NSString *dirPath = fileUrl.path.stringByDeletingLastPathComponent;
            NSString *folderDisplayName = nil;
            if ([dirPath isEqualToString:rootFolder]) {
                folderDisplayName = @"Ana Klasör";
            } else {
                folderDisplayName = dirPath.lastPathComponent;
            }
            
            NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@] | ", folderDisplayName] attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium],
                NSForegroundColorAttributeName: [UIColor colorWithRed:0.75 green:0.5 blue:1.0 alpha:0.9]
            }];
            
            NSAttributedString *fileAttr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]", fileName] attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightBold],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            }];
            
            [attrStr appendAttributedString:fileAttr];
            cell.textLabel.attributedText = attrStr;
        } else {
            cell.textLabel.attributedText = nil;
            cell.textLabel.text = fileName;
        }
        
        cell.imageView.image = [UIImage systemImageNamed:@"waveform"];
        cell.imageView.tintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
        
        UIView *accView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 70, 40)];
        
        UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        
        BOOL isPlayingThis = (self.audioPlayer && self.audioPlayer.isPlaying && [self.currentlyPlayingURL.path isEqualToString:fileUrl.path]);
        NSString *iconName = isPlayingThis ? @"stop.circle.fill" : @"play.circle.fill";
        [playBtn setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
        playBtn.tintColor = isPlayingThis ? [UIColor redColor] : [UIColor greenColor];
        playBtn.accessibilityIdentifier = fileUrl.path;
        [playBtn addTarget:self action:@selector(previewVoiceTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        if ([globalSelectedVoicePath isEqualToString:fileUrl.path]) {
            playBtn.frame = CGRectMake(5, 5, 30, 30);
            
            UIImageView *checkMark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
            checkMark.frame = CGRectMake(45, 10, 20, 20);
            checkMark.tintColor = [UIColor blueColor];
            [accView addSubview:checkMark];
            
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.25];
            cell.layer.cornerRadius = 8;
        } else {
            playBtn.frame = CGRectMake(45, 5, 30, 30);
            
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.backgroundColor = [UIColor clearColor];
        }
        
        [accView addSubview:playBtn];
        cell.accessoryView = accView;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSURL *selected = self.filteredItems[indexPath.row];
    NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
    
    if (![self.currentDirectoryPath isEqualToString:rootFolder] && [selected.path isEqualToString:[self.currentDirectoryPath stringByDeletingLastPathComponent]]) {
        self.currentDirectoryPath = selected.path;
        [self loadVoices];
        return;
    }
    
    NSNumber *isDir = nil;
    [selected getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
    if ([isDir boolValue]) {
        self.currentDirectoryPath = selected.path;
        if (self.searchBar.text.length > 0) {
            self.searchBar.text = @"";
            [self.searchBar resignFirstResponder];
        }
        [self loadVoices];
        return;
    }
    
    if ([globalSelectedVoicePath isEqualToString:selected.path]) {
        globalSelectedVoicePath = nil;
    } else {
        globalSelectedVoicePath = selected.absoluteURL.path;
    }
    [self.tableView reloadData];
}

#pragma mark - Voice Preview

- (void)previewVoiceTapped:(UIButton *)sender {
    NSString *path = sender.accessibilityIdentifier;
    if (!path) return;
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    
    if (self.audioPlayer && self.audioPlayer.isPlaying) {
        [self.audioPlayer stop];
        BOOL wasPlayingSame = [self.currentlyPlayingURL.path isEqualToString:path];
        self.audioPlayer = nil;
        self.currentlyPlayingURL = nil;
        
        [self.tableView reloadData];
        if (wasPlayingSame) return; // If same, we just stopped it
    }
    
    NSError *err = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:&err];
    if (!err) {
        self.audioPlayer.delegate = self;
        self.currentlyPlayingURL = fileUrl;
        [self.audioPlayer play];
    }
    [self.tableView reloadData];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    self.audioPlayer = nil;
    self.currentlyPlayingURL = nil;
    [self.tableView reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSURL *fileUrl = self.filteredItems[indexPath.row];
    NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
    if (![self.currentDirectoryPath isEqualToString:rootFolder] && [fileUrl.path isEqualToString:[self.currentDirectoryPath stringByDeletingLastPathComponent]]) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSURL *fileUrl = self.filteredItems[indexPath.row];
        NSError *err = nil;
        [[NSFileManager defaultManager] removeItemAtURL:fileUrl error:&err];
        
        if (!err) {
            if (globalSelectedVoicePath && [globalSelectedVoicePath hasPrefix:fileUrl.path]) {
                globalSelectedVoicePath = nil;
            }
            [self loadVoices];
        }
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint p = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
        if (indexPath) {
            NSURL *fileUrl = self.filteredItems[indexPath.row];
            NSString *rootFolder = [[InstaLocalStorage shared] getVoicesFolder];
            if (![self.currentDirectoryPath isEqualToString:rootFolder] && [fileUrl.path isEqualToString:[self.currentDirectoryPath stringByDeletingLastPathComponent]]) {
                return;
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Yeniden Adlandır" message:@"Yeni ismi girin:" preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.text = [fileUrl.lastPathComponent stringByDeletingPathExtension];
            }];
            [alert addAction:[UIAlertAction actionWithTitle:@"İptal" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *newName = alert.textFields.firstObject.text;
                if (newName && newName.length > 0) {
                    NSString *ext = fileUrl.pathExtension;
                    NSString *newFullName = ext.length > 0 ? [NSString stringWithFormat:@"%@.%@", newName, ext] : newName;
                    NSURL *newUrl = [fileUrl.URLByDeletingLastPathComponent URLByAppendingPathComponent:newFullName];
                    [[NSFileManager defaultManager] moveItemAtURL:fileUrl toURL:newUrl error:nil];
                    if ([globalSelectedVoicePath isEqualToString:fileUrl.path]) {
                        globalSelectedVoicePath = newUrl.path;
                    }
                    [self loadVoices];
                }
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end

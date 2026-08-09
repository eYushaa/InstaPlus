#import "RVCSettingsViewController.h"

@interface RVCSettingsViewController () <UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UITextField *modelField;
@property (nonatomic, strong) UISwitch *pitchSwitch;
@property (nonatomic, strong) UISlider *pitchSlider;
@property (nonatomic, strong) UILabel *pitchLabel;
@property (nonatomic, strong) UILabel *indexLabel;
@property (nonatomic, strong) UISlider *indexSlider;
@property (nonatomic, strong) UITextField *bgField;
@property (nonatomic, strong) UISlider *bgVolumeSlider;
@property (nonatomic, strong) UILabel *bgVolumeLabel;
@property (nonatomic, strong) UISlider *noiseSlider;
@property (nonatomic, strong) UILabel *noiseLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *bgLabel;
@property (nonatomic, strong) UIButton *saveBtn;
@property (nonatomic, strong) UIVisualEffectView *blurView;


@property (nonatomic, strong) UIPickerView *modelPicker;
@property (nonatomic, strong) UIPickerView *bgPicker;
@property (nonatomic, strong) NSArray<NSString *> *models;
@property (nonatomic, strong) NSArray<NSString *> *backgrounds;
@end

@implementation RVCSettingsViewController {
    UIView *_containerView;
}

+ (UIViewController *)topMostViewController {
    UIViewController *topController = nil;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (w.isKeyWindow) {
            topController = w.rootViewController;
            break;
        }
    }
    if (!topController) {
        topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    }
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

+ (void)showSettings {
    UIViewController *topVC = [self topMostViewController];
    if (!topVC) return;
    
    RVCSettingsViewController *vc = [[RVCSettingsViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [topVC presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.models = @[@"None"];
    self.backgrounds = @[@"None"];
    
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 600)];
    _containerView.center = self.view.center;
    _containerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_containerView];
    
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    self.blurView.frame = _containerView.bounds;
    self.blurView.layer.cornerRadius = 24;
    self.blurView.clipsToBounds = YES;
    self.blurView.layer.borderWidth = 1.5;
    self.blurView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.5].CGColor;
    [_containerView addSubview:self.blurView];
    
    _containerView.layer.shadowColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.6].CGColor;
    _containerView.layer.shadowOffset = CGSizeZero;
    _containerView.layer.shadowOpacity = 0.5;
    _containerView.layer.shadowRadius = 15;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 280, 30)];
    titleLabel.text = @"RVC Cloud Ayarları";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:titleLabel];
    
    UILabel *urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, 280, 20)];
    urlLabel.text = @"Ngrok veya Sunucu URL:";
    urlLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    urlLabel.textColor = [UIColor whiteColor];
    [_containerView addSubview:urlLabel];
    
    self.urlField = [[UITextField alloc] initWithFrame:CGRectMake(20, 78, 280, 32)];
    self.urlField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.urlField.textColor = [UIColor whiteColor];
    self.urlField.layer.cornerRadius = 8;
    self.urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_URL"] ?: @"";
    self.urlField.delegate = self;
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 32)];
    self.urlField.leftView = paddingView;
    self.urlField.leftViewMode = UITextFieldViewModeAlways;
    [_containerView addSubview:self.urlField];
    
    UIButton *fetchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    fetchBtn.frame = CGRectMake(20, 118, 280, 32);
    fetchBtn.backgroundColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.3];
    fetchBtn.layer.cornerRadius = 8;
    [fetchBtn setTitle:@"Bağlan & Verileri Çek" forState:UIControlStateNormal];
    fetchBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [fetchBtn addTarget:self action:@selector(fetchData) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:fetchBtn];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.frame = CGRectMake(140, 4, 24, 24);
    [fetchBtn addSubview:self.spinner];
    
    self.modelPicker = [[UIPickerView alloc] init];
    self.modelPicker.delegate = self;
    self.modelPicker.dataSource = self;
    
    self.bgPicker = [[UIPickerView alloc] init];
    self.bgPicker.delegate = self;
    self.bgPicker.dataSource = self;
    
    UILabel *mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, 280, 18)];
    mLabel.text = @"Kullanılacak Model:";
    mLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    mLabel.textColor = [UIColor whiteColor];
    [_containerView addSubview:mLabel];
    
    self.modelField = [[UITextField alloc] initWithFrame:CGRectMake(20, 180, 280, 32)];
    self.modelField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.modelField.textColor = [UIColor whiteColor];
    self.modelField.layer.cornerRadius = 8;
    self.modelField.inputView = self.modelPicker;
    self.modelField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_MODEL"] ?: @"None";
    self.modelField.delegate = self;
    UIView *p2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 32)];
    self.modelField.leftView = p2;
    self.modelField.leftViewMode = UITextFieldViewModeAlways;
    [_containerView addSubview:self.modelField];
    
    // Pitch (Ses Tonu) Switch & Slider
    UILabel *pSwitchLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 222, 200, 24)];
    pSwitchLabel.text = @"Özel Pitch (Ses Tonu):";
    pSwitchLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    pSwitchLabel.textColor = [UIColor whiteColor];
    [_containerView addSubview:pSwitchLabel];
    
    self.pitchSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(240, 218, 51, 31)];
    self.pitchSwitch.onTintColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0];
    self.pitchSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"C2M_RVC_PITCH_ENABLED"];
    [_containerView addSubview:self.pitchSwitch];
    
    float savedPitch = [[NSUserDefaults standardUserDefaults] integerForKey:@"C2M_RVC_PITCH"];
    self.pitchLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 252, 280, 18)];
    self.pitchLabel.text = [NSString stringWithFormat:@"Pitch (Ses Tonu): %+.0f yarım ton", savedPitch];
    self.pitchLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.pitchLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    [_containerView addSubview:self.pitchLabel];
    
    self.pitchSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 272, 280, 24)];
    self.pitchSlider.minimumValue = -24;
    self.pitchSlider.maximumValue = 24;
    self.pitchSlider.value = savedPitch;
    self.pitchSlider.tintColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0];
    [self.pitchSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:self.pitchSlider];
    
    // Index Slider
    float savedIndex = [[NSUserDefaults standardUserDefaults] floatForKey:@"C2M_RVC_INDEX"];
    if (savedIndex == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:@"C2M_RVC_INDEX"]) savedIndex = 0.4;
    
    self.indexLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 305, 280, 18)];
    self.indexLabel.text = [NSString stringWithFormat:@"Index Oranı: %.2f", savedIndex];
    self.indexLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.indexLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.indexLabel.hidden = YES;
    [_containerView addSubview:self.indexLabel];
    
    self.indexSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 325, 280, 24)];
    self.indexSlider.minimumValue = 0.0;
    self.indexSlider.maximumValue = 1.0;
    self.indexSlider.value = savedIndex;
    self.indexSlider.tintColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0];
    self.indexSlider.hidden = YES;
    [self.indexSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:self.indexSlider];

    // Arka Plan Sesi & Volume
    self.bgLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 355, 280, 18)];
    self.bgLabel.text = @"Arka Plan Sesi (Gürültü/Yağmur):";
    self.bgLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.self.bgLabel.textColor = [UIColor whiteColor];
    [_containerView addSubview:self.bgLabel];
    
    self.bgField = [[UITextField alloc] initWithFrame:CGRectMake(20, 375, 280, 32)];
    self.bgField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.bgField.textColor = [UIColor whiteColor];
    self.bgField.layer.cornerRadius = 8;
    self.bgField.inputView = self.bgPicker;
    self.bgField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_BG"] ?: @"None";
    self.bgField.delegate = self;
    UIView *p3 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 32)];
    self.bgField.leftView = p3;
    self.bgField.leftViewMode = UITextFieldViewModeAlways;
    [_containerView addSubview:self.bgField];
    
    float savedBgVol = [[NSUserDefaults standardUserDefaults] floatForKey:@"C2M_RVC_BG_VOL"];
    if (savedBgVol == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:@"C2M_RVC_BG_VOL"]) savedBgVol = -15.0;
    
    self.bgVolumeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 412, 280, 18)];
    self.bgVolumeLabel.text = [NSString stringWithFormat:@"Arka Plan Ses Seviyesi (%.0f dB)", savedBgVol];
    self.bgVolumeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.bgVolumeLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    [_containerView addSubview:self.bgVolumeLabel];
    
    self.bgVolumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 432, 280, 24)];
    self.bgVolumeSlider.minimumValue = -40;
    self.bgVolumeSlider.maximumValue = 0;
    self.bgVolumeSlider.value = savedBgVol;
    self.bgVolumeSlider.tintColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0];
    [self.bgVolumeSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:self.bgVolumeSlider];
    
    // Gürültü Engelleme
    float savedNoise = [[NSUserDefaults standardUserDefaults] floatForKey:@"C2M_RVC_NOISE"];
    if (savedNoise == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:@"C2M_RVC_NOISE"]) savedNoise = 0.75;
    
    self.noiseLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 465, 280, 18)];
    self.noiseLabel.text = [NSString stringWithFormat:@"Gürültü Engelleme (%.0f%%)", savedNoise * 100];
    self.noiseLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.noiseLabel.textColor = [UIColor whiteColor];
    [_containerView addSubview:self.noiseLabel];
    
    self.noiseSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 485, 280, 24)];
    self.noiseSlider.minimumValue = 0.0;
    self.noiseSlider.maximumValue = 1.0;
    self.noiseSlider.value = savedNoise;
    self.noiseSlider.tintColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:1.0];
    [self.noiseSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_containerView addSubview:self.noiseSlider];
    
    // Action Buttons
    self.saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.saveBtn.frame = CGRectMake(20, 545, 280, 42);
    self.saveBtn.backgroundColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.6 alpha:0.8];
    self.saveBtn.layer.cornerRadius = 14;
    [self.saveBtn setTitle:@"Kaydet ve Kapat" forState:UIControlStateNormal];
    self.saveBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [self.saveBtn addTarget:self action:@selector(saveAndClose) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:self.saveBtn];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
}


- (void)updateUIForIndex:(BOOL)hasIndex animated:(BOOL)animated {
    CGFloat offset = hasIndex ? 0 : -50;
    CGFloat baseHeight = 600;
    CGFloat newHeight = baseHeight + offset;
    
    CGFloat bgLabelY = 355;
    CGFloat bgFieldY = 375;
    CGFloat bgVolLabelY = 412;
    CGFloat bgVolSliderY = 432;
    CGFloat noiseLabelY = 465;
    CGFloat noiseSliderY = 485;
    CGFloat saveBtnY = 545;
    
    void (^animations)(void) = ^{
        self.indexLabel.alpha = hasIndex ? 1.0 : 0.0;
        self.indexSlider.alpha = hasIndex ? 1.0 : 0.0;
        
        CGRect f1 = self.bgLabel.frame; f1.origin.y = bgLabelY + offset; self.bgLabel.frame = f1;
        CGRect f2 = self.bgField.frame; f2.origin.y = bgFieldY + offset; self.bgField.frame = f2;
        CGRect f3 = self.bgVolumeLabel.frame; f3.origin.y = bgVolLabelY + offset; self.bgVolumeLabel.frame = f3;
        CGRect f4 = self.bgVolumeSlider.frame; f4.origin.y = bgVolSliderY + offset; self.bgVolumeSlider.frame = f4;
        CGRect f5 = self.noiseLabel.frame; f5.origin.y = noiseLabelY + offset; self.noiseLabel.frame = f5;
        CGRect f6 = self.noiseSlider.frame; f6.origin.y = noiseSliderY + offset; self.noiseSlider.frame = f6;
        CGRect f7 = self.saveBtn.frame; f7.origin.y = saveBtnY + offset; self.saveBtn.frame = f7;
        
        CGRect cFrame = _containerView.frame;
        cFrame.size.height = newHeight;
        _containerView.frame = cFrame;
        _containerView.center = self.view.center;
        
        CGRect bFrame = self.blurView.frame;
        bFrame.size.height = newHeight;
        self.blurView.frame = bFrame;
    };
    
    if (animated) {
        if (hasIndex) {
            self.indexLabel.hidden = NO;
            self.indexSlider.hidden = NO;
        }
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:animations completion:^(BOOL finished) {
            if (!hasIndex) {
                self.indexLabel.hidden = YES;
                self.indexSlider.hidden = YES;
            }
        }];
    } else {
        self.indexLabel.hidden = !hasIndex;
        self.indexSlider.hidden = !hasIndex;
        animations();
    }
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)sliderValueChanged:(UISlider *)slider {
    if (slider == self.pitchSlider) {
        float val = roundf(slider.value);
        self.pitchLabel.text = [NSString stringWithFormat:@"Pitch (Ses Tonu): %+.0f yarım ton", val];
    } else if (slider == self.indexSlider) {
        self.indexLabel.text = [NSString stringWithFormat:@"Index Oranı: %.2f", slider.value];
    } else if (slider == self.bgVolumeSlider) {
        self.bgVolumeLabel.text = [NSString stringWithFormat:@"Arka Plan Ses Seviyesi (%.0f dB)", slider.value];
    } else if (slider == self.noiseSlider) {
        self.noiseLabel.text = [NSString stringWithFormat:@"Gürültü Engelleme (%.0f%%)", slider.value * 100];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.urlField.text.length > 0) {
        [self fetchData];
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == self.modelField) {
        NSString *currentModel = self.modelField.text;
        for (int i=0; i<self.models.count; i++) {
            if ([self.models[i] hasPrefix:currentModel]) {
                [self.modelPicker selectRow:i inComponent:0 animated:NO];
                break;
            }
        }
    } else if (textField == self.bgField) {
        NSUInteger idx = [self.backgrounds indexOfObject:self.bgField.text];
        if (idx != NSNotFound) {
            [self.bgPicker selectRow:idx inComponent:0 animated:NO];
        }
    }
}

- (void)fetchData {
    [self dismissKeyboard];
    NSString *urlStr = self.urlField.text;
    if (urlStr.length == 0) return;
    
    if ([urlStr hasSuffix:@"/"]) {
        urlStr = [urlStr substringToIndex:urlStr.length - 1];
    }
    
    [self.spinner startAnimating];
    
    NSURL *modelsUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/models", urlStr]];
    NSURLSessionDataTask *task1 = [[NSURLSession sharedSession] dataTaskWithURL:modelsUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error && data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && json[@"models"]) {
                NSMutableArray *m = [NSMutableArray arrayWithObject:@"None"];
                [m addObjectsFromArray:json[@"models"]];
                self.models = m;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.modelPicker reloadAllComponents];
            
            NSString *savedModel = self.modelField.text;
            NSUInteger mIdx = NSNotFound;
            for (int i=0; i<self.models.count; i++) {
                if ([self.models[i] hasPrefix:savedModel]) {
                    mIdx = i; break;
                }
            }
            if (mIdx != NSNotFound) {
                [self.modelPicker selectRow:mIdx inComponent:0 animated:NO];
                
                NSString *raw = self.models[mIdx];
                NSArray *parts = [raw componentsSeparatedByString:@"|"];
                self.modelField.text = parts.firstObject;
                BOOL hasIndex = NO;
                if (parts.count > 1 && [parts[1] isEqualToString:@"1"]) {
                    hasIndex = YES;
                }
                [self updateUIForIndex:hasIndex animated:NO];
            }
            
            NSURL *bgUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/backgrounds", urlStr]];
            NSURLSessionDataTask *task2 = [[NSURLSession sharedSession] dataTaskWithURL:bgUrl completionHandler:^(NSData *d2, NSURLResponse *r2, NSError *e2) {
                if (!e2 && d2) {
                    NSDictionary *j2 = [NSJSONSerialization JSONObjectWithData:d2 options:0 error:nil];
                    if (j2 && j2[@"backgrounds"]) {
                        NSMutableArray *b = [NSMutableArray arrayWithObject:@"None"];
                        [b addObjectsFromArray:j2[@"backgrounds"]];
                        self.backgrounds = b;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bgPicker reloadAllComponents];
                    NSString *savedBg = self.bgField.text;
                    NSUInteger bIdx = [self.backgrounds indexOfObject:savedBg];
                    if (bIdx != NSNotFound) {
                        [self.bgPicker selectRow:bIdx inComponent:0 animated:NO];
                    }
                    [self.spinner stopAnimating];
                });
            }];
            [task2 resume];
        });
    }];
    [task1 resume];
}

- (void)saveAndClose {
    [[NSUserDefaults standardUserDefaults] setObject:self.urlField.text forKey:@"C2M_RVC_URL"];
    [[NSUserDefaults standardUserDefaults] setObject:self.modelField.text forKey:@"C2M_RVC_MODEL"];
    [[NSUserDefaults standardUserDefaults] setBool:self.pitchSwitch.isOn forKey:@"C2M_RVC_PITCH_ENABLED"];
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)roundf(self.pitchSlider.value) forKey:@"C2M_RVC_PITCH"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.indexSlider.value forKey:@"C2M_RVC_INDEX"];
    [[NSUserDefaults standardUserDefaults] setObject:self.bgField.text forKey:@"C2M_RVC_BG"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.bgVolumeSlider.value forKey:@"C2M_RVC_BG_VOL"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.noiseSlider.value forKey:@"C2M_RVC_NOISE"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // ANINDA MODEL DEGISTIRME ISTEGI
    NSString *urlStr = self.urlField.text;
    if ([urlStr hasSuffix:@"/"]) urlStr = [urlStr substringToIndex:urlStr.length - 1];
    NSString *modelStr = self.modelField.text;
    if (![modelStr isEqualToString:@"None"] && modelStr.length > 0 && urlStr.length > 0) {
        NSURL *setModelUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/set_model", urlStr]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:setModelUrl];
        req.HTTPMethod = @"POST";
        NSString *bodyStr = [NSString stringWithFormat:@"model_id=%@&index_ratio=%f", [modelStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], self.indexSlider.value];
        req.HTTPBody = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [[[NSURLSession sharedSession] dataTaskWithRequest:req] resume];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIPickerView
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) return self.models.count;
    return self.backgrounds.count;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) {
        NSString *raw = self.models[row];
        return [raw componentsSeparatedByString:@"|"].firstObject;
    }
    return self.backgrounds[row];
}
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) {
        if (row < self.models.count) {
            NSString *raw = self.models[row];
            NSArray *parts = [raw componentsSeparatedByString:@"|"];
            self.modelField.text = parts.firstObject;
            
            BOOL hasIndex = NO;
            if (parts.count > 1 && [parts[1] isEqualToString:@"1"]) {
                hasIndex = YES;
            }
            [self updateUIForIndex:hasIndex animated:YES];
        }
    } else {
        if (row < self.backgrounds.count) {
            self.bgField.text = self.backgrounds[row];
        }
    }
}
@end

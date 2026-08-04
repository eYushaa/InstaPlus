#import <AVFoundation/AVFoundation.h>
#import <sys/xattr.h>
#import <UIKit/UIKit.h>

static NSURL *globalLastRecordedURL = nil;
static NSDate *lastProcessedFileModDate = nil;
static void processRVCForInstagramAudioURL(NSURL *recordUrl);



// ==========================================
// RVC VOICE & GALLERY FOR INSTAGRAM DM
// ==========================================
#import "VoiceGalleryViewController.h"
#import "RVCSettingsViewController.h"
#import "InstaLocalStorage.h"
extern NSString *globalSelectedVoicePath;
static __thread BOOL isRVCInternalWriting = NO;
static void processRVCForInstagramAudioURL(NSURL *recordUrl) {
    NSLog(@"[InstaPLUS] RVC: processRVCForInstagramAudioURL called with recordUrl: %@", recordUrl);
    if (!recordUrl || ![recordUrl isFileURL]) {
        NSLog(@"[InstaPLUS] RVC: recordUrl is nil or not fileURL. Aborting.");
        return;
    }
    
    NSString *path = recordUrl.path;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *currentModDate = [attrs fileModificationDate];
    
    if (lastProcessedFileModDate && currentModDate && [currentModDate isEqualToDate:lastProcessedFileModDate]) {
        NSLog(@"[InstaPLUS] RVC: Skipping because this file modification date was already processed.");
        return;
    }

    static dispatch_once_t onceToken;
    static dispatch_semaphore_t processLock = nil;
    static NSDate *lastAnyProcessTime = nil;
    dispatch_once(&onceToken, ^{
        processLock = dispatch_semaphore_create(1);
    });

    NSLog(@"[InstaPLUS] RVC: Waiting for processLock...");
    dispatch_semaphore_wait(processLock, DISPATCH_TIME_FOREVER);
    NSLog(@"[InstaPLUS] RVC: Acquired processLock!");
    
    if (lastAnyProcessTime && [[NSDate date] timeIntervalSinceDate:lastAnyProcessTime] < 2.0) {
        NSLog(@"[InstaPLUS] RVC: Skipping because another file was just processed within 2s. (Path: %@)", path);
        dispatch_semaphore_signal(processLock);
        return;
    }

    dispatch_block_t cleanupProcessingBlock = ^{
        NSLog(@"[InstaPLUS] RVC: cleanupProcessingBlock called.");
        lastAnyProcessTime = [NSDate date];
        dispatch_semaphore_signal(processLock);
    };

    BOOL rvcEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"rvc_enabled"];
    NSLog(@"[InstaPLUS] RVC: rvc_enabled = %d, globalSelectedVoicePath = %@", rvcEnabled, globalSelectedVoicePath);

    // 1. Galeri Sesi Kontrolu
    if (globalSelectedVoicePath && globalSelectedVoicePath.length > 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:globalSelectedVoicePath]) {
            NSLog(@"[InstaPLUS] RVC: Applying gallery voice from path: %@", globalSelectedVoicePath);
            isRVCInternalWriting = YES;
            [fm removeItemAtURL:recordUrl error:nil];
            [fm copyItemAtPath:globalSelectedVoicePath toPath:recordUrl.path error:nil];
            isRVCInternalWriting = NO;
            NSLog(@"[InstaPLUS] RVC: Galeri sesi başarıyla uygulandı.");
            globalSelectedVoicePath = nil; // Clear after use
            
            NSDictionary *newAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:recordUrl.path error:nil];
            lastProcessedFileModDate = [newAttrs fileModificationDate];
            
            cleanupProcessingBlock();
            return;
        } else {
            NSLog(@"[InstaPLUS] RVC: Gallery voice file does NOT exist at path: %@", globalSelectedVoicePath);
        }
    }

    // 2. RVC Cloud Kontrolu
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_URL"];
    NSLog(@"[InstaPLUS] RVC: serverUrl = %@", serverUrl);
    if (rvcEnabled && serverUrl && serverUrl.length > 0) {
        NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_MODEL"];
        NSString *bg = [[NSUserDefaults standardUserDefaults] stringForKey:@"C2M_RVC_BG"];
        float bgVol = [[NSUserDefaults standardUserDefaults] floatForKey:@"C2M_RVC_BG_VOL"];
        float noiseReduction = [[NSUserDefaults standardUserDefaults] floatForKey:@"C2M_RVC_NOISE"];
        if (noiseReduction == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:@"C2M_RVC_NOISE"]) noiseReduction = 0.75;

        if ([serverUrl hasSuffix:@"/"]) {
            serverUrl = [serverUrl substringToIndex:serverUrl.length - 1];
        }

        if (![serverUrl hasPrefix:@"http://"] && ![serverUrl hasPrefix:@"https://"]) {
            serverUrl = [NSString stringWithFormat:@"http://%@", serverUrl];
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/process", serverUrl]]];
        req.HTTPMethod = @"POST";
        NSLog(@"[InstaPLUS] RVC: Prepared HTTP POST request to: %@", req.URL);

        NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
        [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

        NSMutableData *body = [NSMutableData data];
        NSData *audioData = [NSData dataWithContentsOfURL:recordUrl];
        if (!audioData || audioData.length == 0) {
            NSLog(@"[InstaPLUS] RVC: ERROR - audioData is nil or empty! Cannot upload.");
            cleanupProcessingBlock();
            return;
        }
        NSLog(@"[InstaPLUS] RVC: Audio data read successfully. Size: %lu bytes", (unsigned long)audioData.length);

        [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\nContent-Type: audio/m4a\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:audioData];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

        // Model
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"model_id\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", model ?: @""] dataUsingEncoding:NSUTF8StringEncoding]];

        // BG
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"background\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", bg ?: @""] dataUsingEncoding:NSUTF8StringEncoding]];

        // BG Vol
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"bg_volume\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%f\r\n", bgVol] dataUsingEncoding:NSUTF8StringEncoding]];

        BOOL pitchEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"C2M_RVC_PITCH_ENABLED"];
        if (pitchEnabled) {
            NSInteger pitchVal = [[NSUserDefaults standardUserDefaults] integerForKey:@"C2M_RVC_PITCH"];
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"pitch\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"%ld\r\n", (long)pitchVal] dataUsingEncoding:NSUTF8StringEncoding]];
        }

        // Noise Reduction
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"noise_reduction\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%f\r\n", noiseReduction] dataUsingEncoding:NSUTF8StringEncoding]];

        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

        req.HTTPBody = body;
        NSLog(@"[InstaPLUS] RVC: Initiating NSURLSession upload task...");

        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data && data.length > 0) {
                NSLog(@"[InstaPLUS] RVC: RVC Cloud successful! Received response data size: %lu", (unsigned long)data.length);
                isRVCInternalWriting = YES;
                [[NSFileManager defaultManager] removeItemAtURL:recordUrl error:nil];
                [data writeToURL:recordUrl atomically:YES];
                isRVCInternalWriting = NO;
                
                NSDictionary *newAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:recordUrl.path error:nil];
                lastProcessedFileModDate = [newAttrs fileModificationDate];
            } else {
                NSLog(@"[InstaPLUS] RVC: RVC Cloud Error! error: %@, response: %@, data length: %lu", error, response, (unsigned long)data.length);
            }
            dispatch_semaphore_signal(sema);
        }];
        [task resume];

        NSLog(@"[InstaPLUS] RVC: Waiting for network response...");
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        NSLog(@"[InstaPLUS] RVC: Network response received!");
    } else {
        NSLog(@"[InstaPLUS] RVC: Condition failed. rvcEnabled=%d, serverUrl='%@'", rvcEnabled, serverUrl);
    }

    cleanupProcessingBlock();
}
#import <substrate.h>
#import <AudioToolbox/AudioToolbox.h>
static NSMutableDictionary<NSValue *, NSURL *> *audioFileToURLMap = nil;
static OSStatus (*orig_ExtAudioFileCreateWithURL)(CFURLRef, AudioFileTypeID, const AudioStreamBasicDescription *, const AudioChannelLayout *, UInt32, ExtAudioFileRef *);
static OSStatus hooked_ExtAudioFileCreateWithURL(CFURLRef inURL, AudioFileTypeID inFileTypeID, const AudioStreamBasicDescription *inStreamDesc, const AudioChannelLayout *inChannelLayout, UInt32 inFlags, ExtAudioFileRef *outAudioFile) {
    OSStatus res = orig_ExtAudioFileCreateWithURL(inURL, inFileTypeID, inStreamDesc, inChannelLayout, inFlags, outAudioFile);
    if (res == noErr && outAudioFile && *outAudioFile) {
        NSURL *url = (__bridge NSURL *)inURL;
        if (url) {
            NSLog(@"[InstaPLUS] AUDIO_HOOK: ExtAudioFileCreateWithURL for %@", url);
            @synchronized (audioFileToURLMap) {
                if (!isRVCInternalWriting) {
                    [audioFileToURLMap setObject:url forKey:[NSValue valueWithPointer:*outAudioFile]];
                    globalLastRecordedURL = url;
                }
            }
        }
    }
    return res;
}
static OSStatus (*orig_AudioFileCreateWithURL)(CFURLRef, AudioFileTypeID, const AudioStreamBasicDescription *, UInt32, AudioFileID *);
static OSStatus hooked_AudioFileCreateWithURL(CFURLRef inURL, AudioFileTypeID inFileTypeID, const AudioStreamBasicDescription *inStreamDesc, UInt32 inFlags, AudioFileID *outAudioFile) {
    OSStatus res = orig_AudioFileCreateWithURL(inURL, inFileTypeID, inStreamDesc, inFlags, outAudioFile);
    if (res == noErr && outAudioFile && *outAudioFile) {
        NSURL *url = (__bridge NSURL *)inURL;
        if (url) {
            @synchronized (audioFileToURLMap) {
                audioFileToURLMap[[NSValue valueWithPointer:*outAudioFile]] = url;
            }
        }
    }
    return res;
}
static OSStatus (*orig_ExtAudioFileDispose)(ExtAudioFileRef);
static OSStatus hooked_ExtAudioFileDispose(ExtAudioFileRef inExtAudioFile) {
    NSURL *url = nil;
    if (audioFileToURLMap) {
        @synchronized (audioFileToURLMap) {
            NSValue *key = [NSValue valueWithPointer:inExtAudioFile];
            url = audioFileToURLMap[key];
            if (url) [audioFileToURLMap removeObjectForKey:key];
        }
    }
    OSStatus res = orig_ExtAudioFileDispose(inExtAudioFile);
    if (url) {
        NSLog(@"[InstaPLUS] AUDIO_HOOK: ExtAudioFileDispose for %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
        if (!isRVCInternalWriting) {
            globalLastRecordedURL = url;
            processRVCForInstagramAudioURL(url);
        }
    }
    return res;
}
static OSStatus (*orig_AudioFileClose)(AudioFileID);
static OSStatus hooked_AudioFileClose(AudioFileID inAudioFile) {
    NSURL *url = nil;
    if (audioFileToURLMap) {
        @synchronized (audioFileToURLMap) {
            NSValue *key = [NSValue valueWithPointer:inAudioFile];
            url = audioFileToURLMap[key];
            if (url) [audioFileToURLMap removeObjectForKey:key];
        }
    }
    OSStatus res = orig_AudioFileClose(inAudioFile);
    if (url) {
        NSLog(@"[InstaPLUS] AUDIO_HOOK: AudioFileClose for %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
        if (!isRVCInternalWriting) {
            globalLastRecordedURL = url;
            processRVCForInstagramAudioURL(url);
        }
    }
    return res;
}

static OSStatus (*orig_AudioQueueStop)(AudioQueueRef, Boolean);
static OSStatus hooked_AudioQueueStop(AudioQueueRef inAQ, Boolean inImmediate) {
    OSStatus res = orig_AudioQueueStop(inAQ, inImmediate);
    if (globalLastRecordedURL) {
        NSLog(@"[InstaPLUS] AUDIO_HOOK: AudioQueueStop called. globalLastRecordedURL: %@ (isRVCInternalWriting: %d)", globalLastRecordedURL, isRVCInternalWriting);
        if (!isRVCInternalWriting) {
            processRVCForInstagramAudioURL(globalLastRecordedURL);
        }
    } else {
        NSLog(@"[InstaPLUS] AUDIO_HOOK: AudioQueueStop called but globalLastRecordedURL is nil");
    }
    return res;
}

// ----------------------------------------------------

%group RVCHooks

%hook IGDirectThreadViewController
- (void)voiceRecordViewController:(id)arg1 didRecordAudioClipWithURL:(NSURL *)arg2 waveform:(id)arg3 duration:(CGFloat)arg4 entryPoint:(NSInteger)arg5 {
    NSLog(@"[InstaPLUS] didRecordAudioClipWithURL called. arg2=%@, globalLastRecordedURL=%@", arg2, globalLastRecordedURL);
    if (arg2) {
        processRVCForInstagramAudioURL(arg2);
    } else if (globalLastRecordedURL) {
        processRVCForInstagramAudioURL(globalLastRecordedURL);
    }
    %orig;
}
%end

%hook _TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView
- (void)didTapSend {
    NSLog(@"[InstaPLUS] didTapSend called. globalLastRecordedURL=%@", globalLastRecordedURL);
    if (globalLastRecordedURL) {
        processRVCForInstagramAudioURL(globalLastRecordedURL);
    }
    %orig;
}
%end

%hook AVAudioRecorder
- (void)stop {
    NSURL *url = self.url;
    NSLog(@"[InstaPLUS] AUDIO_HOOK: [AVAudioRecorder stop] called. URL: %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
    %orig;
    if (url && !isRVCInternalWriting) {
        globalLastRecordedURL = url;
        processRVCForInstagramAudioURL(url);
    }
}
%end

%hook NSData
- (BOOL)writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr {
    BOOL res = %orig;
    if (res && url) {
        NSString *path = url.path.lowercaseString;
        if ([path containsString:@".m4a"] || [path containsString:@".caf"] || [path containsString:@".aac"] || [path containsString:@".wav"] || [path containsString:@"audio_"] || [path containsString:@"voice_"]) {
            if (![path containsString:@"instagallery"] && ![path containsString:@"insta_voices"]) {
                NSLog(@"[InstaPLUS] AUDIO_HOOK: [NSData writeToURL:] for %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
                if (!isRVCInternalWriting) {
                    globalLastRecordedURL = url;
                    processRVCForInstagramAudioURL(url);
                }
            }
        }
    }
    return res;
}

- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr {
    BOOL res = %orig;
    if (res && path) {
        NSString *lpath = path.lowercaseString;
        if ([lpath containsString:@".m4a"] || [lpath containsString:@".caf"] || [lpath containsString:@".aac"] || [path containsString:@".wav"] || [path containsString:@"audio_"] || [path containsString:@"voice_"]) {
            if (![lpath containsString:@"instagallery"] && ![lpath containsString:@"insta_voices"]) {
                NSLog(@"[InstaPLUS] AUDIO_HOOK: [NSData writeToFile:] for %@ (isRVCInternalWriting: %d)", path, isRVCInternalWriting);
                if (!isRVCInternalWriting) {
                    NSURL *url = [NSURL fileURLWithPath:path];
                    globalLastRecordedURL = url;
                    processRVCForInstagramAudioURL(url);
                }
            }
        }
    }
    return res;
}
%end

%hook IGDirectComposer
- (void)_didLongPressVoiceMessage:(UIGestureRecognizer *)arg1 {
    if (arg1.state == UIGestureRecognizerStateEnded || arg1.state == UIGestureRecognizerStateCancelled) {
        NSLog(@"[InstaPLUS] _didLongPressVoiceMessage ENDED. globalLastRecordedURL=%@", globalLastRecordedURL);
        
        NSURL *urlToProcess = globalLastRecordedURL;
        if (!urlToProcess) {
            NSLog(@"[InstaPLUS] globalLastRecordedURL is nil! Trying to find the most recent audio file in temp directory...");
            NSString *tempDir = NSTemporaryDirectory();
            NSFileManager *fm = [NSFileManager defaultManager];
            NSArray *files = [fm contentsOfDirectoryAtPath:tempDir error:nil];
            NSString *newestFile = nil;
            NSDate *newestDate = nil;
            
            for (NSString *file in files) {
                if ([file hasSuffix:@".m4a"] || [file hasSuffix:@".caf"] || [file hasSuffix:@".aac"] || [file hasSuffix:@".wav"]) {
                    NSString *fullPath = [tempDir stringByAppendingPathComponent:file];
                    NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                    NSDate *modDate = [attrs fileModificationDate];
                    if (!newestDate || [modDate compare:newestDate] == NSOrderedDescending) {
                        newestDate = modDate;
                        newestFile = fullPath;
                    }
                }
            }
            if (newestFile) {
                urlToProcess = [NSURL fileURLWithPath:newestFile];
                NSLog(@"[InstaPLUS] Found newest audio file: %@", urlToProcess);
            } else {
                NSLog(@"[InstaPLUS] Could not find any audio file in temp directory!");
            }
        }
        
        if (urlToProcess) {
            processRVCForInstagramAudioURL(urlToProcess);
        }
    }
    %orig;
}
%end

%hook AVAssetWriter
- (void)finishWritingWithCompletionHandler:(void (^)(void))handler {
    NSURL *url = self.outputURL;
    NSString *path = url.path.lowercaseString;
    NSLog(@"[InstaPLUS] AUDIO_HOOK: [AVAssetWriter finishWritingWithCompletionHandler] URL: %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
    
    BOOL shouldSaveURL = NO;
    if (!isRVCInternalWriting && ([path containsString:@".m4a"] || [path containsString:@".caf"] || [path containsString:@".aac"] || [path containsString:@"audio"] || [path containsString:@"voice"])) {
        if (![path containsString:@"instagallery"] && ![path containsString:@"insta_voices"]) {
            shouldSaveURL = YES;
        }
    }
    
    void (^customHandler)(void) = ^{
        if (shouldSaveURL) {
            globalLastRecordedURL = url;
            processRVCForInstagramAudioURL(url);
        }
        if (handler) handler();
    };
    
    %orig(customHandler);
}

- (BOOL)finishWriting {
    NSURL *url = self.outputURL;
    NSString *path = url.path.lowercaseString;
    NSLog(@"[InstaPLUS] AUDIO_HOOK: [AVAssetWriter finishWriting] URL: %@ (isRVCInternalWriting: %d)", url, isRVCInternalWriting);
    
    if (!isRVCInternalWriting && ([path containsString:@".m4a"] || [path containsString:@".caf"] || [path containsString:@".aac"] || [path containsString:@"audio"] || [path containsString:@"voice"])) {
        if (![path containsString:@"instagallery"] && ![path containsString:@"insta_voices"]) {
            globalLastRecordedURL = url;
            processRVCForInstagramAudioURL(url);
        }
    }
    return %orig;
}
%end

%hook AVAudioFile
- (instancetype)initForWriting:(NSURL *)fileURL settings:(NSDictionary *)settings error:(NSError **)outError {
    NSLog(@"[InstaPLUS] AUDIO_HOOK: [AVAudioFile initForWriting] URL: %@", fileURL);
    if (!isRVCInternalWriting && fileURL) {
        NSString *path = fileURL.path.lowercaseString;
        if (![path containsString:@"instagallery"] && ![path containsString:@"insta_voices"]) {
            globalLastRecordedURL = fileURL;
        }
    }
    return %orig;
}
%end

%end // end group RVCHooks

%ctor {
    %init;
    %init(RVCHooks);
    audioFileToURLMap = [NSMutableDictionary new];
    MSHookFunction((void *)ExtAudioFileCreateWithURL, (void *)hooked_ExtAudioFileCreateWithURL, (void **)&orig_ExtAudioFileCreateWithURL);
    MSHookFunction((void *)AudioFileCreateWithURL, (void *)hooked_AudioFileCreateWithURL, (void **)&orig_AudioFileCreateWithURL);
    MSHookFunction((void *)ExtAudioFileDispose, (void *)hooked_ExtAudioFileDispose, (void **)&orig_ExtAudioFileDispose);
    MSHookFunction((void *)AudioFileClose, (void *)hooked_AudioFileClose, (void **)&orig_AudioFileClose);
    MSHookFunction((void *)AudioQueueStop, (void *)hooked_AudioQueueStop, (void **)&orig_AudioQueueStop);
}

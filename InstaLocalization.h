#import <Foundation/Foundation.h>

#define L(key) [[InstaLocalization shared] localizedStringForKey:key]

@interface InstaLocalization : NSObject

+ (instancetype)shared;

- (NSString *)localizedStringForKey:(NSString *)key;
- (void)setLanguage:(NSString *)langCode;
- (NSString *)currentLanguage;
- (NSArray<NSString *> *)availableLanguageCodes;
- (NSString *)displayNameForLanguage:(NSString *)langCode;

@end

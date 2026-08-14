#import "InstaLocalization.h"

@interface InstaLocalization ()
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *strings_tr;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *strings_en;
@property (nonatomic, strong) NSString *lang;
@end

@implementation InstaLocalization

+ (instancetype)shared {
    static InstaLocalization *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"instaplus_language"];
        _lang = saved ?: @"tr";
        [self buildStringTables];
    }
    return self;
}

- (void)buildStringTables {
    // ===================== TÜRKÇE =====================
    _strings_tr = @{
        // === Ortak / Common ===
        @"yes": @"Evet",
        @"cancel": @"İptal",
        @"ok": @"Tamam",
        @"save": @"Kaydet",
        @"close": @"Kapat",
        @"delete": @"Sil",
        @"error": @"Hata",
        @"success": @"Başarılı",
        @"create": @"Oluştur",
        @"language": @"Dil",

        // === Mod Menü ===
        @"mod_title": @"InstaPlus | eYushaa",
        @"mod_subtitle": @"GELİŞMİŞ GİZLİLİK VE MEDYA SİSTEMİ",
        @"internal_gallery": @"Dahili Galeri",
        @"ad_blocker": @"Reklam Engelleyici",
        @"anti_screenshot": @"Anti-Screenshot",
        @"hide_seen": @"Görüldü Gizle",
        @"hide_typing": @"Yazıyor Gizle",
        @"keep_deleted": @"Silinenleri Tut",
        @"unlimited_view_once": @"Tek İzlemelikleri Sınırsız Yap",
        @"auto_save_view_once": @"Tek İzlemelikleri Oto-Kaydet",
        @"like_confirm": @"Beğeni Onayı",
        @"follow_confirm": @"Takip Onayı",
        @"call_confirm": @"Arama Onayı",
        @"rvc_voice_changer": @"RVC Ses Değiştirici",
        @"voice_gallery_btn": @"Ses Galerisi Butonu",
        @"media_download_btn": @"Medya İndirme Butonu",
        @"instant_btn": @"Şipşak Butonu",

        // === Onay Diyalogları ===
        @"confirmation_required": @"Onay Gerekiyor",
        @"confirm_message_format": @"'%@' işlemini gerçekleştirmek istediğinize emin misiniz?",
        @"action_like_post": @"Gönderi Beğenme",
        @"action_double_tap_like": @"Çift Tıkla Beğenme",
        @"action_follow_user": @"Kullanıcıyı Takip Etme",
        @"action_voice_call": @"Sesli Arama Başlatma",
        @"action_video_call": @"Görüntülü Arama Başlatma",

        // === DM Medya Overlay ===
        @"downloading_video": @"Video İndiriliyor... Lütfen bekleyin.",
        @"video_saved_format": @"Video @%@ klasörüne kaydedildi!",
        @"download_error": @"İndirme Hatası",
        @"video_save_failed_format": @"Video kaydedilemedi.\nHata: %@\n\nLOG:\n%@",
        @"unknown": @"Bilinmiyor",
        @"video_url_not_found": @"Video URL Bulunamadı",
        @"video_url_not_found_msg_format": @"Ekrandaki medya Video olarak tespit edildi ancak indirme adresi alınamadı.\n\nLOG:\n%@",
        @"photo_saved_format": @"Fotoğraf @%@ klasörüne kaydedildi!",
        @"save_error": @"Kaydetme Hatası",
        @"photo_save_failed_format": @"Fotoğraf kaydedilemedi: %@",
        @"error_log": @"Hata (Log)",
        @"photo_downloaded": @"📸 Fotoğraf İndirildi",
        @"download_error_icon": @"❌ İndirme Hatası",
        @"video_downloaded": @"🎥 Video İndirildi",
        @"media_not_found": @"❌ Medya Bulunamadı",

        // === RVC Ayarları ===
        @"rvc_cloud_settings": @"RVC Cloud Ayarları",
        @"ngrok_url_label": @"Ngrok veya Sunucu URL:",
        @"connect_fetch": @"Bağlan & Verileri Çek",
        @"model_to_use": @"Kullanılacak Model:",
        @"custom_pitch": @"Özel Pitch (Ses Tonu):",
        @"pitch_format": @"Pitch (Ses Tonu): %+.0f yarım ton",
        @"index_ratio_format": @"Index Oranı: %.2f",
        @"background_sound": @"Arka Plan Sesi (Gürültü/Yağmur):",
        @"bg_volume_format": @"Arka Plan Ses Seviyesi (%.0f dB)",
        @"noise_reduction_format": @"Gürültü Engelleme (%.0f%%)",
        @"save_and_close": @"Kaydet ve Kapat",

        // === Şipşak (Instants) ===
        @"instant_photo_placed": @"✓ Fotoğraf Kırpıldı ve Şipşak Ekranına Yerleştirildi!",
        @"returned_to_camera": @"Canlı Kamera Görünümüne Dönüldü",

        // === Galeri Listesi ===
        @"saved_users": @"Kaydedilen Kullanıcılar",
        @"all": @"Tümü",
        @"search_username": @"Kullanıcı Adı Ara...",
        @"no_results": @"Sonuç bulunamadı.",
        @"no_users_saved": @"Henüz hiç kullanıcı kaydedilmemiş.",
        @"delete_user": @"Kullanıcıyı Sil",
        @"delete_user_confirm_format": @"@%@ kullanıcısına ait tüm kaydedilmiş fotoğraf ve videolar kalıcı olarak silinecek. Emin misiniz?",
        @"yes_delete_all": @"Evet, Hepsini Sil",

        // === Ses Galerisi ===
        @"voice_gallery": @"Ses Galerisi",
        @"search_voices": @"Seslerde ara...",
        @"new_folder": @"Yeni Klasör",
        @"new_voice": @"Yeni Ses",
        @"go_back": @"Geri Dön",
        @"root_folder": @"Ana Klasör",
        @"enter_folder_name": @"Klasör adını girin.",
        @"folder_name": @"Klasör Adı",
        @"importing_voices": @"Sesler Aktarılıyor",
        @"processing_voices_format": @"%lu/%lu ses işleniyor:\n%@",
        @"processing_voices_init_format": @"0/%lu ses işleniyor...",
        @"rename": @"Yeniden Adlandır",
        @"enter_new_name": @"Yeni ismi girin:",

        // === Kullanıcı Galerisi ===
        @"all_media": @"Tüm Medyalar",
        @"select": @"Seç",
        @"select_all": @"Tümünü Seç",
        @"deselect_all": @"Tümünü Bırak",
        @"selected_count_format": @"%lu Seçili",
        @"select_items": @"Öğe Seçin",
        @"export_to_camera_roll": @"Film Rulosuna Aktar",
        @"delete_media_confirm": @"Bu medyayı silmek istediğinize emin misiniz?",
        @"media_saved_to_roll": @"Medya film rulosuna kaydedildi.",
        @"delete_items_confirm_format": @"%lu ögeyi silmek istediğinize emin misiniz?",
        @"items_saved_to_roll": @"Seçili ögeler film rulosuna kaydedildi.",
    };

    // ===================== ENGLISH =====================
    _strings_en = @{
        // === Common ===
        @"yes": @"Yes",
        @"cancel": @"Cancel",
        @"ok": @"OK",
        @"save": @"Save",
        @"close": @"Close",
        @"delete": @"Delete",
        @"error": @"Error",
        @"success": @"Success",
        @"create": @"Create",
        @"language": @"Language",

        // === Mod Menu ===
        @"mod_title": @"InstaPlus | eYushaa",
        @"mod_subtitle": @"ADVANCED PRIVACY & MEDIA SYSTEM",
        @"internal_gallery": @"Internal Gallery",
        @"ad_blocker": @"Ad Blocker",
        @"anti_screenshot": @"Anti-Screenshot",
        @"hide_seen": @"Hide Seen",
        @"hide_typing": @"Hide Typing",
        @"keep_deleted": @"Keep Deleted",
        @"unlimited_view_once": @"Unlimited View Once",
        @"auto_save_view_once": @"Auto-Save View Once",
        @"like_confirm": @"Like Confirmation",
        @"follow_confirm": @"Follow Confirmation",
        @"call_confirm": @"Call Confirmation",
        @"rvc_voice_changer": @"RVC Voice Changer",
        @"voice_gallery_btn": @"Voice Gallery Button",
        @"media_download_btn": @"Media Download Button",
        @"instant_btn": @"Instant Button",

        // === Confirmation Dialogs ===
        @"confirmation_required": @"Confirmation Required",
        @"confirm_message_format": @"Are you sure you want to perform '%@'?",
        @"action_like_post": @"Like Post",
        @"action_double_tap_like": @"Double Tap Like",
        @"action_follow_user": @"Follow User",
        @"action_voice_call": @"Start Voice Call",
        @"action_video_call": @"Start Video Call",

        // === DM Media Overlay ===
        @"downloading_video": @"Downloading video... Please wait.",
        @"video_saved_format": @"Video saved to @%@ folder!",
        @"download_error": @"Download Error",
        @"video_save_failed_format": @"Could not save video.\nError: %@\n\nLOG:\n%@",
        @"unknown": @"Unknown",
        @"video_url_not_found": @"Video URL Not Found",
        @"video_url_not_found_msg_format": @"The media on screen was detected as Video but the download URL could not be retrieved.\n\nLOG:\n%@",
        @"photo_saved_format": @"Photo saved to @%@ folder!",
        @"save_error": @"Save Error",
        @"photo_save_failed_format": @"Could not save photo: %@",
        @"error_log": @"Error (Log)",
        @"photo_downloaded": @"📸 Photo Downloaded",
        @"download_error_icon": @"❌ Download Error",
        @"video_downloaded": @"🎥 Video Downloaded",
        @"media_not_found": @"❌ Media Not Found",

        // === RVC Settings ===
        @"rvc_cloud_settings": @"RVC Cloud Settings",
        @"ngrok_url_label": @"Ngrok or Server URL:",
        @"connect_fetch": @"Connect & Fetch Data",
        @"model_to_use": @"Model to Use:",
        @"custom_pitch": @"Custom Pitch (Tone):",
        @"pitch_format": @"Pitch (Tone): %+.0f semitones",
        @"index_ratio_format": @"Index Ratio: %.2f",
        @"background_sound": @"Background Sound (Noise/Rain):",
        @"bg_volume_format": @"Background Volume (%.0f dB)",
        @"noise_reduction_format": @"Noise Reduction (%.0f%%)",
        @"save_and_close": @"Save & Close",

        // === Instants ===
        @"instant_photo_placed": @"✓ Photo Cropped & Placed on Instant Screen!",
        @"returned_to_camera": @"Returned to Live Camera View",

        // === Gallery List ===
        @"saved_users": @"Saved Users",
        @"all": @"All",
        @"search_username": @"Search Username...",
        @"no_results": @"No results found.",
        @"no_users_saved": @"No users saved yet.",
        @"delete_user": @"Delete User",
        @"delete_user_confirm_format": @"All saved photos and videos for @%@ will be permanently deleted. Are you sure?",
        @"yes_delete_all": @"Yes, Delete All",

        // === Voice Gallery ===
        @"voice_gallery": @"Voice Gallery",
        @"search_voices": @"Search voices...",
        @"new_folder": @"New Folder",
        @"new_voice": @"New Voice",
        @"go_back": @"Go Back",
        @"root_folder": @"Root Folder",
        @"enter_folder_name": @"Enter folder name.",
        @"folder_name": @"Folder Name",
        @"importing_voices": @"Importing Voices",
        @"processing_voices_format": @"Processing %lu/%lu voices:\n%@",
        @"processing_voices_init_format": @"Processing 0/%lu voices...",
        @"rename": @"Rename",
        @"enter_new_name": @"Enter new name:",

        // === User Gallery ===
        @"all_media": @"All Media",
        @"select": @"Select",
        @"select_all": @"Select All",
        @"deselect_all": @"Deselect All",
        @"selected_count_format": @"%lu Selected",
        @"select_items": @"Select Items",
        @"export_to_camera_roll": @"Export to Camera Roll",
        @"delete_media_confirm": @"Are you sure you want to delete this media?",
        @"media_saved_to_roll": @"Media saved to camera roll.",
        @"delete_items_confirm_format": @"Are you sure you want to delete %lu items?",
        @"items_saved_to_roll": @"Selected items saved to camera roll.",
    };
}

- (NSString *)localizedStringForKey:(NSString *)key {
    NSDictionary *table = [_lang isEqualToString:@"en"] ? _strings_en : _strings_tr;
    NSString *val = table[key];
    return val ?: key;
}

- (void)setLanguage:(NSString *)langCode {
    _lang = langCode;
    [[NSUserDefaults standardUserDefaults] setObject:langCode forKey:@"instaplus_language"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)currentLanguage {
    return _lang;
}

- (NSArray<NSString *> *)availableLanguageCodes {
    return @[@"tr", @"en"];
}

- (NSString *)displayNameForLanguage:(NSString *)langCode {
    if ([langCode isEqualToString:@"tr"]) return @"🇹🇷 Türkçe";
    if ([langCode isEqualToString:@"en"]) return @"🇬🇧 English";
    return langCode;
}

@end

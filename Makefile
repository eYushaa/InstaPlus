export THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:12.4:11.0
CODESIGNING_METHOD = adhoc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InstaPlusV2
InstaPlusV2_FILES = src/Hooks/Tweak.x src/Hooks/InstaPlusFeatures.x src/Managers/FloatingButtonManager.m src/Managers/FloatingVoiceButtonManager.m src/Managers/LocalPhotoManager.m src/Managers/MediaExtractor.m src/Managers/DMMediaOverlayManager.m src/Managers/InstantsManager.m src/Managers/InstaLocalStorage.m src/UI/GalleryListViewController.m src/UI/UserGalleryViewController.m src/UI/VoiceGalleryViewController.m src/UI/RVCSettingsViewController.m src/UI/ModMenuUI.m src/Utils/InstaLocalization.m
InstaPlusV2_CFLAGS = -fobjc-arc -fno-modules -fno-threadsafe-statics -Isrc/UI -Isrc/Managers -Isrc/Utils -Isrc/Hooks
InstaPlusV2_LDFLAGS = -lc++
InstaPlusV2_FRAMEWORKS = UIKit Foundation AVFoundation AVKit Photos

include $(THEOS_MAKE_PATH)/tweak.mk

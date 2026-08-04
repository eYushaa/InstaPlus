export THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:12.4:11.0
CODESIGNING_METHOD = adhoc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InstaPlus
InstaPlus_FILES = Tweak.x FloatingButtonManager.m FloatingVoiceButtonManager.m GalleryListViewController.m UserGalleryViewController.m LocalPhotoManager.m MediaExtractor.m DMMediaOverlayManager.m InstantsManager.m InstaPlusFeatures.x InstaLocalStorage.m VoiceGalleryViewController.m RVCSettingsViewController.m ModMenuUI.m
InstaPlus_CFLAGS = -fobjc-arc -fno-modules -fno-threadsafe-statics
InstaPlus_LDFLAGS = -lc++
InstaPlus_FRAMEWORKS = UIKit Foundation AVFoundation AVKit

include $(THEOS_MAKE_PATH)/tweak.mk

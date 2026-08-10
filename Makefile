export THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:12.4:11.0
CODESIGNING_METHOD = adhoc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = InstaPlusV2
InstaPlusV2_FILES = Tweak.x FloatingButtonManager.m FloatingVoiceButtonManager.m GalleryListViewController.m UserGalleryViewController.m LocalPhotoManager.m MediaExtractor.m DMMediaOverlayManager.m InstantsManager.m InstaPlusFeatures.x InstaLocalStorage.m VoiceGalleryViewController.m RVCSettingsViewController.m ModMenuUI.m
InstaPlusV2_CFLAGS = -fobjc-arc -fno-modules -fno-threadsafe-statics
InstaPlusV2_LDFLAGS = -lc++
InstaPlusV2_FRAMEWORKS = UIKit Foundation AVFoundation AVKit Photos

include $(THEOS_MAKE_PATH)/tweak.mk

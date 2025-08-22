export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:14.0

THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard Preferences
SUBPROJECTS = Tweak/Core Tweak/Target Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

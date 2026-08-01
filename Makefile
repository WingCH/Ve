export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:14.0

THEOS_PACKAGE_SCHEME ?= rootless

ifneq ($(words $(filter $(THEOS_PACKAGE_SCHEME),rootless roothide)),1)
$(error Unsupported THEOS_PACKAGE_SCHEME '$(THEOS_PACKAGE_SCHEME)'; expected rootless or roothide)
endif

INSTALL_TARGET_PROCESSES = SpringBoard Preferences
SUBPROJECTS = Tweak/Core Tweak/Target Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

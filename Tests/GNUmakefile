include $(GNUSTEP_MAKEFILES)/common.make

#
# Main framework
#
BUNDLE_NAME = DBusKitTests

# Include configuration

-include ../config.make
-include ../GNUmakefile.preamble

DBusKitTests_OBJCFLAGS += $(WARN_FLAGS) -I .
# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
DBusKitTests_OBJCFLAGS += -Werror
endif

DBusKitTests_LDFLAGS=-L../Source/DBusKit.framework/$(GNUSTEP_TARGET_LDIR) -lDBusKit -lUnitKit

DBusKitTests_OBJC_FILES += \
	TestDKArgument.m \
	TestDKEndpointManager.m \
	TestDKInterface.m \
        TestDKMethod.m \
	TestDKMethodCall.m \
        TestDKPort.m \
	TestDKProperty.m \
	TestDKProxy.m

#DBusKitTests_RESOURCE_FILES += \
	Resources/TestHeader.h

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

# Quick hack to keep gnustep-make from installing the testcase-bundle:
DBusKitTests.install.bundle.variables::
	@echo "Not installing testcases"

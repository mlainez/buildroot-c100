################################################################################
#
# whisper-cpp
#
################################################################################

WHISPER_CPP_VERSION = 1.9.5
WHISPER_CPP_SITE = $(call github,ggml-org,whisper.cpp,v$(WHISPER_CPP_VERSION))
WHISPER_CPP_LICENSE = MIT
WHISPER_CPP_LICENSE_FILES = LICENSE

# llama-cpp installs its own, different, shared ggml: link whisper's ggml
# statically into its tools so that both can be installed
WHISPER_CPP_CONF_OPTS = \
	-DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DWHISPER_BUILD_TESTS=OFF \
	-DWHISPER_BUILD_EXAMPLES=ON \
	-DWHISPER_BUILD_SERVER=ON \
	-DWHISPER_FATAL_WARNINGS=OFF \
	-DGGML_NATIVE=OFF

ifeq ($(BR2_TOOLCHAIN_HAS_LIBATOMIC),y)
WHISPER_CPP_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS=-latomic
endif

ifeq ($(BR2_PACKAGE_WHISPER_CPP_VULKAN),y)
WHISPER_CPP_DEPENDENCIES += host-shaderc vulkan-loader
WHISPER_CPP_CONF_OPTS += -DGGML_VULKAN=ON
else
WHISPER_CPP_CONF_OPTS += -DGGML_VULKAN=OFF
endif

# Only the tools are installed; the static libraries and headers are not
define WHISPER_CPP_INSTALL_TARGET_CMDS
	$(foreach t,whisper-cli whisper-server whisper-bench,\
		$(INSTALL) -D -m 0755 $(@D)/buildroot-build/bin/$(t) \
			$(TARGET_DIR)/usr/bin/$(t)$(sep))
endef

$(eval $(cmake-package))

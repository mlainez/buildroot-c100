################################################################################
#
# shaderc
#
################################################################################

SHADERC_VERSION = 2026.4
SHADERC_SITE = $(call github,google,shaderc,v$(SHADERC_VERSION))
SHADERC_LICENSE = Apache-2.0
SHADERC_LICENSE_FILES = LICENSE

# shaderc builds glslang and SPIRV-Tools from third_party/, at the revisions
# pinned in its DEPS file
HOST_SHADERC_GLSLANG_REV = e1b562a8bed273a02f30b59b66a5d499793cede5
HOST_SHADERC_SPIRV_TOOLS_REV = ef96ed763b43b59b33b31b362f09a02b729fa1c9
HOST_SHADERC_SPIRV_HEADERS_REV = 04fd3caa1e8267e4d95c806cad901181728e1006
HOST_SHADERC_EXTRA_DOWNLOADS = \
	https://github.com/KhronosGroup/glslang/archive/$(HOST_SHADERC_GLSLANG_REV).tar.gz \
	https://github.com/KhronosGroup/SPIRV-Tools/archive/$(HOST_SHADERC_SPIRV_TOOLS_REV).tar.gz \
	https://github.com/KhronosGroup/SPIRV-Headers/archive/$(HOST_SHADERC_SPIRV_HEADERS_REV).tar.gz

define HOST_SHADERC_EXTRACT_THIRD_PARTY
	$(foreach d,glslang:$(HOST_SHADERC_GLSLANG_REV) \
		spirv-tools:$(HOST_SHADERC_SPIRV_TOOLS_REV) \
		spirv-headers:$(HOST_SHADERC_SPIRV_HEADERS_REV),\
		mkdir -p $(@D)/third_party/$(firstword $(subst :, ,$(d)))$(sep)\
		$(call suitable-extractor,.tar.gz) \
			$(HOST_SHADERC_DL_DIR)/$(lastword $(subst :, ,$(d))).tar.gz | \
			$(TAR) --strip-components=1 \
				-C $(@D)/third_party/$(firstword $(subst :, ,$(d))) \
				$(TAR_OPTIONS) -$(sep))
endef
HOST_SHADERC_POST_EXTRACT_HOOKS += HOST_SHADERC_EXTRACT_THIRD_PARTY

HOST_SHADERC_DEPENDENCIES = host-python3
HOST_SHADERC_CONF_OPTS = \
	-DSHADERC_SKIP_TESTS=ON \
	-DSHADERC_SKIP_EXAMPLES=ON \
	-DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
	-DSPIRV_SKIP_TESTS=ON \
	-DSPIRV_SKIP_EXECUTABLES=ON \
	-DENABLE_GLSLANG_BINARIES=OFF

$(eval $(host-cmake-package))

# Buildroot's llama-cpp compiles ggml's Vulkan shaders with glslc
ifeq ($(BR2_PACKAGE_LLAMA_CPP_VULKAN),y)
LLAMA_CPP_DEPENDENCIES += host-shaderc
$(LLAMA_CPP_TARGET_CONFIGURE): | host-shaderc
endif

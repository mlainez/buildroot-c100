################################################################################
#
# llama-cpp-extra
#
################################################################################

# Adjusts Buildroot's llama-cpp package. External makefiles are included after
# Buildroot's, so this appends to its variables; its dependencies have already
# become make rules, so the extra ones are added to its configure step.

ifeq ($(BR2_PACKAGE_LLAMA_CPP),y)

# ggml's Vulkan shaders are compiled with glslc
ifeq ($(BR2_PACKAGE_LLAMA_CPP_VULKAN),y)
LLAMA_CPP_DEPENDENCIES += host-shaderc
$(LLAMA_CPP_TARGET_CONFIGURE): | host-shaderc
endif

endif

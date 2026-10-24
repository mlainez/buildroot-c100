################################################################################
#
# opencv4-vkstereo
#
################################################################################

OPENCV4_VKSTEREO_VERSION = f7ab0d0b060d787d693452185a3e404453a88f24
OPENCV4_VKSTEREO_SITE = https://github.com/mlainez/opencv_vkstereo
OPENCV4_VKSTEREO_SITE_METHOD = git
OPENCV4_VKSTEREO_LICENSE = Apache-2.0
OPENCV4_VKSTEREO_LICENSE_FILES = LICENSE
OPENCV4_VKSTEREO_INSTALL_TARGET = NO

$(eval $(generic-package))

# OpenCV builds the module from this package's source, next to opencv4-contrib
# when that is enabled. Its shaders are compiled with the host glslangValidator.
ifeq ($(BR2_PACKAGE_OPENCV4_VKSTEREO),y)
OPENCV4_VKSTEREO_OPENCV_DEPENDENCIES = \
	host-python-glslang \
	opencv4-vkstereo \
	vulkan-headers \
	vulkan-loader
OPENCV4_DEPENDENCIES += $(OPENCV4_VKSTEREO_OPENCV_DEPENDENCIES)
$(OPENCV4_TARGET_CONFIGURE): | $(OPENCV4_VKSTEREO_OPENCV_DEPENDENCIES)
OPENCV4_CONF_OPTS += \
	-DOPENCV_EXTRA_MODULES_PATH="$(if $(BR2_PACKAGE_OPENCV4_CONTRIB),$(OPENCV4_CONTRIB_DIR)/modules;)$(OPENCV4_VKSTEREO_DIR)/modules" \
	-DBUILD_opencv_vkstereo=ON
endif

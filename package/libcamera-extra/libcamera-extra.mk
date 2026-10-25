################################################################################
#
# libcamera-extra
#
################################################################################

# Adjusts Buildroot's libcamera package: Buildroot disables libcamera's
# automatic features, which include the software ISP's GPU acceleration.
# Without an ISP driver for the Tegra210, the software ISP processes every
# frame from the CSI cameras, so it runs on the GPU through OpenGL ES.

ifeq ($(BR2_PACKAGE_LIBCAMERA):$(BR2_PACKAGE_MESA3D_OPENGL_EGL):$(BR2_PACKAGE_MESA3D_OPENGL_ES),y:y:y)
LIBCAMERA_DEPENDENCIES += mesa3d
$(LIBCAMERA_TARGET_CONFIGURE): | mesa3d
LIBCAMERA_CONF_OPTS += -Dsoftisp-gpu=enabled
endif

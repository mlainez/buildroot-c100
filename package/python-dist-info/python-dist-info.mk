################################################################################
#
# python-dist-info
#
################################################################################

# Buildroot installs NumPy and OpenCV without pip metadata, so pip would
# install PyPI's builds over them for any tool that requires them, and the
# OpenCV wheel has no cv2.vkstereo. These records tell pip they are installed.

PYTHON_DIST_INFO_SITE_PACKAGES = $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages

# $(1): distribution name, $(2): version
define PYTHON_DIST_INFO_RECORD
	mkdir -p $(PYTHON_DIST_INFO_SITE_PACKAGES)/$(subst -,_,$(1))-$(2).dist-info
	printf 'Metadata-Version: 2.1\nName: %s\nVersion: %s\n' $(1) $(2) \
		> $(PYTHON_DIST_INFO_SITE_PACKAGES)/$(subst -,_,$(1))-$(2).dist-info/METADATA
	echo buildroot > $(PYTHON_DIST_INFO_SITE_PACKAGES)/$(subst -,_,$(1))-$(2).dist-info/INSTALLER
	touch $(PYTHON_DIST_INFO_SITE_PACKAGES)/$(subst -,_,$(1))-$(2).dist-info/RECORD
endef

define PYTHON_DIST_INFO_NUMPY
	$(call PYTHON_DIST_INFO_RECORD,numpy,$(PYTHON_NUMPY_VERSION))
endef
PYTHON_NUMPY_POST_INSTALL_TARGET_HOOKS += PYTHON_DIST_INFO_NUMPY

ifeq ($(BR2_PACKAGE_OPENCV4_LIB_PYTHON),y)
define PYTHON_DIST_INFO_OPENCV
	$(foreach d,opencv-python opencv-python-headless,\
		$(call PYTHON_DIST_INFO_RECORD,$(d),$(OPENCV4_VERSION))$(sep))
endef
OPENCV4_POST_INSTALL_TARGET_HOOKS += PYTHON_DIST_INFO_OPENCV
endif

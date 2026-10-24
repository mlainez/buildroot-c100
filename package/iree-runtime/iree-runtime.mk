################################################################################
#
# iree-runtime
#
################################################################################

IREE_RUNTIME_VERSION = 89ece87b89852100c0a4ac3d515e14842d090967
IREE_RUNTIME_SITE = $(call github,iree-org,iree,$(IREE_RUNTIME_VERSION))
IREE_RUNTIME_LICENSE = Apache-2.0 with LLVM exception
IREE_RUNTIME_LICENSE_FILES = LICENSE
IREE_RUNTIME_INSTALL_STAGING = YES
# IREE writes files to its source directory that it also generates in its
# build directory
IREE_RUNTIME_SUPPORTS_IN_SOURCE_BUILD = NO
# The Python extension's output name has directories that only Ninja creates
IREE_RUNTIME_CMAKE_BACKEND = ninja

# The runtime needs only a few of IREE's git submodules, at the revisions
# that this IREE revision pins; the Python bindings also need nanobind.
IREE_RUNTIME_FLATCC_REV = 9362cd00f0007d8cbee7bff86e90fb4b6b227ff3
IREE_RUNTIME_VULKAN_HEADERS_REV = df60f0316899460eeaaefa06d2dd7e4e300c1604
IREE_RUNTIME_NANOBIND_REV = cc860b2b771a0003ce70415fc56ea18f61b0a153
IREE_RUNTIME_ROBIN_MAP_REV = 4ec1bf19c6a96125ea22062f38c2cf5b958e448e
IREE_RUNTIME_EXTRA_DOWNLOADS = \
	https://github.com/dvidelabs/flatcc/archive/$(IREE_RUNTIME_FLATCC_REV).tar.gz \
	https://github.com/KhronosGroup/Vulkan-Headers/archive/$(IREE_RUNTIME_VULKAN_HEADERS_REV).tar.gz \
	https://github.com/wjakob/nanobind/archive/$(IREE_RUNTIME_NANOBIND_REV).tar.gz \
	https://github.com/Tessil/robin-map/archive/$(IREE_RUNTIME_ROBIN_MAP_REV).tar.gz
HOST_IREE_RUNTIME_EXTRA_DOWNLOADS = $(IREE_RUNTIME_EXTRA_DOWNLOADS)

# $(1): package variable prefix, $(2): archive revision, $(3): directory
define IREE_RUNTIME_EXTRACT_ONE
	mkdir -p $(@D)/$(3)
	$(call suitable-extractor,.tar.gz) $($(1)_DL_DIR)/$(2).tar.gz | \
		$(TAR) --strip-components=1 -C $(@D)/$(3) $(TAR_OPTIONS) -
endef

define IREE_RUNTIME_EXTRACT_DEPS
	$(call IREE_RUNTIME_EXTRACT_ONE,$(PKG),$(IREE_RUNTIME_FLATCC_REV),third_party/flatcc)
	$(call IREE_RUNTIME_EXTRACT_ONE,$(PKG),$(IREE_RUNTIME_VULKAN_HEADERS_REV),third_party/vulkan_headers)
	$(call IREE_RUNTIME_EXTRACT_ONE,$(PKG),$(IREE_RUNTIME_NANOBIND_REV),nanobind)
	$(call IREE_RUNTIME_EXTRACT_ONE,$(PKG),$(IREE_RUNTIME_ROBIN_MAP_REV),nanobind/ext/robin_map)
endef
IREE_RUNTIME_POST_EXTRACT_HOOKS += IREE_RUNTIME_EXTRACT_DEPS
HOST_IREE_RUNTIME_POST_EXTRACT_HOOKS += IREE_RUNTIME_EXTRACT_DEPS

IREE_RUNTIME_COMMON_CONF_OPTS = \
	-DIREE_BUILD_COMPILER=OFF \
	-DIREE_BUILD_TESTS=OFF \
	-DIREE_BUILD_SAMPLES=OFF \
	-DIREE_BUILD_BENCHMARKS=OFF \
	-DIREE_BUILD_BINDINGS_TFLITE=OFF \
	-DIREE_ENABLE_WERROR_FLAG=OFF \
	-DIREE_ERROR_ON_MISSING_SUBMODULES=OFF \
	-DIREE_HAL_DRIVER_DEFAULTS=OFF \
	-DIREE_ENABLE_LIBBACKTRACE=OFF \
	-DFETCHCONTENT_FULLY_DISCONNECTED=ON

# The host build only provides the tools the cross build runs
HOST_IREE_RUNTIME_DEPENDENCIES = host-python3
HOST_IREE_RUNTIME_CONF_OPTS = \
	$(IREE_RUNTIME_COMMON_CONF_OPTS) \
	-DIREE_BUILD_PYTHON_BINDINGS=OFF \
	-DIREE_HAL_DRIVER_LOCAL_SYNC=ON

define HOST_IREE_RUNTIME_BUILD_CMDS
	$(HOST_MAKE_ENV) $(BR2_CMAKE) --build $(HOST_IREE_RUNTIME_BUILDDIR) -j$(PARALLEL_JOBS) \
		--target iree-c-embed-data iree-flatcc-cli
endef

define HOST_IREE_RUNTIME_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(HOST_IREE_RUNTIME_BUILDDIR)/tools/iree-c-embed-data \
		$(HOST_DIR)/bin/iree-c-embed-data
	$(INSTALL) -D -m 0755 $(HOST_IREE_RUNTIME_BUILDDIR)/tools/iree-flatcc-cli \
		$(HOST_DIR)/bin/iree-flatcc-cli
endef

IREE_RUNTIME_DEPENDENCIES = host-iree-runtime vulkan-loader
IREE_RUNTIME_CONF_OPTS = \
	$(IREE_RUNTIME_COMMON_CONF_OPTS) \
	-DIREE_HOST_BIN_DIR=$(HOST_DIR)/bin \
	-DIREE_HAL_DRIVER_VULKAN=ON \
	-DIREE_HAL_DRIVER_LOCAL_SYNC=ON \
	-DIREE_HAL_DRIVER_LOCAL_TASK=ON

ifeq ($(BR2_PACKAGE_PYTHON3)$(BR2_PACKAGE_PYTHON_NUMPY),yy)
IREE_RUNTIME_DEPENDENCIES += python3 python-numpy
# FindPython runs the host interpreter, so point it at the target's headers
# and NumPy. The extension is built against Python's stable ABI, so its file
# name does not depend on the build host.
IREE_RUNTIME_CONF_OPTS += \
	-DIREE_BUILD_PYTHON_BINDINGS=ON \
	-DIREE_USE_SYSTEM_DEPS=OFF \
	-DFETCHCONTENT_SOURCE_DIR_NANOBIND=$(@D)/nanobind \
	-DIREE_ENABLE_PYTHON_STABLE_ABI=ON \
	-DPython3_EXECUTABLE=$(HOST_DIR)/bin/python3 \
	-DPython3_INCLUDE_DIR=$(STAGING_DIR)/usr/include/python$(PYTHON3_VERSION_MAJOR) \
	-DPython3_NumPy_INCLUDE_DIR=$(STAGING_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/numpy/_core/include \
	-DPython_EXECUTABLE=$(HOST_DIR)/bin/python3 \
	-DPython_INCLUDE_DIR=$(STAGING_DIR)/usr/include/python$(PYTHON3_VERSION_MAJOR) \
	-DPython_NumPy_INCLUDE_DIR=$(STAGING_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/numpy/_core/include

define IREE_RUNTIME_INSTALL_PYTHON_PACKAGE
	rm -rf $(@D)/python-install
	$(BR2_CMAKE) --install $(IREE_RUNTIME_BUILDDIR) \
		--component IreePythonPackage-runtime --prefix $(@D)/python-install
	cp -a $(@D)/python-install/python_packages/iree_runtime/iree \
		$(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/
endef
IREE_RUNTIME_POST_INSTALL_TARGET_HOOKS += IREE_RUNTIME_INSTALL_PYTHON_PACKAGE
else
IREE_RUNTIME_CONF_OPTS += -DIREE_BUILD_PYTHON_BINDINGS=OFF
endif

$(eval $(cmake-package))
$(eval $(host-cmake-package))

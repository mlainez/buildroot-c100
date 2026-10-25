################################################################################
#
# openblas-extra
#
################################################################################

# Adjusts Buildroot's openblas package. Without a Fortran compiler it builds
# only the CBLAS interface, but NumPy and ggml look for the Fortran-style BLAS
# symbols (dgemm_, sgemm_) and NumPy for LAPACK. OpenBLAS can build both from
# C sources instead.

ifeq ($(BR2_PACKAGE_OPENBLAS),y)
ifeq ($(BR2_TOOLCHAIN_HAS_FORTRAN),)
OPENBLAS_MAKE_OPTS := \
	$(filter-out ONLY_CBLAS=1,$(OPENBLAS_MAKE_OPTS)) \
	NOFORTRAN=1 \
	C_LAPACK=1

# NumPy only uses a LAPACK library from the lapack package, which needs Fortran
ifeq ($(BR2_PACKAGE_PYTHON_NUMPY):$(BR2_PACKAGE_LAPACK),y:)
PYTHON_NUMPY_CONF_OPTS += -Dlapack=openblas
endif
endif
endif

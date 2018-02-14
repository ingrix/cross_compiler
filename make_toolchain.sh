#!/bin/bash

## if you have not already extracted the source archives of the necessary
## softwares (below) into the cwd, then run this script as: EXTRACT_SOURCES=1
## make_toolchain.sh

export CROSS_TARGET=armv6-linux-gnueabi
export CROSS_ARCH=arm
export HOST_CFLAGS=
export CROSS_CFLAGS=
export HOST_LDFLAGS=
export CROSS_LDFLAGS=
export CROSS_TOOLS_PREFIX=$HOME/cross_compiler/${CROSS_TARGET}
export CROSS_SYSROOT_PREFIX="sysroot"
export CROSS_SYSROOT=${CROSS_TOOLS_PREFIX}/${CROSS_TARGET}/${CROSS_SYSROOT_PREFIX}


ORIG_DIR="$PWD"
ORIG_PATH="$PATH" 

# necessary softwares

LINUX_VERSION=4.14
BINUTILS_VERSION=2.27
CLOOG_VERSION=0.18.4
GCC_VERSION=6.3.0
GMP_VERSION=6.1.2
MPFR_VERSION=3.1.5
ISL_VERSION=0.18
MPC_VERSION=1.0.3
# TEXINFO_VERSION=6.3 # optional

if [ "${EXTRACT_SOURCES}" == "1" ] ; then
  extract_error=0
  set -x
  tar -xf binutils-${BINUTILS_VERSION}.tar.* || extract_error=1
  tar -xf linux-${LINUX_VERSION}.tar.* || extract_error=1
  tar -xf gmp-${GMP_VERSION}.tar.* || extract_error=1
  tar -xf mpfr-${MPFR_VERSION}.tar.* || extract_error=1
  tar -xf mpc-${MPC_VERSION}.tar.* || extract_error=1
  tar -xf isl-${ISL_VERSION}.tar.* || extract_error=1
  tar -xf cloog-${CLOOG_VERSION}.tar.* || extract_error=1
  tar -xf gcc-${GCC_VERSION}.tar.* || extract_error=1
  set +x

  if [ "$extract_error" == "1" ] ; then
    echo "Extract error"
    exit -1
  fi
fi

TOP_BUILD_DIR=$ORIG_DIR/build
mkdir -p $TOP_BUILD_DIR || exit -1

BINUTILS_DIR=$TOP_BUILD_DIR/binutils
mkdir -p $BINUTILS_DIR
cd $BINUTILS_DIR || exit -1

echo -e "\n\nBuilding binutils"
#sleep 3

$ORIG_DIR/binutils-${BINUTILS_VERSION}/configure --target=${CROSS_TARGET} --prefix=${CROSS_TOOLS_PREFIX} --with-sysroot=${CROSS_SYSROOT} --disable-nls --disable-werror --with-gnu-ld --with-gnu-as
make LDFLAGS="${HOST_LDFLAGS}" configure-host || exit -1
make LDFLAGS="${HOST_LDFLAGS}" -j8 || exit -1
make LDFLAGS="${HOST_LDFLAGS}" install || exit -1

cd $ORIG_DIR

export PATH=${CROSS_TOOLS_PREFIX}/bin:$PATH

GMP_DIR=$TOP_BUILD_DIR/gmp
mkdir -p $GMP_DIR
cd $GMP_DIR || exit -1

echo -e "\n\nBuilding gmp"
#sleep 3
$ORIG_DIR/gmp-${GMP_VERSION}/configure --prefix=${CROSS_TOOLS_PREFIX} --disable-shared || exit -1
make -j8 || exit -1
make install || exit -1

cd $ORIG_DIR

MPFR_DIR=${TOP_BUILD_DIR}/mpfr
mkdir -p $MPFR_DIR
cd $MPFR_DIR || exit -1

echo -e "\n\nBuilding mpfr"
#sleep 3

# make sure we include the lib directory from our crosstools dir
export HOST_LDFLAGS="-Wl,-rpath,${CROSS_PREFIX}/lib"

${ORIG_DIR}/mpfr-${MPFR_VERSION}/configure --prefix=${CROSS_TOOLS_PREFIX} --disable-shared --with-gmp=${CROSS_TOOLS_PREFIX} --with-gnu-ld --with-gnu-as
make LDFLAGS="${HOST_LDFLAGS}" -j8 || exit -1
make LDFLAGS="${HOST_LDFLAGS}" -j8 install || exit -1

cd $ORIG_DIR

MPC_DIR=$TOP_BUILD_DIR/mpc
mkdir -p $MPC_DIR
cd $MPC_DIR || exit -1

${ORIG_DIR}/mpc-${MPC_VERSION}/configure --prefix=${CROSS_TOOLS_PREFIX} --with-gmp=${CROSS_TOOLS_PREFIX} --with-mpfr=${PREFIX} --disable-shared --with-gnu-ld --with-gnu-as
make LDFLAGS="${HOST_LDFLAGS}" -j8 || exit -1
make LDFLAGS="${HOST_LDFLAGS}" -j8 install || exit -1

cd $ORIG_DIR

echo "Installing kernel headers"
#sleep 3

# install kernel headers
LINUX_TOP_DIR=${ORIG_DIR}/linux-${LINUX_VERSION}

cd "$LINUX_TOP_DIR" || exit -1

# put one in the gcc include dirs
make ARCH=${CROSS_ARCH} INSTALL_HDR_PATH=${CROSS_TOOLS_PREFIX}/ headers_install || exit -1

# put one in the sysroot too
make ARCH=${CROSS_ARCH} INSTALL_HDR_PATH=${CROSS_SYSROOT}/usr/ headers_install || exit -1

cd $ORIG_DIR || exit -1

GCC_DIR=$TOP_BUILD_DIR/gcc
mkdir -p $GCC_DIR
cd $GCC_DIR || exit -1

echo -e "\n\nBuilding bootstrap gcc"
#sleep 3

$ORIG_DIR/gcc-${GCC_VERSION}/configure \
  --prefix=${CROSS_TOOLS_PREFIX} \
  --with-gmp=${CROSS_TOOLS_PREFIX} \
  --with-mpfr=${CROSS_TOOLS_PREFIX} \
  --with-mpc=${CROSS_TOOLS_PREFIX} \
  --target=${CROSS_TARGET} \
  --with-sysroot=${CROSS_SYSROOT} \
  --with-mode=thumb \
  --without-headers \
  --with-newlib \
  --disable-shared \
  --disable-nls \
  --enable-languages=c \
  --disable-multilib \
  --disable-threads \
  --disable-decimal-float \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libmpx \
  --disable-libquadmath \
  --disable-libssp \
  --disable-libvtv \
  --disable-libstdcxx \
  --disable-libmudflap \
  --with-gnu-as \
  --with-gnu-ld \
  --enable-symvers=gnu \
  --enable-clocale=uclibc \
  --with-interwork \
  --enable-c99 \
  --enable-long-long \
  --enable-cross \
  --disable-checking

echo -e "\n\nMaking bootstrap gcc"
#sleep 3
make LDFLAGS="${HOST_LDFLAGS}" -j8 all-gcc
make LDFLAGS="${HOST_LDFLAGS}" install-gcc
export HOST_LDFLAGS="$HOST_LDFLAGS -Wl,-rpath,${CROSS_PREFIX}/libexec/gcc/${CROSS_TARGET}/${GCC_VERSION}/"

echo -e "\n\nMaking bootstrap libgcc"
#sleep 3

#export CROSS_CFLAGS="-mbig-endian"
make CFLAGS="${CROSS_CFLAGS}" LDFLAGS="${HOST_LDFLAGS}" -j8 clean-target-libgcc || exit -1
make CFLAGS="${CROSS_CFLAGS}" LDFLAGS="${HOST_LDFLAGS}" -j8 all-target-libgcc || exit -1
make CFLAGS="${CROSS_CFLAGS}" LDFLAGS="${HOST_LDFLAGS}" -j8 install-target-libgcc || exit -1

cd $ORIG_DIR

#
# Custom Linux toolchain based on musl-libc
# Steps:
# 1. Install Linux headers
# 2. Binutils
#   a. Prepare Binutils
#   b. Build Binutils
# 3. Build GMP, MPFR, MPC (Maybe later)
# 4. GCC
#   a. Prepare GCC
#   b. Build static GCC
# 5. musl-libc
#   a. Prepare musl-libc
#   b. Build musl-libc
# 6. Build final GCC
#
# Possible errors: Kernel-headers not sanitized, sysroot != prefix
#
# MUSL NOT WORKING, EVERY THING ELSE IS FINE!
#


TARGET="x86_64-linux-musl"
PREFIX="/root/C_Utils/toolchain"
SYSROOT="$PREFIX/$TARGET"
LIB_PATH="$PREFIX/$TARGET/lib"

BUILD_DIR="/root/C_Utils"

LINUX_DIR="$BUILD_DIR/linux"
BINUTILS_DIR="$BUILD_DIR/binutils"
GCC_DIR="$BUILD_DIR/gcc"
MUSL_DIR="$BUILD_DIR/musl"


rm -rf $BUILD_DIR
mkdir $BUILD_DIR

mkdir $LINUX_DIR
mkdir $BINUTILS_DIR
mkdir $GCC_DIR
mkdir $MUSL_DIR


tar -xvf /root/tars/linux.tar.gz -C $LINUX_DIR
tar -xvf /root/tars/binutils.tar.gz -C $BINUTILS_DIR
tar -xvf /root/tars/gcc.tar.gz -C $GCC_DIR
tar -xvf /root/tars/musl.tar.gz -C $MUSL_DIR

install_headers() {
    echo "Installing headers"
    cd $LINUX_DIR/linux*
        
    make mrproper
    make                                        \
        -j $(nproc)                             \
        ARCH=x86_64                             \
        INSTALL_HDR_PATH=$PREFIX/$TARGET    \
        headers_install
}

install_binutils() {
    echo "Installing binutils"
    cd $BINUTILS_DIR/binutils*

    ./configure                     \
        --prefix=$PREFIX            \
        --target=$TARGET            \
        --with-sysroot=$SYSROOT     \
        --with-lib-path=$LIB_PATH   \
        --disable-nls               \
        --disable-multilib
    
    make configure-host
    make -j $(nproc)
    make install
        
}

install_static_gcc() {
    echo "Installing GCC"
    cd $GCC_DIR/gcc*
    
    ./contrib/download_prerequisites

    cd ..
    mkdir gcc-build
    cd gcc-build

    ../gcc*/configure               \
        --prefix=$PREFIX            \
        --target=$TARGET            \
        --with-sysroot=$SYSROOT     \
        --disable-multiarch         \
        --disable-nls               \
        --disable-shared            \
        --without-headers           \
        --with-newlib               \
        --disable-decimal-float     \
        --disable-libgomp           \
        --disable-libmudflap        \
        --disable-libssp            \
        --disable-libquadmath       \
        --disable-threads           \
        --enable-languages=c        \
        --disable-multilib          
    
    make -j $(nproc) all-gcc all-target-libgcc
    make install-gcc install-target-libgcc

}

install_musl() {
    echo "Installing musl"
    cd $MUSL_DIR/musl*
    
    ./configure                 \
        --prefix=$PREFIX/$TARGET\
        --target=$TARGET        \
        --disable-gcc-wrapper   \
        --disable-debug         \
        --disable-warning       \
        CC=gcc

    make
    #make DESTDIR=$DESTDIR install

    

}

#install_final_gcc() {
#    --with-native-system-header-dir=/usr/include \
#}


install_headers &&      \
install_binutils &&     \
install_static_gcc &&   \
#install_musl &&         \
echo "Success!"

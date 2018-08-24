#!/bin/bash

# Setting colors
red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
yellow='\e[1;33m%s\e[0m\n'

# Number of cores for compiling
NR_OF_CORES=$(nproc)

HOME_DIR="/root"
TARGET="x86_64-custom-linux-musl"

START_DATE=$(date)

# Linux filenames
LINUX_KERNEL_VER="v4.x"
LINUX_UNAME="-4.17.12"
LINUX="linux$LINUX_UNAME"
LINUX_PATH="$HOME_DIR/$LINUX"
LINUX_TAR_LOCATION="$LINUX.tar.xz"
LINUX_CONFIG_PATH=""

# Busybox filenames
BUSYBOX="busybox-1.29.2"
BUSYBOX_PATH="$HOME_DIR/$BUSYBOX"
BUSYBOX_TAR_LOCATION="$BUSYBOX.tar.bz2"

# Folder for the files and output iso
ROOT="/root/CD_Root"
OUTPUT_FILE="output.iso"

INIT_LOCATION="/root/initramfs"

# Location of binaries
IMAGE_LOCATION="$LINUX_PATH/arch/x86/boot/bzImage"
BUSYBOX_LOCATION="$BUSYBOX_PATH/busybox"
# Destination of binaries
IMAGE_DESTINATION="$ROOT/boot/vmlinuz$LINUX_UNAME"
BUSYBOX_DESTINATION="$INIT_LOCATION/bin/busybox"

cd ~

usage() {
	echo "---------------------------------------------"
	echo "usage: $0 [-] [filepath (optional)] "
	echo
	echo Create root filesystem in $ROOT
	echo
	echo "-compile		Build system from scratch"
	echo "	filepath (optional) 	Alternative config file for kernel."
	echo ""
	echo "-compile-keep-root	Compile, but don't rebuild $ROOT, just add new kernel"
	echo "	filepath (optional) 	Alternative config file for kernel."
	echo ""
	echo "-no-compile           Don't build, just download/verify source packages."
	echo "-download		        Download non-existing packages"
	echo "-gen-linux-config	    Generate linux configuration file."
	echo "-mkisohybrid		    Create the iso file with isolinux."
	#echo "-edit-configs         Edit both config files."
    #echo "-edit-linux-config    Edit Linux config files."
    #echo "-edit-bb-config       Edit busybox config files."
    echo "---------------------------------------------"	
	exit 1

}

if [ "$1" != '-compile' ] && [ "$1" != '-no-compile' ] && [ "$1" != '-download' ] && [ "$1" != '-compile-keep-root' ] \
       	&& [ "$1" != '-gen-linux-config' ] && [ "$1" != '-mkisohybrid' ] && [ "$1" != '-edit-linux-config' ] ; then
	usage
fi

#Verify build root folder
#verify() {
#	
#}

cleanup() {
	rm -rf $ROOT
	rm -rf $OUTPUT_FILE
    rm -rf $INIT_LOCATION
}

download_linux() {
	rm -rf $LINUX_PATH
	
	if [ ! -f $HOME_DIR/$LINUX_TAR_LOCATION ]; then
		echo "Downloading linux kernel to linux_latest/*.tar.xz"
		wget https://cdn.kernel.org/pub/linux/kernel/$LINUX_KERNEL_VER/$LINUX_TAR_LOCATION
	fi

	tar xf $HOME_DIR/$LINUX_TAR_LOCATION
}

download_bb() {
	rm -rf $BUSYBOX_PATH

	if [ ! -f $HOME_DIR/$BUSYBOX_TAR_LOCATION ]; then
		echo "Downloading busybox to busybox to busybox.tar.bz2"
		wget http://busybox.net/downloads/$BUSYBOX_TAR_LOCATION
		git clone https://github.com/sabotage-linux/kernel-headers.git
	fi

	tar xf $HOME_DIR/$BUSYBOX_TAR_LOCATION
}

generate_linux_config() {
	cd ~
	download_linux
	cd $LINUX_PATH

	echo "Generating configuration"
	make mrproper
	
	make x86_64_defconfig

    if [ "$LINUX_CONFIG_PATH" != "" ]; then
		cp -v $LINUX_CONFIG_PATH $LINUX_PATH/.config
    else
	    make menuconfig
    fi

	printf "$green" ".config file ready in $LINUX_PATH/.config"
}

compile_linux() {		
	generate_linux_config
	cd $LINUX_PATH
	
    (make -j $NR_OF_CORES && printf "$green" "Kernel: arch/x86/boot/bzImage is ready") || printf "$red" "Build failed"	
	#make modules_install

	cd ~
}

compile_bb() {
    download_bb
	cd $BUSYBOX_PATH

	make defconfig 

	#make allnoconfig
	#make menuconfig
    cp /root/busybox-config .config
	#sed -ie 's!CONFIG_EXTRA_CFLAGS=!c!CONFIG_EXTRA_CFLAGS="-I../kernel-headers/x86_64/include!g"' .config

	make LDFLAGS=--static CC=musl-gcc -j $NR_OF_CORES	
	#make LDFLAGS=--static -j $NR_OF_CORES

}

compile_keep_root() {
	echo "Compile-keep-root not stable, dont use"
    exit 1
    if [ ! -f $LINUX_TAR_LOCATION ]; then
		echo "Downloading linux kernel to linux_latest.tar.xz"
		wget https://cdn.kernel.org/pub/linux/kernel/$LINUX_KERNEL_VER/$LINUX_TAR_LOCATION
	fi
	rm -rf $LINUX_PATH
	tar xf $LINUX_TAR_LOCATION

	echo "Changing dir to $LINUX_PATH" 
	cd $LINUX_PATH
	make x86_64_defconfig
	echo "Prepare compilation"
	make -j $NR_OF_CORES
	#make modules_install

	printf "$green" "Kernel: arch/x86/boot/bzImage is ready"


	cd $ROOT
	
	echo "Copying binaries"
	cp -iv $IMAGE_LOCATION $IMAGE_DESTINATION
	cp -iv $LINUX_PATH/.config $ROOT/boot/.config$LINUX_UNAME
	cp -iv $LINUX_PATH/System.map $ROOT/boot/System.map$LINUX_UNAME
	#cp -rv /root/kernel-headers/x86_64/include/* usr/include
}

mkdirs() {
    cleanup	
	cd ~
	mkdir -p "$ROOT"/boot
}

cplinuxfiles() {
	echo "Copying Linux binaries"
	cp -iv $IMAGE_LOCATION $IMAGE_DESTINATION
	cp -iv $LINUX_PATH/.config $ROOT/boot/.config$LINUX_UNAME
	cp -iv $LINUX_PATH/System.map $ROOT/boot/System.map$LINUX_UNAME
}

mkinitramfs() {
    rm -rf $INIT_LOCATION
    mkdir -p "$INIT_LOCATION"/{etc,tmp,proc,sys,dev,home,mnt,root,usr/{bin,sbin,lib,share,include},bin,sbin,lib,var}
    chmod a+rwxt "$INIT_LOCATION"/tmp
    
    cp -r $ROOT/boot/ $INIT_LOCATION/boot
	cp -a $BUSYBOX_LOCATION $BUSYBOX_DESTINATION
  
    cp -ivr /root/C_Utils/cross/bin/gcc $INIT_LOCATION/usr/bin
    cp -ivr /root/C_Utils/cross/bin/make $INIT_LOCATION/usr/bin
    cp -ivr /root/C_Utils/cross/bin/ld $INIT_LOCATION/usr/bin
    cp -ivr /root/C_Utils/cross/bin/ar $INIT_LOCATION/usr/bin
    cp -ivr /root/C_Utils/cross/bin/as $INIT_LOCATION/usr/bin
    cp -ivr /root/C_Utils/cross/bin/musl-gcc $INIT_LOCATION/usr/bin

    cp -ivr /root/C_Utils/cross/libexec $INIT_LOCATION/usr/

    cp -ivr /root/C_Utils/gcc/gcc-bin/lib/* $INIT_LOCATION/usr/lib
    cp -ivr /root/C_Utils/cross/include/* $INIT_LOCATION/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
    cp -ivr /root/C_Utils/cross/lib/* $INIT_LOCATION/usr/lib
    #cp -ivr /root/C_Utils/cross/lib/* $INIT_LOCATION/lib
    
    #ln -vs $INIT_LOCATION/usr/bin/musl-gcc $INIT_LOCATION/bin/musl-gcc


    chroot $INIT_LOCATION /bin/busybox --install -s
    
cat > $INIT_LOCATION/etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
EOF
cat > $INIT_LOCATION/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
tape:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
EOF

cat > $INIT_LOCATION/init << "EOF"
#!/bin/sh 

# Mount the /proc and /sys filesystems.

mount -vt proc none /proc
mount -vt sysfs none /sys
mount -nvt tmpfs none /dev

echo "Creating mountpoints and initial device nodes."

bin/mknod -m 666 /dev/console c 5 1
bin/mknod -m 666 /dev/null c 1 3

mknod -m 666 /dev/zero c 1 5
mknod -m 666 /dev/ptmx c 5 2
mknod -m 666 /dev/tty c 5 0
mknod -m 666 /dev/ttyS0 c 4 64
mknod -m 444 /dev/random c 1 8
mknod -m 444 /dev/urandom c 1 9
chown -v root:tty /dev/console
chown -v root:tty /dev/ptmx
chown -v root:tty /dev/tty
chown -v root:tty /dev/ttyS0
mkdir -v /dev/pts
mkdir -v /dev/shm

mount -vt devpts -o gid=4,mode=620 none /dev/pts


# Do your stuff here.
echo "$(date)This script just mounts and boots the rootfs, nothing else!"

# Mount the root filesystem.
#mount -o ro /dev/sdb1 /mnt/root

# Clean up.
#umount /proc
#umount /sys

# Boot the real thing.
#exec switch_root /mnt/root /sbin/init
echo "Executing interactive shell..."
setsid  cttyhack sh
#echo "Could not execute /bin/sh"
EOF

cat > $INIT_LOCATION/etc/profile << "EOF"
PS1='# '



EOF

	chmod a+rwx $INIT_LOCATION/init
	cd $INIT_LOCATION
	find . | cpio -H newc -o | gzip > $ROOT/boot/initramfs$LINUX_UNAME
    #chmod +x /root/building/sub/init
    #cd /root/building/sub
    #find . | cpio -H newc -o | gzip > /root/$ROOT/boot/initramfs$LINUX_UNAME
}

mkisohybrid() {
	echo "Preparing for isolinux hybrid iso"

	echo "Downloading syslinux"

	cd ~

	SYSLINUX_PATH="syslinux-6.04-pre1"
	SYSLINUX_TAR_LOCATION="$SYSLINUX_PATH.tar.gz"

    if [ ! -f $SYSLINUX_PATH ] && [ ! -f $SYSLINUX_TAR_LOCATION ]; then
	    wget https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/Testing/6.04/$SYSLINUX_TAR_LOCATION
        tar xf $SYSLINUX_TAR_LOCATION
    fi

	mkdir -p $ROOT/isolinux

	cp $SYSLINUX_PATH/bios/core/isolinux.bin $ROOT/isolinux
	cp $SYSLINUX_PATH/bios/com32/elflink/ldlinux/ldlinux.c32 $ROOT/isolinux

	mkdir -p $ROOT/{images,kernel}

	cp $SYSLINUX_PATH/bios/memdisk/memdisk $ROOT/kernel
	cat > $ROOT/isolinux/isolinux.cfg <<EOF
	SERIAL 0
    PROMPT 1
    TIMEOUT 50
    DEFAULT Linux

    SAY
    SAY   ##################################################################
    SAY   #                                                                #
    SAY   #  Press <ENTER> to boot Linux Live or wait 5 seconds.   #
    SAY   #                                                                #
    SAY   #  Press <TAB> to view available boot entries or enter Syslinux  #
    SAY   #  commands directly.                                            #
    SAY   #                                                                #
    SAY   ##################################################################
    SAY

	LABEL Linux
	MENU LABEL Linux vanilla
	KERNEL /boot/vmlinuz$LINUX_UNAME
    INITRD /boot/initramfs$LINUX_UNAME
	APPEND quiet splash
EOF
	rm -rf $OUTPUT_FILE
	echo "Generating output.iso"
	xorriso -as mkisofs \
	   -o $OUTPUT_FILE \
	     -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
	       -c isolinux/boot.cat \
	         -b isolinux/isolinux.bin \
		    -no-emul-boot -boot-load-size 4 -boot-info-table \
		      $ROOT

	printf "$green" "Successfully generated isohybrid to $OUTPUT_FILE"
}

build_message() {
	echo "Compilation started on $START_DATE, and finished on '$(date)'"
	exit 0
}


build_full() {
    compile_linux
    compile_bb
    mkdirs
    cplinuxfiles
    mkinitramfs
    
    mkisohybrid
	build_message
}

build_no_compile() {
    mkdirs
	cplinuxfiles
	mkinitramfs

    mkisohybrid
    build_message
}

build_keep_root() {
    exit 1
}

if [ "$1" == "-compile" ]; then	
	echo "Compiling Linux and Busybox"
	if [[ ! -z "$2" ]]; then
	       LINUX_CONFIG_PATH="$2"
	       echo "Using linux config file in $LINUX_CONFIG_PATH" 
	fi
	build_full

elif [ "$1" == "-no-compile" ]; then
	if [ ! -f $IMAGE_DESTINATION ] && [ ! -f $BUSYBOX_DESTINATION ]; then
		echo "Binaries does not exist, must compile"
		build_full
	else
		echo "Binaries exist, will not compile"
		build_no_compile
	fi

elif [ "$1" == "-download" ]; then
	download

elif [ "$1" == "-compile-keep-root" ]; then
	echo "Compiling Linux but keeping root"
	if [[ ! -z "$2" ]]; then
	       LINUX_CONFIG_PATH="$2"
	       echo "Using linux config file in $LINUX_CONFIG_PATH" 
	fi
	compile_keep_root #### FIX ME WITH PROPER FUNCTION

elif [ "$1" == "-gen-linux-config" ]; then
	echo "Generating default linux config file"
	generate_linux_config

elif [ "$1" == "-mkisohybrid" ]; then
	echo "Creating the isohybrid image of $ROOT"
	mkisohybrid

else
	usage

fi


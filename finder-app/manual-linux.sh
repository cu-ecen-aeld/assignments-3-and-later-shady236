#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE mrproper			# deep clean
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig			# default condig
    make -j4 ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE all			# build
    # make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE modules
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE dtbs				# device tree build
fi

echo "Adding the Image in outdir"
cp "$OUTDIR/linux-stable/arch/$ARCH/boot/Image" "$OUTDIR"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p "$OUTDIR/rootfs"
cd "$OUTDIR/rootfs"
mkdir -p bin dev etc sbin home lib lib64 proc sys tmp var 
mkdir -p usr/bin usr/sbin usr/lib
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
else
    cd busybox
fi

# TODO: Make and install busybox
echo "cleaning busybox"
make distclean
echo "defconfig busybox"
make defconfig
echo "naking busybox"
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
echo "installing busybox"
make CONFIG_PREFIX="$OUTDIR/rootfs/" ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install
cd "$OUTDIR/rootfs"

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
cp -r "$FINDER_APP_DIR/../deb/lib" "$OUTDIR/rootfs/"
cp -r "$FINDER_APP_DIR/../deb/lib64" "$OUTDIR/rootfs/"


# TODO: Make device nodes
sudo mknod -m 666 "$OUTDIR/rootfs/dev/null" c 1 3
sudo mknod -m 666 "$OUTDIR/rootfs/dev/console" c 5 1
echo "Added device nodes"

# TODO: Clean and build the writer utility
cd "$FINDER_APP_DIR"
make clean
make CROSS_COMPILE=aarch64-none-linux-gnu- all

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp writer.sh         "$OUTDIR/rootfs/home"
cp writer            "$OUTDIR/rootfs/home"
cp finder.sh         "$OUTDIR/rootfs/home"
cp finder-test.sh    "$OUTDIR/rootfs/home"
cp autorun-qemu.sh   "$OUTDIR/rootfs/home"
cp -r conf           "$OUTDIR/rootfs/home"
# cp conf/username.txt conf/assignment.txt "$OUTDIR/rootfs/home"


# TODO: Chown the root directory


# TODO: Create initramfs.cpio.gz
cd "$OUTDIR/rootfs"
find . | cpio -H newc -ov --owner root:root > "$OUTDIR/initramfs.cpio"
cd "$OUTDIR"
gzip -f initramfs.cpio


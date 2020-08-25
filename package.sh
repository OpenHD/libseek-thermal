#!/bin/bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

PACKAGE_ARCH=$1
OS=$2
DISTRO=$3
BUILD_TYPE=$4

if [ "${BUILD_TYPE}" == "docker" ]; then
    cat << EOF > /etc/resolv.conf
options rotate
options timeout:1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi

./install_dep.sh || exit 1

PACKAGE_NAME=libseek-thermal

TMPDIR=/tmp/${PACKAGE_NAME}-installdir

rm -rf ${TMPDIR}/*

mkdir -p ${TMPDIR}/usr/local/bin || exit 1
mkdir -p ${TMPDIR}/usr/local/lib || exit 1
mkdir -p ${TMPDIR}/etc/systemd/system || exit 1
mkdir -p ${TMPDIR}/usr/local/include/seek || exit 1
mkdir -p build

pushd build
cmake ../
make clean || exit 1
make || exit 1

cp -a examples/seek_viewer ${TMPDIR}/usr/local/bin/ || exit 1
cp -a examples/seek_create_flat_field ${TMPDIR}/usr/local/bin/ || exit 1
cp -a src/libseek.so ${TMPDIR}/usr/local/lib/ || exit 1
cp -a src/libseek_static.a ${TMPDIR}/usr/local/lib/ || exit 1

cp -a ../src/SeekCam.h ${TMPDIR}/usr/local/include/seek/ || exit 1
cp -a ../src/SeekDevice.h ${TMPDIR}/usr/local/include/seek/ || exit 1
cp -a ../src/seek.h ${TMPDIR}/usr/local/include/seek/ || exit 1
cp -a ../src/SeekLogging.h ${TMPDIR}/usr/local/include/seek/ || exit 1
cp -a ../src/SeekThermal.h ${TMPDIR}/usr/local/include/seek/ || exit 1
cp -a ../src/SeekThermalPro.h ${TMPDIR}/usr/local/include/seek/ || exit 1

popd

cp -a seekthermal.service ${TMPDIR}/etc/systemd/system/ || exit 1

VERSION=$(git describe)

rm ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb > /dev/null 2>&1

fpm -a ${PACKAGE_ARCH} -s dir -t deb -n ${PACKAGE_NAME} -v ${VERSION//v} -C ${TMPDIR} \
  -p ${PACKAGE_NAME}_VERSION_ARCH.deb \
  -d "libboost-program-options-dev" \
  -d "libopencv-dev" \
  -d "libusb-1.0-0 >= 1.0" || exit 1


#
# Only push to cloudsmith for tags. If you don't want something to be pushed to the repo, 
# don't create a tag. You can build packages and test them locally without tagging.
#
git describe --exact-match HEAD > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "Pushing package to OpenHD repository"
    cloudsmith push deb openhd/openhd-2-1/${OS}/${DISTRO} ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb
else
    echo "Pushing package to OpenHD testing repository"
    cloudsmith push deb openhd/openhd-2-1-testing/${OS}/${DISTRO} ${PACKAGE_NAME}_${VERSION//v}_${PACKAGE_ARCH}.deb
fi

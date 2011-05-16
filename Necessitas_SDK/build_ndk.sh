#!/bin/bash

# Copyright (c) 2011, Ray Donnelly <mingw.android@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ "$OSTYPE" = "msys" ]; then
    TEMP_PATH=/usr/ndk-build
else
    pushd ~
    TEMP_PATH=$PWD/ndk-build
    popd
fi

REPO_SRC_PATH=$PWD
PYTHONVER=/usr
mkdir -p $TEMP_PATH
pushd $TEMP_PATH

function error_msg
{
    echo $1 >&2
    exit 1
}

function removeAndExit
{
    rm -fr $1 && error_msg "Can't download $1"
}

function downloadIfNotExists
{
    if [ ! -f $1 ]
    then
        wget $2 || removeAndExit $1
    fi
}

function makeInstallPython
{
    if [ "$OSTYPE" = "linux-gnu" ] ; then
        BUILD=linux
        BUILD_NDK=linux-x86
    else
        if [ "$OSTYPE" = "msys" ] ; then
        BUILD=windows
        BUILD_NDK=windows
        else
            BUILD=macosx
            BUILD_NDK=darwin-x86
        fi
    fi

    if [ -f $REPO_SRC_PATH/python-${BUILD}.7z ]
    then
        PYTHONVER=$PWD/python/install-python-$BUILD
    else
        if [ ! -d python ]
        then
            git clone git://gitorious.org/mingw-python/mingw-python.git python
        fi
        cd python
        ./build-python.sh
        PYTHONVER=$PWD/install-python-$BUILD
        # If successful, the build is packaged into /usr/ndk-build/python-mingw.7z
        cp ../python-${BUILD}.7z $REPO_SRC_PATH/
        cd ..
    fi
}

function makeInstallMinGWBits
{
    wget -c http://downloads.sourceforge.net/pdcurses/pdcurses/3.4/PDCurses-3.4.tar.gz
    rm -rf PDCurses-3.4
    tar -xvzf PDCurses-3.4.tar.gz
    cd PDCurses-3.4/win32
    sed '90s/-copy/-cp/' mingwin32.mak > mingwin32-fixed.mak
    make -f mingwin32-fixed.mak WIDE=Y UTF8=Y DLL=N
    cp pdcurses.a /usr/lib/libcurses.a
    cp pdcurses.a /usr/lib/libncurses.a
    cp pdcurses.a /usr/lib/libpdcurses.a
    cp ../curses.h /usr/include
    cp ../panel.h /usr/include
    cd ../..

    wget -c http://ftp.gnu.org/pub/gnu/readline/readline-6.2.tar.gz
    rm -rf readline-6.2
    tar -xvzf readline-6.2.tar.gz
    cd readline-6.2
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses --enable-multibyte --prefix=/usr CFLAGS=-O2
    make && make install
    cd ..

    rm -rf android-various
    git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various
    mkdir -p android-various/make-3.82-build
    cd android-various/make-3.82-build
    ../make-3.82/build-mingw.sh
    cp make.exe $REPO_SRC_PATH/
    cd ../..
    cd android-various/android-sdk
    gcc -Wl,-subsystem,windows -Wno-write-strings android.cpp -static-libgcc -s -O3 -o android.exe 
    cp android.exe $REPO_SRC_PATH/
}

function makeNDK
{
    mkdir src
    cd src

    if [ ! -d "mpfr" ]
	then
        git clone git://android.git.kernel.org/toolchain/mpfr.git mpfr
        cd mpfr
        downloadIfNotExists mpfr-2.4.2.tar.bz2 http://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2
        cd ..
    fi
    if [ ! -d "binutils" ]
	then
        git clone git://android.git.kernel.org/toolchain/binutils.git binutils
    fi
    if [ ! -d "gmp" ]
	then
        git clone git://android.git.kernel.org/toolchain/gmp.git gmp
    fi
	if [ ! -d "gold" ]
	then
        git clone git://android.git.kernel.org/toolchain/gold.git gold
    fi
	if [ ! -d "build" ]
	then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-build.git build
    fi
	if [ ! -d "gcc" ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gcc.git gcc
    fi
	if [ ! -d "gdb" ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb
    fi
    TCSRC=`pwd`
    cd ..
    mkdir ndk
    cd ndk
    git clone git://android.git.kernel.org/platform/development.git development
    git clone git://gitorious.org/mingw-android-ndk/mingw-android-ndk.git ndk
    cd ndk
    git checkout -b integration origin/integration
    cd ..
    export NDK=`pwd`/ndk
    export ANDROID_NDK_ROOT=$NDK && $NDK/build/tools/build-platforms.sh --verbose

    ROOTDIR=`pwd`
    RELEASE=`date +%Y%m%d`
    NDK=`pwd`/ndk
    ANDROID_NDK_ROOT=$NDK

    if [ ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 -o ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
        $NDK/build/tools/rebuild-all-prebuilt.sh --build-dir=$ROOTDIR/ndk-toolchain-${BUILD}-build-tmp --verbose --package-dir=$ROOTDIR --gdb-version=7.2.50.20110211 --mpfr-version=2.4.2 --toolchain-src-dir=$TCSRC --gdb-with-python=$PYTHONVER --only-latest
    else
        echo "Skipping NDK build, already done."
        echo $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    fi
}

function mixPythonWithNDK
{
    if [ ! -f $REPO_SRC_PATH/python-${BUILD}.7z ]; then
       echo "Failed to find python, $REPO_SRC_PATH/python-${BUILD}.7z"
    fi
    if [ ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 ]; then
       echo "Failed to find gdbserver, $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2"
    fi
    if [ ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
       echo "Failed to find toolchain, arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2"
    fi
    rm -rf /tmp/android-ndk-r5b-${BUILD}
    mkdir -p /tmp/android-ndk-r5b-${BUILD}
    pushd /tmp/android-ndk-r5b-${BUILD}
    tar -jxvf $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    tar -jxvf $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2
    pushd toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK}
    7za x $REPO_SRC_PATH/python-${BUILD}.7z
    popd
    7za a -mx9 android-ndk-r5b-gdb-7.2-${BUILD}.7z toolchains
    popd
}

if [ "$OSTYPE" = "msys" ] ; then
     makeInstallMinGWBits
fi

makeInstallPython
makeNDK
mixPythonWithNDK

popd

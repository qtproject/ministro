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
            if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
            curl --insecure -S -L -O $2 || removeAndExit $1
        else
            wget --no-check-certificate -c $2 || removeAndExit $1
        fi
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

    if [ ! -f $REPO_SRC_PATH/python-${BUILD}.7z ]
    then
        if [ ! -d Python-2.7.1 ]
        then
            git clone git://gitorious.org/mingw-python/mingw-python.git Python-2.7.1
        fi
        pushd Python-2.7.1
        mkdir python-build
        pushd python-build
        ../Python-2.7.1/build-python.sh
        # If successful, the build is packaged into /usr/ndk-build/python-mingw.7z
        cp ../python-${BUILD}.7z $REPO_SRC_PATH/
        popd
		popd
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
    pushd readline-6.2
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses --enable-multibyte --prefix=/usr CFLAGS=-O2
    make && make install
    popd

    rm -rf android-various
    git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various
    mkdir -p android-various/make-3.82-build
    pushd android-various/make-3.82-build
    ../make-3.82/build-mingw.sh
    cp make.exe $REPO_SRC_PATH/
    popd
    pushd android-various/android-sdk
    gcc -Wl,-subsystem,windows -Wno-write-strings android.cpp -static-libgcc -s -O3 -o android.exe 
    cp android.exe $REPO_SRC_PATH/
	popd
}

function makeNDK
{
    mkdir src
    pushd src

	GDB_BRANCH=integration_7_3
	GDB_ROOT_PATH=
#    GDB_BRANCH=master
#    GDB_ROOT_PATH=gdb

    PYTHONVER=$PWD/python-install
    if [ ! -d $PYTHONVER ] ; then
        if [ -f $REPO_SRC_PATH/python-${BUILD}.7z ]; then
            mkdir $PYTHONVER
            pushd $PYTHONVER
                7za x $REPO_SRC_PATH/python-${BUILD}.7z
                PYTHONVER=$PWD
            popd
        fi
    fi

    if [ ! -d "mpfr" ]
    then
        git clone git://android.git.kernel.org/toolchain/mpfr.git mpfr
        pushd mpfr
        downloadIfNotExists mpfr-2.4.2.tar.bz2 http://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2
        popd
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
    pushd gdb
        git checkout integration_7_3
        git reset --hard
		GDB_ROOT_PATH=$PWD/$GDB_ROOT_PATH
		GDB_VERSION=7.3
    popd

    TCSRC=$PWD
    popd

    mkdir build-${BUILD_NDK}
    pushd build-${BUILD_NDK}
	if [ ! -d "development" ]
	then
        git clone git://android.git.kernel.org/platform/development.git development || error_msg "Can't clone development"
	fi
	if [ ! -d "ndk" ]
	then
        git clone git://gitorious.org/mingw-android-ndk/mingw-android-ndk.git ndk || error_msg "Can't clone ndk"
    fi
    pushd ndk
        git checkout -b integration origin/integration
    popd
    export NDK=$PWD/ndk
    export ANDROID_NDK_ROOT=$NDK
    $NDK/build/tools/build-platforms.sh --verbose

    ROOTDIR=$PWD
    RELEASE=`date +%Y%m%d`
    NDK=`pwd`/ndk
    ANDROID_NDK_ROOT=$NDK

    echo GDB_ROOT_PATH $GDB_ROOT_PATH
    if [ ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 -o ! -f $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
        $NDK/build/tools/rebuild-all-prebuilt.sh --build-dir=$ROOTDIR/ndk-toolchain-${BUILD}-build-tmp --verbose --package-dir=$ROOTDIR --gdb-path=$GDB_ROOT_PATH --gdb-version=$GDB_VERSION --mpfr-version=2.4.2 --binutils-version=2.20.1 --toolchain-src-dir=$TCSRC --gdb-with-python=$PYTHONVER --only-latest --only-gdb
    else
        echo "Skipping NDK build, already done."
        echo $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    fi
    cp $ROOTDIR/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    cp $ROOTDIR/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2
}

function mixPythonWithNDK
{
    if [ ! -f $REPO_SRC_PATH/python-${BUILD}.7z ]; then
       echo "Failed to find python, $REPO_SRC_PATH/python-${BUILD}.7z"
    fi
    if [ ! -f $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 ]; then
       echo "Failed to find gdbserver, $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2"
    fi
    if [ ! -f $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
       echo "Failed to find toolchain, $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2"
    fi
    rm -rf /tmp/android-ndk-r5b-${BUILD}
    mkdir -p /tmp/android-ndk-r5b-${BUILD}
    pushd /tmp/android-ndk-r5b-${BUILD}
    tar -jxvf $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    tar -jxvf $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2
    pushd toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK}
    7za x $REPO_SRC_PATH/python-${BUILD}.7z
    popd
    7za a -mx9 android-ndk-r5b-gdb-7.2-${BUILD}.7z toolchains
    cp android-ndk-r5b-gdb-7.2-${BUILD}.7z $REPO_SRC_PATH
    popd
}

if [ "$OSTYPE" = "linux-gnu" ]; then
    TEMP_PATH=/tmp/ndk-build
else
    TEMP_PATH=/usr/ndk-build
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        sudo mkdir -p $TEMP_PATH
        sudo chown `whoami` $TEMP_PATH
    fi
fi

REPO_SRC_PATH=$PWD/ndk-packages
mkdir $REPO_SRC_PATH
PYTHONVER=/usr
pushd $TEMP_PATH

echo $PWD $PWD $PWD $PWD

if [ "$OSTYPE" = "msys" ] ; then
     makeInstallMinGWBits
fi

if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
    if [ ! -f /usr/local/bin/7za ] ; then
        downloadIfNotExists p7zip-macosx.tar.bz2 http://mingw-and-ndk.googlecode.com/files/p7zip-macosx.tar.bz2
        tar xjvf p7zip-macosx.tar.bz2
        chmod 755 opt/bin/7za
        cp opt/bin/7za /usr/local/bin
    fi
fi

makeInstallPython
makeNDK
mixPythonWithNDK

popd

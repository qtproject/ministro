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

. ndk_vars.sh

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
    if [ ! -f $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z ]
    then
        if [ ! -d Python-2.7.1 ]
        then
            git clone git://gitorious.org/mingw-python/mingw-python.git Python-2.7.1 || error_msg "Can't clone Python"
        fi
        pushd Python-2.7.1
        mkdir python-build
        pushd python-build
#        ../build-python.sh --with-pydebug
        ../build-python.sh
        # If successful, the build is packaged into /usr/ndk-build/python-mingw.7z
        cp ../python-${BUILD_PYTHON}.7z $REPO_SRC_PATH/
        popd
        popd
    fi
}

function makeInstallMinGWBits
{
    if [ ! -f /usr/lib/libcurses.a ] ; then
        wget -c http://downloads.sourceforge.net/pdcurses/pdcurses/3.4/PDCurses-3.4.tar.gz
        rm -rf PDCurses-3.4
        tar -xvzf PDCurses-3.4.tar.gz
        pushd PDCurses-3.4/win32
        sed '90s/-copy/-cp/' mingwin32.mak > mingwin32-fixed.mak
        make -f mingwin32-fixed.mak WIDE=Y UTF8=Y DLL=N
        cp pdcurses.a /usr/lib/libcurses.a
        cp pdcurses.a /usr/lib/libncurses.a
        cp pdcurses.a /usr/lib/libpdcurses.a
        cp ../curses.h /usr/include
        cp ../panel.h /usr/include
        popd
    fi

    if [ ! -f /usr/lib/libreadline.a ] ; then
        wget -c http://ftp.gnu.org/pub/gnu/readline/readline-6.2.tar.gz
        rm -rf readline-6.2
        tar -xvzf readline-6.2.tar.gz
        pushd readline-6.2
        CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses --enable-multibyte --prefix=/usr CFLAGS=-O2
        make && make install
        popd
    fi

    if [ ! -d android-various ] ; then
        git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various || error_msg "Can't clone android-various"
    fi

    if [ ! -f $REPO_SRC_PATH/make.exe ] ; then
        mkdir -p android-various/make-3.82-build
        pushd android-various/make-3.82-build
        ../make-3.82/build-mingw.sh
        cp make.exe $REPO_SRC_PATH/
        popd
    fi

    pushd android-various/android-sdk
    gcc -Wl,-subsystem,windows -Wno-write-strings android.cpp -static-libgcc -s -O3 -o android.exe 
    cp android.exe $REPO_SRC_PATH/
    popd
}

function makeNDKForArch
{
    ARCH=$1
    ROOTDIR=$2
    REPO_SRC_PATH=$3
    if [ "$ARCH" = "arm" ] ; then
        ARCH_ABI=$ARCH-linux-androideabi
    else
        ARCH_ABI=$ARCH
    fi
#    if [ ! -f $ROOTDIR/${ARCH_ABI}-4.4.3-gdbserver.tar.bz2 -o ! -f $ROOTDIR/${ARCH_ABI}-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
    if [ ! -f $ROOTDIR/${ARCH_ABI}-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
        $NDK/build/tools/rebuild-all-prebuilt.sh --arch=$ARCH --patches-dir=$NDK/build/tools/toolchain-patches --build-dir=$ROOTDIR/ndk-toolchain-${BUILD}-build-tmp --verbose --package-dir=$ROOTDIR --gdb-path=$GDB_ROOT_PATH --gdb-version=$GDB_VER --mpfr-version=2.4.2 --gmp-version=4.2.4 --binutils-version=2.20.1 --toolchain-src-dir=$TCSRC --gdb-with-python=$PYTHONVER --only-latest
    else
        echo "Skipping NDK build, already done."
        echo $ROOTDIR/${ARCH_ABI}-4.4.3-${BUILD_NDK}.tar.bz2
    fi
    cp $ROOTDIR/${ARCH_ABI}-4.4.3-${BUILD_NDK}.tar.bz2 $REPO_SRC_PATH/${ARCH_ABI}-4.4.3-${BUILD_NDK}.tar.bz2
    cp $ROOTDIR/${ARCH_ABI}-4.4.3-gdbserver.tar.bz2 $REPO_SRC_PATH/${ARCH_ABI}-4.4.3-gdbserver.tar.bz2
}

function makeNDK
{
    PYTHONVER=`pwd`/Python-2.7.1/python-build/install-python-${BUILD_PYTHON}
    mkdir src
    pushd src
#   PYTHONVER=$PWD/python-install

    if [ ! -d $PYTHONVER ] ; then
        if [ -f $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z ]; then
            mkdir -p $PYTHONVER
            pushd $PYTHONVER
                7za x $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z
                PYTHONVER=`pwd`
            popd
        fi
    fi

    if [ ! -d "mpfr" ]
    then
        git clone git://android.git.kernel.org/toolchain/mpfr.git mpfr || error_msg "Can't clone mpfr"
        pushd mpfr
        downloadIfNotExists mpfr-2.4.2.tar.bz2 http://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2
        popd
    fi
    if [ ! -d "binutils" ]
    then
        git clone git://android.git.kernel.org/toolchain/binutils.git binutils || error_msg "Can't clone binutils"
    fi
    if [ ! -d "gmp" ]
    then
        git clone git://android.git.kernel.org/toolchain/gmp.git gmp || error_msg "Can't clone gmp"
    fi
    if [ ! -d "gold" ]
    then
        git clone git://android.git.kernel.org/toolchain/gold.git gold || error_msg "Can't clone gold"
    fi
    if [ ! -d "build" ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-build.git build || error_msg "Can't clone build"
        git reset --hard
    fi
    # reset so that ndk r6 patches apply.
    pushd build
        git reset --hard
    popd
    if [ ! -d "gcc" ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gcc.git gcc || error_msg "Can't clone gcc"
    fi
    # reset so that ndk r6 patches apply (usually this will undo the previously applied patches).
    pushd gcc
        git reset --hard
        git checkout --force integration
        if [ -n "$GCC_GIT_DATE" ] ; then
            REVISION=`git rev-list -n 1 --until="$GCC_GIT_DATE" HEAD`
            echo "Using sources for date '$GCC_GIT_DATE': toolchain/$1 revision $REVISION"
            git checkout $REVISION
        fi
    popd

    mkdir gdb
    if [ ! -d "ma-gdb" ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git ma-gdb || error_msg "Can't clone gdb"
    fi
    pushd ma-gdb
        git checkout $GDB_BRANCH
        git reset --hard
        GDB_ROOT_PATH=$PWD/$GDB_ROOT_PATH
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
    $NDK/build/tools/build-platforms.sh --arch="arm" --verbose

    ROOTDIR=$PWD
    RELEASE=`date +%Y%m%d`
    NDK=`pwd`/ndk
    ANDROID_NDK_ROOT=$NDK

    echo GDB_ROOT_PATH $GDB_ROOT_PATH
    PYTHONHOME=""
    unset PYTHONHOME
    makeNDKForArch arm $ROOTDIR $REPO_SRC_PATH
    makeNDKForArch x86 $ROOTDIR $REPO_SRC_PATH
}

# This also copies the new libstdc++'s over the old ones (the NDK's build scripts are
# buggy (--keep-libstdc++ doesn't work right).
function mixPythonWithNDK
{
    if [ ! -f $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z ]; then
       echo "Failed to find python, $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z"
    fi
    if [ ! -f $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2 ]; then
       echo "Failed to find arm gdbserver, $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2"
    fi
    if [ ! -f $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
       echo "Failed to find arm toolchain, $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2"
    fi
    if [ ! -f $REPO_SRC_PATH/x86-4.4.3-gdbserver.tar.bz2 ]; then
       echo "Failed to find x86 gdbserver, $REPO_SRC_PATH/x86-linux-androideabi-4.4.3-gdbserver.tar.bz2"
    fi
    if [ ! -f $REPO_SRC_PATH/x86-4.4.3-${BUILD_NDK}.tar.bz2 ]; then
       echo "Failed to find x86 toolchain, $REPO_SRC_PATH/x86-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2"
    fi
    mkdir -p /tmp/android-ndk-${NDK_VER}-${BUILD_NDK}-repack
    rm -rf /tmp/android-ndk-${NDK_VER}-${BUILD_NDK}-repack/android-ndk-${NDK_VER}
    pushd /tmp/android-ndk-${NDK_VER}-${BUILD_NDK}-repack
    if [ "$OSTYPE" = "msys" ] ; then
        downloadIfNotExists android-ndk-${NDK_VER}-windows.zip http://dl.google.com/android/ndk/android-ndk-${NDK_VER}-windows.zip
        unzip android-ndk-${NDK_VER}-windows.zip
    else
        if [ "$OSTYPE" = "linux-gnu" ] ; then
            downloadIfNotExists android-ndk-${NDK_VER}-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${NDK_VER}-linux-x86.tar.bz2
            tar xjvf android-ndk-${NDK_VER}-linux-x86.tar.bz2
        else
            downloadIfNotExists android-ndk-${NDK_VER}-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${NDK_VER}-darwin-x86.tar.bz2
            tar xjvf android-ndk-${NDK_VER}-darwin-x86.tar.bz2
        fi
    fi
    pushd android-ndk-${NDK_VER}
    tar -jxvf $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-${BUILD_NDK}.tar.bz2
    tar -jxvf $REPO_SRC_PATH/x86-4.4.3-${BUILD_NDK}.tar.bz2
    # The official NDK uses thumb version of libstdc++ for armeabi and
    # an arm version for armeabi-v7a, so copy the appropriate one over.
    cp toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK}/arm-linux-androideabi/lib/thumb/libstdc++.* sources/cxx-stl/gnu-libstdc++/libs/armeabi/
    cp toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK}/arm-linux-androideabi/lib/armv7-a/libstdc++.* sources/cxx-stl/gnu-libstdc++/libs/armeabi-v7a/
    cp toolchains/x86-4.4.3/prebuilt/${BUILD_NDK}/i686-android-linux/lib/ibstdc++.* sources/cxx-stl/gnu-libstdc++/libs/x86/
    tar -jxvf $REPO_SRC_PATH/arm-linux-androideabi-4.4.3-gdbserver.tar.bz2
    tar -jxvf $REPO_SRC_PATH/x86-4.4.3-gdbserver.tar.bz2
    if [ -d toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK} ] ; then
        pushd toolchains/arm-linux-androideabi-4.4.3/prebuilt/${BUILD_NDK}
            7za x $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z
        popd
    fi
    if [ -d toolchains/x86-4.4.3/prebuilt/${BUILD_NDK} ] ; then
        pushd toolchains/x86-4.4.3/prebuilt/${BUILD_NDK}
            7za x $REPO_SRC_PATH/python-${BUILD_PYTHON}.7z
        popd
    fi
    # Get rid of old and unused stuff.
    rm -rf toolchains/arm-eabi-4.4.0
#    rm -rf toolchains/x86-4.4.3
    popd
    7za a -mx9 android-ndk-${NDK_VER}-gdb-${GDB_VER}-${BUILD_NDK}.7z android-ndk-${NDK_VER}
    mv android-ndk-${NDK_VER}-gdb-${GDB_VER}-${BUILD_NDK}.7z $REPO_SRC_PATH
    popd
}

if [ "$OSTYPE" = "linux-gnu" ] ; then
    BUILD=linux
    BUILD_NDK=linux-x86
    BUILD_PYTHON=$BUILD
else
    if [ "$OSTYPE" = "msys" ] ; then
    BUILD=windows
    BUILD_NDK=windows
    BUILD_PYTHON=mingw
    else
        BUILD=macosx
        BUILD_NDK=darwin-x86
        BUILD_PYTHON=$BUILD
    fi
fi

if [ "$OSTYPE" = "linux-gnu" ]; then
    TEMP_PATH=/usr/ndk-build
else
    TEMP_PATH=/usr/ndk-build
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        sudo mkdir -p $TEMP_PATH
        sudo chown `whoami` $TEMP_PATH
    fi
fi

REPO_SRC_PATH=`pwd`/ndk-packages
mkdir $REPO_SRC_PATH
PYTHONVER=/usr
mkdir $TEMP_PATH
pushd $TEMP_PATH

#cp -rf /usr/ndk-build-old/src .
#mkdir build-windows
#cp -rf /usr/ndk-build-old/build-windows/ndk ./build-windows
#cp -rf /usr/ndk-build-old/build-windows/development ./build-windows

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


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

TEMP_PATH=/usr/ndk-build

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

    if [ ! -d python ]
    then
        git clone git@gitorious.org:mingw-python/mingw-python.git python
    fi
    cd python
    ./build-python.sh
	PYTHONVER=$PWD/install-python-mingw
    # If successful, the build is packaged into /usr/src/others/python-mingw.7z
    cp ../python-mingw.7z $REPO_SRC_PATH/
    cd ..

    rm -rf android-various
    git clone git://gitorious.org:mingw-android-various/mingw-android-various.git android-various
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
    mkdir src && cd src
    if [ ! -d mpfr ]
	then
        git clone git://android.git.kernel.org/toolchain/mpfr.git mpfr
        cd mpfr
        downloadIfNotExists mpfr-2.4.2.tar.bz2 http://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2
        cd ..
    fi
    if [ ! -d binutils ]
	then
        git clone git://android.git.kernel.org/toolchain/binutils.git binutils
    fi
    if [ ! -d gmp ]
	then
        git clone git://android.git.kernel.org/toolchain/gmp.git gmp
    fi
	if [ ! -d gold ]
	then
        git clone git://android.git.kernel.org/toolchain/gold.git gold
    fi
	if [ ! -d build ]
	then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-build.git build
    fi
	if [ ! -d gcc ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gcc.git gcc
    fi
	if [ ! -d gdb ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb
    fi
	cd ..
	mkdir ndk && cd ndk
    git clone git://android.git.kernel.org/platform/development.git development
    git clone git://gitorious.org/mingw-android-ndk/mingw-android-ndk.git ndk
    cd ndk && git checkout -b integration origin/integration && cd ..
    export NDK=`pwd`/ndk
    export ANDROID_NDK_ROOT=$NDK && $NDK/build/tools/build-platforms.sh --verbose

    ROOTDIR=`pwd`
    RELEASE=`date +%Y%m%d`
    NDK=`pwd`/ndk
    ANDROID_NDK_ROOT=$NDK

    if [ "$OSTYPE" = "msys" ]; then
        $NDK/build/tools/rebuild-all-prebuilt.sh --build-dir=$ROOTDIR/ndk-toolchain-windows-build-tmp --verbose --package-dir=$ROOTDIR --gdb-version=7.2.50.20110211 --mpfr-version=2.4.2 --toolchain-src-dir=`pwd`/src --gdb-with-python=$PYTHONVER --only-latest
    else
        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
            $NDK/build/tools/rebuild-all-prebuilt.sh --build-dir=$ROOTDIR/ndk-toolchain-darwin-x86-build-tmp --verbose --package-dir=$ROOTDIR --gdb-version=7.2.50.20110211 --mpfr-version=2.4.2 --toolchain-src-dir=`pwd`/src --gdb-with-python=/usr --only-latest
        else
            $NDK/build/tools/rebuild-all-prebuilt.sh --build-dir=$ROOTDIR/ndk-toolchain-linux-build-tmp --verbose --package-dir=$ROOTDIR --gdb-version=7.2.50.20110211 --mpfr-version=2.4.2 --toolchain-src-dir=`pwd`/src --gdb-with-python=/usr --only-latest
        fi
    fi
}

if [ "$OSTYPE" = "msys" ] ; then
     makeInstallMinGWBits
fi
makeNDK

popd

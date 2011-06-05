#!/bin/bash

# Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>
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

. sdk_vars.sh

REPO_SRC_PATH=$PWD
TEMP_PATH_PREFIX=/tmp

if [ "$OSTYPE" = "msys" ]; then
    TEMP_PATH_PREFIX=/usr
fi

TEMP_PATH=$TEMP_PATH_PREFIX/necessitas
if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
    # On Mac OS X, user accounts don't have write perms for /var, same is true for Ubuntu.
    sudo mkdir -p $TEMP_PATH
    sudo chmod 777 $TEMP_PATH
    sudo mkdir -p $TEMP_PATH_PREFIX/www
    sudo chmod 777 $TEMP_PATH_PREFIX/www
    STRIP="strip -S"
    CPRL="cp -RL"
else
    mkdir -p $TEMP_PATH
    STRIP="strip -s"
    CPRL="cp -rL"
fi

# These are global
# For google gdb (master):
#GDB_ROOT_PATH=../gdb-7.2.50.20110211
# For integration_7_3
GDB_ROOT_PATH=..
GDB_VER=7.3

pushd $TEMP_PATH

MINISTRO_REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/qt
REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/sdk
STATIC_QT_PATH=""
SHARED_QT_PATH=""
SDK_TOOLS_PATH=""
ANDROID_STRIP_BINARY=""
ANDROID_READELF_BINARY=""
QPATCH_PATH=""
EXE_EXT=""
export PYTHONHOME=""

if [ "$OSTYPE" = "msys" ] ; then
    HOST_CFG_OPTIONS=" -platform win32-g++ -reduce-exports -release -prefix . "
    HOST_TAG=windows
    HOST_TAG_NDK=windows
    EXE_EXT=.exe
    SHLIB_EXT=.dll
    SCRIPT_EXT=.bat
    JOBS=9
else
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        HOST_CFG_OPTIONS=" -platform macx-g++42 -sdk /Developer/SDKs/MacOSX10.5.sdk -arch i386 -arch x86_64 -cocoa -release -prefix . "
        HOST_QM_CFG_OPTIONS="CONFIG+=x86 CONFIG+=x86_64"
        # -reduce-exports doesn't work for static Mac OS X i386 build.
        # (ld: bad codegen, pointer diff in fulltextsearch::clucene::QHelpSearchIndexReaderClucene::run()     to global weak symbol vtable for QtSharedPointer::ExternalRefCountDatafor architecture i386)
        HOST_CFG_OPTIONS_STATIC=" -no-reduce-exports "
        HOST_TAG=darwin-x86
        HOST_TAG_NDK=darwin-x86
        SHLIB_EXT=.dylib
        JOBS=9
    else
        HOST_CFG_OPTIONS=" -platform linux-g++ -developer-build "
        HOST_TAG=linux-x86
        HOST_TAG_NDK=linux-x86
        SHLIB_EXT=.so
        JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
        JOBS=`expr $JOBS + 2`
    fi
fi

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
        wget --no-check-certificate -c $2 || removeAndExit $1
    fi
}

function doMake
{
    if [ "$OSTYPE" = "msys" -o  "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        if [ "$OSTYPE" = "msys" ] ; then
            MAKEDIR=`pwd -W`
            MAKEFOREVER=1
        else
            MAKEDIR=`pwd`
            MAKEFOREVER=0
        fi
        MAKEFILE=$MAKEDIR/Makefile
        make -f $MAKEFILE -j$JOBS
        while [ "$?" != "0" -a "$MAKEFOREVER" = "1" ]
        do
            if [ -f /usr/break-make ]; then
                echo "Detected break-make"
                rm -f /usr/break-make
                error_msg $1
            fi
            make -f $MAKEFILE -j$JOBS
        done
        echo $2>all_done
    else
        make -j$JOBS || error_msg $1
        echo $2>all_done
    fi
}

function doSed
{
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]
    then
        sed -i '.bak' "$1" $2
        rm ${2}.bak
    else
        sed "$1" -i $2
    fi
}

function prepareHostQt
{
    # download, compile & install qt, it is used to compile the installer
    if [ "$OSTYPE" = "msys" ]
    then
        downloadIfNotExists 7za920.zip http://downloads.sourceforge.net/sevenzip/7za920.zip
        SEVEN7LOC=$PWD
        pushd /usr/local/bin
        unzip -o $SEVEN7LOC/7za920.zip
        popd

        # Get a more recent sed, one that can do -i.
        downloadIfNotExists sed-4.2.1-2-msys-1.0.13-bin.tar.lzma http://downloads.sourceforge.net/project/mingw/MSYS/BaseSystem/sed/sed-4.2.1-2/sed-4.2.1-2-msys-1.0.13-bin.tar.lzma
        rm -rf sed-4.2.1-2-msys-1.0.13-bin.tar
        rm /usr/bin/sed.exe
        7za x sed-4.2.1-2-msys-1.0.13-bin.tar.lzma
        tar -xvf sed-4.2.1-2-msys-1.0.13-bin.tar
        mv bin/sed.exe /usr/bin

        # download, compile & install zlib to /usr
        downloadIfNotExists zlib-1.2.5.tar.gz http://downloads.sourceforge.net/libpng/zlib/1.2.5/zlib-1.2.5.tar.gz
        if [ ! -f /usr/lib/libz.a ] ; then
            tar -xvzf zlib-1.2.5.tar.gz
            cd zlib-1.2.5
            doSed $"s/usr\/local/usr/" win32/Makefile.gcc
            make -f win32/Makefile.gcc
            export INCLUDE_PATH=/usr/include
            export LIBRARY_PATH=/usr/lib
            make -f win32/Makefile.gcc install
            rm -rf zlib-1.2.5
            cd ..
        fi
    fi

    if [ "$OSTYPE" = "msys" -o "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]
    then
        if [ ! -d $HOST_QT_VERSION ]
        then
            git clone git://gitorious.org/~mingwandroid/qt/mingw-android-official-qt.git $HOST_QT_VERSION
        fi
    else
        downloadIfNotExists $HOST_QT_VERSION.tar.gz http://get.qt.nokia.com/qt/source/$HOST_QT_VERSION.tar.gz

        if [ ! -d $HOST_QT_VERSION ]
        then
            tar -xzvf $HOST_QT_VERSION.tar.gz || error_msg "Can't untar $HOST_QT_VERSION.tar.gz"
        fi
    fi

    #build qt statically, needed by Sdk installer
    mkdir build-$HOST_QT_VERSION-static
    pushd build-$HOST_QT_VERSION-static
    STATIC_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -static -no-webkit -no-phonon -no-dbus -no-opengl -no-qt3support -no-xmlpatterns -no-svg -qt-sql-sqlite -plugin-sql-sqlite -confirm-license $HOST_CFG_OPTIONS $HOST_CFG_OPTIONS_STATIC -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        doMake "Can't compile static $HOST_QT_VERSION" "all done"
        if [ "$OSTYPE" = "msys" ]; then
            # Horrible; need to fix this properly.
            doSed $"s/qt warn_on release /qt static warn_on release /" mkspecs/win32-g++/qmake.conf
        fi
    fi
    popd

    #build qt shared, needed by QtCreator
    mkdir build-$HOST_QT_VERSION-shared
    pushd build-$HOST_QT_VERSION-shared
    SHARED_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -shared -webkit -no-phonon -qt-sql-sqlite -plugin-sql-sqlite -no-qt3support -confirm-license $HOST_CFG_OPTIONS -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        doMake "Can't compile shared $HOST_QT_VERSION" "all done"
        if [ "$OSTYPE" = "msys" ]; then
            # Horrible; need to fix this properly.
            doSed $"s/qt warn_on release /qt shared warn_on release /" mkspecs/win32-g++/qmake.conf
        fi
    fi
    popd

}

function prepareSdkInstallerTools
{
    # get installer source code
    if [ ! -d necessitas-installer-framework ]
    then
        git clone git://gitorious.org/~taipan/qt-labs/necessitas-installer-framework.git || error_msg "Can't clone necessitas-installer-framework"
    fi

    pushd necessitas-installer-framework/installerbuilder

    if [ ! -f all_done ]
    then
        git checkout master
        $STATIC_QT_PATH/bin/qmake $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure necessitas-installer-framework"
        doMake "Can't compile necessitas-installer-framework" "all done"
    fi
    popd
    pushd $SDK_TOOLS_PATH
    $STRIP *
    popd
}


function prepareNecessitasQtCreator
{
    if [ ! -d android-qt-creator ]
    then
        git clone git://anongit.kde.org/android-qt-creator.git android-qt-creator || error_msg "Can't clone android-qt-creator"
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}.7z ]
    then
        pushd android-qt-creator
        git checkout testing
        if [ ! -f all_done ]
        then
            $SHARED_QT_PATH/bin/qmake "CONFIG+=release" $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure android-qt-creator"
            doMake "Can't compile android-qt-creator" "all done"
        fi
        rm -fr QtCreator
        export INSTALL_ROOT=$PWD/QtCreator
        make install

        #download and install sdk-updater-plugin
        export QTC_SOURCE=$PWD
        downloadIfNotExists research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz http://android-lighthouse.googlecode.com/files/research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz
        if [ ! -d research-sdk-updater-plugin-master-snapshot-20110524185306 ]
        then
            tar xvfz research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz
        fi
        pushd research-sdk-updater-plugin-master-snapshot-20110524185306
            $SHARED_QT_PATH/bin/qmake "CONFIG+=release" $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure sdk-updater-plugin"
            doMake "Can't compile sdk-updater-plugin" "all done"
            make install
        popd

        mkdir -p $PWD/QtCreator/Qt/imports
        mkdir -p $PWD/QtCreator/Qt/plugins
        if [ "$OSTYPE" = "msys" ]; then
            mkdir -p $PWD/QtCreator/bin
            cp -rf lib/qtcreator/* $PWD/QtCreator/bin/
            cp -a /usr/bin/libgcc_s_dw2-1.dll $PWD/QtCreator/bin/
            cp -a /usr/bin/libstdc++-6.dll $PWD/QtCreator/bin/
            QT_LIB_DEST=$PWD/QtCreator/bin/
            cp -a $SHARED_QT_PATH/lib/* $QT_LIB_DEST
            cp -a bin/necessitas.bat $PWD/QtCreator/bin/
        else
            if [ "$OSTYPE" = "linux-gnu" ]; then
                mkdir -p $PWD/QtCreator/Qt/lib
                QT_LIB_DEST=$PWD/QtCreator/Qt/lib/
                cp -a $SHARED_QT_PATH/lib/* $QT_LIB_DEST
                rm -fr $QT_LIB_DEST/pkgconfig
                find . $QT_LIB_DEST -name *.la | xargs rm -fr
                find . $QT_LIB_DEST -name *.prl | xargs rm -fr
                cp -a $SHARED_QT_PATH/imports/* ${QT_LIB_DEST}../imports
                cp -a $SHARED_QT_PATH/plugins/* ${QT_LIB_DEST}../plugins
                cp -a bin/necessitas $PWD/QtCreator/bin/
            else
                pushd macdeployqt
                $SHARED_QT_PATH/bin/qmake $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure macdeployqt"
                doMake "Can't compile macdeployqt" "all done"
                popd
                pushd bin
                rm -rf NecessitasQtCreatorBackup.app
                cp -rf NecessitasQtCreator.app NecessitasQtCreatorBackup.app
                ../macdeployqt/macdeployqt/macdeployqt NecessitasQtCreator.app
                popd
                mv bin/NecessitasQtCreator.app $PWD/QtCreator/bin/NecessitasQtCreator.app
                mv bin/NecessitasQtCreatorBackup.app bin/NecessitasQtCreator.app
            fi
        fi
        mkdir $PWD/QtCreator/images
        cp -a bin/necessitas*.png $PWD/QtCreator/images/
        pushd QtCreator
        find . -name "*$SHLIB_EXT" | xargs $STRIP
        popd
        $SDK_TOOLS_PATH/archivegen QtCreator qtcreator-${HOST_TAG}.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data
        mv qtcreator-${HOST_TAG}.7z $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}.7z
        popd
    fi

    mkdir qpatch-build
    pushd qpatch-build
    if [ ! -f all_done ]
    then
        $STATIC_QT_PATH/bin/qmake "CONFIG+=release" $HOST_QM_CFG_OPTIONS -r ../android-qt-creator/src/tools/qpatch/qpatch.pro
        if [ "$OSTYPE" = "msys" ]; then
            make -f Makefile.Release || error_msg "Can't compile qpatch"
        else
            make || error_msg "Can't compile qpatch"
        fi
        echo "all_done">all_done
    fi

    if [ "$OSTYPE" = "msys" ]; then
        QPATCH_PATH=$PWD/release/qpatch$EXE_EXT
    else
        QPATCH_PATH=$PWD/qpatch
    fi
    popd
}

function makeInstallMinGWBits
{
    install_dir=$1
    mkdir mingw-bits
    pushd mingw-bits
    # Tools. Maybe move these bits to setup_mingw_for_necessitas_build.sh?
    downloadIfNotExists autoconf-2.68.tar.bz2 http://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.bz2
    rm -rf autoconf-2.68
    tar -xvjf autoconf-2.68.tar.bz2
    pushd autoconf-2.68
    ./configure -prefix=/usr/local
    make
    make install
    popd

    downloadIfNotExists automake-1.10.3.tar.bz2 http://ftp.gnu.org/gnu/automake/automake-1.10.3.tar.bz2
    rm -rf automake-1.10.3
    tar -xvjf automake-1.10.3.tar.bz2
    pushd automake-1.10.3
    ./configure -prefix=/usr/local
    make
    make install
    popd

    downloadIfNotExists libtool-2.4.tar.gz http://ftp.gnu.org/gnu/libtool/libtool-2.4.tar.gz
    rm -rf libtool-2.4
    tar -xvzf libtool-2.4.tar.gz
    pushd libtool-2.4
    ./configure -prefix=/usr/local
    make
    make install
    popd

    downloadIfNotExists PDCurses-3.4.tar.gz http://downloads.sourceforge.net/pdcurses/pdcurses/3.4/PDCurses-3.4.tar.gz
    rm -rf PDCurses-3.4
    tar -xvzf PDCurses-3.4.tar.gz
    pushd PDCurses-3.4/win32
    sed '90s/-copy/-cp/' mingwin32.mak > mingwin32-fixed.mak
    make -f mingwin32-fixed.mak WIDE=Y UTF8=Y DLL=N
    mkdir -p $install_dir/lib
    mkdir -p $install_dir/include
    cp pdcurses.a $install_dir/lib/libcurses.a
    cp pdcurses.a $install_dir/lib/libncurses.a
    cp pdcurses.a $install_dir/lib/libpdcurses.a
    cp panel.a $install_dir/lib/libpanel.a
    cp ../curses.h $install_dir/include
    cp ../panel.h $install_dir/include
    popd

    downloadIfNotExists libiconv-1.13.tar.gz http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.13.tar.gz
    rm -rf libiconv-1.13
    tar -xvzf libiconv-1.13.tar.gz
    pushd libiconv-1.13
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=  CFLAGS=-O2
    make && make DESTDIR=$install_dir install
    popd

    downloadIfNotExists readline-6.2.tar.gz http://ftp.gnu.org/pub/gnu/readline/readline-6.2.tar.gz
    rm -rf readline-6.2
    tar -xvzf readline-6.2.tar.gz
    pushd readline-6.2
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=  CFLAGS=-O2
    make && make DESTDIR=$install_dir install
    popd
    
    # awk command fails during configure (I think).
    downloadIfNotExists regex-2.7-src.zip http://downloads.sourceforge.net/sourceforge/gnuwin32/regex/2.7/regex-2.7-src.zip
    unzip regex-2.7-src.zip
    pushd src/regex/2.7/regex-2.7-src
#   aclocal
#   autoconf
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --prefix= CFLAGS=-O2
    make && make DESTDIR=$install_dir install
    popd

    # texinfo fails because regex.h not found (part of libc)
    downloadIfNotExists texinfo-4.13a.tar.gz http://ftp.gnu.org/gnu/texinfo/texinfo-4.13a.tar.gz
    rm -rf texinfo-4.13
    tar -xvzf texinfo-4.13a.tar.gz
    pushd texinfo-4.13
    CFLAGS=-O2 && ./configure --prefix= CFLAGS=-O2
    make
    make install
    popd

    popd
}

function prepareNDKs
{
    # repack official windows NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-windows.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-windows.zip http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-windows.zip
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        unzip android-ndk-${ANDROID_NDK_VERSION}-windows.zip
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-windows.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-windows.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-windows.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    # repack official mac NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        tar xjvf android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    # repack official linux-x86 NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        tar xjvf android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    if [ BUILD_ANDROID_GIT_NDK = 1 ]
    then
        export ANDROID_NDK_ROOT=$PWD/android-ndk-${ANDROID_NDK_VERSION}-git
        export ANDROID_NDK_FOLDER_NAME=android-ndk-${ANDROID_NDK_VERSION}-git
    else
        export ANDROID_NDK_ROOT=$PWD/android-ndk-${ANDROID_NDK_VERSION}
        export ANDROID_NDK_FOLDER_NAME=android-ndk-${ANDROID_NDK_VERSION}
    fi

    export ANDROID_NDK_HOST=$HOST_TAG_NDK
    export ANDROID_NDK_ROOT=$ANDROID_NDK_FOLDER_NAME

    if [ ! -d $ANDROID_NDK_FOLDER_NAME ]; then
        if [ "$OSTYPE" = "msys" ]; then
            downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-windows.zip http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-windows.zip
            unzip android-ndk-${ANDROID_NDK_VERSION}-windows.zip
        fi

        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
            downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
            tar xjvf android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
        fi

        if [ "$OSTYPE" = "linux-gnu" ]; then
            downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
            tar xjvf android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
        fi

        if [ BUILD_ANDROID_GIT_NDK = 1 ]
        then
            mv android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-git
            git clone http://android.git.kernel.org/platform/ndk.git android_git_ndk
            pushd android_git_ndk
                ./build/tools/rebuild-all-prebuilt.sh --ndk-dir=$ANDROID_NDK_ROOT --git-http --gdb-version=7.1 --sysroot=$ANDROID_NDK_ROOT/platforms/android-9 --verbose --package-dir=
            popd
            rm -fr android_git_ndk
            mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}_git/data
            $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION}-git $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}_git/data/android-ndk-${ANDROID_NDK_VERSION}-git-${HOST_TAG_NDK}.7z
        fi
    fi

    ANDROID_STRIP_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-strip$EXE_EXT
    ANDROID_READELF_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-readelf$EXE_EXT
}

function prepareGDB
{
    package_name_ver=${GDB_VER//./_} # replace . with _
    package_path=$REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.gdb_$package_name_ver/data
    #This function depends on prepareNDKs
    if [ -f $package_path/gdb-${GDB_VER}-${HOST_TAG}.7z ]
    then
        return
    fi

    mkdir gdb-build
    pushd gdb-build
    pyversion=2.7
    pyfullversion=2.7.1
    install_dir=$PWD/install
    target_dir=$PWD/gdb-$GDB_VER
    mkdir -p $target_dir

    downloadIfNotExists expat-2.0.1.tar.gz http://downloads.sourceforge.net/sourceforge/expat/expat-2.0.1.tar.gz || error_msg "Can't download expat library"
    if [ ! -d expat-2.0.1 ]
    then
        tar xzvf expat-2.0.1.tar.gz
        pushd expat-2.0.1
            ./configure --disable-shared --enable-static -prefix=/ && make -j$JOBS && make DESTDIR=$install_dir install || error_msg "Can't compile expat library"
        popd
    fi

    OLDCC=$CC
    OLDCXX=$CXX
    if [ ! -f Python-$pyfullversion/all_done ]
    then
        if [ "$OSTYPE" = "linux-gnu" ]; then
            downloadIfNotExists Python-$pyfullversion.tar.bz2 http://www.python.org/ftp/python/$pyfullversion/Python-$pyfullversion.tar.bz2 || error_msg "Can't download python library"
            tar xjvf Python-$pyfullversion.tar.bz2
            USINGMAPYTHON=0
        else
#            if [ "$OSTYPE" = "msys" ]; then
#                makeInstallMinGWBits $install_dir
#            fi
            rm -rf Python-$pyfullversion
            git clone git://gitorious.org/mingw-python/mingw-python.git Python-$pyfullversion
            USINGMAPYTHON=1
        fi

        pushd Python-$pyfullversion
        unset PYTHONHOME
        OLDPATH=$PATH

        if [ "$OSTYPE" = "linux-gnu" ] ; then
            HOST=i386-linux-gnu
            CC32="gcc -m32"
            CXX32="g++ -m32"
            PYCFGDIR=$install_dir/lib/python$pyversion/config
        else
            if [ "$OSTYPE" = "msys" ] ; then
                SUFFIX=.exe
                HOST_EXE=.exe
                HOST=i686-pc-mingw32
                PYCFGDIR=$install_dir/bin/Lib/config
                export PATH=.:$PATH
                CC32=gcc.exe
                CXX32=g++.exe
                PYCCFG="--enable-shared --disable-static"
            else
                # On some OS X installs (case insensitive filesystem), the dir "Python" clashes with the executable "python"
                # --with-suffix can be used to get around this.
                SUFFIX=Mac
                export PATH=.:$PATH
                CC32="gcc -m32"
                CXX32="g++ -m32"
            fi
        fi

        if [ "$USINGMAPYTHON" = "1" ] ; then
            autoconf
            touch Include/Python-ast.h
            touch Include/Python-ast.c
        fi

        CC=$CC32 CXX=$CXX32 ./configure $PYCCFG --host=$HOST --prefix=$install_dir --with-suffix=$SUFFIX || error_msg "Can't configure Python"
        doMake "Can't compile Python" "all done"
        make install || error_msg "Can't install Python"

        if [ "$OSTYPE" = "msys" ] ; then
            cd pywin32-216
            # TODO :: Fix this, builds ok but then tries to copy pywintypes27.lib instead of libpywintypes27.a and pywintypes27.dll.
            ../python$EXE_EXT setup.py build
            cd ..
        fi

        mkdir -p $target_dir/python/lib
        cp LICENSE $target_dir/PYTHON-LICENSE

        if [ "$OSTYPE" = "msys" ] ; then
            mkdir -p $PYCFGDIR
            cp Modules/makesetup $PYCFGDIR
            cp Modules/config.c.in $PYCFGDIR
            cp Modules/config.c $PYCFGDIR
            cp libpython$pyversion.a $PYCFGDIR
            cp Makefile $PYCFGDIR
            cp Modules/python.o $PYCFGDIR
            cp Modules/Setup.local $PYCFGDIR
            cp install-sh  $PYCFGDIR
            cp Modules/Setup $PYCFGDIR
            cp Modules/Setup.config $PYCFGDIR
            cp libpython$pyversion.a $install_dir/lib/python$pyversion
            cp libpython$pyversion.dll $install_dir/lib/python$pyversion
            cp libpython$pyversion.dll $target_dir/
        fi

        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/2to3
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/idle
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/pydoc
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/python-config
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/python2.7-config
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/smtpd.py
        fi

        cp -a $install_dir/lib/python$pyversion $target_dir/python/lib/
        mkdir -p $target_dir/python/include/python$pyversion
        mkdir -p $target_dir/python/bin
        cp $install_dir/include/python$pyversion/pyconfig.h $target_dir/python/include/python$pyversion/
        # Remove the $SUFFIX if present (OS X)
        mv $install_dir/bin/python$pyversion$SUFFIX$EXE_EXT $install_dir/bin/python$pyversion$EXE_EXT
        mv $install_dir/bin/python$SUFFIX$EXE_EXT $install_dir/bin/python$EXE_EXT
        cp -a $install_dir/bin/python$pyversion* $target_dir/python/bin/
        if [ "$OSTYPE" = "msys" ] ; then
            cp -fr $install_dir/bin/Lib $target_dir/
        fi
        $STRIP $target_dir/python/bin/python$pyversion$EXE_EXT
        popd
        export PATH=$OLDPATH
    fi

	# Something is setting PYTHONHOME as an Env. Var for Windows and I'm not sure what... installer? NQTC?
    unset PYTHONHOME
    unset PYTHONPATH

    if [ ! -d gdb-src ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb-src
        pushd gdb-src
        git checkout integration_7_3
        popd
    fi

    if [ ! -d gdb-src/build-gdb ]
    then
        mkdir -p gdb-src/build-gdb
        pushd gdb-src/build-gdb
        OLDPATH=$PATH
        export PATH=$install_dir/bin/:$PATH
        CC=$CC32 CXX=$CXX32 $GDB_ROOT_PATH/configure --enable-initfini-array --enable-gdbserver=no --enable-tui=yes --with-sysroot=$TEMP_PATH/android-ndk-r5b/platforms/android-9/arch-arm --with-python=$install_dir --with-expat=yes --with-libexpat-prefix=$install_dir --prefix=$target_dir --target=arm-elf-linux --host=$HOST --build=$HOST --disable-nls
        doMake "Can't compile android gdb $GDB_VER" "all done"
        cp -a gdb/gdb$EXE_EXT $target_dir/
        # Fix building gdb-tui, it used to work and was handy to have.
        # cp -a gdb/gdb-tui$EXE_EXT $target_dir/
        $STRIP $target_dir/gdb$EXE_EXT
        export PATH=$OLDPATH
        popd
    fi

    CC=$OLDCC
    CXX=$OLDCXX

    pushd $target_dir
    find . -name *.py[co] | xargs rm -f
    find . -name test | xargs rm -fr
    find . -name tests | xargs rm -fr
    popd

    $SDK_TOOLS_PATH/archivegen gdb-$GDB_VER gdb-$GDB_VER-${HOST_TAG}.7z
    mkdir -p $package_path
 
    mv gdb-${GDB_VER}-${HOST_TAG}.7z $package_path/

    popd #gdb-build
}

function prepareGDBServer
{
    package_name_ver=${GDB_VER//./_} # replace - with _
    package_path=$REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.gdb_$package_name_ver/data

    if [ -f $package_path/gdbserver-$GDB_VER.7z ]
    then
        return
    fi

    export NDK_DIR=$TEMP_PATH/android-ndk-r5b

    mkdir gdb-build
    pushd gdb-build

    if [ ! -d gdb-src ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb-src
        GDB_ROOT_PATH=..
        pushd gdb-src
		git checkout integration_7_3
		popd
    fi

    mkdir -p gdb-src/build-gdbserver
    pushd gdb-src/build-gdbserver

    mkdir android-sysroot
    $CPRL $TEMP_PATH/android-ndk-r5b/platforms/android-9/arch-arm/* android-sysroot/ || error_msg "Can't copy android sysroot"
	# Fix gdbserver bug by using a Gingerbread version of libc.a
	# 'The remote end hung up.'
    # git archive --remote=git://android.git.kernel.org/platform/development.git HEAD:ndk/platforms/android-3/arch-arm/lib libc.a | tar -x
	downloadIfNotExists libc.a https://review.source.android.com//cat/23118%2C1%2Cndk/platforms/android-3/arch-arm/lib/libc.a%5E0
	cp libc.a%5E0 libc.zip
	rm libc_new-*.a
	unzip libc.zip
	mv libc_new-*.a android-sysroot/usr/lib/libc.a
    rm -f android-sysroot/usr/lib/libthread_db*
    rm -f android-sysroot/usr/include/thread_db.h

    TOOLCHAIN_PREFIX=$TEMP_PATH/android-ndk-r5b/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi

    OLD_CC="$CC"
    OLD_CFLAGS="$CFLAGS"
    OLD_LDFLAGS="$LDFLAGS"

    export CC="$TOOLCHAIN_PREFIX-gcc --sysroot=$PWD/android-sysroot"
    export CFLAGS="-O2 -nostdlib -D__ANDROID__ -DANDROID -DSTDC_HEADERS -I$TEMP_PATH/android-ndk-r5b/toolchains/arm-linux-androideabi-4.4.3/prebuilt/linux-x86/lib/gcc/arm-linux-androideabi/4.4.3/include -I$PWD/android-sysroot/usr/include -fno-short-enums"
    export LDFLAGS="-static -Wl,-z,nocopyreloc -Wl,--no-undefined $PWD/android-sysroot/usr/lib/crtbegin_static.o -lc -lm -lgcc -lc $PWD/android-sysroot/usr/lib/crtend_android.o"

    LIBTHREAD_DB_DIR=$TEMP_PATH/android-ndk-r5b/sources/android/libthread_db/gdb-7.1.x/
    cp $LIBTHREAD_DB_DIR/thread_db.h android-sysroot/usr/include/
    $TOOLCHAIN_PREFIX-gcc$EXE_EXT --sysroot=$PWD/android-sysroot -o $PWD/android-sysroot/usr/lib/libthread_db.a -c $LIBTHREAD_DB_DIR/libthread_db.c || error_msg "Can't compile android threaddb"
    $GDB_ROOT_PATH/gdb/gdbserver/configure --host=arm-eabi-linux --with-libthread-db=$PWD/android-sysroot/usr/lib/libthread_db.a || error_msg "Can't configure gdbserver"
    doMake "Can't compile gdbserver" "all done"

    export CC="$OLD_CC"
    export CFLAGS="$OLD_CFLAGS"
    export LDFLAGS="$OLD_LDFLAGS"

    mkdir gdbserver-$GDB_VER
    $TOOLCHAIN_PREFIX-objcopy --strip-unneeded gdbserver $PWD/gdbserver-$GDB_VER/gdbserver

    $SDK_TOOLS_PATH/archivegen gdbserver-$GDB_VER gdbserver-$GDB_VER.7z
    mkdir -p $package_path
    mv gdbserver-$GDB_VER.7z $package_path/

    popd #gdb-src/build-gdbserver

    popd #gdb-build
}

function repackSDK
{
    package_name=${4//-/_} # replace - with _
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data/$2.7z ]
    then
        downloadIfNotExists $1.zip http://dl.google.com/android/repository/$1.zip
        unzip $1.zip
        mkdir -p $3
        mv $1 $3/$4
        $SDK_TOOLS_PATH/archivegen $3 $2.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data
        mv $2.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data/$2.7z
        rm -fr $3
    fi
}


function prepareSDKs
{
    echo "prepare SDKs"
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz
        if [ ! -d android-sdk-linux_x86 ]
        then
            tar -xzvf android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-linux_x86 android-sdk_${ANDROID_SDK_VERSION}-linux_x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-linux_x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z
        rm -fr android-sdk-linux_x86
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip
        if [ ! -d android-sdk-mac_x86 ]
        then
            unzip android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-mac_x86 android-sdk_${ANDROID_SDK_VERSION}-mac_x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-mac_x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z
        rm -fr android-sdk-mac_x86
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-windows.zip http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-windows.zip
        if [ ! -d android-sdk-windows ]
        then
            unzip android-sdk_${ANDROID_SDK_VERSION}-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-windows android-sdk_${ANDROID_SDK_VERSION}-windows.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-windows.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z
        rm -fr android-sdk-windows
    fi

    if [ "$OSTYPE" = "msys" ]
    then
        if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.platform_tools/data/android-sdk-windows-tools-mingw-android.7z ]
        then
            git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various
            mkdir -p android-various/make-3.82-build
            pushd android-various/make-3.82-build
            ../make-3.82/build-mingw.sh
            popd
            pushd android-various/android-sdk
            gcc -Wl,-subsystem,windows -Wno-write-strings android.cpp -static-libgcc -s -O2 -o android.exe
            popd
            mkdir -p android-sdk-windows/tools/
            cp android-various/make-3.82-build/make.exe android-sdk-windows/tools/
            cp android-various/android-sdk/android.exe android-sdk-windows/tools/
            $SDK_TOOLS_PATH/archivegen android-sdk-windows android-sdk-windows-tools-mingw-android.7z
            mv android-sdk-windows-tools-mingw-android.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.platform_tools/data/android-sdk-windows-tools-mingw-android.7z
            rm -rf android-various
        fi
    fi

    # repack platform-tools
    repackSDK platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-linux platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-linux android-sdk-linux_x86 platform-tools
    repackSDK platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-macosx platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-macosx android-sdk-mac_x86 platform-tools
    # should we also include ant binary for windows ?
    repackSDK platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-windows platform-tools_${ANDROID_PLATFORM_TOOLS_VERSION}-windows android-sdk-windows platform-tools

    # repack api-4
    repackSDK android-${ANDROID_API_4_VERSION}-linux android-${ANDROID_API_4_VERSION}-linux android-sdk-linux_x86/platforms android-4
    repackSDK android-${ANDROID_API_4_VERSION}-macosx android-${ANDROID_API_4_VERSION}-macosx android-sdk-mac_x86/platforms android-4
    repackSDK android-${ANDROID_API_4_VERSION}-windows android-${ANDROID_API_4_VERSION}-windows android-sdk-windows/platforms android-4

    # repack api-5
    repackSDK android-${ANDROID_API_5_VERSION}-linux android-${ANDROID_API_5_VERSION}-linux android-sdk-linux_x86/platforms android-5
    repackSDK android-${ANDROID_API_5_VERSION}-macosx android-${ANDROID_API_5_VERSION}-macosx android-sdk-mac_x86/platforms android-5
    repackSDK android-${ANDROID_API_5_VERSION}-windows android-${ANDROID_API_5_VERSION}-windows android-sdk-windows/platforms android-5

    # repack api-6
    repackSDK android-${ANDROID_API_6_VERSION}-linux  android-${ANDROID_API_6_VERSION}-linux  android-sdk-linux_x86/platforms android-6
    repackSDK android-${ANDROID_API_6_VERSION}-macosx android-${ANDROID_API_6_VERSION}-macosx android-sdk-mac_x86/platforms android-6
    repackSDK android-${ANDROID_API_6_VERSION}-windows android-${ANDROID_API_6_VERSION}-windows android-sdk-windows/platforms android-6

    # repack api-7
    repackSDK android-${ANDROID_API_7_VERSION}-linux android-${ANDROID_API_7_VERSION}-linux android-sdk-linux_x86/platforms android-7
    repackSDK android-${ANDROID_API_7_VERSION}-macosx android-${ANDROID_API_7_VERSION}-macosx android-sdk-mac_x86/platforms android-7
    repackSDK android-${ANDROID_API_7_VERSION}-windows android-${ANDROID_API_7_VERSION}-windows android-sdk-windows/platforms android-7

    # repack api-8
    repackSDK android-${ANDROID_API_8_VERSION}-linux android-${ANDROID_API_8_VERSION}-linux android-sdk-linux_x86/platforms android-8
    repackSDK android-${ANDROID_API_8_VERSION}-macosx android-${ANDROID_API_8_VERSION}-macosx android-sdk-mac_x86/platforms android-8
    repackSDK android-${ANDROID_API_8_VERSION}-windows android-${ANDROID_API_8_VERSION}-windows android-sdk-windows/platforms android-8

    # repack api-9
    repackSDK android-${ANDROID_API_9_VERSION}-linux android-${ANDROID_API_9_VERSION}-linux android-sdk-linux_x86/platforms android-9
    repackSDK android-${ANDROID_API_9_VERSION}-linux android-${ANDROID_API_9_VERSION}-macosx android-sdk-mac_x86/platforms android-9
    repackSDK android-${ANDROID_API_9_VERSION}-linux android-${ANDROID_API_9_VERSION}-windows android-sdk-windows/platforms android-9

    # repack api-10
    repackSDK android-${ANDROID_API_10_VERSION}-linux android-${ANDROID_API_10_VERSION}-linux android-sdk-linux_x86/platforms android-10
    repackSDK android-${ANDROID_API_10_VERSION}-linux android-${ANDROID_API_10_VERSION}-macosx android-sdk-mac_x86/platforms android-10
    repackSDK android-${ANDROID_API_10_VERSION}-linux android-${ANDROID_API_10_VERSION}-windows android-sdk-windows/platforms android-10

    # repack api-11
    repackSDK android-${ANDROID_API_11_VERSION}-linux android-${ANDROID_API_11_VERSION}-linux android-sdk-linux_x86/platforms android-11
    repackSDK android-${ANDROID_API_11_VERSION}-linux android-${ANDROID_API_11_VERSION}-macosx android-sdk-mac_x86/platforms android-11
    repackSDK android-${ANDROID_API_11_VERSION}-linux android-${ANDROID_API_11_VERSION}-windows android-sdk-windows/platforms android-11
}

function patchQtFiles
{
    echo "bin/qmake$EXE_EXT" >files_to_patch
    echo "bin/lrelease$EXE_EXT" >>files_to_patch
    echo "%%" >>files_to_patch
    find . -name *.pc >>files_to_patch
    find . -name *.la >>files_to_patch
    find . -name *.prl >>files_to_patch
    find . -name *.prf >>files_to_patch
    if [ "$OSTYPE" = "msys" ] ; then
        cp -a $SHARED_QT_PATH/bin/*.dll ../qt-src/
    fi
    echo files_to_patch > qpatch.cmdline
    echo /data/data/eu.licentia.necessitas.ministro/files/qt >> qpatch.cmdline
    echo $PWD >> qpatch.cmdline
    echo . >> qpatch.cmdline
    $QPATCH_PATH @qpatch.cmdline
}

function packSource
{
    package_name=${1//-/.} # replace - with .
    rm -fr $TEMP_PATH/source_temp_path
    mkdir -p $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION
    mv $1/.git .
    if [ $1 = "qt-src" ]
    then
        mv $1/src/3rdparty/webkit .
        mv $1/tests .
    fi
    mv $1 $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION/
    pushd $TEMP_PATH/source_temp_path
    $SDK_TOOLS_PATH/archivegen Android $1.7z
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.$package_name/data
    mv $1.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.$package_name/data/$1.7z
    popd
    mv $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION/$1 .
    mv .git $1/
    if [ $1 = "qt-src" ]
    then
        mv webkit $1/src/3rdparty/
        mv tests $1/
    fi
    rm -fr $TEMP_PATH/source_temp_path
}

function compileNecessitasQt
{
    if [ ! -f all_done ]
    then
        git checkout testing
        ../qt-src/androidconfigbuild.sh -c 1 -q 1 -n $TEMP_PATH/android-ndk-r5b -a $1 -k 0 -i /data/data/eu.licentia.necessitas.ministro/files/qt || error_msg "Can't configure android-qt"
        echo "all done">all_done
    fi

    package_name=${1//-/_} # replace - with _

    if [ $package_name = "armeabi_v7a" ]
    then
        doSed $"s/= armeabi/= armeabi-v7a/g" mkspecs/android-g++/qmake.conf
# On next release
#        doSed $"s/= android-4/= android-5/g" mkspecs/android-g++/qmake.conf
    else
        doSed $"s/= armeabi-v7a/= armeabi/g" mkspecs/android-g++/qmake.conf
# On next release
#        doSed $"s/= android-5/= android-4/g" mkspecs/android-g++/qmake.conf
    fi

    rm -fr data
    export INSTALL_ROOT=$PWD
    make install
    mkdir -p $2/$1
    mv data/data/eu.licentia.necessitas.ministro/files/qt/bin $2/$1
    if [ "$OSTYPE" = "msys" ]; then
        cp -a /usr/bin/libgcc_s_dw2-1.dll $2/$1/bin/
        cp -a /usr/bin/libstdc++-6.dll $2/$1/bin/
    fi
    $SDK_TOOLS_PATH/archivegen Android qt-tools-${HOST_TAG}.7z
    rm -fr $2/$1/bin
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data
    mv qt-tools-${HOST_TAG}.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-tools-${HOST_TAG}.7z
    mv data/data/eu.licentia.necessitas.ministro/files/qt/* $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-framework.7z
    mv qt-framework.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-framework.7z
    patchQtFiles
}


function prepareNecessitasQt
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION
    pushd Android/Qt/$NECESSITAS_QT_VERSION

    if [ ! -d qt-src ]
    then
        git clone git://anongit.kde.org/android-qt.git qt-src|| error_msg "Can't clone android-qt"
        pushd qt-src
        git checkout experimental
        popd
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi/data/qt-tools-${HOST_TAG}.7z ]
    then
        mkdir build-armeabi
        pushd build-armeabi
        compileNecessitasQt armeabi Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-armeabi
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi_v7a/data/qt-tools-${HOST_TAG}.7z ]
    then
        mkdir build-armeabi-v7a
        pushd build-armeabi-v7a
        compileNecessitasQt armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-armeabi-v7a
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data/qt-src.7z ]
    then
        packSource qt-src
    fi

    popd #Android/Qt/$NECESSITAS_QT_VERSION
}

function compileNecessitasQtMobility
{
    export ANDROID_TARGET_ARCH=$1
    if [ ! -f all_done ]
    then
        pushd ../qtmobility-src
        git checkout master
        popd
        ../qtmobility-src/configure -prefix /data/data/eu.licentia.necessitas.ministro/files/qt -staticconfig android -qmake-exec ../build-$1/bin/qmake -modules "bearer location contacts multimedia versit messaging systeminfo serviceframework sensors gallery organizer feedback connectivity" || error_msg "Can't configure android-qtmobility"
        doMake "Can't compile android-qtmobility" "all done"
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr data
    rm -fr $2
    export INSTALL_ROOT=$PWD
    make install
    mkdir -p $2/$1
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.$package_name/data
    mv data/data/eu.licentia.necessitas.ministro/files/qt/* $2/$1
    cp -a $PWD/$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$1/* $2/$1
    rm -fr $PWD/$TEMP_PATH
    $SDK_TOOLS_PATH/archivegen Android qtmobility.7z
    mv qtmobility.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.$package_name/data/qtmobility.7z
    cp -a $2/$1/* ../build-$1
    pushd ../build-$1
    patchQtFiles
    popd
}


function prepareNecessitasQtMobility
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION
    pushd Android/Qt/$NECESSITAS_QT_VERSION

    if [ ! -d qtmobility-src ]
    then
        git clone git://anongit.kde.org/android-qt-mobility.git qtmobility-src || error_msg "Can't clone android-qt-mobility"
        pushd qtmobility-src
        git checkout testing
        popd
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi/data/qtmobility.7z ]
    then
        mkdir build-mobility-armeabi
        pushd build-mobility-armeabi
        compileNecessitasQtMobility armeabi Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-mobility-armeabi
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/qtmobility.7z ]
    then
        mkdir build-mobility-armeabi-v7a
        pushd build-mobility-armeabi-v7a
        compileNecessitasQtMobility armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-mobility-armeabi-v7a
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.src/data/qtmobility-src.7z ]
    then
        packSource qtmobility-src
    fi
    popd #Android/Qt/$NECESSITAS_QT_VERSION
}

function compileNecessitasQtWebkit
{
    export ANDROID_TARGET_ARCH=$1
    export SQLITE3SRCDIR=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/qt-src/src/3rdparty/sqlite
    if [ ! -f all_done ]
    then
        if [ "$OSTYPE" = "msys" ] ; then
            if [ ! -f `which gprof` ] ; then
                downloadIfNotExists gperf-3.0.4.tar.gz http://ftp.gnu.org/pub/gnu/gperf/gperf-3.0.4.tar.gz
                rm -rf gperf-3.0.4
                tar -xzvf gperf-3.0.4.tar.gz
                pushd gperf-3.0.4
                CFLAGS=-O2 LDFLAGS="-enable-auto-import" && ./configure --enable-static --disable-shared --prefix=/usr CFLAGS=-O2 LDFLAGS="-enable-auto-import"
                make && make install
                popd
            fi
            downloadIfNotExists strawberry-perl-5.12.2.0.msi http://strawberryperl.com/download/5.12.2.0/strawberry-perl-5.12.2.0.msi
            if [ ! -f /${SYSTEMDRIVE:0:1}/strawberry/perl/bin/perl.exe ]; then
                msiexec //i strawberry-perl-5.12.2.0.msi //q
            fi
            if [ "`which perl`" != "/${SYSTEMDRIVE:0:1}/strawberry/perl/bin/perl.exe" ]; then
                export PATH=/${SYSTEMDRIVE:0:1}/strawberry/perl/bin:$PATH
            fi
            if [ "`which perl`" != "/${SYSTEMDRIVE:0:1}/strawberry/perl/bin/perl.exe" ]; then
                error_msg "Not using the correct perl"
            fi
        fi
        export WEBKITOUTPUTDIR=$PWD
        echo "doing perl"
        ../qtwebkit-src/WebKitTools/Scripts/build-webkit --qt --makeargs="-j$JOBS" --qmake=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$1/bin/qmake$EXE_EXT --no-video --no-xslt || error_msg "Can't configure android-qtwebkit"
        echo "all done">all_done
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr $PWD/$TEMP_PATH
    pushd Release
    export INSTALL_ROOT=$PWD/../
    make install
    popd
    rm -fr $2
    mkdir -p $2/$1
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.$package_name/data
    mv $PWD/$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$1/* $2/$1
    pushd $2/$1
    qt_build_path=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$1
    qt_build_path=${qt_build_path//\//\\\/}
    sed_cmd="s/$qt_build_path/\/data\/data\/eu.licentia.necessitas.ministro\/files\/qt/g"
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
        find . -name *.pc | xargs sed -i '.bak' $sed_cmd
        find . -name *.pc.bak | xargs rm -f
    else
        find . -name *.pc | xargs sed $sed_cmd -i
    fi
    popd
    rm -fr $PWD/$TEMP_PATH
    $SDK_TOOLS_PATH/archivegen Android qtwebkit.7z
    mv qtwebkit.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.$package_name/data/qtwebkit.7z
    cp -a $2/$1/* ../build-$1/
    pushd ../build-$1
    patchQtFiles
    popd
}

function prepareNecessitasQtWebkit
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION
    pushd Android/Qt/$NECESSITAS_QT_VERSION

    if [ ! -d qtwebkit-src ]
    then
        git clone git://gitorious.org/~taipan/webkit/android-qtwebkit.git qtwebkit-src || error_msg "Can't clone android-qtwebkit"
        pushd qtwebkit-src
        git checkout stable
        popd
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi/data/qtwebkit.7z ]
    then
        mkdir build-webkit-armeabi
        pushd build-webkit-armeabi
        compileNecessitasQtWebkit armeabi Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-webkit-armeabi
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/qtwebkit.7z ]
    then
        mkdir build-webkit-armeabi-v7a
        pushd build-webkit-armeabi-v7a
        compileNecessitasQtWebkit armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-webkit-armeabi-v7a
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.src/data/qtwebkit-src.7z ]
    then
        packSource qtwebkit-src
    fi
    popd #Android/Qt/$NECESSITAS_QT_VERSION
}

function patchPackages
{
    pushd $REPO_SRC_PATH/packages
        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
            find . -name *.qs | xargs sed -i '.bak' "s/@@COMPACT_VERSION@@/$NECESSITAS_QT_VERSION/g"
            find . -name *.qs.bak | xargs rm -f
            find . -name *.qs | xargs sed -i '.bak' "s/@@VERSION@@/$NECESSITAS_QT_VERSION_LONG/g"
            find . -name *.qs.bak | xargs rm -f
        else
            find . -name *.qs | xargs sed "s/@@COMPACT_VERSION@@/$NECESSITAS_QT_VERSION/g" -i
            find . -name *.qs | xargs sed "s/@@VERSION@@/$NECESSITAS_QT_VERSION_LONG/g" -i
        fi
    popd
}

function revertPatchPackages
{
    pushd $REPO_SRC_PATH/packages
        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
            find . -name *.qs | xargs sed -i '.bak' "s/$NECESSITAS_QT_VERSION/@@COMPACT_VERSION@@/g"
            find . -name *.qs.bak | xargs rm -f
            find . -name *.qs | xargs sed -i '.bak' "s/$NECESSITAS_QT_VERSION_LONG/@@VERSION@@/g"
            find . -name *.qs.bak | xargs rm -f
        else
            find . -name *.qs | xargs sed "s/$NECESSITAS_QT_VERSION/@@COMPACT_VERSION@@/g" -i
            find . -name *.qs | xargs sed "s/$NECESSITAS_QT_VERSION_LONG/@@VERSION@@/g" -i
        fi
    popd
}

function prepareSDKBinary
{
    echo $SDK_TOOLS_PATH/binarycreator -v -t $SDK_TOOLS_PATH/installerbase$EXE_EXT -c $REPO_SRC_PATH/config -p $REPO_SRC_PATH/packages -n $REPO_SRC_PATH/necessitas-sdk-installer$EXE_EXT org.kde.necessitas
    $SDK_TOOLS_PATH/binarycreator -v -t $SDK_TOOLS_PATH/installerbase$EXE_EXT -c $REPO_SRC_PATH/config -p $REPO_SRC_PATH/packages -n $REPO_SRC_PATH/necessitas-sdk-installer$EXE_EXT org.kde.necessitas
}

function prepareSDKRepository
{
    rm -fr $REPO_PATH
    $SDK_TOOLS_PATH/repogen -v  -p $REPO_SRC_PATH/packages -c $REPO_SRC_PATH/config $REPO_PATH org.kde.necessitas
}

function prepareMinistroRepository
{
    pushd $REPO_SRC_PATH/ministrorepogen
    if [ ! -f all_done ]
    then
        $STATIC_QT_PATH/bin/qmake -r || error_msg "Can't configure ministrorepogen"
        doMake "Can't compile ministrorepogen" "all done"
    fi
    popd
    for architecture in armeabi armeabi-v7a
    do
        rm -fr $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION
        mkdir -p $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION
        pushd $TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$architecture
        rm -fr Android
        for lib in `find . -name *.so`
        do
            libDirname=`dirname $lib`
            mkdir -p $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$libDirname
            cp $lib $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$libDirname/
            $ANDROID_STRIP_BINARY --strip-unneeded $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$lib
        done

        for qmldirfile in `find . -name qmldir`
        do
            qmldirfileDirname=`dirname $qmldirfile`
            cp $qmldirfile $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$qmldirfileDirname/
        done

        if [ "$OSTYPE" = "msys" ] ; then
            cp $REPO_SRC_PATH/ministrorepogen/release/ministrorepogen$EXE_EXT $REPO_SRC_PATH/ministrorepogen/ministrorepogen$EXE_EXT
        fi
        $REPO_SRC_PATH/ministrorepogen/ministrorepogen$EXE_EXT $ANDROID_READELF_BINARY $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION $MINISTRO_VERSION $architecture $REPO_SRC_PATH/ministrorepogen/rules.xml $MINISTRO_REPO_PATH
        popd
    done
}

function packforWindows
{
    rm -fr $TEMP_PATH/packforWindows
    mkdir -p $TEMP_PATH/packforWindows
    pushd $TEMP_PATH/packforWindows
        7z x $1/$2.7z
        mv Android Android_old
        $CPRL Android_old Android
        rm -fr Android_old
        find -name *.so.4* | xargs rm -fr
        find -name *.so.1* | xargs rm -fr
        $SDK_TOOLS_PATH/archivegen Android $1/$2-windows.7z
    popd
    rm -fr $TEMP_PATH/packforWindows
}

function prepareWindowsPackages
{
    #  Qt framework
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi/data/qt-framework-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi/data/ qt-framework
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi_v7a/data/qt-framework-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi_v7a/data/ qt-framework
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data/qt-src-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data/ qt-src
    fi


    #  Qt Mobility
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi/data/qtmobility-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi/data/ qtmobility
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/qtmobility-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/ qtmobility
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.src/data/qtmobility-src-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtmobility.src/data/ qtmobility-src
    fi


    #  Qt WebKit
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi/data/qtwebkit-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi/data/ qtwebkit
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/qtwebkit-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/ qtwebkit
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.src/data/qtwebkit-src-windows.7z ]
    then
        packforWindows $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.src/data/ qtwebkit-src
    fi

}
# This is needed early.
SDK_TOOLS_PATH=$PWD/necessitas-installer-framework/installerbuilder/bin

prepareHostQt
prepareSdkInstallerTools
prepareNDKs
prepareGDB
prepareGDBServer
prepareSDKs
prepareNecessitasQtCreator
prepareNecessitasQt
# TODO :: Fix webkit build in Windows (-no-video fails) and Mac OS X (debug-and-release config incorrectly used and fails)
if [ "$OSTYPE" = "linux-gnu" ] ; then
    prepareNecessitasQtWebkit
fi
prepareNecessitasQtMobility

if [ "$OSTYPE" = "linux-gnu" ] ; then
    prepareWindowsPackages
fi

patchPackages
prepareSDKBinary
prepareSDKRepository
revertPatchPackages
prepareMinistroRepository

popd

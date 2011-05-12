#!/bin/bash

# Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>
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


REPO_SRC_PATH=$PWD
TEMP_PATH_PREFIX=/var
if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
    pushd ~ >/dev/null
    TEMP_PATH_PREFIX=$PWD
    popd
else
    if [ "$OSTYPE" = "msys"  ]; then
        TEMP_PATH_PREFIX=/usr
    fi
fi

TEMP_PATH=$TEMP_PATH_PREFIX/necessitas
mkdir -p $TEMP_PATH
pushd $TEMP_PATH

NECESSITAS_QT_VERSION=4762
NECESSITAS_QT_VERSION_LONG="4.7.62"
MINISTRO_VERSION="0.2"
MINISTRO_REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/qt
REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/sdk
HOST_QT_VERSION=qt-everywhere-opensource-src-4.7.2
STATIC_QT_PATH=""
SHARED_QT_PATH=""
SDK_TOOLS_PATH=""
ANDROID_STRIP_BINARY=""
ANDROID_READELF_BINARY=""
QPATCH_PATH=""

if [ "$OSTYPE" = "msys" ] ; then
    HOST_CFG_OPTIONS=" -platform win32-g++ -reduce-exports "
    HOST_TAG=windows-x86
    HOST_TAG_NDK=windows
    EXE_EXT=.exe
    JOBS=9
else
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        HOST_CFG_OPTIONS=" -platform macx-g++42 -sdk /Developer/SDKs/MacOSX10.5.sdk -arch i386 -arch x86_64 -cocoa "
        # -reduce-exports doesn't work for static Mac OS X i386 build.
        # (ld: bad codegen, pointer diff in fulltextsearch::clucene::QHelpSearchIndexReaderClucene::run()     to global weak symbol vtable for QtSharedPointer::ExternalRefCountDatafor architecture i386)
        HOST_CFG_OPTIONS_STATIC=" -no-reduce-exports "
        HOST_TAG=darwin-x86
        HOST_TAG_NDK=darwin-x86
        JOBS=9
    else
        HOST_CFG_OPTIONS=" -platform linux-g++ "
        HOST_TAG=linux-x86
        HOST_TAG_NDK=linux-x86
        JOBS=4
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
        wget $2 || removeAndExit $1
    fi
}

function doMake
{
    if [ "$OSTYPE" = "msys" -o  "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        if [ "$OSTYPE" = "msys" ] ; then
            MAKEDIR=`pwd -W`
        else
            MAKEDIR=`pwd`
        fi
        MAKEFILE=$MAKEDIR/Makefile
        make -f $MAKEFILE -j$JOBS
        while [ "$?" != "0" ]
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
        # Get a more recent sed, one that can do -i.
        downloadIfNotExists sed-4.2.1-2-msys-1.0.13-bin.tar.lzma http://downloads.sourceforge.net/project/mingw/MSYS/BaseSystem/sed/sed-4.2.1-2/sed-4.2.1-2-msys-1.0.13-bin.tar.lzma
        rm -rf sed-4.2.1-2-msys-1.0.13-bin.tar
        rm /usr/bin/sed.exe
        7za x sed-4.2.1-2-msys-1.0.13-bin.tar.lzma
        tar -xvf sed-4.2.1-2-msys-1.0.13-bin.tar
        mv bin/sed.exe /usr/bin

        # download, compile & install zlib to /usr
        downloadIfNotExists zlib-1.2.5.tar.gz http://downloads.sourceforge.net/libpng/zlib/1.2.5/zlib-1.2.5.tar.gz
        tar -xvzf zlib-1.2.5.tar.gz
        cd zlib-1.2.5
        doSed $"s/usr\/local/usr/" win32/Makefile.gcc
        make -f win32/Makefile.gcc
        export INCLUDE_PATH=/usr/include && export LIBRARY_PATH=/usr/lib && make -f win32/Makefile.gcc install
        rm -rf zlib-1.2.5
        cd ..
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
            tar xvfz $HOST_QT_VERSION.tar.gz || error_msg "Can't untar $HOST_QT_VERSION.tar.gz"
        fi
    fi

    #build qt statically, needed by Sdk installer
    mkdir build-$HOST_QT_VERSION-static
    pushd build-$HOST_QT_VERSION-static
    STATIC_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
	rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -developer-build -static -no-webkit -no-phonon -no-dbus -no-opengl -no-qt3support -no-xmlpatterns -no-svg -release -qt-sql-sqlite -plugin-sql-sqlite -confirm-license $HOST_CFG_OPTIONS $HOST_CFG_OPTIONS_STATIC -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        doMake "Can't compile static $HOST_QT_VERSION" "all done"
    fi
    popd

    #build qt shared, needed by QtCreator
    mkdir build-$HOST_QT_VERSION-shared
    pushd build-$HOST_QT_VERSION-shared
    SHARED_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -developer-build -shared -webkit -no-phonon -release -qt-sql-sqlite -plugin-sql-sqlite -no-qt3support -confirm-license $HOST_CFG_OPTIONS -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        doMake "Can't compile shared $HOST_QT_VERSION" "all done"
        if [ "$OSTYPE" = "msys" ]; then
            # Horrible; need to fix this properly.
            doSed $"s/qt warn_on release /qt shared warn_on release /" mkspecs/win32-g++/qmake.conf
        fi
    fi
    popd

}

function perpareSdkInstallerTools
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
        $STATIC_QT_PATH/bin/qmake -r || error_msg "Can't configure necessitas-installer-framework"
        doMake "Can't compile necessitas-installer-framework" "all done"
    fi
    popd
}


function perpareNecessitasQtCreator
{
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}.7z ]
    then
        if [ ! -d android-qt-creator ]
        then
            git clone git://anongit.kde.org/android-qt-creator.git android-qt-creator || error_msg "Can't clone android-qt-creator"
        fi

        pushd android-qt-creator

        if [ ! -f all_done ]
        then
            git checkout testing
            $SHARED_QT_PATH/bin/qmake -r || error_msg "Can't configure android-qt-creator"
            doMake "Can't compile android-qt-creator" "all done"
        fi
        rm -fr QtCreator
        export INSTALL_ROOT=$PWD/QtCreator && make install
        mkdir -p $PWD/QtCreator/Qt/lib
        mkdir -p $PWD/QtCreator/Qt/imports
        cp -a $SHARED_QT_PATH/lib/* $PWD/QtCreator/Qt/lib/
        rm -fr $PWD/QtCreator/Qt/lib/pkgconfig
        find . $PWD/QtCreator/Qt -name *.la | xargs rm -fr
        find . $PWD/QtCreator/Qt -name *.prl | xargs rm -fr
        cp -a $SHARED_QT_PATH/imports/* $PWD/QtCreator/Qt/imports/
        cp -a bin/necessitas$EXE_EXT $PWD/QtCreator/bin/
        mkdir $PWD/QtCreator/images
        cp -a bin/necessitas*.png $PWD/QtCreator/images/
        $SDK_TOOLS_PATH/archivegen QtCreator qtcreator-${HOST_TAG}.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data
        mv qtcreator-${HOST_TAG}.7z $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}.7z
        popd
    fi

    mkdir qpatch-build
    pushd qpatch-build
    if [ ! -f all_done ]
    then
        $STATIC_QT_PATH/bin/qmake "QT_CONFIG=release" -r ../android-qt-creator/src/tools/qpatch/qpatch.pro
        if [ "$OSTYPE" = "msys" ]; then
            make -f Makefile.Release || error_msg "Can't compile qpatch"
        else
            make || error_msg "Can't compile qpatch"
        fi
        echo "all_done">all_done
    fi

    if [ "$OSTYPE" = "msys" ]; then
        QPATCH_PATH=$PWD/release/qpatch${EXE_EXT}
    else
        QPATCH_PATH=$PWD/qpatch
    fi
    popd
}


function perpareNDKs
{
    # repack windows NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z ]
    then
        downloadIfNotExists android-ndk-r5b-windows.zip http://dl.google.com/android/ndk/android-ndk-r5b-windows.zip
        if [ ! -d android-ndk-r5b ]
        then
            unzip android-ndk-r5b-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-windows.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data
        mv android-ndk-r5b-windows.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z
        rm -fr android-ndk-r5b
    fi

    # repack mac NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z ]
    then
        downloadIfNotExists android-ndk-r5b-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-darwin-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xjvf android-ndk-r5b-darwin-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-darwin-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data
        mv android-ndk-r5b-darwin-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z
        rm -fr android-ndk-r5b
    fi

    # repack linux-x86 NDK, it must be the last one because we need it to build qt
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z ]
    then
        downloadIfNotExists android-ndk-r5b-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-linux-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xjvf android-ndk-r5b-linux-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-linux-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data
        mv android-ndk-r5b-linux-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z
        rm -fr android-ndk-r5b
    fi

    export ANDROID_NDK_ROOT=$PWD/android-ndk-r5b
    if [ ! -d android-ndk-r5b ]; then

        if [ "$OSTYPE" = "msys" ]; then
            unzip android-ndk-r5b-windows.zip
        fi

        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
            tar xjvf android-ndk-r5b-darwin-x86.tar.bz2
        fi

        if [ "$OSTYPE" = "linux-gnu" ]; then
            tar xjvf android-ndk-r5b-linux-x86.tar.bz2
        fi
    fi

    ANDROID_STRIP_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-strip$EXE_EXT
    ANDROID_READELF_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-readelf$EXE_EXT

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


function perpareSDKs
{
    echo "prepare SDKs"
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z ]
    then
        downloadIfNotExists android-sdk_r10-linux_x86.tgz http://dl.google.com/android/android-sdk_r10-linux_x86.tgz
        if [ ! -d android-sdk-linux_x86 ]
        then
            tar xvfa android-sdk_r10-linux_x86.tgz
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-linux_x86 android-sdk_r10-linux_x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_r10-linux_x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z
        rm -fr android-sdk-linux_x86
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z ]
    then
        downloadIfNotExists android-sdk_r10-mac_x86.zip http://dl.google.com/android/android-sdk_r10-mac_x86.zip
        if [ ! -d android-sdk-mac_x86 ]
        then
            unzip android-sdk_r10-mac_x86.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-mac_x86 android-sdk_r10-mac_x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_r10-mac_x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z
        rm -fr android-sdk-mac_x86
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z ]
    then
        downloadIfNotExists android-sdk_r10-windows.zip http://dl.google.com/android/android-sdk_r10-windows.zip
        if [ ! -d android-sdk-windows ]
        then
            unzip android-sdk_r10-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-windows android-sdk_r10-windows.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_r10-windows.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z
        rm -fr android-sdk-windows
    fi

    # repack platform-tools
    repackSDK platform-tools_r03-linux platform-tools_r03-linux android-sdk-linux_x86 platform-tools
    repackSDK platform-tools_r03-macosx platform-tools_r03-macosx android-sdk-mac_x86 platform-tools
    # should we also include ant binary for windows ?
    repackSDK platform-tools_r03-windows platform-tools_r03-windows android-sdk-windows platform-tools

    # repack api-4
    repackSDK android-1.6_r03-linux android-1.6_r03-linux android-sdk-linux_x86/platforms android-4
    repackSDK android-1.6_r03-macosx android-1.6_r03-macosx android-sdk-mac_x86/platforms android-4
    repackSDK android-1.6_r03-windows android-1.6_r03-windows android-sdk-windows/platforms android-4

    # repack api-5
    repackSDK android-2.0_r01-linux android-2.0_r01-linux android-sdk-linux_x86/platforms android-5
    repackSDK android-2.0_r01-macosx android-2.0_r01-macosx android-sdk-mac_x86/platforms android-5
    repackSDK android-2.0_r01-windows android-2.0_r01-windows android-sdk-windows/platforms android-5

    # repack api-6
    repackSDK android-2.0.1_r01-linux  android-2.0.1_r01-linux  android-sdk-linux_x86/platforms android-6
    repackSDK android-2.0.1_r01-macosx android-2.0.1_r01-macosx android-sdk-mac_x86/platforms android-6
    repackSDK android-2.0.1_r01-windows android-2.0.1_r01-windows android-sdk-windows/platforms android-6

    # repack api-7
    repackSDK android-2.1_r02-linux android-2.1_r02-linux android-sdk-linux_x86/platforms android-7
    repackSDK android-2.1_r02-macosx android-2.1_r02-macosx android-sdk-mac_x86/platforms android-7
    repackSDK android-2.1_r02-windows android-2.1_r02-windows android-sdk-windows/platforms android-7

    # repack api-8
    repackSDK android-2.2_r02-linux android-2.2_r02-linux android-sdk-linux_x86/platforms android-8
    repackSDK android-2.2_r02-macosx android-2.2_r02-macosx android-sdk-mac_x86/platforms android-8
    repackSDK android-2.2_r02-windows android-2.2_r02-windows android-sdk-windows/platforms android-8

    # repack api-9
    repackSDK android-2.3.1_r02-linux android-2.3.1_r02-linux android-sdk-linux_x86/platforms android-9
    repackSDK android-2.3.1_r02-linux android-2.3.1_r02-macosx android-sdk-mac_x86/platforms android-9
    repackSDK android-2.3.1_r02-linux android-2.3.1_r02-windows android-sdk-windows/platforms android-9

    # repack api-10
    repackSDK android-2.3.3_r01-linux android-2.3.3_r01-linux android-sdk-linux_x86/platforms android-10
    repackSDK android-2.3.3_r01-linux android-2.3.3_r01-macosx android-sdk-mac_x86/platforms android-10
    repackSDK android-2.3.3_r01-linux android-2.3.3_r01-windows android-sdk-windows/platforms android-10

    # repack api-11
    repackSDK android-3.0_r01-linux android-3.0_r01-linux android-sdk-linux_x86/platforms android-11
    repackSDK android-3.0_r01-linux android-3.0_r01-macosx android-sdk-mac_x86/platforms android-11
    repackSDK android-3.0_r01-linux android-3.0_r01-windows android-sdk-windows/platforms android-11
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
    fi
    rm -fr $TEMP_PATH/source_temp_path
}

function compileNecessitasQt
{
    if [ ! -f all_done ]
    then
        git checkout testing
        ../qt-src/androidconfigbuild.sh -c 1 -q 1 -n $TEMP_PATH/android-ndk-r5b -a $1 -k 1 -i /data/data/eu.licentia.necessitas.ministro/files/qt || error_msg "Can't configure android-qt"
        echo "all done">all_done
    fi

    package_name=${1//-/_} # replace - with _

    if [ $package_name = "armeabi_v7a" ]
    then
        doSed $"s/= armeabi/= armeabi-v7a/g" mkspecs/android-g++/qmake.conf
    else
        doSed $"s/= armeabi-v7a/= armeabi/g" mkspecs/android-g++/qmake.conf
    fi

    rm -fr data
    export INSTALL_ROOT=$PWD && make install
    mkdir -p $2/$1
    mv data/data/eu.licentia.necessitas.ministro/files/qt/bin $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-tools-${HOST_TAG}.7z
    rm -fr $2/$1/bin
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data
    mv qt-tools-${HOST_TAG}.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-tools-${HOST_TAG}.7z
    mv data/data/eu.licentia.necessitas.ministro/files/qt/* $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-farmework.7z
    mv qt-farmework.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-farmework.7z
    patchQtFiles
}


function perpareNecessitasQt
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION
    pushd Android/Qt/$NECESSITAS_QT_VERSION

    if [ ! -d qt-src ]
    then
        git clone git://anongit.kde.org/android-qt.git qt-src|| error_msg "Can't clone android-qt"
        pushd qt-src
        git checkout testing
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
        git checkout testing
#        ../qtmobility-src/configure -prefix /data/data/eu.licentia.necessitas.ministro/files/qt -qmake-exec ../build-$1/bin/qmake -modules "bearer contacts gallery location messaging multimedia systeminfo sensors versit organizer feedback" || error_msg "Can't configure android-qtmobility"
        ../qtmobility-src/configure -prefix /data/data/eu.licentia.necessitas.ministro/files/qt -qmake-exec ../build-$1/bin/qmake -modules "bearer contacts gallery location messaging systeminfo sensors versit organizer feedback" || error_msg "Can't configure android-qtmobility"
        doMake "Can't compile android-qtmobility" "all done"
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr data
    rm -fr $2
    export INSTALL_ROOT=$PWD && make install
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


function perpareNecessitasQtMobility
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
        git checkout stable
        WEBKITOUTPUTDIR=$PWD ../qtwebkit-src/Tools/Scripts/build-webkit --qt --prefix=/data/data/eu.licentia.necessitas.ministro/files/qt --makeargs="-j$JOBS" --qmake=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION/build-$1/bin/qmake || error_msg "Can't configure android-qtwebkit"
        echo "all done">all_done
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr data
    pushd Release
    export INSTALL_ROOT=$PWD/../ && make install
    popd
    rm -fr $2
    mkdir -p $2/$1
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qtwebkit.$package_name/data
    mv data/data/eu.licentia.necessitas.ministro/files/qt/* $2/$1
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

function perpareNecessitasQtWebkit
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
    $SDK_TOOLS_PATH/binarycreator -v -t $SDK_TOOLS_PATH/installerbase -c $REPO_SRC_PATH/config -p $REPO_SRC_PATH/packages -n $REPO_SRC_PATH/necessitas-sdk-installer org.kde.necessitas
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
        for lib in `find -name *.so`
        do
            libDirname=`dirname $lib`
            mkdir -p $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$libDirname
            cp $lib $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$libDirname/
            $ANDROID_STRIP_BINARY --strip-unneeded $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$lib
        done

        for qmldirfile in `find -name qmldir`
        do
            qmldirfileDirname=`dirname $qmldirfile`
            cp $qmldirfile $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/$qmldirfileDirname/
        done

        $REPO_SRC_PATH/ministrorepogen/ministrorepogen $ANDROID_READELF_BINARY $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION/ $MINISTRO_VERSION $architecture $REPO_SRC_PATH/ministrorepogen/rules.xml $MINISTRO_REPO_PATH
        popd
    done
}

# This is needed early.
SDK_TOOLS_PATH=$PWD/necessitas-installer-framework/installerbuilder/bin

prepareHostQt
perpareSdkInstallerTools
perpareNDKs
perpareSDKs
perpareNecessitasQtCreator
perpareNecessitasQt
perpareNecessitasQtWebkit
perpareNecessitasQtMobility
# Want to be able to do this on all hosts.
#if [ "$OSTYPE" = "linux-gnu" ]; then
    prepareMinistroRepository
#    echo $OSTYPE
#fi
patchPackages
prepareSDKBinary
prepareSDKRepository
revertPatchPackages

popd

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

while getopts "h:c:" arg; do
case $arg in
    h)
        help
        exit 0
        ;;
    c)
        CHECKOUT_BRANCH=$OPTARG
        ;;
    ?)
        help
        exit 0
        ;;
esac
done

REPO_SRC_PATH=$PWD
TODAY=`date +%Y-%m-%d`

if [ "$OSTYPE" = "linux-gnu" ] ; then
    TEMP_PATH_PREFIX=/tmp
    TEMP_PATH=$TEMP_PATH_PREFIX/necessitas
else
    TEMP_PATH_PREFIX=/usr
    TEMP_PATH=$TEMP_PATH_PREFIX/nec
fi

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

# Global just because 2 functions use them, only acceptable values for GDB_VER are 7.2 and 7.3
#GDB_VER=7.3
GDB_VER=7.2

pushd $TEMP_PATH

MINISTRO_REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/qt
REPO_PATH=$TEMP_PATH_PREFIX/www/necessitas/sdk
REPO_PATH_PACKAGES=$REPO_SRC_PATH/packages
# TODO :: Ask BogDan what this was here for
# cp -a $REPO_PATH_PACKAGES $TEMP_PATH_PREFIX/www/necessitas/sdk_src
STATIC_QT_PATH=""
SHARED_QT_PATH=""
SDK_TOOLS_PATH=""
ANDROID_STRIP_BINARY=""
ANDROID_READELF_BINARY=""
#QPATCH_PATH=""
EXE_EXT=""
export PYTHONHOME=""

if [ "$OSTYPE" = "msys" ] ; then
    # -tools-fully-static
    HOST_CFG_OPTIONS=" -platform win32-g++ -reduce-exports -ms-bitfields -prefix . "
    HOST_QM_CFG_OPTIONS="CONFIG+=ms_bitfields CONFIG+=static_gcclibs"
    HOST_TAG=windows
    HOST_TAG_NDK=windows
    EXE_EXT=.exe
    SHLIB_EXT=.dll
    SCRIPT_EXT=.bat
    JOBS=`expr $NUMBER_OF_PROCESSORS + 2`
else
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        HOST_CFG_OPTIONS=" -platform macx-g++42 -sdk /Developer/SDKs/MacOSX10.5.sdk -arch i386 -arch x86_64 -cocoa -prefix . "
        HOST_QM_CFG_OPTIONS="CONFIG+=x86 CONFIG+=x86_64"
        # -reduce-exports doesn't work for static Mac OS X i386 build.
        # (ld: bad codegen, pointer diff in fulltextsearch::clucene::QHelpSearchIndexReaderClucene::run()     to global weak symbol vtable for QtSharedPointer::ExternalRefCountDatafor architecture i386)
        HOST_CFG_OPTIONS_STATIC=" -no-reduce-exports "
        HOST_TAG=darwin-x86
        HOST_TAG_NDK=darwin-x86
        SHLIB_EXT=.dylib
        JOBS=`sysctl -n hw.ncpu`
        JOBS=`expr $JOBS + 2`
    else
        HOST_CFG_OPTIONS=" -platform linux-g++ "
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
	    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
            curl --insecure -S -L -O $2 || removeAndExit $1
        else
            wget --no-check-certificate -c $2 || removeAndExit $1
        fi
    fi
}

function doMake
{
    MAKEPROG=make
    if [ "$OSTYPE" = "msys" -o  "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        if [ "$OSTYPE" = "msys" ] ; then
            MAKEDIR=`pwd -W`
            MAKEFOREVER=1
            if [ ! -z $3 ] ; then
                MAKEPROG=$3
            fi
        else
            MAKEDIR=`pwd`
            MAKEFOREVER=0
        fi
        MAKEFILE=$MAKEDIR/Makefile
        $MAKEPROG -f $MAKEFILE -j$JOBS
        while [ "$?" != "0" -a "$MAKEFOREVER" = "1" ]
        do
            if [ -f /usr/break-make ]; then
                echo "Detected break-make"
                rm -f /usr/break-make
                error_msg $1
            fi
            $MAKEPROG -f $MAKEFILE -j$JOBS
        done
        echo $2>all_done
    else
        make -j$JOBS || error_msg $1
        echo $2>all_done
    fi
}

function doMakeInstall
{
    MAKEPROG=make
    if [ "$OSTYPE" = "msys" -o  "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
        if [ "$OSTYPE" = "msys" ] ; then
            MAKEDIR=`pwd -W`
            MAKEFOREVER=1
            if [ ! -z $2 ] ; then
                MAKEPROG=$2
            fi
        else
            MAKEDIR=`pwd`
            MAKEFOREVER=0
        fi
        MAKEFILE=$MAKEDIR/Makefile
        $MAKEPROG -f $MAKEFILE install
        while [ "$?" != "0" -a "$MAKEFOREVER" = "1" ]
        do
            if [ -f /usr/break-make ]; then
                echo "Detected break-make"
                rm -f /usr/break-make
                error_msg $1
            fi
            $MAKEPROG -f $MAKEFILE install
        done
        echo $2>all_done
    else
        make install || error_msg $1
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

function downloadLighthouseSource
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    pushd Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    if [ ! -d qt-src ]
    then
        git clone git://anongit.kde.org/android-qt.git qt-src|| error_msg "Can't clone android-qt"
    fi

    pushd qt-src
        git checkout $CHECKOUT_BRANCH
        git pull
    popd
    popd # Android/Qt/$NECESSITAS_QT_VERSION_SHORT
}
# $1 is either -d (debug build) or nothing.
function prepareHostQt
{
    # download, compile & install qt, it is used to compile the installer
    HOST_QT_CONFIG=$1
    if [ ! "$HOST_QT_VERSION" = "lighthouse" ]
    then
#       if [ "$OSTYPE" = "msys" -o "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]
        if [ "1" = "1" ]
        then
            if [ ! -d $HOST_QT_SRCDIR ]
            then
                git clone git://gitorious.org/~mingwandroid/qt/mingw-android-official-qt.git $HOST_QT_SRCDIR || error_msg "Can't clone mingw qt"
                pushd $HOST_QT_SRCDIR
                if [ "$HOST_QT_BRANCH" = "4.8" ] ; then
                    # TODORMD :: Ask BogDan how to get it setup so "git checkout -b $HOST_QT_BRANCH" works for my 4.8 branch.
                    git checkout -b 4.8 refs/remotes/origin/4.8
                else
                    git checkout -b $HOST_QT_BRANCH
                fi
                popd
            fi
        else
            if [ "$OSTYPE" = "msys" ] ; then
                HOST_QT_SRC_ARCHIVE=$HOST_QT_VERSION_DL.zip
                downloadIfNotExists HOST_QT_SRC_ARCHIVE http://get.qt.nokia.com/qt/source/$HOST_QT_SRC_ARCHIVE
                if [ ! -d $HOST_QT_VERSION ]
                then
                    unzip $HOST_QT_SRC_ARCHIVE || error_msg "Can't unzip $HOST_QT_SRC_ARCHIVE"
                fi
            else
                HOST_QT_SRC_ARCHIVE=$HOST_QT_VERSION_DL.tar.gz
                downloadIfNotExists HOST_QT_SRC_ARCHIVE http://get.qt.nokia.com/qt/source/$HOST_QT_SRC_ARCHIVE
                if [ ! -d $HOST_QT_VERSION ]
                then
                    tar -xzvf $HOST_QT_SRC_ARCHIVE || error_msg "Can't untar $HOST_QT_SRC_ARCHIVE"
                fi
            fi
        fi
    else
        downloadLighthouseSource
    fi

    #build qt statically, needed by Sdk installer
    if [ "$HOST_QT_VERSION" = "lighthouse" ] ; then
        HOST_QT_SRCDIR=lighthouse
    fi
    mkdir b-$HOST_QT_SRCDIR-st$HOST_QT_CONFIG
    pushd b-$HOST_QT_SRCDIR-st$HOST_QT_CONFIG
    OPTS_CFG=" -developer-build "
    if [ "$HOST_QT_CONFIG" = "-d" ] ; then
        STATIC_QT_PATH_DEBUG=$PWD
        if [ "$OSTYPE" = "msys" ] ; then
            OPTS_CFG=" -debug "
            HOST_QT_CFG="CONFIG+=debug"
        else
            if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
                OPTS_CFG=" -debug-and-release "
                HOST_QT_CFG="CONFIG+=debug"
            fi
        fi
    else
        STATIC_QT_PATH=$PWD
        STATIC_QT_PATH_DEBUG=$PWD
        if [ "$OSTYPE" = "msys" -o "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
            OPTS_CFG=" -release "
            HOST_QT_CFG="CONFIG+=release"
        fi
    fi
    # Even on Linux, static Qt 4.8 doesn't build!
    if [ ! -f all_done ]
    then
        rm -fr *
        if [ "$HOST_QT_VERSION" = "lighthouse" ] ; then
            ../Android/Qt/4762/qt-src/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -static -no-phonon -no-dbus -no-opengl -no-qt3support -no-xmlpatterns -no-svg -qt-sql-sqlite -plugin-sql-sqlite -confirm-license $HOST_CFG_OPTIONS $HOST_CFG_OPTIONS_STATIC $OPTS_CFG -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        else
            ../$HOST_QT_SRCDIR/configure        -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -static -no-phonon -no-dbus -no-opengl -no-qt3support -no-xmlpatterns -no-svg -qt-sql-sqlite -plugin-sql-sqlite -confirm-license $HOST_CFG_OPTIONS $HOST_CFG_OPTIONS_STATIC $OPTS_CFG -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        fi
        doMake "Can't compile static $HOST_QT_VERSION" "all done" ma-make
        if [ "$OSTYPE" = "msys" ]; then
            # Horrible; need to fix this properly.
            doSed $"s/qt warn_on /qt static ms_bitfields static_gcclibs warn_on /" mkspecs/win32-g++/qmake.conf
            doSed $"s/qt warn_on /qt static ms_bitfields static_gcclibs warn_on /" mkspecs/default/qmake.conf
            cp -f mkspecs/win32-g++/qplatformdefs.h mkspecs/default/
        fi
    fi
    popd

    #build qt shared, needed by QtCreator
    mkdir b-$HOST_QT_SRCDIR-sh$HOST_QT_CONFIG
    pushd b-$HOST_QT_SRCDIR-sh$HOST_QT_CONFIG
    SHARED_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        if [ "$HOST_QT_VERSION" = "lighthouse" ] ; then
            ../Android/Qt/4762/qt-src/configure -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -shared -webkit -no-phonon -qt-sql-sqlite -plugin-sql-sqlite -no-qt3support -confirm-license $HOST_CFG_OPTIONS $OPTS_CFG -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        else
            ../$HOST_QT_SRCDIR/configure        -fast -nomake examples -nomake demos -nomake tests -system-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -shared -webkit -no-phonon -qt-sql-sqlite -plugin-sql-sqlite -no-qt3support -confirm-license $HOST_CFG_OPTIONS $OPTS_CFG -host-little-endian --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        fi
        doMake "Can't compile shared $HOST_QT_VERSION" "all done" ma-make
        if [ "$OSTYPE" = "msys" ]; then
            # Horrible; need to fix this properly.
            doSed $"s/qt warn_on /qt shared ms_bitfields static_gcclibs warn_on /" mkspecs/win32-g++/qmake.conf
            doSed $"s/qt warn_on /qt shared ms_bitfields static_gcclibs warn_on /" mkspecs/default/qmake.conf
            cp -f mkspecs/win32-g++/qplatformdefs.h mkspecs/default/
        fi
    fi
    popd
}

function prepareSdkInstallerTools
{
    # get installer source code
    SDK_TOOLS_PATH=$PWD/necessitas-installer-framework-$HOST_QT_BRANCH$HOST_QT_CONFIG/installerbuilder/bin
    if [ ! -d necessitas-installer-framework-$HOST_QT_BRANCH$HOST_QT_CONFIG ]
    then
        git clone git://gitorious.org/~taipan/qt-labs/necessitas-installer-framework.git necessitas-installer-framework-$HOST_QT_BRANCH$HOST_QT_CONFIG || error_msg "Can't clone necessitas-installer-framework"
    fi

    pushd necessitas-installer-framework-$HOST_QT_BRANCH$HOST_QT_CONFIG/installerbuilder
    git checkout $CHECKOUT_BRANCH
    git pull
    if [ ! -f all_done ]
    then
        $STATIC_QT_PATH_DEBUG/bin/qmake $HOST_QT_CFG $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure necessitas-installer-framework"
        doMake "Can't compile necessitas-installer-framework" "all done" ma-make
    fi
    popd
    pushd $SDK_TOOLS_PATH
    if [ -z $HOST_QT_CONFIG ] ; then
        $STRIP *
    fi
    popd
}


function prepareNecessitasQtCreator
{
    QTC_PATH=android-qt-creator$HOST_QT_CONFIG

    if [ ! -d $QTC_PATH ]
    then
        git clone git://anongit.kde.org/android-qt-creator.git $QTC_PATH || error_msg "Can't clone android-qt-creator"
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}${HOST_QT_CONFIG}.7z ]
    then
        pushd $QTC_PATH
        QTC_INST_PATH=$PWD/QtCreator$HOST_QT_CONFIG
        if [ ! -f all_done ] ; then
            git checkout 2.3-necessitas
            git pull
            $SHARED_QT_PATH/bin/qmake $HOST_QT_CFG $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure android-qt-creator"
            doMake "Can't compile $QTC_PATH" "all done" ma-make
        fi
        rm -fr $QTC_INST_PATH
        export INSTALL_ROOT=$QTC_INST_PATH
        make install

        #download and install sdk-updater-plugin
        export QTC_SOURCE=$PWD
        downloadIfNotExists research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz http://android-lighthouse.googlecode.com/files/research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz
        if [ ! -d research-sdk-updater-plugin-master-snapshot-20110524185306 ]
        then
            tar xvfz research-sdk-updater-plugin-master-snapshot-20110524185306.tar.gz
        fi
        pushd research-sdk-updater-plugin-master-snapshot-20110524185306
            doSed $"s/FutureProgress::DontKeepOnFinish/FutureProgress::HideOnFinish/" updateinfoplugin.cpp
            $SHARED_QT_PATH/bin/qmake $HOST_QT_CFG $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure sdk-updater-plugin"
            doMake "Can't compile sdk-updater-plugin" "all done" ma-make
            make install
        popd

        mkdir -p $QTC_INST_PATH/Qt/imports
        mkdir -p $QTC_INST_PATH/Qt/plugins
        if [ "$OSTYPE" = "msys" ]; then
            mkdir -p $QTC_INST_PATH/bin
            cp -rf lib/qtcreator/* $QTC_INST_PATH/bin/
            cp -a /usr/bin/libgcc_s_dw2-1.dll $QTC_INST_PATH/bin/
            cp -a /usr/bin/libstdc++-6.dll $QTC_INST_PATH/bin/
            QT_LIB_DEST=$QTC_INST_PATH/bin/
            cp -a $SHARED_QT_PATH/lib/* $QT_LIB_DEST
            cp -a bin/necessitas.bat $QTC_INST_PATH/bin/
# Want to re-enable this, but libintl-8.dll is getting used.
#            git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various
#            mkdir -p android-various/make-3.82-build
#            pushd android-various/make-3.82-build
#            ../make-3.82/build-mingw.sh
#            popd
#            cp android-various/make-3.82-build/make.exe $QTC_INST_PATH/bin/
            cp /usr/local/bin/ma-make.exe $QTC_INST_PATH/bin/make.exe
        else
            if [ "$OSTYPE" = "linux-gnu" ]; then
                mkdir -p $QTC_INST_PATH/Qt/lib
                QT_LIB_DEST=$QTC_INST_PATH/Qt/lib/
                cp -a $SHARED_QT_PATH/lib/* $QT_LIB_DEST
                rm -fr $QT_LIB_DEST/pkgconfig
                find . $QT_LIB_DEST -name *.la | xargs rm -fr
                find . $QT_LIB_DEST -name *.prl | xargs rm -fr
                cp -a $SHARED_QT_PATH/imports/* ${QT_LIB_DEST}../imports
                cp -a $SHARED_QT_PATH/plugins/* ${QT_LIB_DEST}../plugins
                cp -a bin/necessitas $QTC_INST_PATH/bin/
            else
                pushd macdeployqt
                $SHARED_QT_PATH/bin/qmake $HOST_QT_CFG $HOST_QM_CFG_OPTIONS -r || error_msg "Can't configure macdeployqt"
                doMake "Can't compile macdeployqt" "all done" ma-make
                popd
                pushd bin
                rm -rf NecessitasQtCreatorBackup.app
                cp -rf NecessitasQtCreator.app NecessitasQtCreatorBackup.app
                ../macdeployqt/macdeployqt/macdeployqt NecessitasQtCreator.app
                popd
                mv bin/NecessitasQtCreator.app $QTC_INST_PATH/bin/NecessitasQtCreator.app
                mv bin/NecessitasQtCreatorBackup.app bin/NecessitasQtCreator.app
            fi
        fi
        mkdir $QTC_INST_PATH/images
        cp -a bin/necessitas*.png $QTC_INST_PATH/images/
        pushd $QTC_INST_PATH
        if [ -z $HOST_QT_CONFIG ] ; then
            find . -name "*$SHLIB_EXT" | xargs $STRIP
        fi
        popd
        $SDK_TOOLS_PATH/archivegen QtCreator$HOST_QT_CONFIG qtcreator-${HOST_TAG}${HOST_QT_CONFIG}.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.tools.qtcreator/data
        mv qtcreator-${HOST_TAG}${HOST_QT_CONFIG}.7z $REPO_PATH_PACKAGES/org.kde.necessitas.tools.qtcreator/data/qtcreator-${HOST_TAG}${HOST_QT_CONFIG}.7z
        popd
    fi

#    mkdir qpatch-build
#    pushd qpatch-build
#    if [ ! -f all_done ]
#    then
#        $STATIC_QT_PATH/bin/qmake $HOST_QT_CFG $HOST_QM_CFG_OPTIONS -r ../android-qt-creator/src/tools/qpatch/qpatch.pro
#        if [ "$OSTYPE" = "msys" ]; then
#            make -f Makefile.Release || error_msg "Can't compile qpatch"
#        else
#            make || error_msg "Can't compile qpatch"
#        fi
#        echo "all_done">all_done
#    fi

#    if [ "$OSTYPE" = "msys" ]; then
#        QPATCH_PATH=$PWD/release/qpatch$EXE_EXT
#    else
#        QPATCH_PATH=$PWD/qpatch
#    fi
#    popd
}

# A few things are downloaded as binaries.
function makeInstallMinGWLibsAndTools
{
    if [ -d mingw-bits ] ; then
        return
    fi

    mkdir -p /usr/local/bin
    mkdir -p /usr/local/share

    mkdir mingw-bits
    pushd mingw-bits

    mkdir texinfo
    pushd texinfo
	downloadIfNotExists texinfo-4.13a-2-msys-1.0.13-bin.tar.lzma http://heanet.dl.sourceforge.net/project/mingw/MSYS/texinfo/texinfo-4.13a-2/texinfo-4.13a-2-msys-1.0.13-bin.tar.lzma
    rm -rf texinfo-4.13a-2-msys-1.0.13-bin.tar
    7za x texinfo-4.13a-2-msys-1.0.13-bin.tar.lzma
    tar -xvf texinfo-4.13a-2-msys-1.0.13-bin.tar
    mv bin/* /usr/local/bin
    mv share/* /usr/local/share
    popd

    # pdcurses must be in /usr for gdb configure to work (though I'd prefer if mingw gcc would look in /usr/local too!)
    downloadIfNotExists PDCurses-3.4.tar.gz http://downloads.sourceforge.net/pdcurses/pdcurses/3.4/PDCurses-3.4.tar.gz
    rm -rf PDCurses-3.4
    tar -xvzf PDCurses-3.4.tar.gz
    pushd PDCurses-3.4/win32
    sed '90s/-copy/-cp/' mingwin32.mak > mingwin32-fixed.mak
    make -f mingwin32-fixed.mak WIDE=Y UTF8=Y DLL=N
    cp pdcurses.a /usr/lib/libcurses.a
    cp pdcurses.a /usr/lib/libncurses.a
    cp pdcurses.a /usr/lib/libpdcurses.a
    cp panel.a /usr/lib/libpanel.a
    cp ../curses.h /usr/include
    cp ../panel.h /usr/include
    popd

    # download, compile & install zlib to /usr
    downloadIfNotExists zlib-1.2.5.tar.gz http://downloads.sourceforge.net/libpng/zlib/1.2.5/zlib-1.2.5.tar.gz
    if [ ! -f /usr/lib/libz.a ] ; then
        tar -xvzf zlib-1.2.5.tar.gz
        pushd zlib-1.2.5
        doSed $"s#usr/#local/usr#" win32/Makefile.gcc
        make -f win32/Makefile.gcc
        export INCLUDE_PATH=/usr/include
        export LIBRARY_PATH=/usr/lib
        make -f win32/Makefile.gcc install
        rm -rf zlib-1.2.5
        popd
    fi

    # This make can't build gdb or python (it doesn't re-interpret MSYS mounts), but includes jobserver patch from
    # Troy Runkel: http://article.gmane.org/gmane.comp.gnu.make.windows/3223/match=
    # which fixes the longstanding make.exe -jN process hang, allowing un-attended builds of all Qt things.
    downloadIfNotExists make.exe http://mingw-and-ndk.googlecode.com/files/make.exe
    mv make.exe /usr/local/bin/ma-make.exe

    popd
}

function makeInstallMinGWLibs
{
    mkdir mingw-bits
    pushd mingw-bits

    install_dir=$1

    downloadIfNotExists readline-6.2.tar.gz http://ftp.gnu.org/pub/gnu/readline/readline-6.2.tar.gz
    rm -rf readline-6.2
    tar -xvzf readline-6.2.tar.gz
    pushd readline-6.2
    CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=  CFLAGS=-O2
    make && make DESTDIR=$install_dir install
    popd

    popd
}

function prepareNDKs
{
    # repack official windows NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-windows.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-windows.zip http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-windows.zip
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        unzip android-ndk-${ANDROID_NDK_VERSION}-windows.zip
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-windows.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-windows.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-windows.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    # repack official mac NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        tar xjvf android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.tar.bz2
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-darwin-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    # repack official linux-x86 NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
        tar xjvf android-ndk-${ANDROID_NDK_VERSION}-linux-x86.tar.bz2
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_VERSION}-linux-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_VERSION}
    fi

    # mingw android NDKs are only r6 for now, not r6b.
    # repack mingw android windows NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-windows.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z
#        cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z .
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
        7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_MAJOR_VERSION} android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-windows.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-windows.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-windows.7z
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
    fi

    # repack mingw android mac NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-darwin-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z
#        cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z .
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
        7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_MAJOR_VERSION} android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-darwin-x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-darwin-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-darwin-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
    fi

    # repack mingw android linux-x86 NDK
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-linux-x86.7z ]
    then
        downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z
#        cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z .
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
        7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z
        $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_MAJOR_VERSION} android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-linux-x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data
        mv android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-linux-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.ma_${ANDROID_NDK_MAJOR_VERSION}/data/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-ma-linux-x86.7z
        rm -fr android-ndk-${ANDROID_NDK_MAJOR_VERSION}
    fi

    if [ $BUILD_ANDROID_GIT_NDK = 1 ]
    then
        export ANDROID_NDK_ROOT=$PWD/android-ndk-${ANDROID_NDK_VERSION}-git
        export ANDROID_NDK_FOLDER_NAME=android-ndk-${ANDROID_NDK_VERSION}-git
    else
        export ANDROID_NDK_ROOT=$PWD/android-ndk-${ANDROID_NDK_VERSION}
        export ANDROID_NDK_FOLDER_NAME=android-ndk-${ANDROID_NDK_VERSION}
    fi

    export ANDROID_NDK_HOST=$HOST_TAG_NDK
    if [ "$USE_MA_NDK" = "0" ]; then
        USED_ANDROID_NDK_VERSION=r6b
    else
        USED_ANDROID_NDK_VERSION=r6
    fi

    if [ ! -d $ANDROID_NDK_FOLDER_NAME ]; then
        if [ "$USE_MA_NDK" = "0" ]; then
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
        else
            if [ "$OSTYPE" = "msys" ]; then
                downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z
#                cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z .
                7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-windows.7z
            fi

            if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
                downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z
#                cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z .
                7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-darwin-x86.7z
            fi

            if [ "$OSTYPE" = "linux-gnu" ]; then
                downloadIfNotExists android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z http://mingw-and-ndk.googlecode.com/files/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z
#                cp $REPO_SRC_PATH/ndk-packages/android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z .
                7za x android-ndk-${ANDROID_NDK_MAJOR_VERSION}-gdb-7.3.50.20110709-linux-x86.7z
            fi
        fi

        if [ $BUILD_ANDROID_GIT_NDK = 1 ]
        then
            mv android-ndk-${ANDROID_NDK_VERSION} android-ndk-${ANDROID_NDK_VERSION}-git
            git clone http://android.git.kernel.org/platform/ndk.git android_git_ndk || error_msg "Can't clone ndk"
            pushd android_git_ndk
                ./build/tools/rebuild-all-prebuilt.sh --ndk-dir=$ANDROID_NDK_ROOT --git-http --gdb-version=7.1 --sysroot=$USED_ANDROID_NDK_ROOT/platforms/android-9/arch-arm --verbose --package-dir=
            popd
            rm -fr android_git_ndk
            mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}_git/data
            $SDK_TOOLS_PATH/archivegen android-ndk-${ANDROID_NDK_VERSION}-git $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.${ANDROID_NDK_VERSION}_git/data/android-ndk-${ANDROID_NDK_VERSION}-git-${HOST_TAG_NDK}.7z
        fi
    fi

    ANDROID_STRIP_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-strip$EXE_EXT
    ANDROID_READELF_BINARY=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi-readelf$EXE_EXT
}

function prepareGDB
{
    package_name_ver=${GDB_VER//./_} # replace . with _
    if [ -z $GDB_TARG_HOST_TAG ] ; then
        GDB_PKG_NAME=gdb-$GDB_VER-$HOST_TAG
        GDB_FLDR_NAME=gdb-$GDB_VER
        package_path=$REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.gdb_$package_name_ver/data
    else
        GDB_PKG_NAME=gdb_$GDB_TARG_HOST_TAG-$GDB_VER
        GDB_FLDR_NAME=$GDB_PKG_NAME
        package_path=$REPO_PATH_PACKAGES/org.kde.necessitas.misc.host_gdb_$package_name_ver/data
    fi
    #This function depends on prepareNDKs
    if [ -f $package_path/$GDB_PKG_NAME.7z ]
    then
        return
    fi

    mkdir gdb-build
    pushd gdb-build
    pyversion=2.7
    pyfullversion=2.7.1
    install_dir=$PWD/install
    target_dir=$PWD/$GDB_FLDR_NAME
    mkdir -p $target_dir

    OLDPATH=$PATH
    if [ "$OSTYPE" = "linux-gnu" ] ; then
        HOST=i386-linux-gnu
        CC32="gcc -m32"
        CXX32="g++ -m32"
        PYCFGDIR=$install_dir/lib/python$pyversion/config
    else
        if [ "$OSTYPE" = "msys" ] ; then
            SUFFIX=.exe
            HOST=i686-pc-mingw32
            PYCFGDIR=$install_dir/bin/Lib/config
            export PATH=.:$PATH
            CC32=gcc.exe
            CXX32=g++.exe
            PYCCFG="--enable-shared"
         else
            # On some OS X installs (case insensitive filesystem), the dir "Python" clashes with the executable "python"
            # --with-suffix can be used to get around this.
            SUFFIX=Mac
            export PATH=.:$PATH
            CC32="gcc -m32"
            CXX32="g++ -m32"
        fi
    fi

    OLDCC=$CC
    OLDCXX=$CXX
    OLDCFLAGS=$CFLAGS

    downloadIfNotExists expat-2.0.1.tar.gz http://downloads.sourceforge.net/sourceforge/expat/expat-2.0.1.tar.gz || error_msg "Can't download expat library"
    if [ ! -d expat-2.0.1 ]
    then
        tar xzvf expat-2.0.1.tar.gz
        pushd expat-2.0.1
            CC=$CC32 CXX=$CXX32 ./configure --disable-shared --enable-static -prefix=/
            doMake "Can't compile expat" "all done"
            make DESTDIR=$install_dir install || error_msg "Can't install expat library"
        popd
    fi
    # Again, what a terrible failure.
    unset PYTHONHOME
    if [ ! -f Python-$pyfullversion/all_done ]
    then
        if [ "$OSTYPE" = "linux-gnu" ]; then
            downloadIfNotExists Python-$pyfullversion.tar.bz2 http://www.python.org/ftp/python/$pyfullversion/Python-$pyfullversion.tar.bz2 || error_msg "Can't download python library"
            tar xjvf Python-$pyfullversion.tar.bz2
            USINGMAPYTHON=0
        else
            if [ "$OSTYPE" = "msys" ]; then
                makeInstallMinGWLibs $install_dir
            fi
            rm -rf Python-$pyfullversion
            git clone git://gitorious.org/mingw-python/mingw-python.git Python-$pyfullversion || error_msg "Can't clone MinGW Python"
            USINGMAPYTHON=1
        fi

        pushd Python-$pyfullversion
        if [ "$OSTYPE" = "msys" ] ; then
            # Hack for MSI.
            cp /c/strawberry/c/i686-w64-mingw32/include/fci.h fci.h
        fi
        if [ "$USINGMAPYTHON" = "1" ] ; then
            autoconf
            touch Include/Python-ast.h
            touch Include/Python-ast.c
        fi

        CC=$CC32 CXX=$CXX32 ./configure $PYCCFG --host=$HOST --prefix=$install_dir --with-suffix=$SUFFIX || error_msg "Can't configure Python"
        doMake "Can't compile Python" "all done"
        if [ "$OSTYPE" = "msys" ] ; then
            pushd pywin32-216
            # TODO :: Fix this, builds ok but then tries to copy pywintypes27.lib instead of libpywintypes27.a and pywintypes27.dll.
            ../python$EXE_EXT setup.py build
            popd
        fi
        make install

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
            mkdir $install_dir/lib/python$pyversion
            cp libpython$pyversion.a $install_dir/lib/python$pyversion/
            cp libpython$pyversion.dll $install_dir/lib/python$pyversion/
        fi

        if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ] ; then
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/2to3
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/idle
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/pydoc
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/python-config
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/python2.7-config
            doSed $"s/python2\.7Mac/python2\.7/g" $install_dir/bin/smtpd.py
        fi

        popd
    fi

    pushd Python-$pyfullversion
    mkdir -p $target_dir/python/lib
    cp LICENSE $target_dir/PYTHON-LICENSE
    cp libpython$pyversion$SHLIB_EXT $target_dir/
    popd
    export PATH=$OLDPATH
    cp -a $install_dir/lib/python$pyversion $target_dir/python/lib/
    mkdir -p $target_dir/python/include/python$pyversion
    mkdir -p $target_dir/python/bin
    cp $install_dir/include/python$pyversion/pyconfig.h $target_dir/python/include/python$pyversion/
    # Remove the $SUFFIX if present (OS X)
    if [ "$OSTYPE" = "darwin9.0" -o "$OSTYPE" = "darwin10.0" ]; then
        mv $install_dir/bin/python$pyversion$SUFFIX $install_dir/bin/python$pyversion
        mv $install_dir/bin/python$SUFFIX $install_dir/bin/python
    fi
    cp -a $install_dir/bin/python$pyversion* $target_dir/python/bin/
    if [ "$OSTYPE" = "msys" ] ; then
        cp -fr $install_dir/bin/Lib $target_dir/
        cp -f $install_dir/bin/libpython$pyversion.dll $target_dir/python/bin/
    fi
    $STRIP $target_dir/python/bin/python$pyversion$EXE_EXT

    # Something is setting PYTHONHOME as an Env. Var for Windows and I'm not sure what... installer? NQTC? Python build process?
    # TODOMA :: Fix the real problem.
    unset PYTHONHOME
    unset PYTHONPATH

    if [ ! -d gdb-src ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb-src || error_msg "Can't clone gdb"
    fi
    pushd gdb-src
    git checkout $GDB_BRANCH
#    git reset --hard
    popd

    if [ ! -d gdb-src/build-$GDB_PKG_NAME ]
    then
        mkdir -p gdb-src/build-$GDB_PKG_NAME
        pushd gdb-src/build-$GDB_PKG_NAME
        OLDPATH=$PATH
        export PATH=$install_dir/bin/:$PATH
        if [ -z $GDB_TARG_HOST_TAG ] ; then
            CC=$CC32 CXX=$CXX32 CFLAGS="-O0 -g" $GDB_ROOT_PATH/configure --enable-initfini-array --enable-gdbserver=no --enable-tui=yes --with-sysroot=$TEMP_PATH/android-ndk-${USED_ANDROID_NDK_VERSION}/platforms/android-9/arch-arm --with-python=$install_dir --with-expat=yes --with-libexpat-prefix=$install_dir --prefix=$target_dir --target=arm-elf-linux --host=$HOST --build=$HOST --disable-nls
        else
            CC=$CC32 CXX=$CXX32 $GDB_ROOT_PATH/configure --enable-initfini-array --enable-gdbserver=no --enable-tui=yes --with-python=$install_dir --with-expat=yes --with-libexpat-prefix=$install_dir --prefix=$target_dir --target=$HOST --host=$HOST --build=$HOST --disable-nls
        fi
        doMake "Can't compile android gdb $GDB_VER" "all done"
        cp -a gdb/gdb$EXE_EXT $target_dir/
        cp -a gdb/gdbtui$EXE_EXT $target_dir/
#       $STRIP $target_dir/gdb$EXE_EXT .. Just while I fix native host GDB (can't debug the installer exe) and thumb-2 issues.
        export PATH=$OLDPATH
        popd
    fi

    CC=$OLDCC
    CXX=$OLDCXX
    CFLAGS=$OLDCFLAGS

    pushd $target_dir
    find . -name *.py[co] | xargs rm -f
    find . -name test | xargs rm -fr
    find . -name tests | xargs rm -fr
    popd

    $SDK_TOOLS_PATH/archivegen $GDB_FLDR_NAME $GDB_PKG_NAME.7z
    mkdir -p $package_path

    mv $GDB_PKG_NAME.7z $package_path/

    popd #gdb-build
}

function prepareGDBServer
{
    package_name_ver=${GDB_VER//./_} # replace - with _
    package_path=$REPO_PATH_PACKAGES/org.kde.necessitas.misc.ndk.gdb_$package_name_ver/data

    if [ -f $package_path/gdbserver-$GDB_VER.7z ]
    then
        return
    fi

    export NDK_DIR=$TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION}

    mkdir gdb-build
    pushd gdb-build

    if [ ! -d gdb-src ]
    then
        git clone git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git gdb-src || error_msg "Can't clone gdb"
        pushd gdb-src
        git checkout $GDB_BRANCH
        popd
    fi

    mkdir -p gdb-src/build-gdbserver-$GDB_VER
    pushd gdb-src/build-gdbserver-$GDB_VER

    mkdir android-sysroot
    $CPRL $TEMP_PATH/android-ndk-${USED_ANDROID_NDK_VERSION}/platforms/android-9/arch-arm/* android-sysroot/ || error_msg "Can't copy android sysroot"
    rm -f android-sysroot/usr/lib/libthread_db*
    rm -f android-sysroot/usr/include/thread_db.h

    TOOLCHAIN_PREFIX=$TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION}/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$HOST_TAG_NDK/bin/arm-linux-androideabi

    OLD_CC="$CC"
    OLD_CFLAGS="$CFLAGS"
    OLD_LDFLAGS="$LDFLAGS"

    export CC="$TOOLCHAIN_PREFIX-gcc --sysroot=$PWD/android-sysroot"
    if [ "$MAKE_DEBUG_GDBSERVER" = "1" ] ; then
        export CFLAGS="-O0 -g -nostdlib -D__ANDROID__ -DANDROID -DSTDC_HEADERS -I$TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION}/toolchains/arm-linux-androideabi-4.4.3/prebuilt/linux-x86/lib/gcc/arm-linux-androideabi/4.4.3/include -I$PWD/android-sysroot/usr/include -fno-short-enums"
        export LDFLAGS="-static -Wl,-z,nocopyreloc -Wl,--no-undefined $PWD/android-sysroot/usr/lib/crtbegin_static.o -lc -lm -lgcc -lc $PWD/android-sysroot/usr/lib/crtend_android.o"
    else
        export CFLAGS="-O2 -nostdlib -D__ANDROID__ -DANDROID -DSTDC_HEADERS -I$TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION}/toolchains/arm-linux-androideabi-4.4.3/prebuilt/linux-x86/lib/gcc/arm-linux-androideabi/4.4.3/include -I$PWD/android-sysroot/usr/include -fno-short-enums"
        export LDFLAGS="-static -Wl,-z,nocopyreloc -Wl,--no-undefined $PWD/android-sysroot/usr/lib/crtbegin_static.o -lc -lm -lgcc -lc $PWD/android-sysroot/usr/lib/crtend_android.o"
    fi

    LIBTHREAD_DB_DIR=$TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION}/sources/android/libthread_db/gdb-7.1.x/
    cp $LIBTHREAD_DB_DIR/thread_db.h android-sysroot/usr/include/
    $TOOLCHAIN_PREFIX-gcc$EXE_EXT --sysroot=$PWD/android-sysroot -o $PWD/android-sysroot/usr/lib/libthread_db.a -c $LIBTHREAD_DB_DIR/libthread_db.c || error_msg "Can't compile android threaddb"
    $GDB_ROOT_PATH/gdb/gdbserver/configure --host=arm-eabi-linux --with-libthread-db=$PWD/android-sysroot/usr/lib/libthread_db.a || error_msg "Can't configure gdbserver"
    doMake "Can't compile gdbserver" "all done"

    export CC="$OLD_CC"
    export CFLAGS="$OLD_CFLAGS"
    export LDFLAGS="$OLD_LDFLAGS"

    mkdir gdbserver-$GDB_VER
    if [ "$MAKE_DEBUG_GDBSERVER" = "0" ] ; then
        $TOOLCHAIN_PREFIX-objcopy --strip-unneeded gdbserver $PWD/gdbserver-$GDB_VER/gdbserver
    else
        cp gdbserver $PWD/gdbserver-$GDB_VER/gdbserver
    fi

    $SDK_TOOLS_PATH/archivegen gdbserver-$GDB_VER gdbserver-$GDB_VER.7z
    mkdir -p $package_path
    mv gdbserver-$GDB_VER.7z $package_path/

    popd #gdb-src/build-gdbserver-$GDB_VER

    popd #gdb-build
}

function repackSDK
{
    package_name=${4//-/_} # replace - with _
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.$package_name/data/$2.7z ]
    then
        downloadIfNotExists $1.zip http://dl.google.com/android/repository/$1.zip
        unzip $1.zip
        mkdir -p $3
        mv $1 $3/$4
        $SDK_TOOLS_PATH/archivegen $3 $2.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.$package_name/data
        mv $2.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.$package_name/data/$2.7z
        rm -fr $3
    fi
}

function prepareGDBVersion
{
    GDB_VER=$1
    GDB_TARG_HOST_TAG=$2 # windows, linux-x86, darwin-x86 or nothing for android.
    if [ "$GDB_VER" = "7.3" ]; then
        GDB_ROOT_PATH=..
        GDB_BRANCH=integration_7_3
    else
        if [ "$GDB_VER" = "head" ]; then
            GDB_ROOT_PATH=..
            GDB_BRANCH=fsf_head
        else
           GDB_ROOT_PATH=../gdb
           GDB_BRANCH=master
        fi
    fi
    prepareGDB
    if [ -z $GDB_TARG_HOST_TAG ] ; then
        prepareGDBServer
    fi
}

function prepareSDKs
{
    echo "prepare SDKs"
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz
        if [ ! -d android-sdk-linux_x86 ]
        then
            tar -xzvf android-sdk_${ANDROID_SDK_VERSION}-linux_x86.tgz
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-linux_x86 android-sdk_${ANDROID_SDK_VERSION}-linux_x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-linux_x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z
        rm -fr android-sdk-linux_x86
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip
        if [ ! -d android-sdk-mac_x86 ]
        then
            unzip android-sdk_${ANDROID_SDK_VERSION}-mac_x86.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-mac_x86 android-sdk_${ANDROID_SDK_VERSION}-mac_x86.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-mac_x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-mac_x86.7z
        rm -fr android-sdk-mac_x86
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z ]
    then
        downloadIfNotExists android-sdk_${ANDROID_SDK_VERSION}-windows.zip http://dl.google.com/android/android-sdk_${ANDROID_SDK_VERSION}-windows.zip
        if [ ! -d android-sdk-windows ]
        then
            unzip android-sdk_${ANDROID_SDK_VERSION}-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-sdk-windows android-sdk_${ANDROID_SDK_VERSION}-windows.7z
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data
        mv android-sdk_${ANDROID_SDK_VERSION}-windows.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.base/data/android-sdk-windows.7z
        rm -fr android-sdk-windows
    fi

    if [ "$OSTYPE" = "msys" ]
    then
        if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.platform_tools/data/android-sdk-windows-tools-mingw-android.7z ]
        then
            git clone git://gitorious.org/mingw-android-various/mingw-android-various.git android-various || error_msg "Can't clone android-various"
            pushd android-various/android-sdk
            gcc -Wl,-subsystem,windows -Wno-write-strings android.cpp -static-libgcc -s -O2 -o android.exe
            popd
            mkdir -p android-sdk-windows/tools/
            cp android-various/android-sdk/android.exe android-sdk-windows/tools/
            $SDK_TOOLS_PATH/archivegen android-sdk-windows android-sdk-windows-tools-mingw-android.7z
            mv android-sdk-windows-tools-mingw-android.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.sdk.platform_tools/data/android-sdk-windows-tools-mingw-android.7z
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

    # repack api-12
    repackSDK android-${ANDROID_API_12_VERSION}-linux android-${ANDROID_API_12_VERSION}-linux android-sdk-linux_x86/platforms android-12
    repackSDK android-${ANDROID_API_12_VERSION}-linux android-${ANDROID_API_12_VERSION}-macosx android-sdk-mac_x86/platforms android-12
    repackSDK android-${ANDROID_API_12_VERSION}-linux android-${ANDROID_API_12_VERSION}-windows android-sdk-windows/platforms android-12

    # repack api-13
    repackSDK android-${ANDROID_API_13_VERSION}-linux android-${ANDROID_API_13_VERSION}-linux android-sdk-linux_x86/platforms android-13
    repackSDK android-${ANDROID_API_13_VERSION}-linux android-${ANDROID_API_13_VERSION}-macosx android-sdk-mac_x86/platforms android-13
    repackSDK android-${ANDROID_API_13_VERSION}-linux android-${ANDROID_API_13_VERSION}-windows android-sdk-windows/platforms android-13
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
#    $QPATCH_PATH @qpatch.cmdline
}

function packSource
{
    package_name=${1//-/.} # replace - with .
    rm -fr $TEMP_PATH/source_temp_path
    mkdir -p $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    mv $1/.git .
    if [ $1 = "qt-src" ]
    then
        mv $1/src/3rdparty/webkit .
        mv $1/tests .
    fi

    if [ $1 = "qtwebkit-src" ]
    then
        mv $1/LayoutTests .
    fi
    echo cp -rf $1 $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/
    cp -rf $1 $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/
    pushd $TEMP_PATH/source_temp_path
    $SDK_TOOLS_PATH/archivegen Android $1.7z
    mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.android.$package_name/data
    mv $1.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.$package_name/data/$1.7z
    popd
    #mv $TEMP_PATH/source_temp_path/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/$1 .
    mv .git $1/
    if [ $1 = "qt-src" ]
    then
        mv webkit $1/src/3rdparty/
        mv tests $1/
    fi
    if [ $1 = "qtwebkit-src" ]
    then
        mv LayoutTests $1/
    fi
    rm -fr $TEMP_PATH/source_temp_path
}

function compileNecessitasQt
{
    package_name=${1//-/_} # replace - with _
    # Only android-ndk-r6/platforms/android-9/arch-$ARCH/usr/lib (yes both arm and x86) contains crtbegin_so.o, it's missing on
    # other platforms; this file also exists in android-ndk-r6/toolchains/arm-linux-androideabi-4.4.3/prebuilt/windows/sysroot/usr/lib
    # but not in the x86 equivalent, so for now, build it all for 9).
    NDK_TARGET=9
    # NQT_INSTALL_DIR=/data/data/eu.licentia.necessitas.ministro/files/qt
    NQT_INSTALL_DIR=$PWD/install
    if [ ! -f all_done ]
    then
        pushd ../qt-src
        git checkout $CHECKOUT_BRANCH
        git pull
        mkdir -p $NQT_INSTALL_DIR/src/android/cpp/
        # The examples need qtmain_android.cpp in the install dir.
        cp src/android/cpp/qtmain_android.cpp $NQT_INSTALL_DIR/src/android/cpp/
        popd
        ../qt-src/android/androidconfigbuild.sh -l $NDK_TARGET -c 1 -q 1 -n $TEMP_PATH/android-ndk-${ANDROID_NDK_VERSION} -a $1 -k 0 -i $NQT_INSTALL_DIR || error_msg "Can't configure android-qt"
        echo "all done">all_done
    fi

    if [ $package_name = "armeabi_v7a" ]
    then
        doSed $"s/= armeabi/= armeabi-v7a/g" mkspecs/android-g++/qmake.conf
        doSed $"s/= android-4/= android-$NDK_TARGET/g" install/mkspecs/android-g++/qmake.conf
    else
        doSed $"s/= armeabi-v7a/= armeabi/g" mkspecs/android-g++/qmake.conf
        doSed $"s/= android-4/= android-$NDK_TARGET/g" install/mkspecs/android-g++/qmake.conf
    fi

    rm -fr install
    export INSTALL_ROOT=""
    make install
#    doMakeInstall "Failed to make-install Qt Android $package_name" make
    mkdir -p $2/$1
    cp -rf $NQT_INSTALL_DIR/bin $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-tools-${HOST_TAG}.7z
    rm -fr $2/$1/bin
    mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.$package_name/data
    mv qt-tools-${HOST_TAG}.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.$package_name/data/qt-tools-${HOST_TAG}.7z
    cp -rf $NQT_INSTALL_DIR/* $2/$1
    cp -rf ../qt-src/lib/*.xml $2/$1/lib/
    $SDK_TOOLS_PATH/archivegen Android qt-framework.7z
    mv qt-framework.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.$package_name/data/qt-framework.7z
    # Not sure why we're using a different qt-framework package for Windows.
    cp $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.$package_name/data/qt-framework.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.$package_name/data/qt-framework-windows.7z
#    patchQtFiles
}

function prepareNecessitasQt
{
    downloadLighthouseSource
#    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.x86/data/qt-tools-${HOST_TAG}.7z ]
#    then
#        mkdir build-x86
#        pushd build-x86
#        compileNecessitasQt x86 Android/Qt/$NECESSITAS_QT_VERSION_SHORT
#        popd #build-x86
#    fi

    pushd Android/Qt/$NECESSITAS_QT_VERSION_SHORT

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi/data/qt-tools-${HOST_TAG}.7z ]
    then
        mkdir build-armeabi
        pushd build-armeabi
        compileNecessitasQt armeabi Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-armeabi
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi_v7a/data/qt-tools-${HOST_TAG}.7z ]
    then
        mkdir build-armeabi-v7a
        pushd build-armeabi-v7a
        compileNecessitasQt armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-armeabi-v7a
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.src/data/qt-src.7z ]
    then
        packSource qt-src
    fi

    popd #Android/Qt/$NECESSITAS_QT_VERSION_SHORT
}

function compileNecessitasQtMobility
{
    export ANDROID_TARGET_ARCH=$1
    if [ ! -f all_done ]
    then
        pushd ../qtmobility-src
        git checkout $CHECKOUT_BRANCH
        git pull
        popd
#        ../qtmobility-src/configure -prefix $PWD/install -staticconfig android -qmake-exec $PWD/../build-$1/install/bin/qmake$EXE_EXT -modules "bearer location contacts multimedia versit messaging systeminfo serviceframework sensors gallery organizer feedback connectivity" || error_msg "Can't configure android-qtmobility"
        ../qtmobility-src/configure -prefix $PWD/install -staticconfig android -qmake-exec $TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$1/install/bin/qmake$EXE_EXT -modules "bearer location contacts multimedia versit messaging systeminfo serviceframework sensors gallery organizer feedback connectivity" || error_msg "Can't configure android-qtmobility"
        doMake "Can't compile android-qtmobility" "all done" ma-make
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr data
    rm -fr $2
    export INSTALL_ROOT=""
    make install
    mkdir -p $2/$1
    mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.$package_name/data
    mv $PWD/install/* $2/$1
    cp -a $PWD/$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$1/* $2/$1
    rm -fr $PWD/$TEMP_PATH
    $SDK_TOOLS_PATH/archivegen Android qtmobility.7z
    mv qtmobility.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.$package_name/data/qtmobility.7z
    cp -a $2/$1/* ../build-$1
#    pushd ../build-$1
#    patchQtFiles
#    popd
}

function prepareNecessitasQtMobility
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    pushd Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    if [ ! -d qtmobility-src ]
    then
        git clone git://anongit.kde.org/android-qt-mobility.git qtmobility-src || error_msg "Can't clone android-qt-mobility"
        pushd qtmobility-src
        git checkout $CHECKOUT_BRANCH
        git pull
        popd
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi/data/qtmobility.7z ]
    then
        mkdir build-mobility-armeabi
        pushd build-mobility-armeabi
        compileNecessitasQtMobility armeabi Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-mobility-armeabi
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/qtmobility.7z ]
    then
        mkdir build-mobility-armeabi-v7a
        pushd build-mobility-armeabi-v7a
        compileNecessitasQtMobility armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-mobility-armeabi-v7a
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.src/data/qtmobility-src.7z ]
    then
        packSource qtmobility-src
    fi
    popd #Android/Qt/$NECESSITAS_QT_VERSION_SHORT
}

function compileNecessitasQtWebkit
{
    export ANDROID_TARGET_ARCH=$1
    export SQLITE3SRCDIR=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/qt-src/src/3rdparty/sqlite
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
        ../qtwebkit-src/WebKitTools/Scripts/build-webkit --qt --makeargs="-j$JOBS" --qmake=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$1/install/bin/qmake$EXE_EXT --no-video --no-xslt || error_msg "Can't configure android-qtwebkit"
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
    mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.$package_name/data
    mv $PWD/$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$1/* $2/$1
    pushd $2/$1
    qt_build_path=$TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$1
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
    mv qtwebkit.7z $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.$package_name/data/qtwebkit.7z
    cp -a $2/$1/* ../build-$1/
#    pushd ../build-$1
#    patchQtFiles
#    popd
}

function prepareNecessitasQtWebkit
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    pushd Android/Qt/$NECESSITAS_QT_VERSION_SHORT
    if [ ! -d qtwebkit-src ]
    then
        git clone git://gitorious.org/~taipan/webkit/android-qtwebkit.git qtwebkit-src || error_msg "Can't clone android-qtwebkit"
        pushd qtwebkit-src
        git checkout $CHECKOUT_BRANCH
        git pull
        popd
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi/data/qtwebkit.7z ]
    then
        mkdir build-webkit-armeabi
        pushd build-webkit-armeabi
        compileNecessitasQtWebkit armeabi Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-webkit-armeabi
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/qtwebkit.7z ]
    then
        mkdir build-webkit-armeabi-v7a
        pushd build-webkit-armeabi-v7a
        compileNecessitasQtWebkit armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION_SHORT
        popd #build-webkit-armeabi-v7a
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.src/data/qtwebkit-src.7z ]
    then
        packSource qtwebkit-src
    fi
    popd #Android/Qt/$NECESSITAS_QT_VERSION_SHORT
}

function prepareOpenJDK
{
    mkdir openjdk
    pushd openjdk

    mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data
    WINE=0
    which wine && WINE=1
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/openjdk-windows.7z ] ; then
        if [ "$OSTYPE" = "msys" -o "$WINE" = "1" ] ; then
            downloadIfNotExists oscg-openjdk6b21-1-windows-installer.exe http://oscg-downloads.s3.amazonaws.com/installers/oscg-openjdk6b21-1-windows-installer.exe
            rm -rf openjdk6b21-windows
            oscg-openjdk6b21-1-windows-installer.exe --unattendedmodeui none --mode unattended --prefix `pwd`/openjdk6b21-windows
            pushd openjdk6b21-windows
            $SDK_TOOLS_PATH/archivegen openjdk-6.0.21 openjdk-windows.7z
            mv openjdk-windows.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/
            popd
        fi
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/openjdk-linux-x86.7z ] ; then
        downloadIfNotExists openjdk-1.6.0-b21.i386.openscg.deb http://oscg-downloads.s3.amazonaws.com/packages/openjdk-1.6.0-b21.i386.openscg.deb
        ar x openjdk-1.6.0-b21.i386.openscg.deb
        tar xzf data.tar.gz
        pushd opt
        $SDK_TOOLS_PATH/archivegen openjdk openjdk-linux-x86.7z
        mv openjdk-linux-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/
        popd
        tar
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/openjdk-darwin-x86.7z ] ; then
        downloadIfNotExists oscg-openjdk6b16-5a-osx-installer.zip http://oscg-downloads.s3.amazonaws.com/installers/oscg-openjdk6b16-5a-osx-installer.zip
        unzip -o oscg-openjdk6b16-5a-osx-installer.zip
        $SDK_TOOLS_PATH/archivegen oscg-openjdk6b16-5a-osx-installer.app openjdk-darwin-x86.7z
        mv openjdk-darwin-x86.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.openjdk/data/
    fi

    popd
}

function prepareAnt
{
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ant/data/ant.7z ] ; then
        mkdir -p $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ant/data
        downloadIfNotExists apache-ant-1.8.2-bin.tar.bz2 http://mirror.ox.ac.uk/sites/rsync.apache.org//ant/binaries/apache-ant-1.8.2-bin.tar.bz2
        tar xjvf apache-ant-1.8.2-bin.tar.bz2
        $SDK_TOOLS_PATH/archivegen apache-ant-1.8.2 ant.7z
        mv ant.7z $REPO_PATH_PACKAGES/org.kde.necessitas.misc.ant/data/
    fi
}

function patchPackages
{
    pushd $REPO_PATH_PACKAGES
    for files_name in "*.qs" "*.xml"
    do
        for file_name in `find . -name $files_name`
        do
            # Can't use / as a delimiter for paths.
            doSed $"s#$1#$2#g" $file_name
        done
    done
    popd
}

function patchPackage
{
    if [ -d $REPO_PATH_PACKAGES/$3 ] ; then
        pushd $REPO_PATH_PACKAGES/$3
        for files_name in "*.qs" "*.xml"
        do
            for file_name in `find . -name $files_name`
            do
                doSed $"s#$1#$2#g" $file_name
            done
        done
        popd
    else
        echo "patchPackage : Warning, failed to find directory $REPO_PATH_PACKAGES/$3"
    fi
}

function setPackagesVariables
{
    patchPackages "@@TODAY@@" $TODAY

    patchPackages "@@NECESSITAS_QT_VERSION@@" $NECESSITAS_QT_VERSION
    patchPackages "@@NECESSITAS_QT_VERSION_SHORT@@" $NECESSITAS_QT_VERSION_SHORT
    patchPackages "@@NECESSITAS_QTWEBKIT_VERSION@@" $NECESSITAS_QTWEBKIT_VERSION
    patchPackages "@@NECESSITAS_QTMOBILITY_VERSION@@" $NECESSITAS_QTMOBILITY_VERSION
    patchPackages "@@TEMP_PATH@@" $TEMP_PATH

    patchPackage "@@NECESSITAS_QT_CREATOR_VERSION@@" $NECESSITAS_QT_CREATOR_VERSION "org.kde.necessitas.tools.qtcreator"

    patchPackage "@@ANDROID_NDK_VERSION@@" $ANDROID_NDK_VERSION "org.kde.necessitas.misc.ndk.r6"
    patchPackage "@@ANDROID_NDK_MAJOR_VERSION@@" $ANDROID_NDK_MAJOR_VERSION "org.kde.necessitas.misc.ndk.ma_r6"

    patchPackage "@@ANDROID_API_4_VERSION@@" $ANDROID_API_4_VERSION "org.kde.necessitas.misc.sdk.android_4"
    patchPackage "@@ANDROID_API_5_VERSION@@" $ANDROID_API_5_VERSION "org.kde.necessitas.misc.sdk.android_5"
    patchPackage "@@ANDROID_API_6_VERSION@@" $ANDROID_API_6_VERSION "org.kde.necessitas.misc.sdk.android_6"
    patchPackage "@@ANDROID_API_7_VERSION@@" $ANDROID_API_7_VERSION "org.kde.necessitas.misc.sdk.android_7"
    patchPackage "@@ANDROID_API_8_VERSION@@" $ANDROID_API_8_VERSION "org.kde.necessitas.misc.sdk.android_8"
    patchPackage "@@ANDROID_API_9_VERSION@@" $ANDROID_API_9_VERSION "org.kde.necessitas.misc.sdk.android_9"
    patchPackage "@@ANDROID_API_10_VERSION@@" $ANDROID_API_10_VERSION "org.kde.necessitas.misc.sdk.android_10"
    patchPackage "@@ANDROID_API_11_VERSION@@" $ANDROID_API_11_VERSION "org.kde.necessitas.misc.sdk.android_11"
    patchPackage "@@ANDROID_API_12_VERSION@@" $ANDROID_API_12_VERSION "org.kde.necessitas.misc.sdk.android_12"
    patchPackage "@@ANDROID_API_13_VERSION@@" $ANDROID_API_13_VERSION "org.kde.necessitas.misc.sdk.android_13"
    patchPackage "@@ANDROID_PLATFORM_TOOLS_VERSION@@" $ANDROID_PLATFORM_TOOLS_VERSION "org.kde.necessitas.misc.sdk.platform_tools"
    patchPackage "@@ANDROID_SDK_VERSION@@" $ANDROID_SDK_VERSION "org.kde.necessitas.misc.sdk.base"
}

function prepareSDKBinary
{
    $SDK_TOOLS_PATH/binarycreator -v -t $SDK_TOOLS_PATH/installerbase$EXE_EXT -c $REPO_SRC_PATH/config -p $REPO_PATH_PACKAGES -n $REPO_SRC_PATH/necessitas-sdk-installer$HOST_QT_CONFIG$EXE_EXT org.kde.necessitas
}

function prepareSDKRepository
{
    rm -fr $REPO_PATH
    $SDK_TOOLS_PATH/repogen -v  -p $REPO_PATH_PACKAGES -c $REPO_SRC_PATH/config $REPO_PATH org.kde.necessitas
}

function prepareMinistroRepository
{
    pushd $REPO_SRC_PATH/ministrorepogen
    if [ ! -f all_done ]
    then
        $STATIC_QT_PATH/bin/qmake -r || error_msg "Can't configure ministrorepogen"
        doMake "Can't compile ministrorepogen" "all done" ma-make
    fi
    popd
    for architecture in armeabi armeabi-v7a
    do
        rm -fr $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION
        mkdir -p $MINISTRO_REPO_PATH/android/$architecture/objects/$MINISTRO_VERSION
        pushd $TEMP_PATH/Android/Qt/$NECESSITAS_QT_VERSION_SHORT/build-$architecture || error_msg "Can't prepare ministro repo, Android Qt not built?"
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
        7za x $1/$2.7z
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
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi/data/qt-framework-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi/data/ qt-framework
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi_v7a/data/qt-framework-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.armeabi_v7a/data/ qt-framework
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.src/data/qt-src-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qt.src/data/ qt-src
    fi


    #  Qt Mobility
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi/data/qtmobility-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi/data/ qtmobility
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/qtmobility-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.armeabi_v7a/data/ qtmobility
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.src/data/qtmobility-src-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtmobility.src/data/ qtmobility-src
    fi


    #  Qt WebKit
    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi/data/qtwebkit-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi/data/ qtwebkit
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/qtwebkit-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.armeabi_v7a/data/ qtwebkit
    fi

    if [ ! -f $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.src/data/qtwebkit-src-windows.7z ]
    then
        packforWindows $REPO_PATH_PACKAGES/org.kde.necessitas.android.qtwebkit.src/data/ qtwebkit-src
    fi

}

# My new NDK is too untested to be used as the one that builds Android Qt, so use official NDK on Linux
# for now.
USE_MA_NDK=1
if [ "$OSTYPE" = "linux-gnu" ] ; then
    USE_MA_NDK=0
fi

if [ "$OSTYPE" = "msys" ] ; then
    makeInstallMinGWLibsAndTools
fi
prepareHostQt
prepareSdkInstallerTools
prepareOpenJDK
prepareAnt
prepareNDKs
prepareGDBVersion head $HOST_TAG
prepareGDBVersion head
prepareSDKs
prepareNecessitasQtCreator
prepareNecessitasQt

# TODO :: Fix webkit build in Windows (-no-video fails) and Mac OS X (debug-and-release config incorrectly used and fails)
# git clone often fails for webkit
prepareNecessitasQtWebkit

if [ "$OSTYPE" != "msys" ] ; then
    prepareNecessitasQtMobility # if [[ `gcc --version` =~ .*llvm.* ]]; => syntax error near `=~'
fi

prepareWindowsPackages
setPackagesVariables
prepareSDKBinary

# Comment this block in if you want necessitas-sdk-installer-d and qtcreator-d to be built.
if [ "$MAKE_DEBUG_HOST_APPS" = "1" ] ; then
    prepareHostQt -d
    prepareNecessitasQtCreator
    prepareSdkInstallerTools
    prepareSDKBinary
fi

prepareSDKRepository
prepareMinistroRepository

popd

#!/bin/bash

REPO_SRC_DIR=$PWD
TEMP_PATH=/tmp/necessitas
mkdir -p $TEMP_PATH
pushd $TEMP_PATH

HOST_QT_VERSION=qt-everywhere-opensource-src-4.7.2
STATIC_QT_PATH=""
SHARED_QT_PATH=""
SDK_TOOLS_PATH=""

function error_msg
{
        echo $1 >&2
        exit 1
}

function removeAndExit
{
    rm -fr $1 && error_msg "Can't download $1"
}

function downloadIfNotExits
{
    if [ ! -f $1 ]
    then
        wget $2 || removeAndExit $1
    fi
}

function prepareHostQt
{
    # download compile & compile qt, it is used to compile the installer
    downloadIfNotExits $HOST_QT_VERSION.tar.gz http://get.qt.nokia.com/qt/source/$HOST_QT_VERSION.tar.gz

    if [ ! -d $HOST_QT_VERSION ]
    then
        tar xvfz $HOST_QT_VERSION.tar.gz || error_msg "Can't untar $HOST_QT_VERSION.tar.gz"
    fi

    #build qt statically, needed by Sdk installer
    mkdir build-$HOST_QT_VERSION-static
    pushd build-$HOST_QT_VERSION-static
    STATIC_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -qt-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -developer-build -static -no-webkit -no-phonon -no-dbus -no-opengl -no-qt3support -no-xmlpatterns -no-svg -release -qt-sql-sqlite -plugin-sql-sqlite -confirm-license --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        make -j4  || error_msg "Can't compile $HOST_QT_VERSION"
        echo "all done">all_done
    fi
    popd

    #build qt shared, needed by QtCreator
    mkdir build-$HOST_QT_VERSION-shared
    pushd build-$HOST_QT_VERSION-shared
    SHARED_QT_PATH=$PWD
    if [ ! -f all_done ]
    then
        rm -fr *
        ../$HOST_QT_VERSION/configure -fast -nomake examples -nomake demos -qt-zlib -qt-gif -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -developer-build -shared -webkit -no-phonon -release -qt-sql-sqlite -plugin-sql-sqlite -confirm-license --prefix=$PWD || error_msg "Can't configure $HOST_QT_VERSION"
        make -j4  || error_msg "Can't compile $HOST_QT_VERSION"
        echo "all done">all_done
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
    SDK_TOOLS_PATH=$PWD/bin

    if [ ! -f all_done ]
    then
        git checkout master
        $STATIC_QT_PATH/bin/qmake -r || error_msg "Can't configure necessitas-installer-framework"
        make -j4 || error_msg "Can't compile necessitas-installer-framework"
        echo "all done">all_done
    fi
    popd
}


function perpareNecessitasQtCreator
{
    # get installer source code
    if [ ! -d android-qt-creator ]
    then
        git clone git://gitorious.org/~taipan/qt-creator/android-qt-creator.git || error_msg "Can't clone android-qt-creator"
    fi

    pushd android-qt-creator

    if [ ! -f all_done ]
    then
        git checkout testing
        $SHARED_QT_PATH/bin/qmake -r || error_msg "Can't configure android-qt-creator"
        make -j4 || error_msg "Can't compile android-qt-creator"
        echo "all done">all_done
    fi
    INSTALL_ROOT=$PWD/QtCreator make install
    cp -a $SHARED_QT_PATH/lib $PWD/QtCreator/lib
    cp -a $SHARED_QT_PATH/imports $PWD/QtCreator/imports
    cp -a bin/necessitas $PWD/QtCreator/bin/
    mkdir $PWD/QtCreator/images
    cp -a bin/necessitas*.png $PWD/QtCreator/images/
    $SDK_TOOLS_PATH/archivegen QtCreator qtcreator-linux-x86.7z
    mv qtcreator-linux-x86.7z $REPO_SRC_DIR/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-linux-x86.7z
    popd
}


function perpareNDKs
{
    # repack linux-x86 NDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z ]
    then
        downloadIfNotExits android-ndk-r5b-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-linux-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-linux-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-linux-x86.7z
        mv android-ndk-r5b-linux-x86.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z
        rm -fr android-ndk-r5b
    fi

    # repack windows NDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z ]
    then
        downloadIfNotExits android-ndk-r5b-windows.zip http://dl.google.com/android/ndk/android-ndk-r5b-windows.zip
        if [ ! -d android-ndk-r5b ]
        then
            unzip android-ndk-r5b-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-windows.7z
        mv android-ndk-r5b-windows.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z
        rm -fr android-ndk-r5b
    fi

    # repack mac NDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z ]
    then
        downloadIfNotExits android-ndk-r5b-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-darwin-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-darwin-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-darwin-x86.7z
        mv android-ndk-r5b-darwin-x86.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z
        rm -fr android-ndk-r5b
    fi
}

function perpareSDKs
{
    # prepare linux-x86 SDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z ]
    then
        downloadIfNotExits android-ndk-r5b-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-linux-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-linux-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-linux-x86.7z
        mv android-ndk-r5b-linux-x86.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z
        rm -fr android-ndk-r5b
    fi

    # prepare windows SDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z ]
    then
        downloadIfNotExits android-ndk-r5b-windows.zip http://dl.google.com/android/ndk/android-ndk-r5b-windows.zip
        if [ ! -d android-ndk-r5b ]
        then
            unzip android-ndk-r5b-windows.zip
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-windows.7z
        mv android-ndk-r5b-windows.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z
        rm -fr android-ndk-r5b
    fi

    # repack mac NDK
    if [ ! -f $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z ]
    then
        downloadIfNotExits android-ndk-r5b-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-darwin-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-darwin-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-darwin-x86.7z
        mv android-ndk-r5b-darwin-x86.7z $REPO_SRC_DIR/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z
        rm -fr android-ndk-r5b
    fi
}


prepareHostQt
perpareSdkInstallerTools
perpareNecessitasQtCreator
perpareNDKs
popd


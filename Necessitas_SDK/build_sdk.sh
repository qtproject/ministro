#!/bin/bash

REPO_SRC_PATH=$PWD
TEMP_PATH=/var/necessitas
REPO_PATH=/var/www/necessitas/sdk
mkdir -p $TEMP_PATH
pushd $TEMP_PATH

HOST_QT_VERSION=qt-everywhere-opensource-src-4.7.2
NECESSITAS_QT_VERSION=4761
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
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-linux-x86.7z ]
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
            make -j4 || error_msg "Can't compile android-qt-creator"
            echo "all done">all_done
        fi
        rm -fr QtCreator
        INSTALL_ROOT=$PWD/QtCreator make install
        mkdir -p $PWD/QtCreator/Qt/lib
        mkdir -p $PWD/QtCreator/Qt/imports
        cp -a $SHARED_QT_PATH/lib/* $PWD/QtCreator/Qt/lib/
        rm -fr $PWD/QtCreator/Qt/lib/pkgconfig
        find $PWD/QtCreator/Qt -name *.la | xargs rm -fr
        find $PWD/QtCreator/Qt -name *.prl | xargs rm -fr
        cp -a $SHARED_QT_PATH/imports/* $PWD/QtCreator/Qt/imports/
        cp -a bin/necessitas $PWD/QtCreator/bin/
        mkdir $PWD/QtCreator/images
        cp -a bin/necessitas*.png $PWD/QtCreator/images/
        $SDK_TOOLS_PATH/archivegen QtCreator qtcreator-linux-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data
        mv qtcreator-linux-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.tools.qtcreator/data/qtcreator-linux-x86.7z
        popd
    fi
}


function perpareNDKs
{
    # repack windows NDK
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-windows.7z ]
    then
        downloadIfNotExits android-ndk-r5b-windows.zip http://dl.google.com/android/ndk/android-ndk-r5b-windows.zip
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
        downloadIfNotExits android-ndk-r5b-darwin-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-darwin-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-darwin-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-darwin-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data
        mv android-ndk-r5b-darwin-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-darwin-x86.7z
        rm -fr android-ndk-r5b
    fi

    # repack linux-x86 NDK, it must be the last one because we need it to build qt
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z ]
    then
        downloadIfNotExits android-ndk-r5b-linux-x86.tar.bz2 http://dl.google.com/android/ndk/android-ndk-r5b-linux-x86.tar.bz2
        if [ ! -d android-ndk-r5b ]
        then
            tar xvfa android-ndk-r5b-linux-x86.tar.bz2
        fi
        $SDK_TOOLS_PATH/archivegen android-ndk-r5b android-ndk-r5b-linux-x86.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data
        mv android-ndk-r5b-linux-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.ndk.r5b/data/android-ndk-r5b-linux-x86.7z
    fi
}

function repackSDK
{
    package_name=${3//-/_} # replace - with _
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data/$1.7z ]
    then
        downloadIfNotExits $1.zip http://dl.google.com/android/repository/$1.zip
        unzip $1.zip
        mkdir -p $2
        mv $1 $2/$3
        $SDK_TOOLS_PATH/archivegen $2 $1.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data
        mv $1.7z $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.$package_name/data/$1.7z
        rm -fr $2
    fi
}

function perpareSDKs
{
    echo "prepare SDKs"
    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.misc.sdk.base/data/android-sdk-linux_x86.7z ]
    then
        downloadIfNotExits android-sdk_r10-linux_x86.tgz http://dl.google.com/android/android-sdk_r10-linux_x86.tgz
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
        downloadIfNotExits android-sdk_r10-mac_x86.zip http://dl.google.com/android/android-sdk_r10-mac_x86.zip
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
        downloadIfNotExits android-sdk_r10-windows.zip http://dl.google.com/android/android-sdk_r10-windows.zip
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
    repackSDK platform-tools_r03-linux android-sdk-linux_x86 platform-tools
    repackSDK platform-tools_r03-macosx android-sdk-mac_x86 platform-tools
# should we also include ant binary for windows ?
    repackSDK platform-tools_r03-windows android-sdk-windows platform-tools

    # repack api-4
    repackSDK android-1.6_r03-linux android-sdk-linux_x86/platforms android-4
    repackSDK android-1.6_r03-macosx android-sdk-mac_x86/platforms android-4
    repackSDK android-1.6_r03-windows android-sdk-windows/platforms android-4

    # repack api-5
    repackSDK android-2.0_r01-linux android-sdk-linux_x86/platforms android-5
    repackSDK android-2.0_r01-macosx android-sdk-mac_x86/platforms android-5
    repackSDK android-2.0_r01-windows android-sdk-windows/platforms android-5

    # repack api-6
    repackSDK android-2.0.1_r01-linux  android-sdk-linux_x86/platforms android-6
    repackSDK android-2.0.1_r01-macosx android-sdk-mac_x86/platforms android-6
    repackSDK android-2.0.1_r01-windows android-sdk-windows/platforms android-6

    # repack api-7
    repackSDK android-2.1_r02-linux android-sdk-linux_x86/platforms android-7
    repackSDK android-2.1_r02-macosx android-sdk-mac_x86/platforms android-7
    repackSDK android-2.1_r02-windows android-sdk-windows/platforms android-7

    # repack api-8
    repackSDK android-2.2_r02-linux android-sdk-linux_x86/platforms android-8
    repackSDK android-2.2_r02-macosx android-sdk-mac_x86/platforms android-8
    repackSDK android-2.2_r02-windows android-sdk-windows/platforms android-8

    # repack api-9
    repackSDK android-2.3.1_r02-linux android-sdk-linux_x86/platforms android-9
    repackSDK android-2.3.1_r02-linux android-sdk-mac_x86/platforms android-9
    repackSDK android-2.3.1_r02-linux android-sdk-windows/platforms android-9

    # repack api-10
    repackSDK android-2.3.3_r01-linux android-sdk-linux_x86/platforms android-10
    repackSDK android-2.3.3_r01-linux android-sdk-mac_x86/platforms android-10
    repackSDK android-2.3.3_r01-linux android-sdk-windows/platforms android-10

    # repack api-11
    repackSDK android-3.0_r01-linux android-sdk-linux_x86/platforms android-11
    repackSDK android-3.0_r01-linux android-sdk-mac_x86/platforms android-11
    repackSDK android-3.0_r01-linux android-sdk-windows/platforms android-11
}


function compileNecessitasQt
{
    if [ ! -f all_done ]
    then
        git checkout testing
        ../qt-src/androidconfigbuild.sh -q 1 -n $TEMP_PATH/android-ndk-r5b -a $1 -k 1 -i /data/data/eu.licentia.necessitas.ministro/files/qt || error_msg "Can't configure android-qt-creator"
        echo "all done">all_done
    fi
    package_name=${1//-/_} # replace - with _
    rm -fr data
    INSTALL_ROOT=$PWD make install
    mkdir -p $2/$1
    mv data/data/eu.licentia.necessitas.ministro/files/qt/bin $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-tools-linux-x86.7z
    rm -fr $2/$1/bin
    mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data
    mv qt-tools-linux-x86.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-tools-linux-x86.7z
    mv data/data/eu.licentia.necessitas.ministro/files/qt/* $2/$1
    $SDK_TOOLS_PATH/archivegen Android qt-farmework.7z
    mv qt-farmework.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.$package_name/data/qt-farmework.7z
}


function perpareNecessitasQt
{
    mkdir -p Android/Qt/$NECESSITAS_QT_VERSION
    pushd Android/Qt/$NECESSITAS_QT_VERSION
    if [ ! -d qt-src ]
    then
        git clone git://anongit.kde.org/android-qt.git qt-src|| error_msg "Can't clone android-qt-creator"
        pushd qt-src
        git checkout testing
        popd
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi/data/qt-tools-linux-x86.7z ]
    then
        mkdir build-armeabi
        pushd build-armeabi
        compileNecessitasQt armeabi Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-armeabi
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.armeabi_v7a/data/qt-tools-linux-x86.7z ]
    then
        mkdir build-armeabi-v7a
        pushd build-armeabi-v7a
        compileNecessitasQt armeabi-v7a Android/Qt/$NECESSITAS_QT_VERSION
        popd #build-armeabi-v7a
    fi

    if [ ! -f $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data/qt-src.7z ]
    then
        mv qt-src/.git .
        $SDK_TOOLS_PATH/archivegen qt-src qt-src.7z
        mkdir -p $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data
        mv qt-src.7z $REPO_SRC_PATH/packages/org.kde.necessitas.android.qt.src/data/qt-src.7z
        mv .git qt-src/
    fi
    popd #Android/Qt/$NECESSITAS_QT_VERSION
}

function prepareSDKBinary
{
        $SDK_TOOLS_PATH/binarycreator -v -t $SDK_TOOLS_PATH/installerbase -c $REPO_SRC_PATH/config -p $REPO_SRC_PATH/packages -n $REPO_SRC_PATH/necessitas-sdk-installer org.kde.necessitas
}

function prepareSDKRepository
{
        $SDK_TOOLS_PATH/repogen -v  -p $REPO_SRC_PATH/packages -c $REPO_SRC_PATH/config $REPO_PATH org.kde.necessitas
}

perpareNDKs
perpareSDKs
prepareHostQt
perpareSdkInstallerTools
perpareNecessitasQtCreator
perpareNecessitasQt
prepareSDKBinary
prepareSDKRepository

popd

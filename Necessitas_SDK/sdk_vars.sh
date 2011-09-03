MINISTRO_VERSION="0.3" #Ministro repo version

# There's no qpa plugin for Windows in Lighthouse yet.
# The easiest workaround is probably to use angle (a Google Chrome spin-off project):
# svn checkout http://angleproject.googlecode.com/svn/trunk/ angleproject-read-only
# ..which translates GL to DirectX and apparently works quite well, and as used by
# http://code.google.com/p/gamekit/source/browse/#svn%2Ftrunk%2FDependencies%2FWin32%2Fgles2
# But for now, lighthouse can only be used as the Host Qt on Mac and Linux.
# Configure options from http://wayland.freedesktop.org/toolkits.html are -qpa -egl -opengl es2
# if [ "$OSTYPE" = "msys" ] ; then
if [ "$1" = "$1" ] ; then
    HOST_QT_VERSION=qt-everywhere-opensource-src-4.8.0 # Qt which is used to build QtCreator and the SDK installer (only matters that this isn't lighthouse)
    HOST_QT_BRANCH=4.8
    HOST_QT_SRCDIR=qeos-$HOST_QT_BRANCH
else
    HOST_QT_VERSION=lighthouse
fi

CHECKOUT_BRANCH="unstable"

NECESSITAS_QT_CREATOR_VERSION="2.3.81"

# Qt Framework versions
NECESSITAS_QT_VERSION_SHORT=4763 #Necessitas Qt Framework Version
NECESSITAS_QT_VERSION="4.7.63" #Necessitas Qt Framework Long Version

NECESSITAS_QTWEBKIT_VERSION="2.2" #Necessitas QtWebkit Version

NECESSITAS_QTMOBILITY_VERSION="1.2.0" #Necessitas QtMobility Version

# NDK variables
BUILD_ANDROID_GIT_NDK=0 # Latest and the greatest NDK built from sources
ANDROID_NDK_MAJOR_VERSION=r6 # NDK major version, used by package name (and ma ndk)
ANDROID_NDK_VERSION=r6b # NDK full package version

# SDK variables
ANDROID_SDK_VERSION=r12
ANDROID_PLATFORM_TOOLS_VERSION=r06
ANDROID_API_4_VERSION=1.6_r03
ANDROID_API_5_VERSION=2.0_r01
ANDROID_API_6_VERSION=2.0.1_r01
ANDROID_API_7_VERSION=2.1_r02
ANDROID_API_8_VERSION=2.2_r02
ANDROID_API_9_VERSION=2.3.1_r02
ANDROID_API_10_VERSION=2.3.3_r01
ANDROID_API_11_VERSION=3.0_r01
ANDROID_API_12_VERSION=3.1_r01
ANDROID_API_13_VERSION=3.2_r01

# Make debug versions of host applications (Qt Creator and installer).
MAKE_DEBUG_HOST_APPS=0

MAKE_DEBUG_GDBSERVER=0

NDK_VER=r6

# Refers to the gdb branches and folder structure on
# git://gitorious.org/toolchain-mingw-android/mingw-android-toolchain-gdb.git
GDB_BRANCH=fsf_head
GDB_ROOT_PATH=
# This is the name given to the created package.
GDB_VER=7.3.50.20110709
# We apply ndk r6 patches and can't use the cutting edge version of ndk gcc anyway (due to crtbegin_so.o, crtend_so.o changes)
GCC_GIT_DATE=2011-02-27
#GDB_BRANCH=master
#GDB_ROOT_PATH=gdb
#GDB_VER=7.3

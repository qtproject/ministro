#!/bin/bash

mkdir mingw-temp
pushd mingw-temp

wget -c http://sourceforge.net/projects/infozip/files/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz/download
tar -xvzf unzip60.tar.gz
pushd unzip60
mingw32-make.exe -f win32/Makefile.gcc
cp unzip.exe /usr/local/bin
popd

wget -c http://downloads.sourceforge.net/sevenzip/7za920.zip
SEVEN7LOC=$PWD
pushd /usr/local/bin
unzip -o $SEVEN7LOC/7za920.zip
popd

# Get git. Awkwardly, git is packed up with a full mingw/msys env, so unzip
# it to a temporary folder and copy across only certain bits, also, copy them
# to /usr/local/bin so as not to pollute /usr/bin
wget -c http://msysgit.googlecode.com/files/PortableGit-1.7.4-preview20110204.7z
mkdir git-temp
"C:\Program Files\7-zip\7z.exe" x -y -ogit-temp PortableGit-1.7.4-preview20110204.7z
mkdir -p /usr/local/bin
cp git-temp/bin/git* /usr/local/bin/
cp git-temp/bin/ssh* /usr/local/bin/
cp git-temp/bin/msys-crypto* /usr/local/bin/
cp git-temp/bin/msys-minires* /usr/local/bin/
cp git-temp/bin/libcurl-4.dll /usr/local/bin/
cp git-temp/bin/libcrypto.dll /usr/local/bin/
cp git-temp/bin/libssl.dll /usr/local/bin/
cp git-temp/bin/gpg.exe /usr/local/bin/
cp git-temp/bin/libiconv2.dll /usr/local/bin/
mkdir -p /usr/local/share
cp -r git-temp/share/git-core /usr/local/share/
cp -r git-temp/share/gitk /usr/local/share/
mkdir -p /usr/local/libexec
cp -r git-temp/libexec/* /usr/local/libexec/

# Fix mingw include/sys/types.h so that cross libgcc builds.
cat > ./mingw-sys-types-caddr.patch <<DELIM
--- /include-orig/sys/types.h   2009-11-28 07:12:40 +0000
+++ /include/sys/types.h        2010-06-17 21:28:23 +0100
@@ -14,6 +14,11 @@
 /* All the headers include this file. */
 #include <_mingw.h>
 
+/* Added by Ray Donnelly (mingw.android@gmail.com). libgcc build fails for Android 
+   cross gcc without this. I should find another way as this is a horrible thing to do. */
+typedef        int     daddr_t;
+typedef        char *  caddr_t;
+
 #define __need_wchar_t
 #define __need_size_t
 #define __need_ptrdiff_t
DELIM

PATCHFILE=`pwd`/mingw-sys-types-caddr.patch

pushd .
cd /usr/include
patch -p0 < $PATCHFILE
popd

mkdir -p /usr/local/bin
mkdir -p /usr/local/include

# Remove the MinGW iconv.exe and dll, we require a static iconv.
mv /usr/bin/iconv.exe /usr/local/bin/
mv /usr/bin/libiconv-2.dll /usr/local/bin/
mv /usr/include/iconv.h /usr/local/include/
mv /usr/lib/libintl.dll.a /usr/local/lib
mv /usr/lib/libintl.a /usr/local/lib

# Download and compile new iconv.
wget -c http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
rm -rf libiconv-1.14
tar -xvzf libiconv-1.14.tar.gz
pushd libiconv-1.14
CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=/usr  CFLAGS=-O3
make
# Without the /mingw folder, this fails, but only after copying libiconv.a to the right place.
make install
cp include/iconv.h /usr/include
popd

wget -c http://ftp.gnu.org/pub/gnu/gettext/gettext-0.18.1.1.tar.gz
rm -rf gettext-0.18.1.1
tar -xvzf gettext-0.18.1.1.tar.gz
pushd gettext-0.18.1.1
CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=/usr  CFLAGS=-O3
make
make install
popd

# For mingw Python. Generate libmsi.a and copy msi.h, msidefs.h, msimcntl.h, msimcsdk.h, msiquery.h, fci.h to /usr/include.
wget -c http://downloads.sourceforge.net/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/sezero_20101003/mingw-w32-bin_i686-mingw_20101003_sezero.zip
mkdir mingw64-w32-temp
unzip -d mingw64-w32-temp mingw-w32-bin_i686-mingw_20101003_sezero.zip

cp mingw64-w32-temp/mingw32/i686-w64-mingw32/include/msi*.h /usr/include
cp mingw64-w32-temp/mingw32/i686-w64-mingw32/include/fci.h /usr/include
cp mingw64-w32-temp/mingw32/i686-w64-mingw32/include/inaddr.h /usr/include/inaddr.h
cp mingw64-w32-temp/mingw32/bin/gendef.exe /usr/local/bin

if [ ! -z $ProgramW6432 ] ; then
    cp C:/Windows/SysWOW64/msi.dll ./msi.dll
    cp C:/Windows/SysWOW64/cabinet.dll ./cabinet.dll
    cp C:/Windows/SysWOW64/rpcrt4.dll ./rpcrt4.dll
else
    cp C:/Windows/System32/msi.dll ./msi.dll
    cp C:/Windows/System32/cabinet.dll ./cabinet.dll
    cp C:/Windows/System32/rpcrt4.dll ./rpcrt4.dll
fi

# If don't pass -a (assume stdcall if ambiguous, then link fails to find MsiGetLastErrorRecord, unfortunately we get warnings with this:
# Warning: resolving _MsiGetLastErrorRecord@0 by linking to _MsiGetLastErrorRecord, Warning: resolving _MsiRecordGetInteger@8 by linking to _MsiRecordGetInteger
# Use --enable-stdcall-fixup to disable these warnings

gendef - msi.dll > msi.def
gendef - cabinet.dll > cabinet.def

gendef - rpcrt4.dll > rpcrt4.def
cp msi.dll /usr/bin

cp cabinet.dll /usr/bin
cp rpcrt4.dll /usr/bin
dlltool -C -D --export-all-symbols MSI.dll -A -d msi.def -l libmsi.a
dlltool -C -D --export-all-symbols CABINET.dll -A -d cabinet.def -l libcabinet.a
dlltool -C -D --export-all-symbols RPCRT4.dll -A -d rpcrt4.def -l librpcrt4.a

mv libmsi.a /usr/lib
mv libcabinet.a /usr/lib
mv librpcrt4.a /usr/lib
rm -rf mingw64-w32-temp

popd
rm -rf mingw-temp
rm -rf /etc/fstab

exit

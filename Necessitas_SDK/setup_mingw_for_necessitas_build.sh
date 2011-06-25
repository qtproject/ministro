#!/bin/bash

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

mkdir -p /usr/local/bin
mkdir -p /usr/local/include

# Remove the MinGW iconv.exe and dll, we require a static iconv.
mv /usr/bin/iconv.exe /usr/local/bin/
mv /usr/bin/libiconv-2.dll /usr/local/bin/
mv /usr/include/iconv.h /usr/local/include/

# Download and compile new iconv.
wget -c http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.13.tar.gz
rm -rf libiconv-1.13
tar -xvzf libiconv-1.13.tar.gz
pushd libiconv-1.13
CFLAGS=-O2 && ./configure --enable-static --disable-shared --with-curses=$install_dir --enable-multibyte --prefix=/usr  CFLAGS=-O3
make && make DESTDIR=/usr install
popd

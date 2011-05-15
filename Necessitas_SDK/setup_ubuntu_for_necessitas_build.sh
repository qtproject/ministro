#!/bin/sh

# Sets up an clean Ubuntu 11.04 install for using (or building) Necessitas SDK.

# For Oracle's Java; see:
# http://www.ozmox.com/2011/04/30/installing-sun-oracle-java-6-jrejdk-on-ubuntu-11/
sudo add-apt-repository ppa:ferramroberto/java

sudo apt-get update

sudo apt-get install aptitude

sudo apt-get install p7zip-full

# Dev tools.
sudo apt-get install git-core gitk git-gui git-doc curl

# Needed for QtWebKit.
sudo apt-get install gperf

# Dev libs.
sudo apt-get install zlib1g-dev

# Oracle's Java6; select it when asked.
sudo apt-get install sun-java6-jdk sun-java6-jre
sudo update-alternatives --config java

# Dev tools needed for compiling gcc.
sudo apt-get install flex bison autoconf texinfo build-essential

# Libraries needed for compiling ??bit gcc (i.e. I might need to find 32 bit versions)
sudo apt-get install python2.7-dev xorg-dev

# Libraries needed for compiling 32bit gcc.
sudo apt-get install lib32gmp3-dev lib32mpfr-dev lib32ncurses5-dev
# There's no 32bit versoin of this? libmpc-dev 

# Libraries needed for compiling 64bit gcc.
# sudo apt-get install libgmp3-dev libmpfr-dev libncurses5-dev 


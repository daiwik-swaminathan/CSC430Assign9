#!/bin/sh
LUA=lua-5.1.4
ONIG=onig-5.9.2
LREX=lrexlib-2.4.0
LPTY=lpty-0.9-1

`which ruby > /dev/null`
if  [ "$?" -ne "0" ] 
then
	echo Ruby not found in path. Please install Ruby or add it to your path.
	exit
fi

`which gem > /dev/null`
if [ "$?" = "127" ]
then
	echo Could not find RubyGems. Please install it.
fi

`gem list | grep treetop`

if [ "$?" -ne "0" ]
then
	echo Could not find Treetop gem. Please install it via: gem install treetop
	exit
fi

SYSTEM=`uname`

if [ "$SYSTEM" = "Linux" ]
then
	SYSTEM="linux"
elif [ "$SYSTEM" = "Darwin" ]
then
	SYSTEM="osx"
else
	echo Unsupported system: $SYSTEM
	exit -1
fi

BRATPATH=`pwd`
SRC=$BRATPATH/src/$SYSTEM
LIB=$BRATPATH/lib

cd $SRC

echo Building Lua
#Build Lua
cd $LUA

if [ "$SYSTEM" = "osx" ]
then
	make macosx
elif [ "$SYSTEM" = "linux" ]
then
	make linux
fi

#Copy to bin/lua
make install INSTALL_TOP=$BRATPATH/bin/lua

echo Building Oniguruma
cd $SRC/$ONIG
./configure && make

if [ "$SYSTEM" = "osx" ]
then
	#Copy to lib/
	cp -f .libs/libonig.2.0.0.dylib $LIB/

	#Do symbolic links
	cd $LIB
	ln -s libonig.2.0.0.dylib libonig.2.dylib
	ln -s libonig.2.0.0.dylib libonig.dylib

elif [ "$SYSTEM" = "linux" ]
then
	#Copy to lib/
	cp -f .libs/libonig.so.2.0.0 $LIB

	#Do symbolic links
	cd $LIB
	ln -s libonig.so.2.0.0 libonig.so.2
	ln -s libonig.so.2.0.0 libonig.so
fi

echo Building lrexlib
cd $SRC/$LREX
make

#Copy lrexlib to lib/
cp -f src/oniguruma/rex_onig.so.2.4 $LIB
cp -f src/onigurum/librex_onig.a $LIB
cd $LIB
ln -s rex_onig.so.2.4 rex_onig.so

echo Building luafilesystem
cd $SRC/luafilesystem
make

cp -f src/lfs.so $LIB

echo Building md5
cd $SRC/md5
make
cp -f md5.so $LIB

echo Building readline
cd $SRC/readline

if [ "$SYSTEM" = "linux" ]
then
	gcc -fPIC -shared readline.c -o readline.so
elif [ "$SYSTEM" = "osx" ]
then
	gcc -bundle -undefined dynamic_lookup readline.c -o readline.so
fi

mv -f readline.so $LIB

echo Building lpty
cd $SRC/$LPTY
make
cp -f lpty.so $LIB

echo Building parser
cd $BRATPATH/parser
tt brat.treetop

echo Cleaning up...

cd $SRC/$LUA
make clean

cd $SRC/$ONIG
make clean
rm -rf $SRC/$ONIG/.deps

cd $SRC/$LREX
make clean

cd $SRC/luafilesystem
make clean

cd $SRC/md5
make clean

cd $SRC/$LPTY
make clean

cd $BRATPATH

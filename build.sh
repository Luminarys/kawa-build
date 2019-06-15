#!/bin/sh

set -e
set -u

jflag=
jval=2
rebuild=0
download_only=0
uname -mpi | grep -qE 'x86|i386|i686' && is_x86=1 || is_x86=0

while getopts 'j:Bd' OPTION
do
  case $OPTION in
  j)
      jflag=1
      jval="$OPTARG"
      ;;
  B)
      rebuild=1
      ;;
  d)
      download_only=1
      ;;
  ?)
      printf "Usage: %s: [-j concurrency_level] (hint: your cores + 20%%) [-B] [-d]\n" $(basename $0) >&2
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))

if [ "$jflag" ]
then
  if [ "$jval" ]
  then
    printf "Option -j specified (%d)\n" $jval
  fi
fi

[ "$rebuild" -eq 1 ] && echo "Reconfiguring existing packages..."
[ $is_x86 -ne 1 ] && echo "Not using yasm or nasm on non-x86 platform..."

cd `dirname $0`
ENV_ROOT=`pwd`
. ./env.source

#if you want a rebuild
#rm -rf "$DEP_DIR" "$TARGET_DIR"
mkdir -p "$DEP_DIR" "$TARGET_DIR" "$DOWNLOAD_DIR" "$BIN_DIR"

#download and extract package
download(){
  filename="$1"
  if [ ! -z "$2" ];then
    filename="$2"
  fi
  ../download.pl "$DOWNLOAD_DIR" "$1" "$filename" "$3" "$4"
  #disable uncompress
  REPLACE="$rebuild" CACHE_DIR="$DOWNLOAD_DIR" ../fetchurl "http://cache/$filename"
}

echo "#### kawa dependency build ####"

#this is our working directory
cd $DEP_DIR

[ $is_x86 -eq 1 ] && download \
  "yasm-1.3.0.tar.gz" \
  "" \
  "fc9e586751ff789b34b1f21d572d96af" \
  "http://www.tortall.net/projects/yasm/releases/"

[ $is_x86 -eq 1 ] && download \
  "nasm-2.13.01.tar.gz" \
  "" \
  "16050aa29bc0358989ef751d12b04ed2" \
  "http://www.nasm.us/pub/nasm/releasebuilds/2.13.01/"

download \
  "v1.2.11.tar.gz" \
  "zlib1.2.11.tar.gz" \
  "0095d2d2d1f3442ce1318336637b695f" \
  "https://github.com/madler/zlib/archive"

download \
  "lame-3.99.5.tar.gz" \
  "" \
  "84835b313d4a8b68f5349816d33e07ce" \
  "http://downloads.sourceforge.net/project/lame/lame/3.99"

download \
  "opus-1.1.2.tar.gz" \
  "" \
  "1f08a661bc72930187893a07f3741a91" \
  "https://github.com/xiph/opus/releases/download/v1.1.2"

download \
    "v1.3.5.tar.gz" \
    "vorbis1.3.5.tar.gz" \
    "17dd693e2148a2af9604df6b65341f73" \
    "https://github.com/xiph/vorbis/archive/"

download \
    "v1.3.2.tar.gz" \
    "ogg1.3.2.tar.gz" \
    "b85628c0955c4c7608c468d57a82a183" \
    "https://github.com/xiph/ogg/archive/"

download \
  "n4.1.3.tar.gz" \
  "ffmpeg4.1.3.tar.gz" \
  "0192fd36ca1554de955fd4017946329c" \
  "https://github.com/FFmpeg/FFmpeg/archive"

download \
  "OpenSSL_1_0_2l.tar.gz" \
  "" \
  "86d02d7cb7250ee0bb5112c90293f8d9" \
  "https://github.com/openssl/openssl/archive"

[ $download_only -eq 1 ] && exit 0

TARGET_DIR_SED=$(echo $TARGET_DIR | awk '{gsub(/\//, "\\/"); print}')

if [ $is_x86 -eq 1 ]; then
    echo "*** Building yasm ***"
    cd $DEP_DIR/yasm*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    CC="musl-gcc" ./configure --prefix=$TARGET_DIR --bindir=$BIN_DIR
    make -j $jval
    make install
fi

if [ $is_x86 -eq 1 ]; then
    echo "*** Building nasm ***"
    cd $DEP_DIR/nasm*
    [ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
    CC="musl-gcc" ./configure --prefix=$TARGET_DIR --bindir=$BIN_DIR
    make -j $jval
    make install
fi

echo "*** Building zlib ***"
cd $DEP_DIR/zlib*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
CC="musl-gcc" CFLAGS="-fPIC" ./configure --prefix=$TARGET_DIR --static
make
make install

echo "*** Building mp3lame ***"
cd $DEP_DIR/lame*
# The lame build script does not recognize aarch64, so need to set it manually
uname -a | grep -q 'aarch64' && lame_build_target="--build=arm-linux" || lame_build_target=''
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
CC="musl-gcc" CFLAGS="-fPIC" ./configure --prefix=$TARGET_DIR --enable-nasm --disable-shared $lame_build_target
make
make install

echo "*** Building opus ***"
cd $DEP_DIR/opus*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
CC="musl-gcc" CFLAGS="-fPIC" ./configure --prefix=$TARGET_DIR --disable-shared
make
make install

echo "*** Building ogg ***"
cd $DEP_DIR/ogg*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
CC="musl-gcc" CFLAGS="-fPIC -O3" ./configure --prefix=$TARGET_DIR --enable-static --with-pic --enable-shared=no
make install

echo "*** Building vorbis ***"
cd $DEP_DIR/vorbis*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
./autogen.sh
CC="musl-gcc" CFLAGS="-fPIC -O3" ./configure --prefix=$TARGET_DIR --enable-static --enable-shared=no --with-pic
make
make install

# FFMpeg
echo "*** Building FFmpeg ***"
cd $DEP_DIR/FFmpeg*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
PATH="$BIN_DIR:$PATH" \
PKG_CONFIG_PATH="$TARGET_DIR/lib/pkgconfig" ./configure \
  --cc="musl-gcc" \
  --prefix="$TARGET_DIR" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$TARGET_DIR/include" \
  --extra-ldflags="-L$TARGET_DIR/lib" \
  --extra-ldexeflags="-static" \
  --bindir="$BIN_DIR" \
  --enable-pic \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvorbis \
  --enable-static
PATH="$BIN_DIR:$PATH" make -j $jval
make install
make distclean

echo "*** Building OpenSSL ***"
cd $DEP_DIR/openssl*
[ $rebuild -eq 1 -a -f Makefile ] && make distclean || true
CC="musl-gcc" ./config --prefix=$TARGET_DIR
C_INCLUDE_PATH="$TARGET_DIR/include" make depend
make -j $jval
make install

echo "#### kawa dependency build complete ####"
hash -r

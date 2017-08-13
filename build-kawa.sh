#!/bin/sh

set -e
set -u

cd `dirname $0`
ENV_ROOT=`pwd`
. ./env.source
TARGET="x86_64-unknown-linux-musl"
BUILD_DIR="kawa-build"

echo "#### kawa static build ####"

#this is our working directory
cd $ENV_ROOT

echo "*** Checking out kawa ***"
if [ ! -d "$BUILD_DIR" ]
then
    git clone https://github.com/Luminarys/kawa $BUILD_DIR
fi
cd $BUILD_DIR
git checkout -qf $1
if [ $# -eq 2 ] && [ "$2" = "release" ]
then
    echo "*** Building kawa for release ***"
    cargo build --release --target=$TARGET
    cp target/$TARGET/release/kawa $ENV_ROOT/kawa
else
    echo "*** Building and testing kawa ***"
    cargo build --target=$TARGET
    cargo test --target=$TARGET
fi 

echo "#### kawa static build complete ####"
hash -r

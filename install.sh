#!/bin/sh

set -e

dir=$(uuidgen)-locgen_tmp
git clone https://github.com/Holdapp/locgen-swift.git $dir
cd $dir
swift build -c release
cp -f .build/release/locgen-swift /usr/local/bin/locgen-swift
cd -
rm -Rf $dir
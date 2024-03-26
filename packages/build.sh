#!/usr/bin/env bash

cd "$(dirname "$0")"

# Tracy
pushd odin-tracy
c++ -std=c++11 -DTRACY_ENABLE -O2 tracy/public/TracyClient.cpp -c -fPIC -o tracy.o
ar rcs libtracy.a tracy.o
popd

# Dear imgui
pushd odin-imgui
python3 build.py
popd

# nuklear
pushd odin-nuklear
cc -c nuklear.c -std=c99 -o nuklear.o -g
ar rcs nuklear_linux.a nuklear.o
popd

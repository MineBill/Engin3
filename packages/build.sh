#!/usr/bin/env bash

cd "$(dirname "$0")"

# Check if an argument is provided
if [ -z "$1" ]; then
    # If no argument is provided, build all
    build_all
else
    # If an argument is provided, build the specified target
    case "$1" in
        "tracy")
            build_tracy
            ;;
        "imgui")
            build_imgui
            ;;
        "nuklear")
            build_nuklear
            ;;
        *)
            echo "Invalid argument. Valid options are: tracy, imgui, nuklear"
            ;;
    esac
fi

exit 0

build_all() {
    build_tracy
    build_imgui
    build_nuklear
}

build_tracy() {
    # Tracy
    pushd odin-tracy
    c++ -std=c++11 -DTRACY_ENABLE -DTRACY_ON_DEMAND -O2 tracy/public/TracyClient.cpp -c -fPIC -o tracy.o
    ar rcs libtracy.a tracy.o
    popd
}

build_imgui() {
    # Dear imgui
    pushd odin-imgui
    python3 build.py
    popd
}

build_nuklear() {
    # nuklear
    pushd odin-nuklear
    cc -c nuklear.c -std=c99 -o nuklear.o -g
    ar rcs nuklear_linux.a nuklear.o
    popd
}

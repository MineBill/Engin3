#!/usr/bin/env bash

cd "$(dirname "$0")"

build_all() {
    build_tracy
    build_imgui
    build_nuklear
    build_jolt
    build_lua
}

build_tracy() {
    # Tracy
    echo "Building Tracy..."
    pushd odin-tracy
    c++ -std=c++11 -DTRACY_ENABLE -DTRACY_ON_DEMAND -O2 tracy/public/TracyClient.cpp -c -fPIC -o tracy.o
    ar rcs libtracy.a tracy.o
    popd
}

build_imgui() {
    # Dear imgui
    echo "Building Dear ImGui and generating bindings..."
    pushd odin-imgui
    python3 build.py
    popd
}

build_nuklear() {
    # nuklear
    echo "Building Nuklear..."
    pushd odin-nuklear
    cc -c nuklear.c -std=c99 -o nuklear.o -g
    ar rcs nuklear_linux.a nuklear.o
    popd
}

build_jolt() {
    # jolt
    echo "Building Jolt Physics and generating bindings..."
    pushd jolt
    # Check for .venv and create it if it doesn't exist
    # python -m venv .venv
    source .venv/bin/activate
    python -m pip install -r requirements.txt
    python jolt_make_odin_bindings.py

    sh jolt_bindings.sh
    popd
}

build_lua() {
    echo "Building LUA..."
    pushd odin-lua/lua_src
    cc -DLUA_USE_LINUX *.c -c
    ar rcvs lua546.a *.o
    cp lua546.a ../bin/linux
    rm *.o
    rm lua546.a
    popd
}

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
        "jolt")
            build_jolt
            ;;
        "lua")
            build_lua
            ;;
        *)
            echo "Invalid argument. Valid options are: tracy, imgui, nuklear, jolt, lua"
            ;;
    esac
fi

exit 0


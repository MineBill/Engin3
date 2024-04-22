#!/usr/bin/env sh

# Check if clang is in the PATH
if ! command -v clang &> /dev/null; then
    echo "WARNING: clang is not in the path - please make sure clang is installed and accessible."
fi

# Create build directory if it doesn't exist
mkdir -p build
cd build || exit

# Get the machine hardware name
machine=$(uname -m)
CXX_DEFINES=""
CommonCompilerFlagsNoLink=""
# Check if the machine hardware name contains "arm"
if [[ $machine == *"arm"* ]]; then
    echo "ARM CPU detected. Removing sse avx and fp16 flags"
    CXX_DEFINES="-DJPH_DEBUG_RENDERER -DJPH_PROFILE_ENABLED  -DJPH_USE_FMADD -DJPH_USE_LZCNT -DJPH_USE_TZCNT "
    CommonCompilerFlagsNoLink="-std=c++17 -g -c -Wall  -Werror  -Wno-unused-function -Wno-unused-const-variable ${CXX_DEFINES}"
else
    echo "Not an ARM CPU."
    CXX_DEFINES="-DJPH_DEBUG_RENDERER -DJPH_PROFILE_ENABLED -DJPH_USE_AVX -DJPH_USE_AVX2 -DJPH_USE_F16C -DJPH_USE_FMADD -DJPH_USE_LZCNT -DJPH_USE_SSE4_1 -DJPH_USE_SSE4_2 -DJPH_USE_TZCNT -D_DEBUG"
    CommonCompilerFlagsNoLink="-std=c++17 -g -c -Wall  -Werror  -Wno-unused-function -Wno-unused-const-variable -mavx2 -mavx -msse4.1 -msse4.2 ${CXX_DEFINES}"
fi
# Set common compiler flags (without linking)
# Jolt will do some checking to ensure that the same definitions are used between it and the client (jolt_bind.cpp).
# I've taken these defines from JoltPhysics/Build/Linux_Debug/CMakeFiles/Jolt.dir/flags.make to ensure they are the same

# Compile the source file
clang++ $CommonCompilerFlagsNoLink -I../JoltPhysics ../jolt_bind.cpp -o jolt_bind.o

# Compile Jolt
pushd ../JoltPhysics/Build/

# NOTE(minebill): The build mode for all libraries should be handled by a switch somewhere.
rm -rf Linux_Debug
sh ./cmake_linux_clang_gcc.sh Debug clang++ -DTARGET_UNIT_TESTS=OFF -DTARGET_HELLO_WORLD=OFF -DTARGET_PERFORMANCE_TEST=OFF -DTARGET_SAMPLES=OFF -DTARGET_VIEWER=OFF
cd Linux_Debug
make -j 8
popd
cp ../JoltPhysics/Build/Linux_Debug/libJolt.a .

# Check if compilation was successful
if [ $? -eq 0 ]; then
    # Create static library (.a) from object file
    # To correctly link with jolt we need to extract the object files
    # from libJolt and use them to building jolt_binds.a
    if [[ "$os_name" == "Darwin" ]]; then
        if [[ $machine == *"arm"* ]]; then
            echo "ARM CPU detected using lipo to extract arm objectfile."
            lipo libJolt.a -thin arm64 -output libJolt_arch.a
            ar -x libJolt_arch.a
            ar rcvs jolt_bind.a *.o
            rm *.o
        else
            echo "INTEL OR OTHER CPU detected using lipo to extract x64 objectfile."
            lipo libJolt.a -thin x86_64 -output libJolt_arch.a
            ar -x libJolt_arch.a
            ar rcvs jolt_bind.a *.o
            rm *.o
        fi
    else
        echo "Not running on macOS probably linux"
        ar -x libJolt.a
        ar rcvs jolt_bind.a *.o
        rm *.o
    fi
else
    echo "Compilation failed. Please check the error messages above."
fi

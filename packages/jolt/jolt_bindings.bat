@ECHO off
SETLOCAL

where cl >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (ECHO WARNING: cl is not in the path - please set up Visual Studio to do cl builds)

PUSHD JoltPhysics\Build
CALL cmake_vs2022_cl.bat -DUSE_STATIC_MSVC_RUNTIME_LIBRARY=OFF -DINTERPROCEDURAL_OPTIMIZATION=OFF -DTARGET_UNIT_TESTS=OFF -DTARGET_HELLO_WORLD=OFF -DTARGET_PERFORMANCE_TEST=OFF -DTARGET_SAMPLES=OFF -DTARGET_VIEWER=OFF
PUSHD VS2022_CL
msbuild.exe Jolt.vcxproj /property:Configuration=Release
COPY Release\Jolt.lib ..\..\..\build
POPD
POPD

IF NOT EXIST build MKDIR build
PUSHD build

SET CommonCompilerFlagsNoLink= -std:c++17 -EHsc -c /MD -nologo -fp:fast -Gm- -GR- -sdl- -EHa- -Od -Oi -WX -W4 -wd4457 -wd4018 -wd4459 -wd4389 -wd4312 -wd4245 -wd4996 -wd4201 -wd4100 -wd4506 -wd4127 -wd4189 -wd4505 -wd4577 -wd4101 -wd4702 -wd4456 -wd4238 -wd4244 -wd4366 -wd4700 -wd4701 -wd4703 -wd4805 -wd4091 -wd4706 -wd4197 -wd4324 -FC -ZI -DJPH_PROFILE_ENABLED -DJPH_DEBUG_RENDERER -DJPH_FLOATING_POINT_EXCEPTIONS_ENABLED -DJPH_USE_AVX2 -DJPH_USE_AVX -DJPH_USE_SSE4_1 -DJPH_USE_SSE4_2 -DJPH_USE_LZCNT -DJPH_USE_TZCNT -DJPH_USE_F16C -DJPH_USE_FMADD
cl %CommonCompilerFlagsNoLink% /I"../JoltPhysics" ../jolt_bind.cpp
lib /OUT:jolt_bind.lib Jolt.lib jolt_bind.obj

POPD

@echo off

CD /D "%~dp0"

REM Tracy
PUSHD odin-tracy
CALL vcvarsall x64
cl -MT -O2 -DTRACY_ENABLE -c tracy\public\TracyClient.cpp -Fotracy
lib tracy.obj
del tracy.obj
POPD

REM Dear imgui
PUSHD odin-imgui
python3 build.py
POPD

REM nuklear
PUSHD odin-nuklear
CALL vcvarsall x64
cl -c nuklear.c -Fonuklear -O2
lib nuklear.obj
del nuklear.obj
move nuklear.lib nuklear_windows_amd64.lib
POPD

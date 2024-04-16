@echo off

CD /D "%~dp0"

REM Check if an argument is provided
IF "%1"=="" (
    REM If no argument is provided, build all
    CALL :BuildAll
) ELSE (
    REM If an argument is provided, build the specified target
    IF /I "%1"=="tracy" (
        CALL :BuildTracy
    ) ELSE IF /I "%1"=="imgui" (
        CALL :BuildImGui
    ) ELSE IF /I "%1"=="nuklear" (
        CALL :BuildNuklear
    ) ELSE IF /I "%1"=="jolt" (
        CALL :BuildJolt
    ) ELSE (
        ECHO Invalid argument. Valid options are: tracy, imgui, nuklear, jolt
    )
)

REM Exit the script
EXIT /B

:BuildAll
REM Build all targets
CALL :BuildTracy
CALL :BuildImGui
CALL :BuildNuklear
EXIT /B

:BuildTracy
REM Tracy
PUSHD odin-tracy
CALL vcvarsall x64
cl /MD -O2 -DTRACY_ENABLE -DTRACY_ON_DEMAND -c tracy\public\TracyClient.cpp -Fotracy
lib tracy.obj
del tracy.obj
POPD
EXIT /B

:BuildImGui
REM Dear imgui
PUSHD odin-imgui
python3 build.py
POPD
EXIT /B

:BuildNuklear
REM nuklear
PUSHD odin-nuklear
CALL vcvarsall x64
cl -c nuklear.c -Fonuklear -O2
lib nuklear.obj
del nuklear.obj
move nuklear.lib nuklear_windows_amd64.lib
POPD
EXIT /B

:BuildJolt
REM jolt
PUSHD jolt
CALL vcvarsall x64

CALL .venv\Scripts\activate.bat
python -m pip install -r requirements.txt
python jolt_make_odin_bindings.py

call jolt_bindings.bat
POPD
EXIT /B

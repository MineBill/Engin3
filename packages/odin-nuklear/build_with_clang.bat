@echo off

clang -c nuklear.c -std=c99 -o nuklear.obj -g
llvm-lib nuklear.obj
del nuklear.obj
move nuklear.lib nuklear_windows_amd64.lib

package lua

import "core:c"

when JIT_ENABLED { 
    REGISTRYINDEX :: -10000 
    ENVIRONINDEX :: -10001
    GLOBALSINDEX :: -10002

    jit_setglobal :: proc "c" (L: ^State, s: cstring) {
        setfield(L, GLOBALSINDEX, s)
    }

    jit_getglobal :: proc "c" (L: ^State, s: cstring) -> c.int {
        return getfield(L, GLOBALSINDEX, s)
    }
}
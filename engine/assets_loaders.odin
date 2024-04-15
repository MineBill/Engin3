package engine
import gltf "vendor:cgltf"
import "core:log"
import "core:strings"
import gl "vendor:OpenGL"
import "packages:odin-lua/lua"
import "packages:odin-lua/luaL"
import c "core:c/libc"
import "core:mem"
import "base:runtime"
import "core:os"
import "core:slice"

@(loader=LuaScript)
lua_script_loader :: proc(data: []byte) -> ^Asset {
    script := new(LuaScript)
    script.type = .LuaScript

    // script^ = compile_script(g_scriptinEngineInstance, data)

    return script
}

@(loader=Shader)
shader_loader :: proc(data: []byte) -> ^Asset {
    shader := new(Shader)
    shader.type = .Shader

    // data is the binary shader code.

    return shader
}

@(loader=Mesh)
load_mesh :: proc(data: []byte) -> ^Asset {
    return nil
}

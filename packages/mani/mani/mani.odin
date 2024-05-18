package mani

import lua "packages:odin-lua/lua"
import luaL "packages:odin-lua/luaL"
import strings "core:strings"
import "core:c"
import "core:fmt"
import "base:runtime"

LuaName :: distinct string
OdinName :: distinct string
ManiName :: distinct string

MetatableData :: struct {
    name: cstring,
    odin_type: typeid,
    index: lua.CFunction,
    newindex: lua.CFunction,
    methods: map[cstring]lua.CFunction,
}

LuaExport :: struct {
    pkg: string,
    lua_name: LuaName,
    odin_name: OdinName,
}


ProcExport :: struct {
    using base: LuaExport,
    mani_name: ManiName,
    lua_proc: lua.CFunction,
    module: Maybe(string),
}

// Note(Dragos): Test performance
FieldSetProc :: #type proc(L: ^lua.State, s: rawptr, field: string) 
FieldGetProc :: #type proc(L: ^lua.State, s: rawptr, field: string) 


StructFieldExport :: struct {
    lua_name: LuaName,
    odin_name: OdinName,
    type: typeid,
}

StructExport :: struct {
    using base: LuaExport,
    type: typeid,
    fields: map[LuaName]StructFieldExport, // Not needed for now
    light_meta: Maybe(MetatableData),
    full_meta: Maybe(MetatableData),
    methods: map[LuaName]lua.CFunction,
}

EnumExport :: struct {
    name: string,
    fields: map[string]int,
}

// TODO(Add lua state in here aswell) (then we can have a single init function instead of export_all)
State :: struct {
    lua_state: ^lua.State,
    global_procs: map[OdinName]ProcExport, // Key: odin_name
    modules: map[string]map[OdinName]ProcExport,
    structs: map[typeid]StructExport, // Key: type 
    enums: map[string]EnumExport,
    udata_metatable_mapping: map[typeid]cstring, // Key: odin type; Value: lua name
}

global_state := State {
    global_procs = make(map[OdinName]ProcExport),
    modules = make(map[string]map[OdinName]ProcExport),
    structs = make(map[typeid]StructExport),
    enums = make(map[string]EnumExport),
    udata_metatable_mapping = make(map[typeid]cstring),
}

g_global_context: runtime.Context
// default_context: proc "contextless" () -> runtime.Context = nil
default_context :: proc "contextless" () -> runtime.Context {
    return g_global_context
}

add_function :: proc(v: ProcExport) {
    using global_state 
    if module_name, ok := v.module.?; ok {
        if module_name not_in modules {
            modules[module_name] = make(map[OdinName]ProcExport)
        }
        module := &modules[module_name]
        module[v.odin_name] = v
    } else {
        global_procs[v.odin_name] = v
    }
}

add_struct :: proc(s: StructExport) {
    using global_state 
    structs[s.type] = s
    if light, ok := s.light_meta.?; ok {
        udata_metatable_mapping[light.odin_type] = light.name
    }

    if full, ok := s.full_meta.?; ok {
        udata_metatable_mapping[full.odin_type] = full.name
    }
}

add_enum :: proc(s: EnumExport) {
    global_state.enums[s.name] = s
}

init :: proc(L: ^lua.State, using state: ^State, ctx := context) {
    lua_state = L
    for key, val in structs {
        using val 
        if light, ok := light_meta.?; ok {
            assert(light.index != nil && light.newindex != nil)
            luaL.newmetatable(L, light.name)
            lua.pushcfunction(L, light.index)
            lua.setfield(L, -2, "__index")
            lua.pushcfunction(L, light.newindex)
            lua.setfield(L, -2, "__newindex")
            

            if light.methods != nil {
                for name, method in light.methods {
                    lua.pushcfunction(L, method)
                    lua.setfield(L, -2, name)
                }
            }

            lua.pop(L, 1)
        }
        if full, ok := full_meta.?; ok {
            assert(full.index != nil && full.newindex != nil)
            luaL.newmetatable(L, full.name)
            lua.pushcfunction(L, full.index)
            lua.setfield(L, -2, "__index")
            lua.pushcfunction(L, full.newindex)
            lua.setfield(L, -2, "__newindex")

            if full.methods != nil {
                for name, method in full.methods {
                    lua.pushcfunction(L, method)
                    lua.setfield(L, -2, name)
                }
            }

            lua.pop(L, 1)
        }
    }
    for key, val in global_procs {
        lua.pushcfunction(L, val.lua_proc)
        cstr := strings.clone_to_cstring(cast(string)val.lua_name, context.temp_allocator)
        lua.setglobal(L, cstr)
    }

    for module, procs in modules {
        lua.newtable(L)

        for name, p in procs {
            lua.pushcfunction(L, p.lua_proc)
            lua.setfield(L, -2, strings.clone_to_cstring(string(p.lua_name), context.temp_allocator))
        }

        cstr := strings.clone_to_cstring(module, context.temp_allocator)
        lua.setglobal(L, cstr)
    }

    for name, enum_export in enums {
        lua.newtable(L)

        for field_name, field_value in enum_export.fields {
            lua.pushinteger(L, i64(field_value))
            cstr := strings.clone_to_cstring(field_name, context.temp_allocator)
            lua.setfield(L, -2, cstr)
        }

        cstr := strings.clone_to_cstring(string(name), context.temp_allocator)
        lua.setglobal(L, cstr)
    }
}

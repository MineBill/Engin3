package engine
import "packages:mani/mani"
import "packages:odin-lua/lua"
import "packages:odin-lua/luaL"
import c "core:c/libc"
import "base:runtime"
import intr "base:intrinsics"
import "core:reflect"
import "core:strings"
import "core:fmt"
import "core:path/filepath"

@(asset = {
    ImportFormats = ".lua",
})
LuaScript :: struct {
    using base: Asset,

    properties: Properties,
    bytecode: []byte,
}

InvalidPropertyNameError :: struct {
    property_name: string,
}

MetadataError :: enum {
    None,
    MissingTable,
    MissingName,
    ExportNotAStruct,
    DefaultValueIsNil,
    UnknownExportType,
}

ScriptMetadataError :: union {
    MetadataError,
    InvalidPropertyNameError,
}

LuaError :: enum {
    None,
    Syntax,
    Runtime,
    OutOfMemory,
    MessageHandler,
}

ScriptCompilationError :: union #shared_nil {
    LuaError,
    ScriptMetadataError,
}

ScriptType :: UUID

ScriptVTable :: struct {
    object: i64,
    instance_table: i64,

    on_init: i64,
    on_update: i64,
}

ScriptInstance :: struct {
    using vtable: ScriptVTable,

    state: ^lua.State,
    type: ScriptType,
}

script_set_field_value :: proc(instance: ^ScriptInstance, field: string, lua_value: LuaValue, stack_pos: Maybe(int) = nil) {
    L := instance.state
    begin_stack(L)

    if _, ok := stack_pos.?; ok {
        lua.rawgeti(L, lua.REGISTRYINDEX, instance.instance_table)
    }

    lua.pushstring(L, field)
    switch value in lua_value {
    case lua.Number:
        lua.pushnumber(L, value)
    case lua.Integer:
        lua.pushinteger(L, value)
    case string:
        lua.pushstring(L, value)
    case bool:
        lua.pushboolean(L, i32(value))
    case LuaTable:
        assert(false, "LuaTable not implemented")
    }
    if pos, ok := stack_pos.?; ok {
        lua.settable(L, i32(pos) - 2)
    } else {
        lua.settable(L, -3)
    }
}

script_set_field_type :: proc(instance: ^ScriptInstance, field: string, value: $T, stack_pos: Maybe(int) = nil)
    where T != LuaValue {
    L := instance.state
    begin_stack(L)

    if _, ok := stack_pos.?; ok {
        lua.rawgeti(L, lua.REGISTRYINDEX, instance.instance_table)
    }

    lua.pushstring(L, field)
    mani.push_value(L, value)
    if pos, ok := stack_pos.?; ok {
        lua.settable(L, i32(pos) - 2)
    } else {
        lua.settable(L, -3)
    }
}

script_set_field :: proc{
    script_set_field_value,
    script_set_field_type,
}

ScriptingEngine :: struct {
    managed_states: map[ScriptType]ScriptInstance,
}

create_scripting_engine :: proc() -> (engine: ScriptingEngine) {
    // Setup global mani context. It will be used by all
    // functions exported to lua.
    mani.g_global_context = context

    return
}

create_script_instance :: proc(script: ^LuaScript) -> (state: ScriptInstance) {
    if script == nil {
        return {}
    }

    log_debug(LC.ScriptingEngine, "Creating new script instance")
    state.state = luaL.newstate()
    L := state.state

    type := generate_uuid()
    luaL.openlibs(L)

    b := cstring(&script.bytecode[0])

    if luaL.loadbufferx(L, b, c.ptrdiff_t(len(script.bytecode)), "Script", "b") != lua.OK {
        log_error(LC.ScriptingEngine, "Error while doing string")
        return
    }

    if lua.pcall(L, 0, 1, 0) != lua.OK {
        log_error(LC.ScriptingEngine, "Failed to execute bytecode: %v", lua.tostring(L, -1))
        return
    }

    if !lua.istable(L, -1) {
        log_error(LC.ScriptingEngine, "Script did not return a global table.")
        return
    }
    state.object = i64(luaL.ref(L, lua.REGISTRYINDEX))
    lua.rawgeti(L, lua.REGISTRYINDEX, state.object)

    lua.getfield(L, -1, "on_init")
    if !lua.isfunction(L, -1) {
        log_error(LC.ScriptingEngine, "on_init is not a function")
        return
    }

    state.on_init = i64(luaL.ref(L, lua.REGISTRYINDEX))

    lua.getfield(L, -1, "on_update")
    if !lua.isfunction(L, -1) {
        log_error(LC.ScriptingEngine, "on_update is not a function")
        return
    }
    state.on_update = i64(luaL.ref(L, lua.REGISTRYINDEX))

    mani.init(L, &mani.global_state)
    return
}

compile_script :: proc(se: ^ScriptingEngine, data: []byte, strip := false) -> (script: LuaScript, error: ScriptCompilationError) {
    L := luaL.newstate()
    defer lua.close(L)
    luaL.openlibs(L)

    if lua_error := luaL.loadstring(L, cstr(string(data))); lua_error != lua.OK {
        message := lua.tostring(L, -1)
        log_error(LC.ScriptingEngine, "Error while compiling LUA: %s", message)

        switch lua_error {
        case lua.ERRSYNTAX:
            return {}, .Syntax
        case lua.ERRMEM:
            return {}, .OutOfMemory
        }
        // lua_error CANNOT be anything else, according to the documentation
        unreachable()
    }

    Writer :: struct {
        buffer: [dynamic]byte,
        ctx: runtime.Context,
    }
    w := Writer{
        buffer = make([dynamic]byte),
        ctx = context,
    }

    writer :: proc "c" (L: ^lua.State, p: cstring, sz: c.ptrdiff_t, ud: rawptr) -> c.int {
        w := cast(^Writer)ud
        context = w.ctx

        slice := ([^]byte)(rawptr(p))[:sz]
        append(&w.buffer, ..slice)

        return lua.OK
    }

    // Can't fail, out writer always return lua.OK
    lua.dump(L, writer, &w, 1 if strip else 0)

    script.bytecode = make([]byte, len(w.buffer))
    copy(script.bytecode, w.buffer[:])

    log_info(LC.ScriptingEngine, "Compiled lua script:")
    log_info(LC.ScriptingEngine, "\tDebug info stripped: %v", strip)
    log_info(LC.ScriptingEngine, "\tSize: %v bytes.", len(script.bytecode))

    // NOTE(minebill): Ideally, as soon as we got the bytecode, we would return.
    // However, we need to get some metadata about the script and we don't want to do that
    // whenever we create new instance.

    if lua_error := lua.pcall(L, 0, 1, 0); lua_error != lua.OK {
        log_error(LC.ScriptingEngine, "Failed to execute compiled bytecode while gathering script metadata.")

        switch lua_error {
        case lua.ERRRUN:
            return {}, .Runtime
        case lua.ERRMEM:
            return {}, .OutOfMemory
        case lua.ERRERR:
            return {}, .MessageHandler
        }
        unreachable()
    }

    if !lua.istable(L, -1) {
        log_error(LC.ScriptingEngine, "Script must return a table!")
        return {}, ScriptMetadataError(.MissingTable)
    }

    script.properties, error = read_properties_table(L)

    log_debug(LC.ScriptingEngine, "Script properties: %#v", script.properties)
    return
}

api_import :: proc "c" (L: ^lua.State) -> i32 {
    context = mani.default_context()

    path := luaL.checkstring(L, 1)
    PREFIX :: "proj://"
    if strings.contains(path, PREFIX) {
        new_path := path[len(PREFIX):]
        joined := filepath.join({get_cwd(), new_path}, context.temp_allocator)

        if luaL.dofile(L, cstr(joined)) != lua.OK {
            log_error(LC.ScriptingEngine, "Failed to import %v", joined)
            return 0
        }

        if lua.pcall(L, 0, 1, 0) != lua.OK {
            log_error(LC.ScriptingEngine, "Failed to execute import: %v", lua.tostring(L, -1))
            return 0
        }

        return 1
    } else {
        // If the path doesn't start with 'proj://', use default behavior
        lua.getglobal(L, "require")
        lua.pushvalue(L, 1) // Push the module name onto the stack
        lua.call(L, 1, 1)   // Call require with the module name

        return 1
    }

}

is_script_instance_valid :: proc(instance: ScriptInstance) -> bool {
    return instance.state != nil
}

@(deferred_in_out=end_stack)
begin_stack :: proc(L: ^lua.State) -> i32 {
    stack := lua.gettop(L)
    return stack
}

end_stack :: proc(L: ^lua.State, original: i32) {
    pop := lua.gettop(L) - original
    lua.pop(L, pop)
}

// TODO(minebill): Perform validation.
read_properties_table :: proc(L: ^lua.State) -> (props: Properties, error: ScriptMetadataError) {
    begin_stack(L)
    lua.getfield(L, -1, "Properties")
    {
        begin_stack(L)

        lua.getfield(L, -1, "Name")
        props.name = strings.clone(lua.tostring(L, -1))
        log_debug(LC.ScriptingEngine, "Name: %v", props.name)
    }

    lua.getfield(L, -2, "Export")
    {
        begin_stack(L)

        if !lua.istable(L, -1) {
            error = .ExportNotAStruct
            return
        }

        lua.pushnil(L)
        for lua.next(L, -2) != 0 {
            defer lua.pop(L, 1)
            key_type := lua.type(L, -2)
            value_type := lua.type(L, -1)
            if lua.isstring(L, -2) != 1 {
                error = InvalidPropertyNameError{}
                return
            }

            field := LuaField{}
            field.name = strings.clone(lua.tostring(L, -2))

            if lua.istable(L, -1) {
                log_debug(LC.ScriptingEngine, "%v => %v", lua.typename(L, key_type), lua.typename(L, value_type))

                lua.pushnil(L)
                for lua.next(L, -2) != 0 {
                    defer lua.pop(L, 1)

                    {
                        begin_stack(L)
                        lua.getfield(L, -3, "Default")
                        assert(!lua.isnil(L, -1), "Default value must exist, to determine the type.")

                        type := lua.type(L, -1)
                        switch type {
                        case lua.TNUMBER:
                            field.default = lua.tonumber(L, -1)
                        case lua.TSTRING:
                            field.default = strings.clone(lua.tostring(L, -1))
                        case lua.TBOOLEAN:
                            field.default = bool(lua.toboolean(L, -1))
                        case:
                            assert(false, "Unsupported export type.")
                        }
                    }

                    description: {
                        begin_stack(L)
                        lua.getfield(L, -3, "Description")
                        if lua.isnil(L, -1) do break description

                            field.description = strings.clone(lua.tostring(L, -1))
                    }
                }
            } else {
                if lua.isnil(L, -1) {
                    error = .DefaultValueIsNil
                    return
                }
                begin_stack(L)

                type := lua.type(L, -1)
                switch type {
                case lua.TNUMBER:
                    field.default = lua.tonumber(L, -1)
                case lua.TSTRING:
                    field.default = strings.clone(lua.tostring(L, -1))
                case lua.TBOOLEAN:
                    field.default = bool(lua.toboolean(L, -1))
                case:
                    return {}, .UnknownExportType
                }
            }

            props.fields[field.name] = field
        }
    }

    // Iterate over the rest of the fields and add them as private instance fields
    // {
    //     lua.pushnil(L)

    //     for lua.next(L, -3) != 0 {
    //         defer lua.pop(L, -1)
    //         key_type := lua.type(L, -2)
    //         value_type := lua.type(L, -1)

    //         if lua.isstring(L, -2) != 1 {
    //             return {}, InvalidPropertyNameError {}
    //         }
    //         assert(lua.isstring(L, -2) == 1 && lua.isnumber(L, -2) != 1, "You can't export a variable with a number for a name!")

    //         field := LuaField{}
    //         field.name = strings.clone(lua.tostring(L, -2))
    //         log_debug(LC.ScriptingEngine, "%v => %v", lua.typename(L, key_type), lua.typename(L, value_type))

    //         switch value_type {
    //         case lua.TNUMBER:
    //             field.default = lua.tonumber(L, -1)
    //         case lua.TSTRING:
    //             field.default = strings.clone(lua.tostring(L, -1)) // @Allocation
    //         case lua.TBOOLEAN:
    //             field.default = bool(lua.toboolean(L, -1))
    //         case:
    //             return {}, .UnknownExportType
    //         }

    //         props.instance_fields[field.name] = field
    //     }
    // }

    // lua.getfield(L, -3, "Instance")
    // instance: {
    //     begin_stack(L)

    //     if !lua.istable(L, -1) {
    //         break instance
    //     }

    //     lua.pushnil(L)
    //     for lua.next(L, -2) != 0 {
    //         defer lua.pop(L, 1)
    //         key_type := lua.type(L, -2)
    //         value_type := lua.type(L, -1)
    //         assert(lua.isstring(L, -2) == 1 && lua.isnumber(L, -2) != 1, "You can't export a variable with a number for a name!")
    //         // assert(lua.istable(L, -1), "You have to declare the variable in a table format")

    //         field := LuaField{}
    //         field.name = strings.clone(lua.tostring(L, -2))
    //         log_debug(LC.ScriptingEngine, "%v => %v", lua.typename(L, key_type), lua.typename(L, value_type))

    //         switch value_type {
    //         case lua.TNUMBER:
    //             field.default = lua.tonumber(L, -1)
    //         case lua.TSTRING:
    //             field.default = strings.clone(lua.tostring(L, -1))
    //         case lua.TBOOLEAN:
    //             field.default = bool(lua.toboolean(L, -1))
    //         case:
    //             assert(false, "Unsupported export type.")
    //         }

    //         props.instance_fields[field.name] = field
    //     }
    // }
    return
}

table_to_struct :: proc(L: ^lua.State, v: any) {
    // NOTE(minebill): Technically not needed.
    // assert(v.id in mani.global_state.structs, "Type is not exported to lua")

    for lua_name, field in mani.global_state.structs[v.id].fields {
        field_value := reflect.struct_field_value_by_name(v, string(field.odin_name))
        log_debug(LC.ScriptingEngine, "getfield, %v", field.lua_name)
        lua.getfield(L, -1, cstr(string(field.lua_name)))

        // The lua table doesn't contain this struct field.
        if lua.isnil(L, -1) {
            log_debug(LC.ScriptingEngine, "Skipped %v", field.lua_name)
            continue
        }

        switch field.type {
        case typeid_of(int):
            value := &field_value.(int)
            value^ = int(lua.tonumber(L, -1))
        case typeid_of(i32):
            value := &field_value.(i32)
            value^ = i32(lua.tonumber(L, -1))
        case typeid_of(i64):
            value := &field_value.(i64)
            value^ = i64(lua.tonumber(L, -1))
        case typeid_of(f32):
            value := &field_value.(f32)
            value^ = f32(lua.tonumber(L, -1))
        case typeid_of(f64):
            value := &field_value.(f64)
            value^ = f64(lua.tonumber(L, -1))
        case typeid_of(string):
            value := &field_value.(string)
            value^ = strings.clone(lua.tostring(L, -1))
        case:
            switch {
            case reflect.is_struct(type_info_of(field.type)):
                table_to_struct(L, &field_value)
            case:
                assert(false, "Type not supported")
            }
        }

        lua.pop(L, 1)
    }
}

LuaTable :: struct {
    fields: map[string]LuaValue,
}

LuaValue :: union {
    lua.Number,
    lua.Integer,
    bool,
    string,
    LuaTable,
}

LuaField :: struct {
    name:        string,
    default:     LuaValue,
    description: string,
    tag:         string,
}

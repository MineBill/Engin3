package engine
import "packages:odin-lua/lua"
import "packages:odin-lua/luaL"
import "core:runtime"
import "core:strings"
import "core:os"
import "core:reflect"
import "core:math/bits"
import "core:log"
import c "core:c/libc"
import intr "base:intrinsics"
import "core:io"
import "core:strconv"

SerializationMode :: enum {
    Serialize,
    Deserialize,
}

SerializeContext :: struct {
    L: ^lua.State,

    mode: SerializationMode,
    global_table: i64,
    is_global: bool,

    // Serialization Data
    array_index: int,
    table_count: int,
    table_names: [dynamic]string,
}

serialize_init :: proc(s: ^SerializeContext) {
    s.L = luaL.newstate()
    luaL.openlibs(s.L)
    s.is_global = true
    s.mode = .Serialize
}

serialize_init_data :: proc(s: ^SerializeContext, data: []byte) {
    s.L = luaL.newstate()
    L := s.L

    s.mode = .Deserialize
    s.is_global = true

    if len(data) <= 0 {
        log.error("data is empty")
        return
    }

    bytecode := cstring(&data[0])
    if luaL.loadbufferx(L, bytecode, c.ptrdiff_t(len(data)), "Config", "b") != lua.OK {
        log.error("Error reading bytecode")
        return
    }

    if lua.pcall(L, 0, 0, 0) != lua.OK {
        log.errorf("Error executing bytecode: %v", lua.tostring(L, -1))
        return
    }
}

serialize_init_file :: proc(s: ^SerializeContext, file_name: string) {
    s.L = luaL.newstate()
    L := s.L

    if luaL.loadfile(L, strings.clone_to_cstring(file_name, context.temp_allocator)) != lua.OK {
        log.error("Error reading bytecode")
        return
    }

    if lua.pcall(L, 0, 0, 0) != lua.OK {
        log.errorf("Error executing bytecode: %v", lua.tostring(L, -1))
        return
    }

    s.mode = .Deserialize
    s.is_global = true
}

serialize_deinit :: proc(s: ^SerializeContext) {
    lua.close(s.L)
    delete(s.table_names)
}

serialize_begin_table :: proc(s: ^SerializeContext, name: string) -> bool {
    L := s.L
    switch s.mode {
    case .Serialize:
        // begin_stack(L)
        lua.newtable(L)
        if s.table_count >= len(s.table_names) {
            append(&s.table_names, name)
        } else {
            s.table_names[s.table_count] = strings.clone(name)
        }
        s.table_count += 1

        if s.is_global {
            s.is_global = false
            s.global_table = i64(luaL.ref(L, lua.REGISTRYINDEX))
            lua.rawgeti(L, lua.REGISTRYINDEX, s.global_table)
        }
    case .Deserialize:
        name := strings.clone_to_cstring(name, context.temp_allocator)
        if s.is_global {
            lua.getglobal(L, name)
            s.is_global = false
        } else {
            lua.getfield(L, -2, name)
        }
        if !lua.istable(L, -1) {
            lua.pop(L, 1)
            return false
        }

        lua.pushnil(L)
    }
    return true
}

serialize_end_table :: proc(s: ^SerializeContext) {
    L := s.L
    switch s.mode {
    case .Serialize:
        s.table_count -= 1

        name := strings.clone_to_cstring(s.table_names[s.table_count], context.temp_allocator)
        if s.table_count == 0 {
            lua.setglobal(L, name)
        } else {
            lua.setfield(L, -2, name)
        }
    case .Deserialize:
        lua.pop(L, 2)
    }
}

serialize_begin_table_int :: proc(s: ^SerializeContext, key: int) {
    L := s.L
    assert(!s.is_global)

    switch s.mode {
    case .Serialize:
        lua.pushinteger(L, i64(key + 1))
        lua.newtable(L)
    case .Deserialize:
        lua.pushinteger(L, i64(key + 1))
        lua.gettable(L, -3)

        lua.pushnil(L)
    }
}

serialize_end_table_int :: proc(s: ^SerializeContext) {
    L := s.L

    switch s.mode {
    case .Serialize:
        lua.settable(L, -3)
    case .Deserialize:
        lua.pop(L, 2)
    }
}

serialize_begin_array :: proc(s: ^SerializeContext, name: string) {
    switch s.mode {
    case .Serialize:
        s.array_index += 1
    case .Deserialize:
    }
    serialize_begin_table(s, name)
}

serialize_end_array :: proc(s: ^SerializeContext) {
    switch s.mode {
    case .Serialize:
        s.array_index -= 1
    case .Deserialize:
    }
    serialize_end_table(s)
}

serialize_do_field_int :: proc(s: ^SerializeContext, key: int, value: any) -> bool {
    rt :: runtime
    L := s.L
    switch s.mode {
    case .Serialize:
        begin_stack(L)

        lua.pushinteger(L, i64(key))

        serialize_actually_do_field(s, value)
        return true
    case .Deserialize:
        // begin_stack(L)

        has_nil := false
        if lua.isnil(L, -1) {
            has_nil = true
            lua.pop(L, 1)
        }

        lua.pushinteger(L, i64(key))
        lua.gettable(L, -2)

        ret := serialize_read_field(s, value)

        lua.pop(L, 1)

        if has_nil {
            lua.pushnil(L)
        }

        return ret
    }
    unreachable()
}

serialize_do_field_string :: proc(s: ^SerializeContext, name: string, value: any) -> bool {
    rt :: runtime
    L := s.L
    switch s.mode {
    case .Serialize:
        begin_stack(L)

        lua.pushstring(L, name)

        serialize_actually_do_field(s, value)
        return true
    case .Deserialize:
        // begin_stack(L)
        has_nil := false
        if lua.isnil(L, -1) {
            has_nil = true
            lua.pop(L, 1)
        }

        type := lua.getfield(L, -1, strings.clone_to_cstring(name, context.temp_allocator))

        ret := serialize_read_field(s, value)

        lua.pop(L, 1)

        if has_nil {
            lua.pushnil(L)
        }

        return ret
    }
    unreachable()
}

serialize_do_field_type :: proc(s: ^SerializeContext, name: string, value: ^$T) -> bool
    where intr.type_is_bit_set(T) {
    rt :: runtime
    L := s.L
    switch s.mode {
    case .Serialize:
        begin_stack(L)

        lua.pushstring(L, name)

        serialize_actually_do_field(s, any{value, typeid_of(T)})
        return true
    case .Deserialize:
        // begin_stack(L)

        has_nil := false
        if lua.isnil(L, -1) {
            has_nil = true
            lua.pop(L, 1)
        }

        lua.getfield(L, -1, strings.clone_to_cstring(name, context.temp_allocator))

        if lua.isinteger(L, -1) != 1 do return false
        bit_data := lua.tointeger(L, -1)
        value^ = transmute(T)bit_data

        lua.pop(L, 1)

        if has_nil {
            lua.pushnil(L)
        }

        return true
    }
    unreachable()
}

serialize_do_field :: proc {
    serialize_do_field_int,
    serialize_do_field_string,
    serialize_do_field_type,
}

serialize_get_field :: proc(s: ^SerializeContext, field: string, $T: typeid) -> (value: T, found: bool) {
    assert(s.mode == .Deserialize, "Cannot get field in Serialize mode.")

    when intr.type_is_bit_set(T) {
        found = serialize_do_field_type(s, field, &value)
    } else {
        found = serialize_do_field(s, field, value)
    }
    return
}

serialize_to_field_any :: proc(s: ^SerializeContext, field: string, value: ^$T) {
    if v, ok := serialize_get_field(s, field, T); ok {
        value^ = v
    }
}

serialize_to_field :: proc {
    serialize_to_field_any,
}

serialize_get_array :: proc(s: ^SerializeContext) -> int {
    return int(lua.rawlen(s.L, -2))
}

SerializedValue :: union {
    i64,
    f64,
    bool,
    string,
}

serialize_get_keys :: proc(s: ^SerializeContext) -> (key: string, value: SerializedValue, ok: bool) {
    assert(s.mode == .Deserialize, "Cannot get field keys in Serialize mode.")
    L := s.L
    if lua.next(L, -2) == 0 {
        lua.pushnil(L)
        return {}, {}, false
    }

    key = strings.clone(lua.tostring(L, -2), context.temp_allocator)

    type := lua.type(L, -1)
    switch type {
    case lua.TNUMBER:
        if lua.isinteger(L, -1) == 1 {
            value = lua.tointeger(L, -1)
        } else {
            value = lua.tonumber(L, -1)
        }
    case lua.TSTRING:
        value = strings.clone(lua.tostring(L, -1))
    case lua.TBOOLEAN:
        value = lua.toboolean(L, -1) == 1
    case:
        value = nil
    }

    lua.pop(L, 1)
    return key, value, true
}

@(private="file")
assign_int :: proc(val: any, i: $T) -> bool {
    v := reflect.any_core(val)
    switch &dst in v {
    case i8:      dst = i8     (i)
    case i16:     dst = i16    (i)
    case i16le:   dst = i16le  (i)
    case i16be:   dst = i16be  (i)
    case i32:     dst = i32    (i)
    case i32le:   dst = i32le  (i)
    case i32be:   dst = i32be  (i)
    case i64:     dst = i64    (i)
    case i64le:   dst = i64le  (i)
    case i64be:   dst = i64be  (i)
    case i128:    dst = i128   (i)
    case i128le:  dst = i128le (i)
    case i128be:  dst = i128be (i)
    case u8:      dst = u8     (i)
    case u16:     dst = u16    (i)
    case u16le:   dst = u16le  (i)
    case u16be:   dst = u16be  (i)
    case u32:     dst = u32    (i)
    case u32le:   dst = u32le  (i)
    case u32be:   dst = u32be  (i)
    case u64:     dst = u64    (i)
    case u64le:   dst = u64le  (i)
    case u64be:   dst = u64be  (i)
    case u128:    dst = u128   (i)
    case u128le:  dst = u128le (i)
    case u128be:  dst = u128be (i)
    case int:     dst = int    (i)
    case uint:    dst = uint   (i)
    case uintptr: dst = uintptr(i)
    case: return false
    }
    return true
}

serialize_read_field :: proc(s: ^SerializeContext, value: any) -> bool {
    rt :: runtime
    L := s.L

    ti := rt.type_info_base(type_info_of(value.id))
    a := any{value.data, ti.id}

    #partial switch info in ti.variant {
    case rt.Type_Info_Named:
        unreachable()
    case rt.Type_Info_Integer:
        switch i in a {
        case u64:
            if lua.isstring(L, -1) != 1 do return false
            s := lua.tostring(L, -1)
            u, ok := strconv.parse_u64(s)
            if !ok do return false

            assign_int(value, u)

        case u128:
            if lua.isstring(L, -1) != 1 do return false
            s := lua.tostring(L, -1)
            u, ok := strconv.parse_u128(s)
            if !ok do return false

            assign_int(value, u)
        case i128:
            if lua.isstring(L, -1) != 1 do return false
            s := lua.tostring(L, -1)
            u, ok := strconv.parse_i128(s)
            if !ok do return false

            assign_int(value, u)
        case uint:
            if lua.isstring(L, -1) != 1 do return false
            s := lua.tostring(L, -1)
            u, ok := strconv.parse_uint(s)
            if !ok do return false

            assign_int(value, u)
        case uintptr:
            if lua.isstring(L, -1) != 1 do return false
            s := lua.tostring(L, -1)
            u, ok := strconv.parse_uint(s)
            if !ok do return false

            assign_int(value, u)
        case:
            if lua.isinteger(L, -1) != 1 do return false
            u := lua.tointeger(L, -1)

            assign_int(value, u)
        }
    case rt.Type_Info_Float:
        if lua.isnumber(L, -1) != 1 do return false
        u := lua.tonumber(L, -1)

        switch &f in a {
        case f16: f = auto_cast u
        case f32: f = auto_cast u
        case f64: f = auto_cast u
        }
    case rt.Type_Info_String:
        if lua.isstring(L, -1) != 1 do return false
        str := lua.tostring(L, -1)
        switch &s in a {
        case string:
            s = strings.clone(str)
        case cstring:
            s = strings.clone_to_cstring(str)
        }
    case rt.Type_Info_Boolean:
        if !lua.isboolean(L, -1) do return false
        val := lua.toboolean(L, -1)

        switch &b in a {
        case bool: b = auto_cast val
        case b8:   b = auto_cast val
        case b16:  b = auto_cast val
        case b32:  b = auto_cast val
        case b64:  b = auto_cast val
        }
    case rt.Type_Info_Array:
        for i in 0..<info.count {
            elem_ptr := rawptr(uintptr(value.data) + uintptr(i * info.elem_size))
            elem := any{elem_ptr, info.elem.id}

            serialize_do_field_int(s, i + 1, elem)
        }
    case rt.Type_Info_Enum:
        if lua.isstring(L, -1) == 0 do return false
        enum_name := lua.tostring(L, -1)
        enum_value, ok := reflect.enum_from_name_any(value.id, enum_name)
        if !ok do return false

        assign_int(a, enum_value)
    case:
        unreachable()
    }
    return true
}

serialize_actually_do_field :: proc(s: ^SerializeContext, value: any) {
    rt :: runtime
    L := s.L

    ti := rt.type_info_base(type_info_of(value.id))
    a := any{value.data, ti.id}

    #partial type_switch: switch info in ti.variant {
    case rt.Type_Info_Named:
        unreachable()
    case rt.Type_Info_Integer:
        u: i64
        switch i in a {
        case i8:      u = i64(i)
        case i16:     u = i64(i)
        case i32:     u = i64(i)
        case i64:     u = i64(i)
        case int:     u = i64(i)
        case u8:      u = i64(i)
        case u16:     u = i64(i)
        case u32:     u = i64(i)
        case i128:
            sb: strings.Builder
            strings.builder_init(&sb)
            w := strings.to_writer(&sb)
            io.write_i128(w, i)

            lua.pushstring(L, strings.to_string(sb))
            break type_switch
        case u64:
            sb: strings.Builder
            strings.builder_init(&sb)
            w := strings.to_writer(&sb)
            io.write_u64(w, i)

            lua.pushstring(L, strings.to_string(sb))
            break type_switch
        case u128:
            sb: strings.Builder
            strings.builder_init(&sb)
            w := strings.to_writer(&sb)
            io.write_u128(w, i)

            lua.pushstring(L, strings.to_string(sb))
            break type_switch
        case uint:
            sb: strings.Builder
            strings.builder_init(&sb)
            w := strings.to_writer(&sb)
            io.write_uint(w, i)

            lua.pushstring(L, strings.to_string(sb))
            break type_switch
        case uintptr:
            sb: strings.Builder
            strings.builder_init(&sb)
            w := strings.to_writer(&sb)
            io.write_uint(w, uint(i))

            lua.pushstring(L, strings.to_string(sb))
            break type_switch

        case i16le:  unimplemented()
        case i32le:  unimplemented()
        case i64le:  unimplemented()
        case u16le:  unimplemented()
        case u32le:  unimplemented()
        case u64le:  unimplemented()
        case u128le: unimplemented()

        case i16be:  unimplemented()
        case i32be:  unimplemented()
        case i64be:  unimplemented()
        case u16be:  unimplemented()
        case u32be:  unimplemented()
        case u64be:  unimplemented()
        case u128be: unimplemented()
        }
        lua.pushinteger(L, u)
    case rt.Type_Info_Float:
        u: f64
        switch f in a {
        case f16: u = f64(f)
        case f32: u = f64(f)
        case f64: u = f64(f)
        }
        lua.pushnumber(L, u)
    case rt.Type_Info_String:
        switch s in a {
        case string:
            lua.pushstring(L, s)
        case cstring:
            lua.pushcstring(L, s)
        }
    case rt.Type_Info_Boolean:
        val: bool
        switch b in a {
        case bool: val = bool(b)
        case b8:   val = bool(b)
        case b16:  val = bool(b)
        case b32:  val = bool(b)
        case b64:  val = bool(b)
        }
        lua.pushboolean(L, i32(val))
    case rt.Type_Info_Enum:
        name, found := reflect.enum_name_from_value_any(value)
        assert(found, "Could not find enum name with reflection")
        lua.pushstring(L, name)
    case rt.Type_Info_Bit_Set:
        is_bit_set_different_endian_to_platform :: proc(ti: ^runtime.Type_Info) -> bool {
            if ti == nil {
                return false
            }
            t := runtime.type_info_base(ti)
            #partial switch info in t.variant {
            case runtime.Type_Info_Integer:
                switch info.endianness {
                case .Platform: return false
                case .Little:   return ODIN_ENDIAN != .Little
                case .Big:      return ODIN_ENDIAN != .Big
                }
            }
            return false
        }

        bit_data: u64
        bit_size := u64(8*ti.size)

        do_byte_swap := is_bit_set_different_endian_to_platform(info.underlying)

        switch bit_size {
        case  0: bit_data = 0
        case  8:
            x := (^u8)(value.data)^
            bit_data = u64(x)
        case 16:
            x := (^u16)(value.data)^
            if do_byte_swap {
                x = bits.byte_swap(x)
            }
            bit_data = u64(x)
        case 32:
            x := (^u32)(value.data)^
            if do_byte_swap {
                x = bits.byte_swap(x)
            }
            bit_data = u64(x)
        case 64:
            x := (^u64)(value.data)^
            if do_byte_swap {
                x = bits.byte_swap(x)
            }
            bit_data = u64(x)
        case: panic("unknown bit_size size")
        }
        lua.pushinteger(L, i64(bit_data))

    case rt.Type_Info_Array:
        name := strings.clone(lua.tostring(L, -1), context.temp_allocator)
        lua.pop(L, 1)

        serialize_begin_array(s, name)
        for i in 0..<info.count {
            data := uintptr(value.data) + uintptr(i*info.elem_size)
            serialize_do_field_int(s, i + 1, any{rawptr(data), info.elem.id})
        }
        serialize_end_array(s)
        return
    case:
        unreachable()
    }
    lua.settable(L, -3)
}

LUA_DUMPER :: `
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function tableToLuaStringWithTableName(tbl, tableName, indent)
    local result = ""
    indent = indent or ""

    if type(tbl) == "table" then
        if tableName == nil then
            result = result .. "{\n"
        else
            result = result .. tableName .. " = {\n"
        end

        for key, value in spairs(tbl) do
            local keyString = tostring(key)
            if type(key) == "number" then
                keyString = string.format("[%q]", key)
            end

            local valueString = ""
            if type(value) == "table" then
                valueString = tableToLuaStringWithTableName(value, nil, indent .. "    ")
            elseif type(value) == "string" then
                valueString = string.format("%q", value)
            else
                valueString = tostring(value)
            end

            if type(key) == "number" then
                result = result .. indent .. "    " .. valueString .. ",\n"
            else
                result = result .. indent .. "    " .. keyString .. " = " .. valueString .. ",\n"
            end
        end

        result = result .. indent .. "}"
    else
        result = tostring(tbl)
    end

    return result
end

return tableToLuaStringWithTableName
`

// Converts the config into a string and writes it to the file located at `output`.
serialize_dump :: proc(s: ^SerializeContext, output: string) {
    assert(s.table_count == 0, "Did not close all the tables")
    L := s.L

    if luaL.dostring(L, LUA_DUMPER) != lua.OK {
        log.error("Error loading dumper")
        return
    }

    lua.rawgeti(L, lua.REGISTRYINDEX, s.global_table)
    lua.pushstring(L, s.table_names[0])

    if lua.pcall(L, 2, 1, 0) != lua.OK {
        log.error("Error calling dump: %v", lua.tostring(L, -1))
        return
    }

    data := transmute([]byte)lua.tostring(L, -1)
    os.write_entire_file(output, data)
}

package engine
import "core:fmt"
import "core:log"

Fields :: map[string]LuaField

@(LuaExport = {
    Type = {Light},
    Fields = {
        name = "Name",
    },
})
Properties :: struct {
    name:            string,
    fields:          Fields,
    instance_fields: Fields,
}

@(LuaExport = {
    Type = {Full, Light},
    Fields = {
        properties = "Properties",
        owner = "owner",
    },
    Methods = {
        lua_entity_set_position = "set_position",
        lua_entity_get_position = "get_position",
        lua_entity_translate    = "translate",
        lua_entity_set_active = "set_active",
        lua_entity_is_active = "is_active",
    },
    Metamethods = {
        __tostring = lua_entity_to_string,
    },
})
LuaEntity :: struct {
    world: ^World,
    owner: ^Entity,
    entity: u64,
    properties: Properties,
}

// This is a doc comment
@(LuaExport)
lua_entity_set_position :: proc(le: LuaEntity, position: vec3) {
    go := get_object(le.world, UUID(le.entity))
    if go == nil do return

    go.transform.local_position = position
}

@(LuaExport)
lua_entity_get_position :: proc(le: LuaEntity) -> vec3 {
    go := get_object(le.world, UUID(le.entity))
    if go == nil do return vec3{}

    return go.transform.local_position
}

@(LuaExport)
lua_entity_translate :: proc(le: LuaEntity, offset: vec3) {
    go := get_object(le.world, UUID(le.entity))
    if go == nil do return

    go.transform.local_position += offset
}

@(LuaExport)
lua_entity_to_string :: proc(le: LuaEntity) -> string {
    return fmt.tprintf("Entity[%v, %v]", ds_to_string(le.owner.name), le.entity)
}

@(LuaExport)
lua_entity_set_active :: proc(le: LuaEntity, active: bool) {
    go := get_object(le.world, UUID(le.entity))
    if go == nil do return

    go.enabled = active
}

@(LuaExport)
lua_entity_is_active :: proc(le: LuaEntity) -> bool {
    go := get_object(le.world, UUID(le.entity))
    if go == nil do return false
    return go.enabled
}

@(LuaExport)
v2 :: proc(x, y: f32) -> vec2 {
    return vec2{x, y}
}

@(LuaExport)
v3 :: proc(x, y, z: f32) -> vec3 {
    return vec3{x, y, z}
}

@(LuaExport)
v4 :: proc(x, y, z, w: f32) -> vec4 {
    return vec4{x, y, z, w}
}

@(LuaExport)
vec4_to_string :: proc(v: vec4) -> string {
    return fmt.tprintf("vec4{{%v, %v, %v, %v}}", v.x, v.y, v.z, v.w)
}

@(LuaExport)
vec3_to_string :: proc(v: vec3) -> string {
    return fmt.tprintf("vec3{{%v, %v, %v}}", v.x, v.y, v.z)
}

@(LuaExport)
vec2_to_string :: proc(v: vec2) -> string {
    return fmt.tprintf("vec2{{%v, %v}}", v.x, v.y)
}

@(LuaExport)
print :: proc(what: string) {
    log.info(what)
}

@(LuaExport = {
    Name = "find_entity_by_name",
})
api_find_entity_by_name :: proc(name: string) -> LuaEntity {
    return {}
}

// Returns whether the specified key is currently pressed.
// awdawd
@(LuaExport = {
    Name = "is_key_down",
})
api_is_key_down :: proc(key: int) -> bool {
    return is_key_pressed(Key(key))
}

@(LuaExport = {
    Name = "is_key_up",
})
api_is_key_up :: proc(key: int) -> bool {
    return is_key_released(Key(key))
}

@(LuaExport = {
    Name = "is_key_just_pressed",
})
api_is_key_just_pressed :: proc(key: Key) -> bool {
    return is_key_just_pressed(Key(key))
}

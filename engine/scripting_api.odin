package engine
import "core:fmt"
import "core:log"

Fields :: [dynamic]LuaField

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
    },
    MethodPrefix = "lua_entity_",
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

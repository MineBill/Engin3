package engine
import "core:fmt"
import "core:log"
import "packages:odin-lua/lua"
import "packages:odin-lua/luaL"
import "packages:mani/mani"
import "core:path/filepath"
import "core:strings"

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

//!Represents an entity into the world. It is the entity scripts are attached to.
@(LuaExport = {
    Type = {Full, Light},
    Fields = {
        properties = "Properties",
        owner = "owner",
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

@(LuaExport = {
    Name = "do_barrel_roll",
    MethodOf = LuaEntity,
})
lua_entity_do_barrel_roll :: proc(e: LuaEntity) {

}

//!Sets the position of the entity to `position`.
@(LuaExport = {
    Name = "set_position",
    MethodOf = LuaEntity,
})
lua_entity_set_position :: proc(le: LuaEntity, position: vec3) {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return

    go.transform.local_position = position
}

//!Gets the local position of the entity.
//!To get the world space position(global) use `get_global_position`.
//!@see LuaEntity.get_global_position
@(LuaExport = {
    Name = "get_position",
    MethodOf = LuaEntity,
})
lua_entity_get_position :: proc(le: LuaEntity) -> vec3 {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return vec3{}

    return go.transform.local_position
}

@(LuaExport = {
    Name = "get_forward",
    MethodOf = LuaEntity,
})
lua_entity_get_forward :: proc(le: LuaEntity) -> vec3 {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return vec3{}

    return get_forward(go.transform.local_rotation)
}

//!Gets the global position of the entity.
//!To get the local position use `get_position`.
//!@see LuaEntity.get_position
@(LuaExport = {
    Name = "get_global_position",
    MethodOf = LuaEntity,
})
lua_entity_get_global_position :: proc(le: LuaEntity) -> vec3 {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return vec3{}

    return go.transform.position
}

@(LuaExport = {
    Name = "translate",
    MethodOf = LuaEntity,
})
lua_entity_translate :: proc(le: LuaEntity, offset: vec3) {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return

    go.transform.local_position += offset
}

@(LuaExport = {
    Name = "set_active",
    MethodOf = LuaEntity,
})
lua_entity_set_active :: proc(le: LuaEntity, active: bool) {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return

    go.enabled = active
}

@(LuaExport = {
    Name = "is_active",
    MethodOf = LuaEntity,
})
lua_entity_is_active :: proc(le: LuaEntity) -> bool {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return false
    return go.enabled
}

@(LuaExport)
lua_entity_to_string :: proc(le: LuaEntity) -> string {
    go := get_object(le.world, EntityHandle(le.entity))
    if go == nil do return ""
    return fmt.tprintf("Entity[%v, %v]", ds_to_string(go.name), le.entity)
}

@(LuaExport)
make_vec2 :: proc(x, y: f32) -> vec2 {
    return vec2{x, y}
}

@(LuaExport)
make_vec3 :: proc(x, y, z: f32) -> vec3 {
    return vec3{x, y, z}
}

@(LuaExport)
make_vec4 :: proc(x, y, z, w: f32) -> vec4 {
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

@(LuaExport = {
    Module = "Debug",
    Name = "Log",
})
api_print :: proc(what: string) {
    log.infof("DEBUG.LOG: %v", what)
    log_info(LogCategory.UserScript, what)
}

@(LuaExport = {
    Module = "Scene",
    Name = "find_entity_by_name",
})
api_find_entity_by_name :: proc(name: string) -> LuaEntity {
    return {}
}

//!Returns whether the `key` is being pressed. This will keep returning true
//!while the key is being pressed.
@(LuaExport = {
    Module = "Input",
    Name = "is_key_down",
})
api_is_key_down :: proc(key: Key) -> bool {
    return is_key_pressed(key)
}

//!Returns whether the `key` is currently NOT being pressed. This will keep returning true
//!while the key is NOT being pressed.
@(LuaExport = {
    Module = "Input",
    Name = "is_key_up",
})
api_is_key_up :: proc(key: Key) -> bool {
    return is_key_released(key)
}

//!Returns whether the `key` was just pressed the previous frame. It will only return true once.
//!To return true again, the key must be released and pressed again.
@(LuaExport = {
    Module = "Input",
    Name = "is_key_just_pressed",
})
api_is_key_just_pressed :: proc(key: Key) -> bool {
    return is_key_just_pressed(Key(key))
}

//!Returns the mouse delta movement between this and the previous frame.
@(LuaExport = {
    Module = "Input",
    Name = "get_mouse_delta",
})
api_get_mouse_delta :: proc() -> vec2 {
    return get_mouse_delta()
}

@(LuaExport = {
    Module = "Debug",
    Name = "DrawLine",
})
api_debug_draw_line :: proc(from: vec3, to: vec3 = vec3{0, 10, 0}) {
    dbg_draw_line(&EngineInstance.dbg_draw, from, to, color = COLOR_MINT)
}

@(LuaExport = {
    Module = "Physics",
    Name = "RayCast",
})
api_physics_raycast :: proc(origin: vec3, direction: vec3) -> (hit: RayCastHit, ok: bool) {
    return physics_raycast(PhysicsInstance, origin, direction)
}

package engine
import "core:encoding/json"
import "core:io"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"
import "packages:mani/mani"
import "packages:odin-lua/lua"
import "packages:odin-lua/luaL"
import gl "vendor:OpenGL"
import imgui "packages:odin-imgui"
import tracy "packages:odin-tracy"
import "packages:jolt"

// Proc used to serialize components.
// If a proc is this type and it is marked with @(constructor=C), it will be used to serialize component C.
ComponentSerializer :: #type proc(this: rawptr, serialize: bool, s: ^SerializeContext)

// Special case component, every gameobject has a Transform by default.
@(component, LuaExport = {
    Name = "Transform",
    Type = {Full, Light},
    Fields = {
        local_position = "position",
        local_rotation = "rotation",
        local_scale    = "scale",
    },
})
TransformComponent :: struct {
    local_position: vec3,
    local_rotation: vec3,
    local_scale: vec3,

    position: vec3,
    rotation: vec3,
    scale: vec3,

    local_matrix: mat4,
    global_matrix: mat4,

    dirty: bool,
}

default_transform :: proc() -> TransformComponent {
    return {
        local_scale = vec3{1, 1, 1},
        local_matrix = mat4(1.0),
        global_matrix = mat4(1.0),
    }
}

@(serializer=TransformComponent)
serialize_transform :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^TransformComponent)this
    if serialize {
        serialize_do_field(s, "LocalPosition", this.local_position)
        serialize_do_field(s, "LocalRotation", this.local_rotation)
        serialize_do_field(s, "LocalScale", this.local_scale)
    } else {
        if position, ok := serialize_get_field(s, "LocalPosition", vec3); ok {
            this.local_position = position
        }
        if rotation, ok := serialize_get_field(s, "LocalRotation", vec3); ok {
            this.local_rotation = rotation
        }
        if scale, ok := serialize_get_field(s, "LocalScale", vec3); ok {
            this.local_scale = scale
        }
    }
}

// Called by the world/gameobject.
init_transform :: proc(this: ^TransformComponent) {}

// Called by the world/gameobject.
update_transform :: proc(go: ^Entity, this: ^TransformComponent, update: f64) {
    tracy.Zone()
    assert(go != nil, "Entity is nil")
    parent := get_object(go.world, go.parent)

    s := linalg.matrix4_scale(go.transform.local_scale)
    rot := go.transform.local_rotation
    r := linalg.matrix4_from_euler_angles_yxz(
        rot.y * math.RAD_PER_DEG,
        rot.x * math.RAD_PER_DEG,
        rot.z * math.RAD_PER_DEG,
    )
    t := linalg.matrix4_translate(go.transform.local_position)
    go.transform.local_matrix = t * r * s

    if parent == nil {
        go.transform.global_matrix = go.transform.local_matrix
    } else {
        go.transform.global_matrix =  parent.transform.global_matrix * go.transform.local_matrix
    }

    m := go.transform.global_matrix
    go.transform.position = vec3{m[0, 3], m[1, 3], m[2, 3]}
}

set_global_position :: proc(go: ^Entity, pos: vec3) {
    parent := get_object(go.world, go.parent)
    if parent == nil {
        go.transform.local_position = pos
    } else {
        // This assumes that the parents global position is correct
        go.transform.local_position = pos - parent.transform.position
    }
}

Level :: log.Level

@(component="Testing")
PrinterComponent :: struct {
    using base: Component,

    timer: f64,
    log_type: Level,
}

@(constructor=PrinterComponent)
make_printer :: proc() -> rawptr {
    printer := new(PrinterComponent)
    printer.base = default_component_constructor()
    printer.init = printer_init
    printer.update = printer_update
    printer.copy = component_shallow_copy(PrinterComponent)
    return printer
}

printer_init :: proc(this: rawptr) {

}

printer_update :: proc(this: rawptr, delta: f64) {
    this := cast(^PrinterComponent)this
    this.timer += delta
    if this.timer >= 3 {
        this.timer = 0
        log.logf(this.log_type, "I am a printer")
    }
}

@(component="Core/Rendering")
MeshRenderer :: struct {
    using base: Component,

    mesh:    AssetHandle `asset:"Mesh"`,
    material: AssetHandle `asset:"PbrMaterial"`,
}

@(constructor=MeshRenderer)
make_mesh_renderer :: proc() -> rawptr {
    mr := new(MeshRenderer)
    mr^ = {
        base = default_component_constructor(),
    }

    mr.prop_changed = mesh_renderer_prop_changed
    mr.copy         = component_shallow_copy(MeshRenderer)
    return mr
}

mesh_renderer_prop_changed :: proc(this: rawptr, prop: any) {
    this := cast(^MeshRenderer)this
    field, ok := prop.(reflect.Struct_Field)
    if !ok do return

    switch field.name {
    case "material":
    }
}

mesh_renderer_set_mesh :: proc(this: ^MeshRenderer, new_mesh: AssetHandle) {
    this.mesh = new_mesh
}

@(serializer=MeshRenderer)
serialize_mesh_renderer :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^MeshRenderer)this
    am := &EngineInstance.asset_manager
    serialize_asset_handle(am, s, "Mesh", &this.mesh)
    serialize_asset_handle(am, s, "PbrMaterial", &this.material)

    switch s.mode {
    case .Serialize:
    case .Deserialize:
        if this.material == 0 {
            log_info(LC.EntitySystem, "MeshRenderer: Deserialized material is nil, using default material")
            this.material = Renderer3DInstance.default_material
        }
    }
}

@(component="Core/Lights")
PointLightComponent :: struct {
    using base: Component,

    color: Color,
    distance: f32 `range: "0.0, 100.0"`,
    power: f32 `range: "0.0, 10.0"`,

    constant: f32 `hide:""`,
    linear: f32 `hide:""`,
    quadratic: f32 `hide:""`,
}

@(constructor=PointLightComponent)
make_point_light :: proc() -> rawptr {
    light := new(PointLightComponent)
    light^ = {
        base = default_component_constructor(),
        init = component_default_init,
        update = component_default_update,
        prop_changed = point_light_prop_changed,
        copy = component_shallow_copy(PointLightComponent),

        color = Color{1, 1, 1, 1},
        constant = 1.0,
        linear = 0.7,
        quadratic = 1.8,
    }
    return light
}

@(serializer=PointLightComponent)
serialize_point_light :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^PointLightComponent)this
    if serialize {
        serialize_do_field(s, "Color", this.color)
        serialize_do_field(s, "Constant", this.constant)
        serialize_do_field(s, "Linear", this.linear)
        serialize_do_field(s, "Quadratic", this.quadratic)
        serialize_do_field(s, "Distance", this.distance)
        serialize_do_field(s, "Power", this.power)
    } else {
        serialize_to_field(s, "Color", &this.color)
        serialize_to_field(s, "Constant", &this.constant)
        serialize_to_field(s, "Linear", &this.linear)
        serialize_to_field(s, "Quadratic", &this.quadratic)
        serialize_to_field(s, "Distance", &this.distance)
        serialize_to_field(s, "Power", &this.power)
    }
}

point_light_prop_changed :: proc(this: rawptr, prop: any) {
    this := cast(^PointLightComponent)this
    field, ok := prop.(reflect.Struct_Field)
    if !ok do return

    switch field.name {
    case "distance":
        log.debugf("prop_changed: distance is '%v'", this.distance)
    case "color":
        log.debugf("prop_change: color is '%v'", this.color)
    }
}

@(component="Core/Lights")
SpotLightComponent :: struct {
    using base: Component,
}

@(constructor=SpotLightComponent)
make_spotlight :: proc() -> rawptr {
    light := new(SpotLightComponent)
    light.base = default_component_constructor()
    light.copy = component_shallow_copy(SpotLightComponent)

    return light
}

@(component="Core")
MoverComponent :: struct {
    using base: Component,

    offset: f32,
    timer: f32 `editor:"hide"`,
}

@(constructor=MoverComponent)
make_mover :: proc() -> rawptr {
    mover := new(MoverComponent)
    mover.base = default_component_constructor()
    mover.copy = component_shallow_copy(MoverComponent)
    mover.update = mover_update
    return mover
}

mover_update :: proc(this: rawptr, delta: f64) {
    this := cast(^MoverComponent)this
    this.timer += f32(delta)

    go := get_object(this.world, this.owner)
    t := &go.transform
    t.local_position.y = math.sin(this.timer) + this.offset
}

@(component="Core/Lights")
DirectionalLight :: struct {
    using base: Component,

    // direction
    color: Color,

    shadow: struct {
        splits: int `range:"1, 4"`,
        correction: f32 `range:"0.0, 1.5"`,
        distances: vec4,
    },
}

@(constructor=DirectionalLight)
make_directional_light :: proc() -> rawptr {
    light := new(DirectionalLight)
    light.base = default_component_constructor()
    light.copy = component_shallow_copy(DirectionalLight)
    light.debug_draw = directional_light_debug_draw

    light.color = COLOR_WHITE

    return light
}

directional_light_debug_draw :: proc(this: rawptr, ctx: ^DebugDrawContext) {
    this := cast(^DirectionalLight)this
    go := get_object(this.world, this.owner)

    rot := go.transform.local_rotation
    dir_light_quat := linalg.quaternion_from_euler_angles(
        rot.y * math.RAD_PER_DEG,
        rot.x * math.RAD_PER_DEG,
        rot.z * math.RAD_PER_DEG,
        .YXZ)
    dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, -1})

    end := go.transform.position + dir
    dbg_draw_line(g_dbg_context, go.transform.position, end)
    dbg_draw_cube(g_dbg_context, end, {}, VEC3_ONE * 0.125)
}

@(serializer=DirectionalLight)
serialize_directional_light :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^DirectionalLight)this
    if serialize {
        serialize_do_field(s, "Color", this.color)
        serialize_begin_table(s, "Shadow")
        serialize_do_field(s, "Splits", this.shadow.splits)
        serialize_do_field(s, "Correction", this.shadow.correction)
        serialize_end_table(s)
    } else {
        if color, ok := serialize_get_field(s, "Color", Color); ok {
            this.color = color
        }

        if serialize_begin_table(s, "Shadow") {
            if splits, ok := serialize_get_field(s, "Splits", int); ok {
                this.shadow.splits = splits
            }
            if correction, ok := serialize_get_field(s, "Correction", f32); ok {
                this.shadow.correction = correction
            }
            serialize_end_table(s)
        }
    }
}

@(component="Core/Rendering", name="Cubemap")
CubemapComponent :: struct {
    using base: Component,

    texture: AssetHandle `asset:"CubeTexture"`,
    shader: Shader,
}

@(constructor=CubemapComponent)
make_cubemap :: proc() -> rawptr {
    cube := new(CubemapComponent)
    cube.base = default_component_constructor()

    // Hardcoded cubemap
    images :: [?]string {
        "assets/textures/skybox/right.jpg",
        "assets/textures/skybox/left.jpg",
        "assets/textures/skybox/top.jpg",
        "assets/textures/skybox/bottom.jpg",
        "assets/textures/skybox/front.jpg",
        "assets/textures/skybox/back.jpg",
    }

    created := false

    // for image_path, i in images {
    //     data, ok := os.read_entire_file(image_path)
    //     defer delete(data)
    //     if !ok do continue
    //     image, image_loaded := load_image_memory(data)
    //     defer destroy_image(&image)
    //     if !image_loaded {
    //         log.warnf("Failed to load image '%v'", image_path)
    //         continue // NOTE(minebill): Maybe abort?
    //     }
    //     if !created {
    //         spec := TextureSpecification {
    //             format = .RGBA8,
    //             width = image.width,
    //             height = image.height,
    //         }
    //         texture := get_asset(&EngineInstance.asset_manager, cube.texture, Texture2D)
    //         // cube.texture = create_texture2d(spec)
    //         created = true
    //     }

    //     texture := get_asset(&EngineInstance.asset_manager, cube.texture, Texture2D)
    //     set_texture2d_data(texture^, image.data, layer = i)
    // }

    ok: bool
    if !ok {
        log.warnf("Failed to load shader")
    }

    return cube
}

@(component="Core")
Camera :: struct {
    using base: Component,

    fov: f32,
    near_plane: f32 `range:"0.1, 1000.0"`,
    far_plane: f32 `range:"0.1, 1000.0"`,

    rotation: quaternion128,
    projection, view: mat4 `hide:""`,
}

@(constructor=Camera)
make_camera :: proc() -> rawptr {
    camera := new(Camera)
    camera.base = default_component_constructor()
    camera.debug_draw = camera_debug_draw
    camera.copy = component_shallow_copy(Camera)

    camera.fov = 50
    camera.near_plane = 0.1
    camera.far_plane = 100.0
    aspect := f32(EngineInstance.screen_size.x) / f32(EngineInstance.screen_size.y)
    camera.projection = linalg.matrix4_perspective_f32(camera.fov, aspect, 0.1, 1000.0)

    return camera
}

camera_debug_draw :: proc(this: rawptr, ctx: ^DebugDrawContext) {
    this := cast(^Camera)this
    entity := get_object(this.world, this.owner)

    euler := entity.transform.local_rotation
    this.rotation = linalg.quaternion_from_euler_angles(
        euler.y * math.RAD_PER_DEG,
        euler.x * math.RAD_PER_DEG,
        euler.z * math.RAD_PER_DEG,
        .YXZ)

    this.view = linalg.matrix4_from_quaternion(this.rotation) *
                    linalg.inverse(linalg.matrix4_translate(entity.transform.position))
    this.projection = linalg.matrix4_perspective_f32(math.to_radians(f32(this.fov)), f32(EngineInstance.screen_size.x) / f32(EngineInstance.screen_size.y), this.near_plane, this.far_plane)
    corners := get_frustum_corners_world_space(
        this.projection,
        this.view)

    color := Color{0.2, 0.2, 0.7, 1.0}

    dbg_draw_line(ctx, corners[0].xyz, corners[1].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[2].xyz, corners[3].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[4].xyz, corners[5].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[6].xyz, corners[7].xyz, 2.0, color = color)

    dbg_draw_line(ctx, corners[0].xyz, corners[2].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[2].xyz, corners[6].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[6].xyz, corners[4].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[4].xyz, corners[0].xyz, 2.0, color = color)

    dbg_draw_line(ctx, corners[1].xyz, corners[3].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[3].xyz, corners[7].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[7].xyz, corners[5].xyz, 2.0, color = color)
    dbg_draw_line(ctx, corners[5].xyz, corners[1].xyz, 2.0, color = color)

}

camera_prop_changed :: proc(this: rawptr, prop: any) {
    this := cast(^Camera)this
    field, ok := prop.(reflect.Struct_Field)
    if !ok do return

    switch field.name {
    case "fov":
    case "near_plane":
    case "far_plane":
        aspect := f32(EngineInstance.screen_size.x) / f32(EngineInstance.screen_size.y)
        this.projection = linalg.matrix4_perspective_f32(this.fov, aspect, this.near_plane, this.far_plane)
        // upload_material(this.material)
    }
}

@(serializer=Camera)
serialize_camera :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^Camera)this
    if serialize {
        serialize_do_field(s, "Fov", this.fov)
        serialize_do_field(s, "NearPlane", this.near_plane)
        serialize_do_field(s, "FarPlane", this.far_plane)
    } else {
        if fov, ok := serialize_get_field(s, "Fov", type_of(this.fov)); ok {
            this.fov = fov
        }

        if near, ok := serialize_get_field(s, "NearPlane", type_of(this.near_plane)); ok {
            this.near_plane = near
        }

        if far, ok := serialize_get_field(s, "FarPlane", type_of(this.far_plane)); ok {
            this.far_plane = far
        }
    }
}

@(component="Core/Scripting")
ScriptComponent :: struct {
    using base: Component,

    script_fields: map[string]LuaValue,
    script:        AssetHandle `asset:"LuaScript"`,
    instance:      ScriptInstance,

    scripts:       [dynamic]^LuaScript,
    instances:     [dynamic]ScriptInstance,
    lua_entity:    LuaEntity,
}

@(constructor=ScriptComponent)
make_script_component :: proc() -> rawptr {
    script := new(ScriptComponent)
    script.base = default_component_constructor()

    script.init = script_init
    script.update = script_update
    script.destroy = script_destroy
    script.copy = script_copy

    when USE_EDITOR {
        script.editor_ui = script_editor_ui
    }
    return script
}

script_copy :: proc(this: rawptr) -> rawptr {
    this := cast(^ScriptComponent) this
    script := new(ScriptComponent)
    script^ = this^

    script.script_fields = clone(this.script_fields)
    script.scripts = clone(this.scripts)
    script.instances = clone(this.instances)

    return script
}

script_init :: proc(this: rawptr) {
    tracy.Zone()
    this := cast(^ScriptComponent)this
    // this.script = cast(^LuaScript)load_asset(this.script.path, LuaScript, this.script.id)
    // this.instance = create_script_instance(this.script)

    go := get_object(this.world, this.owner)
    this.lua_entity = LuaEntity{
        world = this.world,
        entity = u64(this.owner),
        owner = go,
    }

    script := get_asset(&EngineInstance.asset_manager, this.script, LuaScript)
    if script != nil  && is_script_instance_valid(this.instance) {
        L := this.instance.state

        stack_before := lua.gettop(L)

        lua.newtable(L)

        this.instance.instance_table = i64(luaL.ref(L, lua.REGISTRYINDEX))
        lua.rawgeti(L, lua.REGISTRYINDEX, this.instance.instance_table)

        for name, field in script.properties.fields {
            if name in this.script_fields {
                value := this.script_fields[name]
                log.debugf("Initializing script export %v from cache with value %v", name, value)
                script_set_field(&this.instance, field.name, value, -1)
            } else {
                script_set_field(&this.instance, field.name, field.default, -1)
            }
        }

        for name, field in script.properties.instance_fields {
            script_set_field(&this.instance, field.name, field.default, -1)
        }

        script_set_field(&this.instance, "entity", this.lua_entity, -1)

        lua.rawgeti(L, lua.REGISTRYINDEX, this.instance.on_init)

        if lua.gettop(L)+2 > lua.MINSTACK {
            log.error("Lua stack overflow: Insufficient space to push values.")
            return
        }

        lua.pushvalue(L, -2)

        if lua.pcall(L, 1, 0, 0) != lua.OK {
            message := lua.tostring(L, -1)
            log.errorf("Error calling script on_init: %v", message)
            lua.pop(L, lua.gettop(L) - stack_before)
        }

        items_pushed := lua.gettop(L) - stack_before

        lua.pop(L, items_pushed)
    }
}

script_update :: proc(this: rawptr, delta: f64) {
    tracy.Zone()
    this := cast(^ScriptComponent)this

    if is_script_instance_valid(this.instance) {
        L := this.instance.state

        stack_before := lua.gettop(L)


        lua.rawgeti(L, lua.REGISTRYINDEX, this.instance.on_update)
        if !lua.isfunction(L, -1) {
            log.error("init_ref is not a function")
            return
        }

        if lua.gettop(L)+2 > lua.MINSTACK {
            log.error("Lua stack overflow: Insufficient space to push values.")
            return
        }

        lua.rawgeti(L, lua.REGISTRYINDEX, this.instance.instance_table)
        lua.pushnumber(L, delta)

        if lua.pcall(L, 2, 0, 0) != lua.OK {
            message := lua.tostring(L, -1)
            log.errorf("Error calling script on_update: %v", message)
            lua.pop(L, lua.gettop(L) - stack_before)
        }

        items_pushed := lua.gettop(L) - stack_before

        lua.pop(L, items_pushed)
    }
}

script_destroy :: proc(this: rawptr) {
    this := cast(^ScriptComponent)this

    for name, _ in this.script_fields {
        delete(name)
    }
    delete(this.script_fields)
}

script_component_add_script :: proc(this: ^ScriptComponent, type: ScriptType) {
    // lua_sript := get_lua_script_from_type(type)
    // instance := create_script_instance(lua_script)
}

script_component_get_script :: proc(this: ^ScriptComponent, type: ScriptType) -> ScriptInstance {
    return {}
}

when USE_EDITOR {
    script_editor_ui :: proc(this: rawptr, editor: ^Editor, s: any) -> (modified: bool) {
        this := cast(^ScriptComponent)this
        pos := imgui.GetCursorPos()
        imgui.Dummy(imgui.GetContentRegionAvail())

        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
                data := cast(^AssetHandle)payload.Data

                this.script = data^
            }
            imgui.EndDragDropTarget()
        }

        imgui.SetCursorPos(pos)

        script := get_asset(&EngineInstance.asset_manager, this.script, LuaScript)
        if script != nil {
            imgui.TextUnformatted(cstr(script.properties.name))

            if imgui.Button("Press me") {
                log.debugf("%p", &this.script_fields)
            }
            if imgui.TreeNode("Exports") {
                for name, &field in this.script_fields {
                    imgui.PushIDPtr(&field)
                    defer imgui.PopID()
                    imgui.TextUnformatted(cstr(name))
                    if name != "" {
                        if imgui.BeginItemTooltip() {
                            imgui.PushTextWrapPos(imgui.GetFontSize() * 25.0)
                            imgui.TextUnformatted(cstr(script.properties.fields[name].description))
                            imgui.PopTextWrapPos()
                            imgui.EndTooltip()
                        }
                    }
                    switch &v in field {
                    case lua.Number:
                        sf := reflect.Struct_Field{
                            tag = "",
                            type = type_info_of(lua.Number),
                        }
                        draw_struct_field(editor, v, sf)
                    case lua.Integer:
                        sf := reflect.Struct_Field{
                            tag = "",
                            type = type_info_of(lua.Integer),
                        }
                        draw_struct_field(editor, v, sf)
                    case bool:
                        sf := reflect.Struct_Field{
                            tag = "",
                            type = type_info_of(bool),
                        }
                        draw_struct_field(editor, v, sf)
                    case string:
                        sf := reflect.Struct_Field{
                            tag = "",
                            type = type_info_of(string),
                        }
                        draw_struct_field(editor, v, sf)
                    case LuaTable:
                        assert(false, "LuaTable not implemented")
                    }
                }
                imgui.TreePop()
            }

            @(static) show_instance_fields := false
            imgui.Checkbox("Show Intance Fields", &show_instance_fields)
            if show_instance_fields && imgui.TreeNode("Instance Fields") {
                for name, field in script.properties.instance_fields {
                    imgui.TextUnformatted(cstr(name))
                }
                imgui.TreePop()
            }
        }
        return
    }
}

@(serializer=ScriptComponent)
serialize_script_component :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^ScriptComponent)this
    serialize_asset_handle(&EngineInstance.asset_manager, s, "Script", &this.script)

    if serialize {
        serialize_begin_table(s, "Exports")
        defer serialize_end_table(s)

        for name, value in this.script_fields {
            switch v in value {
            case lua.Number:
                serialize_do_field(s, name, v)
            case lua.Integer:
                serialize_do_field(s, name, v)
            case bool:
                serialize_do_field(s, name, v)
            case string:
                serialize_do_field(s, name, v)
            case LuaTable:
            }
        }
    } else {
        if serialize_begin_table(s, "Exports") {
            defer serialize_end_table(s)
            for key, value in serialize_get_keys(s) {
                serialized_value_to_lua_value :: proc(s: SerializedValue) -> LuaValue {
                    switch v in s {
                    case i64:
                        return LuaValue(v)
                    case f64:
                        return LuaValue(v)
                    case bool:
                        return LuaValue(v)
                    case string:
                        return LuaValue(v)
                    }
                    unreachable()
                }

                this.script_fields[strings.clone(key)] = serialized_value_to_lua_value(value)
            }
        }

        script := get_asset(&EngineInstance.asset_manager, this.script, LuaScript)
        if script != nil {
            this.instance = create_script_instance(script)
            if len(this.script_fields) != len(script.properties.fields) {
                for name, field in script.properties.fields {
                    name := strings.clone(name)
                    this.script_fields[name] = field.default
                }
            }
        }
    }
}

@(component = {
    Category = "Core/Physics",
    Conficts = { SphereColliderComponent },
})
BoxColliderComponent :: struct {
    using base: Component,

    half_extent: vec3,
}

@(constructor = BoxColliderComponent)
make_box_collider :: proc() -> rawptr {
    box := new(BoxColliderComponent)
    box.base = default_component_constructor()
    box.debug_draw = box_collider_debug_draw
    box.copy = component_shallow_copy(BoxColliderComponent)

    box.half_extent = VEC3_ONE * 0.5

    return box
}

box_collider_debug_draw :: proc(this: rawptr, d: ^DebugDrawContext) {
    this := cast(^BoxColliderComponent) this
    entity := get_object(this.world, this.owner)

    size := this.half_extent * 2 * entity.transform.local_scale
    dbg_draw_cube(d, entity.transform.position, entity.transform.local_rotation, size)
}

@(serializer = BoxColliderComponent)
serialize_box_collider :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^BoxColliderComponent) this
    if serialize {
        serialize_do_field(s, "HalfExtent", this.half_extent)
    } else {
        if he, ok := serialize_get_field(s, "HalfExtent", vec3); ok {
            this.half_extent = he
        }
    }
}

@(component = {
    Category = "Core/Physics",
    Conficts = { BoxColliderComponent },
})
SphereColliderComponent :: struct {
    using base: Component,

    radius: f32,
}

@(constructor = SphereColliderComponent)
make_sphere_collider :: proc() -> rawptr {
    sphere := new(SphereColliderComponent)
    sphere.base = default_component_constructor()
    sphere.debug_draw = sphere_collider_debug_draw
    sphere.copy = component_shallow_copy(SphereColliderComponent)

    sphere.radius = 0.5
    return sphere
}

sphere_collider_debug_draw :: proc(this: rawptr, d: ^DebugDrawContext) {
    this := cast(^SphereColliderComponent) this
    entity := get_object(this.world, this.owner)

    dbg_draw_sphere(d, entity.transform.position, entity.transform.local_rotation, this.radius)
}

@(serializer = SphereColliderComponent)
serialize_sphere_collider :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^SphereColliderComponent) this
    if serialize {
        serialize_do_field(s, "Radius", this.radius)
    } else {
        if radius, ok := serialize_get_field(s, "Radius", f32); ok {
            this.radius = radius
        }
    }
}

@(component = {
    Category = "Core/Physics",
})
RigidBodyComponent :: struct {
    using base: Component,

    body_type: BodyType,
    linear_damping: f32,
    angular_damping: f32,

    body_id: jolt.BodyID `hide:""`,
}

@(constructor=RigidBodyComponent)
make_rigid_body :: proc() -> rawptr {
    body := new(RigidBodyComponent)
    body.base       = default_component_constructor()
    body.init       = rigid_body_init
    body.update     = rigid_body_update
    body.destroy    = rigid_body_destroy
    body.copy       = rigid_body_copy

    body.angular_damping = 0.5
    body.linear_damping = 0.5

    return body
}

rigid_body_init :: proc(this: rawptr) {
    this := cast(^RigidBodyComponent) this
    entity := get_object(this.world, this.owner)
    if entity == nil do return

    physics := PhysicsInstance

    sphere_shape: ^jolt.Shape

    switch {
    case has_component(this.world, this.owner, BoxColliderComponent):
        box_collider := get_component(this.world, this.owner, BoxColliderComponent)

        extent := box_collider.half_extent * entity.transform.local_scale
        sphere_shape_settings := jolt.BoxShapeSettings_Create(&extent)
        sphere_shape = jolt.ShapeSettings_CreateShape(cast(^jolt.ShapeSettings) sphere_shape_settings)
    case has_component(this.world, this.owner, SphereColliderComponent):
        sphere_collider := get_component(this.world, this.owner, SphereColliderComponent)

        sphere_shape_settings := jolt.SphereShapeSettings_Create(sphere_collider.radius)
        sphere_shape = jolt.ShapeSettings_CreateShape(cast(^jolt.ShapeSettings) sphere_shape_settings)
    }
    if sphere_shape == nil {
        return
    }

    euler_angles := entity.transform.local_rotation
    quat := linalg.quaternion_from_euler_angles(euler_angles.y, euler_angles.x, euler_angles.z, .YXZ)
    quat_to_vec4 := transmute(vec4)quat
    sphere_body_settings: jolt.BodyCreationSettings

    jolt.BodyCreationSettings_Set(
        &sphere_body_settings,
        sphere_shape,
        &entity.transform.local_position,
        &quat_to_vec4,
        body_type_to_jolt(this.body_type),
        jolt.ObjectLayer(ObjectLayers.Moving))
    sphere := jolt.BodyInterface_CreateBody(physics.body_interface, &sphere_body_settings)
    sphere.user_data = cast(u64) this.owner
    this.body_id = sphere.id

    // TODO(minebill): Future possibility??
    // sphere := body_interface->CreateBody(&sphere_body_settings)
    // body_interface->AddBody(sphere.id, .ACTIVATION_ACTIVATE)

    jolt.BodyInterface_AddBody(physics.body_interface, sphere.id, .ACTIVATION_ACTIVATE)

    if sphere.motion_properties != nil {
        sphere.motion_properties.linear_damping = this.linear_damping
        sphere.motion_properties.angular_damping = this.angular_damping
    }
}

rigid_body_update :: proc(this: rawptr, delta: f64) {
    this := cast(^RigidBodyComponent) this
    if jolt.BodyID_IsInvalid(this.body_id) || this.body_id == 0 {
        return
    }

    physics := PhysicsInstance

    position: vec3
    jolt.BodyInterface_GetPosition(physics.body_interface, this.body_id, &position)

    r: vec4
    jolt.BodyInterface_GetRotation(physics.body_interface, this.body_id, &r)

    rotation := transmute(quaternion128)r

    entity := get_object(this.world, this.owner)
    set_global_position(entity, position)

    y, x, z := linalg.euler_angles_from_quaternion(rotation, .YXZ)
    entity.transform.local_rotation = vec3{
        x * math.DEG_PER_RAD,
        y * math.DEG_PER_RAD,
        z * math.DEG_PER_RAD}
}

rigid_body_destroy :: proc(this: rawptr) {
    this := cast(^RigidBodyComponent) this
    defer free(this)
    if jolt.BodyID_IsInvalid(this.body_id) || this.body_id == 0 {
        return
    }

    jolt.BodyInterface_RemoveBody(PhysicsInstance.body_interface, this.body_id)
    jolt.BodyInterface_DestroyBody(PhysicsInstance.body_interface, this.body_id)
}

rigid_body_copy :: proc(this: rawptr) -> rawptr {
    this := cast(^RigidBodyComponent) this

    body := new(RigidBodyComponent)
    body^ = this^

        // body_type: BodyType,
        // linear_damping: f32,
        // angular_damping: f32,

        // body_id: jolt.BodyID `hide:""`,
    return body
}

@(serializer=RigidBodyComponent)
rigid_body_serialize :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^RigidBodyComponent) this
    switch s.mode {
    case .Serialize:
        serialize_do_field(s, "BodyType", this.body_type)
        serialize_do_field(s, "LinearDamping", this.linear_damping)
        serialize_do_field(s, "AngularDamping", this.angular_damping)
    case .Deserialize:
        if body_type, ok := serialize_get_field(s, "BodyType", BodyType); ok {
            this.body_type = body_type
        }

        if ld, ok := serialize_get_field(s, "LinearDamping", f32); ok {
            this.linear_damping = ld
        }

        if ad, ok := serialize_get_field(s, "AngularDamping", f32); ok {
            this.angular_damping = ad
        }
    }
}

SkyBoxType :: enum {
    Procedural,
    HDRI,
}

@(component = {
    Category = "Core/Rendering",
})
SkyComponent :: struct {
    using base: Component,

    type: SkyBoxType,
    clouds: bool,
    clouds_density: f32,
    rayleigh_coefficient: f32,
    mie_coefficient: f32,
    mie_scattering_direction: f32,
}

@(constructor=SkyComponent)
make_sky_component :: proc() -> rawptr {
    sky := new(SkyComponent)
    sky.base = default_component_constructor()
    sky.copy = component_shallow_copy(SkyComponent)
    // sky.update     = rigid_body_update
    // sky.destroy    = rigid_body_destroy
    // sky.copy       = rigid_body_copy

    return sky
}

@(serializer=SkyComponent)
sky_component_serialize :: proc(this: rawptr, serialize: bool, s: ^SerializeContext) {
    this := cast(^SkyComponent) this

    switch s.mode {
    case .Serialize:
        serialize_do_field(s, "Type", this.type)
        serialize_do_field(s, "Clouds", this.clouds)
        serialize_do_field(s, "CloudsDensity", this.clouds_density)
        serialize_do_field(s, "RayleighCoefficient", this.rayleigh_coefficient)
        serialize_do_field(s, "MieCoefficient", this.mie_coefficient)
        serialize_do_field(s, "MieScatteringDirection", this.mie_scattering_direction)
    case .Deserialize:
        if clouds, ok := serialize_get_field(s, "Clouds", bool); ok {
            this.clouds = clouds
        }
        if clouds_density, ok := serialize_get_field(s, "CloudsDensity", f32); ok {
            this.clouds_density = clouds_density
        }
        if rayleigh_coefficient, ok := serialize_get_field(s, "RayleighCoefficient", f32); ok {
            this.rayleigh_coefficient = rayleigh_coefficient
        }
        if mie_coefficient, ok := serialize_get_field(s, "MieCoefficient", f32); ok {
            this.mie_coefficient = mie_coefficient
        }
        if mie_scattering_direction, ok := serialize_get_field(s, "MieScatteringDirection", f32); ok {
            this.mie_scattering_direction = mie_scattering_direction
        }
    }
}
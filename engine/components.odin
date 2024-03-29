package engine
import "core:log"
import "core:math/linalg"
import "core:math"
import "core:reflect"
import "core:os"
import gl "vendor:OpenGL"
import imgui "packages:odin-imgui"
import tracy "packages:odin-tracy"
import "core:io"
import "core:encoding/json"

Serializer :: struct {
    // Serialize data
    writer: io.Writer,
    opt: ^json.Marshal_Options,

    // Deserialize data
    object: json.Object,
}

// Proc used to serialize components.
// If a proc is this type and it is marked with @(constructor=C), it will be used to serialize component C.
ComponentSerializer :: #type proc(this: rawptr, serialize: bool, s: ^Serializer)

// Special case component, every gameobject has a Transform by default.
@(component)
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
serialize_transform :: proc(this: rawptr, serialize: bool, s: ^Serializer) {
    this := cast(^TransformComponent)this

    if serialize {
        w := s.writer
        opt := s.opt

        json.opt_write_start(w, opt, '{')
        json.opt_write_iteration(w, opt, 0)
        json.opt_write_key(w, opt, "LocalPosition")
        json.marshal_to_writer(w, this.local_position, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "LocalRotation")
        json.marshal_to_writer(w, this.local_rotation, opt)

        json.opt_write_iteration(w, opt, 2)
        json.opt_write_key(w, opt, "LocalScale")
        json.marshal_to_writer(w, this.local_scale, opt)
        json.opt_write_end(w, opt, '}')
    } else {
        this.local_position = json_array_to_vec(vec3, s.object["LocalPosition"].(json.Array))
        this.local_rotation = json_array_to_vec(vec3, s.object["LocalRotation"].(json.Array))
        this.local_scale = json_array_to_vec(vec3, s.object["LocalScale"].(json.Array))
    }
}

// Called by the world/gameobject.
init_transform :: proc(this: ^TransformComponent) {}

// Called by the world/gameobject.
update_transform :: proc(go: ^Entity, this: ^TransformComponent, update: f64) {
    tracy.Zone()
    parent := get_object(go.world, go.parent)

    s := linalg.matrix4_scale(go.transform.local_scale)
    r := linalg.matrix4_from_euler_angles_xyz(expand_values(go.transform.local_rotation))
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

    model:    Model,
    material: Material,
}

@(constructor=MeshRenderer)
make_mesh_renderer :: proc() -> rawptr {
    mr := new(MeshRenderer)
    mr^ = {
        base = default_component_constructor(),
        material = default_material(),
    }

    update_material(&mr.material, nil, nil, nil)

    mr.init         = mesh_renderer_init
    mr.update       = mesh_renderer_update
    mr.destroy      = mesh_renderer_destroy
    mr.prop_changed = mesh_renderer_prop_changed
    return mr
}

mesh_renderer_init :: proc(this: rawptr) {
    component_default_init(this)
}

mesh_renderer_update :: proc(this: rawptr, delta: f64) {
    component_default_update(this, delta)
}

mesh_renderer_destroy :: proc(this: rawptr) {
    component_default_destroy(this)
}

mesh_renderer_prop_changed :: proc(this: rawptr, prop: any) {
    this := cast(^MeshRenderer)this
    field, ok := prop.(reflect.Struct_Field)
    if !ok do return

    switch field.name {
    case "material":
        upload_material(this.material)
    }
}

@(serializer=MeshRenderer)
serialize_mesh_renderer :: proc(this: rawptr, serialize: bool, s: ^Serializer) {
    this := cast(^MeshRenderer)this
    am := &g_engine.asset_manager
    serialize_asset(am, s, serialize, &this.model)
    if serialize {
        w := s.writer
        opt := s.opt

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "MaterialAlbedoColor")
        json.marshal_to_writer(w, this.material.albedo_color, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "MaterialRoughness")
        json.marshal_to_writer(w, this.material.roughness_factor, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "MaterialMetalness")
        json.marshal_to_writer(w, this.material.metallic_factor, opt)
    } else {
        // model := s.object["Model"].(json.Object)
        // this.model = deserialize_asset(model, Model)
        if "MaterialAlbedoColor"in s.object {
            this.material.albedo_color = json_array_to_vec(Color, s.object["MaterialAlbedoColor"].(json.Array))
        }

        if "MaterialRoughness" in s.object {
            this.material.roughness_factor = f32(s.object["MaterialRoughness"].(json.Float))
        }

        if "MaterialMetalness" in s.object {
            this.material.metallic_factor = f32(s.object["MaterialMetalness"].(json.Float))
        }

        update_material(&this.material, nil, nil, nil)
    }
}

mesh_renderer_update_material :: proc(mr: ^MeshRenderer) {
    upload_material(mr.material)
}

@(component="Core/Lights")
PointLightComponent :: struct {
    using base: Component,

    color: Color,
    distance: f32 `range:"0.0, 100.0"`,
    power: f32 `range:"0.0, 10.0"`,

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

        color = Color{1, 1, 1, 1},
        constant = 1.0,
        linear = 0.7,
        quadratic = 1.8,
    }
    return light
}

@(serializer=PointLightComponent)
serialize_point_light :: proc(this: rawptr, serialize: bool, s: ^Serializer) {
    this := cast(^PointLightComponent)this
    if serialize {
        w := s.writer
        opt := s.opt

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "color")
        json.marshal_to_writer(w, this.color, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "constant")
        json.marshal_to_writer(w, this.constant, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "linear")
        json.marshal_to_writer(w, this.linear, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "quadratic")
        json.marshal_to_writer(w, this.quadratic, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "distance")
        json.marshal_to_writer(w, this.distance, opt)

        json.opt_write_iteration(w, opt, 1)
        json.opt_write_key(w, opt, "power")
        json.marshal_to_writer(w, this.power, opt)
    } else {
        this.color = json_array_to_vec(Color, s.object["color"].(json.Array))
        this.constant = f32(s.object["constant"].(json.Float))
        this.linear = f32(s.object["linear"].(json.Float))
        this.quadratic = f32(s.object["quadratic"].(json.Float))
        this.distance = f32(s.object["distance"].(json.Float))
        this.power = f32(s.object["power"].(json.Float))
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
}

@(constructor=DirectionalLight)
make_directional_light :: proc() -> rawptr {
    light := new(DirectionalLight)
    light.base = default_component_constructor()
    // light.init = directional_light_init

    light.color = COLOR_WHITE

    return light
}

json_array_to_vec :: proc($V: typeid/[$N]$E, arr: json.Array) -> (vec: V)
where N == 2 || N == 3 || N == 4 {
    when E == f32 {
        for i in 0..<N {
            vec[i] = f32(arr[i].(json.Float))
        }
    } else when E == i32 {
        for i in 0..<N {
            vec[i] = i32(arr[i].(json.Integer))
        }
    }
    return
}

@(serializer=DirectionalLight)
serialize_directional_light :: proc(this: rawptr, serialize: bool, s: ^Serializer) {
    this := cast(^DirectionalLight)this
    if serialize {
        json.opt_write_iteration(s.writer, s.opt, 1)
        json.opt_write_key(s.writer, s.opt, "color")
        json.marshal_to_writer(s.writer, this.color, s.opt)
    } else {
        c, ok := s.object["color"].(json.Array)
        if !ok do return
        assert(len(c) == len(Color))

        // for i in 0..<4 {
        //     this.color[i] = f32(c[i].(json.Float))
        // }
        this.color = json_array_to_vec(Color, c)

    }
}

@(component="Core/Rendering", name="Cubemap")
CubemapComponent :: struct {
    using base: Component,

    texture: Texture2D,
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

    for image_path, i in images {
        data, ok := os.read_entire_file(image_path)
        defer delete(data)
        if !ok do continue
        image, image_loaded := load_image_memory(data)
        defer destroy_image(&image)
        if !image_loaded {
            log.warnf("Failed to load image '%v'", image_path)
            continue // NOTE(minebill): Maybe abort?
        }
        if !created {
            params := DEFAULT_TEXTURE_PARAMS
            params.format = gl.RGBA8
            cube.texture = create_cubemap_texture(image.width, image.height, params)
            created = true
        }

        gl.TextureSubImage3D(
            cube.texture.handle,
            0, 0, 0, i32(i),
            cast(i32)image.width,
            cast(i32)image.height,
            1,
            gl.RGBA, gl.UNSIGNED_BYTE, raw_data(image.data))
    }

    ok: bool
    cube.shader, ok = shader_load_from_file(
        "assets/shaders/cubemap.vert.glsl",
        "assets/shaders/cubemap.frag.glsl")
    if !ok {
        log.warnf("Failed to load shader")
    }

    return cube
}

@(component="Testing")
BallGenerator :: struct {
    using base: Component,

    object_to_clone: Handle,

    draw_preview: bool,
    spawn_count: vec3i,
    size: vec3,
}

@(constructor=BallGenerator)
make_ball_generator :: proc() -> rawptr {
    this := new(BallGenerator)
    this.base = default_component_constructor()
    this.update = bg_update

    this.spawn_count = vec3i{5, 1, 5}

    when USE_EDITOR {
        this.editor_ui = bg_editor_ui
    }

    return this
}

bg_init :: proc(this: rawptr) {
    this := cast(^BallGenerator)this
}

bg_update :: proc(this: rawptr, delta: f64) {
    this := cast(^BallGenerator)this

    if this.draw_preview {
        d := g_dbg_context
        go := get_object(this.world, this.owner)

        for x in 0..<this.spawn_count.x {
            for z in 0..<this.spawn_count.z {
                dbg_draw_cube(d, go.transform.position + vec3{f32(x), 0, f32(z)}, vec3{0.5, 0.5, 0.5})
            }
        }

        dbg_draw_cube(d, go.transform.position, linalg.array_cast(this.spawn_count, f32) + vec3{0.5, 0.5, 0.5})
    }
}

when USE_EDITOR {

bg_editor_ui :: proc(this: rawptr) {
    this := cast(^BallGenerator)this

    imgui.Separator()

    if imgui.Button("Generate") {
        material := default_material()
        update_material(&material, nil, nil, nil)

        material.albedo_color = Color{1, 0, 0, 1}

        to_clone_mr := get_component(this.world, this.object_to_clone, MeshRenderer)
        if to_clone_mr == nil do return

        metalness := f32(1) / f32(this.spawn_count.x)
        for x in 0..<this.spawn_count.x {
            roughness := f32(1) / f32(this.spawn_count.z)
            for z in 0..<this.spawn_count.z {
                handle := new_object(this.world, parent = this.owner)
                mr := get_or_add_component(this.world, handle, MeshRenderer)
                mr.model = to_clone_mr.model

                mr.material = clone_material(material)
                // mr.material.albedo_color = color{0, 1, 0, 1}
                mr.material.roughness_factor = roughness
                mr.material.metallic_factor = metalness
                mesh_renderer_update_material(mr)

                go := get_object(this.world, handle)
                go.transform.local_position = vec3{f32(x), 0, f32(z)}
                roughness += f32(1) / f32(this.spawn_count.z)
            }
            metalness += f32(1) / f32(this.spawn_count.x)
        }
    }
}

}

package engine
import "core:log"
import "core:math/linalg"
import "core:math"
import "core:reflect"
import "core:os"
import gl "vendor:OpenGL"
import imgui "packages:odin-imgui"
import tracy "packages:odin-tracy"

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

// Called by the world/gameobject.
init_transform :: proc(this: ^TransformComponent) {}

// Called by the world/gameobject.
update_transform :: proc(go: ^GameObject, this: ^TransformComponent, update: f64) {
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

set_global_position :: proc(go: ^GameObject, pos: vec3) {
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

@(ctor_for=PrinterComponent)
make_printer :: proc() -> rawptr {
    printer := new(PrinterComponent)
    // printer.base = default_component_constructor()
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

@(component)
MeshRenderer :: struct {
    using base: Component,

    model:    Model,
    material: Material,
}

@(ctor_for=MeshRenderer)
make_mesh_renderer :: proc() -> rawptr {
    mr := new(MeshRenderer)
    mr^ = {
        base = default_component_constructor(),
        material = default_material(),
    }

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
    log.debug("Prop changed: %v", field.name)

    switch field.name {
    case "material":
        upload_material(this.material)
    }
}

mesh_renderer_update_material :: proc(mr: ^MeshRenderer) {
    upload_material(mr.material)
}

@(component="Core/Lights")
PointLightComponent :: struct {
    using base: Component,

    color: color,
    distance: f32 `range:"0.0, 100.0"`,
    power: f32 `range:"0.0, 10.0"`,

    constant: f32 `hide:""`,
    linear: f32 `hide:""`,
    quadratic: f32 `hide:""`,
}

@(ctor_for=PointLightComponent)
make_point_light :: proc() -> rawptr {
    light := new(PointLightComponent)
    light^ = {
        base = default_component_constructor(),
        init = component_default_init,
        update = component_default_update,
        prop_changed = point_light_prop_changed,

        color = color{1, 1, 1, 1},
        constant = 1.0,
        linear = 0.7,
        quadratic = 1.8,
    }
    return light
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

@(ctor_for=SpotLightComponent)
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

@(ctor_for=MoverComponent)
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
    color: color,
}

@(ctor_for=DirectionalLight)
make_directional_light :: proc() -> rawptr {
    light := new(DirectionalLight)
    light.base = default_component_constructor()
    // light.init = directional_light_init

    light.color = COLOR_WHITE

    return light
}

@(component="Core/Rendering", name="Cubemap")
CubemapComponent :: struct {
    using base: Component,

    texture: Texture2D,
    shader: Shader,
}

@(ctor_for=CubemapComponent)
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
        if !ok do continue
        image, image_loaded := load_image_memory(data)
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

@(ctor_for=BallGenerator)
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

        material.albedo_color = color{1, 0, 0, 1}

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

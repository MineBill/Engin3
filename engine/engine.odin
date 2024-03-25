package engine
import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:log"
import "core:runtime"
import "core:math/linalg"
import "core:math"
import tracy "packages:odin-tracy"
import nk "packages:odin-nuklear"
import "../monitor"
import "core:thread"
import "packages:odin-imgui/imgui_impl_glfw"
import "packages:odin-imgui/imgui_impl_opengl3"
import imgui "packages:odin-imgui"
import "core:sys/windows"

GL_DEBUG_CONTEXT :: ODIN_DEBUG

CAMERA_DEFAULT_POSITION :: vec3{0, 3, 10}

SHADOW_MAP_RES :: 4096

Camera :: struct {
    position:       vec3,
    rotation:       quaternion128,
    euler_angles:   vec3,
    fov:            f32,

    projection: mat4,
}

Scene_Data :: struct {
    using block : struct {
        view_position: vec4,
        ambient_color: vec4,
    },

    ubo: u32,
}

MAX_SPOTLIGHTS :: 10
MAX_POINTLIGHTS :: 10

Lights_Data :: struct {
    using block : struct {
        directional: struct {
            direction: vec4,
            color: color,
            light_space_matrix: mat4,
        },

        pointlights: [MAX_POINTLIGHTS]struct {
            color: color,
            position: vec3,

            constant: f32,
            linear: f32,
            quadratic: f32,
            _: f32,
        },
        spotlights: [MAX_SPOTLIGHTS]struct {
            _: f32,
        },
    },
    ubo: u32,
}

EngineMode :: enum {
    Game,
    Editor,
}

Engine :: struct {
    ctx:    runtime.Context,
    window: glfw.WindowHandle,
    quit:   bool,

    triangle_shader: Shader,
    outline_shader:  Shader,
    screen_shader:   Shader,
    grid_shader:     Shader,
    depth_shader:    Shader,

    triangle_va:     u32,
    grid_va: u32,

    ubo:          u32,
    material_ubo: u32,
    scene_data:   Scene_Data,
    lights:       Lights_Data,

    light_entity: int,
    box_entity: int,

    previouse_mouse: vec2,
    camera:          Camera,
    scene:           Scene,
    editor:          Editor,
    game:            Game,
    run_mode:        EngineMode,

    world: World,

    shader_monitor: monitor.Monitor,

    viewport_fb:          FrameBuffer,
    depth_fb:             FrameBuffer,
    viewport_resolved_fb: FrameBuffer,
    scene_fb:             FrameBuffer,

    dbg_draw: DebugDrawContext,

    width, height: i32,
}

engine_init :: proc(e: ^Engine) -> Engine_Error {
    tracy.SetThreadName("main")
    tracy.Zone()


    engine_setup_window(e) or_return

    when GL_DEBUG_CONTEXT {
        flags: i32
        gl.GetIntegerv(gl.CONTEXT_FLAGS, &flags)
        if flags & gl.CONTEXT_FLAG_DEBUG_BIT != 0 {
            gl.Enable(gl.DEBUG_OUTPUT)
            gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
            gl.DebugMessageCallback(opengl_debug_callback, e)
            gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, true)
        }
    }

    vendor   := gl.GetString(gl.VENDOR)
    renderer := gl.GetString(gl.RENDERER)
    version  := gl.GetString(gl.VERSION)
    log.infof("Vendor %v", vendor)
    log.infof("\tUsing %v", renderer)
    log.infof("\tVersion %v", version)

    data: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &data)
    log.debugf("Max texture anistotropy: %v", data)

    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.FrontFace(gl.CW)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.FRONT)

    gl.Enable(gl.STENCIL_TEST)
    gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)

    editor_init(&e.editor, e)
    context.logger = e.editor.logger

    game_init(&e.game, e)

    // === POST INITIALIZE ===
    ok: bool
    e.triangle_shader, ok = shader_load_from_file(
        "assets/shaders/triangle.vert.glsl",
        "assets/shaders/pbr.frag.glsl")
    if !ok {
        return .Shader
    }

    e.outline_shader, ok = shader_load_from_file(
        "assets/shaders/outline.vert.glsl",
        "assets/shaders/outline.frag.glsl")
    if !ok {
        return .Shader
    }

    e.grid_shader, ok = shader_load_from_file(
        "assets/shaders/grid.vert.glsl",
        "assets/shaders/grid.frag.glsl")
    if !ok {
        return .Shader
    }

    e.depth_shader, ok = shader_load_from_file(
        "assets/shaders/depth.vert.glsl",
        "assets/shaders/depth.frag.glsl")
    if !ok {
        return .Shader
    }

    gl.CreateVertexArrays(1, &e.grid_va)

    {
        SCREEN_VERTEX_SRC : string : `
#version 460 core

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 uv;

layout(location = 0) out VS_OUT {
    vec2 uv;
} OUT;

void main() {
    OUT.uv = uv;
    gl_Position = vec4(position, 0.0, 1.0);
}
        `
        SCREEN_FRAG_SRC : string : `
#version 460 core

layout(location = 0) in VS_IN {
    vec2 uv;
} IN;

layout(binding = 0) uniform sampler2D screen_texture;

layout(location = 0) out vec4 out_color;

void main() {
    out_color = texture(screen_texture, IN.uv);
    out_color.rgb = pow(out_color.rgb, vec3(1.0 / 2.2));
}
        `
        e.screen_shader, ok = shader_load_from_memory(
            transmute([]byte)SCREEN_VERTEX_SRC,
            transmute([]byte)SCREEN_FRAG_SRC)
        if !ok {
            return .Shader
        }

    }

    // View_Data UBO
    {
        gl.CreateBuffers(1, &e.ubo)
        gl.NamedBufferData(e.ubo, size_of(Uniform), nil, gl.DYNAMIC_DRAW)

        e.camera.fov = 45.0;
        e.camera.projection = linalg.matrix4_perspective_f32(e.camera.fov, 16.0 / 9.0, 0.1, 1000.0)
        gl.NamedBufferSubData(e.ubo, 0, size_of(mat4), &e.camera.projection)

        // view := linalg.matrix4_translate(vec3{0, 3, -10})
        // gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &view)
        e.camera.position = CAMERA_DEFAULT_POSITION

        gl.BindBufferBase(gl.UNIFORM_BUFFER, 0, e.ubo)
    }

    // Scene_Data UBO
    {
        gl.CreateBuffers(1, &e.scene_data.ubo)
        gl.NamedBufferData(e.scene_data.ubo, size_of(e.scene_data.block), &e.scene_data.block, gl.DYNAMIC_DRAW)

        gl.BindBufferBase(gl.UNIFORM_BUFFER, 1, e.scene_data.ubo)
    }

    {
        gl.CreateBuffers(1, &e.lights.ubo)
        gl.NamedBufferData(e.lights.ubo, size_of(e.lights.block), &e.lights.block, gl.DYNAMIC_DRAW)

        gl.BindBufferBase(gl.UNIFORM_BUFFER, 3, e.lights.ubo)
    }

    // model_loc := gl.GetUniformLocation(e.triangle_shader.program, "model")
    // e.triangle_shader.uniforms["model"] = model_loc

    spec := FrameBufferSpecification {
        width = 800,
        height = 800,
        attachments = attachment_list(.RGBA16F, .RED_INTEGER, .DEPTH),
        samples = 1,
    }
    e.viewport_fb          = create_framebuffer(spec)

    spec.attachments = attachment_list(.RGBA16F, .DEPTH)
    e.viewport_resolved_fb = create_framebuffer(spec)
    e.scene_fb             = create_framebuffer(spec)

    spec.width       = SHADOW_MAP_RES
    spec.height      = SHADOW_MAP_RES
    spec.attachments = attachment_list(.DEPTH32F)
    spec.samples = 1
    e.depth_fb       = create_framebuffer(spec)

    // e.viewport_fb          = gen_framebuffer(800, 800, format = gl.RGBA16F)
    // e.viewport_resolved_fb = gen_framebuffer(800, 800, format = gl.RGBA16F)
    // e.scene_fb             = gen_framebuffer(800, 800, format = gl.RGBA16F)
    // e.depth_fb             = gen_framebuffer(SHADOW_MAP_RES, SHADOW_MAP_RES, pure_depth = true)
    e.width = 800
    e.height = 800

    imgui.CreateContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += {.DockingEnable, .ViewportsEnable}
    io.IniFilename = nil
    imgui.LoadIniSettingsFromDisk("editor_layout.ini")

    setup_imgui_style()

    // imgui.FontAtlas_AddFont(io.Fonts, )
    inter_font :: #load("../assets/fonts/inter/Inter-Regular.ttf")
    imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(inter_font), cast(i32)len(inter_font), 16, nil, nil)

    imgui_impl_glfw.InitForOpenGL(e.window, true)
    imgui_impl_opengl3.Init("#version 450 core")

    nk_init(e.window)
    atlas: ^nk.Font_Atlas
    nk_font_stash_begin(&atlas)
    nk_font_stash_end()

    dbg_init(&e.dbg_draw)
    g_dbg_context = &e.dbg_draw

    monitor.init(&e.shader_monitor, "assets/shaders", {
        "triangle.vert.glsl",
        "pbr.frag.glsl",

        "outline.vert.glsl",
        "outline.frag.glsl",

        "grid.vert.glsl",
        "grid.frag.glsl",
    })

    thread.run_with_data(&e.shader_monitor, monitor.thread_proc)

    e.run_mode = .Editor

    e.world = create_world()
    log.debug(e.world.next_handle)
    root := &e.world.objects[e.world.root]
    root.world = &e.world
    root.transform.local_scale = vec3{1, 1, 1}
    root.transform.local_scale = vec3{1, 1, 1}
    root.parent = 9999

    go_handle := new_object(&e.world, "Pepegas")
    log.debug(e.world.next_handle)

    go := &e.world.objects[go_handle]

    // set_global_position(go, vec3{1, 1, 1})

    a := new_object(&e.world, "Hmm", go_handle)
    b := new_object(&e.world, "Hmm2", go_handle)
    c := new_object(&e.world, "Hehehehe", b)

    dir_handle := new_object(&e.world, "Directional Light")
    dir_go := get_object(&e.world, dir_handle)
    dir_go.transform.local_rotation = vec3{75, 0, 0}
    add_component(&e.world, dir_handle, DirectionalLight)

    scene_load_from_file(&e.world, "assets/scenes/simple_scene.glb", &e.scene)

    return {}
}

// This is its own separate proc, so it can be called from
// the editor during viewport resize.
engine_resize :: proc(e: ^Engine, width, height: int) {
    _destroy_framebuffer(e.viewport_fb)
    _destroy_framebuffer(e.viewport_resolved_fb)
    _destroy_framebuffer(e.scene_fb)
    // destroy_framebuffer(e.depth_fb)

    // e.viewport_fb = gen_framebuffer(width, height, i32(g_msaa_level), format = gl.RGBA16F)
    e.viewport_fb.spec.samples = int(g_msaa_level)
    resize_framebuffer(&e.viewport_fb, width, height)
    resize_framebuffer(&e.viewport_resolved_fb, width, height)
    resize_framebuffer(&e.scene_fb, width, height)

    // e.viewport_resolved_fb = gen_framebuffer(width, height, format = gl.RGBA16F)
    // e.scene_fb = gen_framebuffer(width, height)
    // e.depth_fb = gen_framebuffer(width, height)

    e.width = i32(width)
    e.height = i32(height)
}

engine_update :: proc(e: ^Engine, _delta: f64) {

    context.logger = e.editor.logger

    @static CAMERA_SPEED := f32(2)
    defer tracy.FrameMark()
    tracy.Zone()
    delta := f32(_delta)
    glfw.PollEvents()

    if e.shader_monitor.triggered {
        log.debug("Shader reload triggered")
        e.shader_monitor.triggered = false

        {
            copy := e.triangle_shader
            if shader_reload(&copy) {
                e.triangle_shader = copy
            }
        }

        {
            copy := e.outline_shader
            if shader_reload(&copy) {
                e.outline_shader = copy
            }
        }

        {
            copy := e.grid_shader
            if shader_reload(&copy) {
                e.grid_shader = copy
            }
        }
    }

    if is_key_just_released(.f1) {
        if e.run_mode == .Game {
            e.run_mode = .Editor
        } else {
            e.run_mode = .Game

            width, height := glfw.GetWindowSize(e.window)
            append(&g_event_ctx.events, WindowResizedEvent{size = [2]f32{f32(width), f32(height)}})
        }

    }

    nk_new_frame()

    switch e.run_mode {
    case .Game:
        game_update(&e.game, _delta)

    case .Editor:

        imgui_impl_glfw.NewFrame()
        imgui_impl_opengl3.NewFrame()
        imgui.NewFrame()

        editor_update(&e.editor, _delta)
        n := &nk_context.ctx
        if nk.begin(n, "Window", nk.rect(0, 0, f32(e.width), 150), {}) {
            nk.layout_row_dynamic(n, 30, 2)
            if nk.button_string(n, "Button") {
                log.debug("Button!")
            }
            nk.label_string(n, "Label!", {.Centered})
            nk.end(n)
        }
    }
    world_update(&e.world, _delta)

    engine_draw(e)

    flush_input()
    free_all(context.temp_allocator)
}

engine_draw :: proc(e: ^Engine) {
    tracy.Zone()
    i: int

    // Collect all meshes
    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in e.world.objects do if go.enabled && has_component(&e.world, handle, MeshRenderer) {
            mr := get_component(&e.world, handle, MeshRenderer)
            append(&mesh_components, mr)
        }
    }

    // Push all the light data to the GPU
    gl.BindFramebuffer(gl.FRAMEBUFFER, e.depth_fb.handle)
    gl.Viewport(0, 0, SHADOW_MAP_RES, SHADOW_MAP_RES)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.FrontFace(gl.CW)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.FRONT)
    gl.Enable(gl.BLEND)

    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    // if dir_light, ok := get_entity(e.light_entity, Directional_Light); ok && dir_light.enabled {
    for handle, &go in e.world.objects do if go.enabled && has_component(&e.world, handle, DirectionalLight) {
        dir_light := get_component(&e.world, handle, DirectionalLight)
        r := go.transform.local_rotation
        dir_light_quat := linalg.quaternion_from_euler_angles(
                            r.x * math.RAD_PER_DEG,
                            r.y * math.RAD_PER_DEG,
                            r.z * math.RAD_PER_DEG,
                            .XYZ)
        dir := linalg.quaternion_mul_vector3(dir_light_quat, vec3{0, 0, -1})

        ubo_data: struct {
            view: mat4,
            proj: mat4,
        }

        camera_view := linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
        camera_proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(e.width) / f32(e.height), 0.1, 20.0)
        corners := get_frustum_corners_world_space(camera_proj, camera_view)

        center := vec3{}

        for corner in corners {
            center += corner.xyz
        }
        center /= len(corners)

        dbg_draw_line(&e.dbg_draw, center - vec3{0, 0.125, 0}, center + vec3{0, 0.125, 0})
        dbg_draw_line(&e.dbg_draw, center - vec3{0.125, 0, 0}, center + vec3{0.125, 0, 0})
        dbg_draw_line(&e.dbg_draw, center - vec3{0, 0, 0.125}, center + vec3{0, 0, 0.125})

        ubo_data.view = linalg.matrix4_look_at_f32(center + dir, center, vec3{0, 1, 0})
        // ubo_data.view = linalg.matrix4_from_quaternion(dir_light_quat) 

        min_f :: min(f32)
        max_f :: max(f32)

        min, max := vec3{max_f, max_f, max_f}, vec3{min_f, min_f, min_f}

        for corner in corners {
            hm := (ubo_data.view * corner).xyz

            if hm.x < min.x {
                min.x = hm.x
            }
            if hm.y < min.y {
                min.y = hm.y
            }
            if hm.z < min.z {
                min.z = hm.z
            }

            if hm.x > max.x {
                max.x = hm.x
            }
            if hm.y > max.y {
                max.y = hm.y
            }
            if hm.z > max.z {
                max.z = hm.z
            }
        }

        ubo_data.proj = linalg.matrix_ortho3d_f32(
            left = min.x, 
            right = max.x,
            bottom = min.y,
            top = max.y,
            near = min.z,
            far = max.z)

        gl.NamedBufferSubData(e.ubo, 0, size_of(ubo_data), &ubo_data)

        e.lights.directional.direction = vec4{dir.x, dir.y, dir.z, 0}
        e.lights.directional.color = dir_light.color
        e.lights.directional.light_space_matrix = ubo_data.proj * ubo_data.view

        gl.NamedBufferSubData(e.lights.ubo, int(offset_of(e.lights.block.directional)), size_of(e.lights.block.directional), &e.lights.block)

        gl.UseProgram(e.depth_shader.program)
        gl.UniformMatrix4fv(uniform(&e.depth_shader, "light_space"), 1, false, &e.lights.directional.light_space_matrix[0][0])
        for mr in mesh_components {
            gl.BindVertexArray(mr.model.vertex_array)

            go := get_object(&e.world, mr.owner)
            mm := &go.transform.global_matrix
            gl.UniformMatrix4fv(uniform(&e.depth_shader, "model"), 1, false, &mm[0][0])

            gl.DrawElements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT, nil)
        }
    }

    num_point_lights := 0
    { // Collect all the point lights.
        tracy.ZoneN("Light Collection")
        for handle, &go in e.world.objects do if has_component(&e.world, handle, PointLightComponent) {
            point_light := get_component(&e.world, handle, PointLightComponent)

            light := &e.lights.pointlights[num_point_lights]
            light.color = point_light.color
            light.linear = point_light.linear
            light.constant = point_light.constant
            light.quadratic = point_light.quadratic
            light.position = go.transform.position

            num_point_lights += 1
        }

        if num_point_lights > 0 {
            gl.NamedBufferSubData(
                e.lights.ubo,
                int(offset_of(e.lights.block.pointlights)),
                size_of(e.lights.block.pointlights[0]) * num_point_lights,
                &e.lights.pointlights)
        }
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, e.viewport_fb.handle)
    gl.Viewport(0, 0, i32(e.width), i32(e.height))

    // view := linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
    // gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &view)
    e.camera.projection = linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(e.width) / f32(e.height), 0.1, 1000.0)
    gl.NamedBufferSubData(e.ubo, 0, size_of(mat4), &e.camera.projection)

    e.scene_data.view_position.xyz = e.camera.position
    gl.NamedBufferSubData(
        e.scene_data.ubo,
        int(offset_of(e.scene_data.view_position)),
        size_of(e.scene_data.view_position),
        &e.scene_data.view_position)

    // gl.Enable(gl.DEPTH_TEST)
    // gl.DepthFunc(gl.LESS)
    // gl.FrontFace(gl.CW)

    // gl.Enable(gl.CULL_FACE)
    // gl.CullFace(gl.FRONT)
    // gl.Enable(gl.BLEND)

    // gl.ClearColor(0.1, 0.8, 0.2, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

    gl.Disable(gl.DEPTH_TEST)
    // === SKYBOX ===
    if cubemap := find_first_component(&e.world, CubemapComponent); cubemap != nil {
        view := linalg.matrix4_from_quaternion(e.camera.rotation)
        gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &view)

        gl.UseProgram(cubemap.shader.program)
        gl.BindVertexArray(e.grid_va)
        gl.BindTextureUnit(6, cubemap.texture.handle)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }
    gl.Enable(gl.DEPTH_TEST)

    view := linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
    gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &view)

    gl.UseProgram(e.triangle_shader.program)

    gl.Uniform1i(uniform(&e.triangle_shader, "num_point_lights"), i32(num_point_lights))

    gl.Disable(gl.STENCIL_TEST)
    gl.BindTextureUnit(2, get_depth_attachment(e.depth_fb))
    i = 0
    // for entity in entities_iter(&i, Model_Entity) do if entity.enabled {

    for mr in mesh_components {
        go := get_object(&e.world, mr.owner)
        gl.BindVertexArray(mr.model.vertex_array)
        bind_material(&mr.material)
        // gl.BindBuffer(gl.UNIFORM_BUFFER, model.material.ubo)

        mm := &go.transform.global_matrix
        gl.UniformMatrix4fv(uniform(&e.triangle_shader, "model"), 1, false, &mm[0][0])
        gl.Uniform1i(uniform(&e.triangle_shader, "gameobject_id"), i32(go.handle))

        gl.DrawElements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT, nil)
    }

    gl.UseProgram(e.triangle_shader.program)
    gl.Enable(gl.STENCIL_TEST)

    // Enable some stencil stuff here

    // gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
    gl.Disable(gl.DEPTH_TEST)
    gl.ColorMask(false, false, false, false)
    gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
    gl.StencilMask(0xFF)

    for mr in mesh_components {
        go := get_object(&e.world, mr.owner)
        if .Outlined not_in go.flags {
            continue
        }

        gl.BindVertexArray(mr.model.vertex_array)

        SCALE :: 1.0
        mm := &go.transform.global_matrix
        gl.UniformMatrix4fv(uniform(&e.triangle_shader, "model"), 1, false, &mm[0][0])

        gl.DrawElements(gl.TRIANGLES, mr.model.num_indices, gl.UNSIGNED_SHORT, nil)
    }
    gl.Disable(gl.STENCIL_TEST)
    gl.Enable(gl.DEPTH_TEST)
    gl.ColorMask(true, true, true, true)

    dbg_render(&e.dbg_draw)
    // gl.DepthFunc(gl.LESS)

    gl.Enable(gl.BLEND)
    gl.UseProgram(e.grid_shader.program)
    gl.BindVertexArray(e.grid_va)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    width, height := f32(e.width), f32(e.height)
    blit_framebuffer_new(e.viewport_fb, e.viewport_resolved_fb, {{0, 0}, {width, height}}, {{0, 0}, {width, height}}, 0)

    final_fb: u32
    switch e.run_mode {
    case .Game: final_fb = 0
    case .Editor: final_fb = e.scene_fb.handle
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, final_fb)
    gl.Viewport(0, 0, e.width, e.height)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

    {
        blend := gl.IsEnabled(gl.BLEND)
        gl.Disable(gl.DEPTH_TEST)
        vao: u32
        // gl.PolygonMode()
        gl.CreateVertexArrays(1, &vao)
        defer gl.DeleteVertexArrays(1, &vao)

        screen: u32
        gl.CreateBuffers(1, &screen)
        defer gl.DeleteBuffers(1, &screen)
        vertices := []f32 {
        -1.0,  1.0,  0.0, 1.0,
        -1.0, -1.0,  0.0, 0.0,
         1.0, -1.0,  1.0, 0.0,

        -1.0,  1.0,  0.0, 1.0,
         1.0, -1.0,  1.0, 0.0,
         1.0,  1.0,  1.0, 1.0,
        }
        gl.NamedBufferStorage(screen, len(vertices) * size_of(f32), raw_data(vertices), gl.DYNAMIC_STORAGE_BIT)

        gl.VertexArrayVertexBuffer(vao, 0, screen, 0, 4 * size_of(f32))

        gl.EnableVertexArrayAttrib(vao, 0)
        gl.EnableVertexArrayAttrib(vao, 1)

        gl.VertexArrayAttribFormat(vao, 0, 2, gl.FLOAT, false, 0)
        gl.VertexArrayAttribFormat(vao, 1, 2, gl.FLOAT, false, 2 * size_of(f32))

        gl.VertexArrayAttribBinding(vao, 0, 0)
        gl.VertexArrayAttribBinding(vao, 1, 0)

        gl.BindVertexArray(vao)

        gl.UseProgram(e.screen_shader.program)
        gl.BindTextureUnit(0, get_color_attachment(e.viewport_resolved_fb))
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))

        #partial switch e.run_mode {
        case .Editor:
            gl.UseProgram(e.outline_shader.program)
            gl.BindTextureUnit(1, get_color_attachment(e.viewport_resolved_fb))
            gl.BindTextureUnit(0, get_depth_attachment(e.viewport_resolved_fb))
            gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))
        }

        // if !blend do gl.Disable(gl.BLEND)
        gl.Enable(gl.DEPTH_TEST)
    }

    nk_render()

    switch e.run_mode {
    case .Game:
    case .Editor:
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        imgui.Render()
        data := imgui.GetDrawData()
        imgui_impl_opengl3.RenderDrawData(data)

        if .ViewportsEnable in imgui.GetIO().ConfigFlags {
            ctx := glfw.GetCurrentContext()
            imgui.UpdatePlatformWindows()
            imgui.RenderPlatformWindowsDefault()
            glfw.MakeContextCurrent(ctx)
        }
    }


    glfw.SwapBuffers(e.window)
}

engine_deinit :: proc(e: ^Engine) {
    scene_deinit(&e.scene)
    shader_deinit(&e.triangle_shader)
    shader_deinit(&e.outline_shader)
    destroy_world(&e.world)

    editor_deinit(&e.editor)

    monitor.deinit(&e.shader_monitor)
}

engine_should_close :: proc(e: ^Engine) -> bool {
    return glfw.WindowShouldClose(e.window) == true
}

engine_setup_window :: proc(e: ^Engine) -> Engine_Error {
    if !glfw.Init() {
        return .GLFW_Failed_Init
    }

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    // glfw.WindowHint(glfw.SRGB_CAPABLE, glfw.TRUE)

    when GL_DEBUG_CONTEXT {
        glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, true)
    }
    e.window = glfw.CreateWindow(1280, 720, "Engin3", nil, nil)
    if e.window == nil do return .GLFW_Failed_Window

    when ODIN_OS == .Windows {
        handle := glfw.GetWin32Window(e.window)
        value: windows.BOOL = true
        _ = windows.DwmSetWindowAttribute(handle, 20, &value, size_of(value))
    }

    glfw.SetInputMode(e.window, glfw.RAW_MOUSE_MOTION, 1)

    glfw.MakeContextCurrent(e.window)
    gl.load_up_to(4, 6, glfw.gl_set_proc_address)

    glfw.SwapInterval(1)

    setup_glfw_callbacks(e.window)
    return {}
}

opengl_debug_callback :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
    // if id == 131169 || id == 131185 || id == 131218 || id == 131204 do return
    e := cast(^Engine)userParam
    context = e.ctx

    source_str: string
    switch source
    {
        case gl.DEBUG_SOURCE_API:             source_str = "API"
        case gl.DEBUG_SOURCE_WINDOW_SYSTEM:   source_str = "Window System"
        case gl.DEBUG_SOURCE_SHADER_COMPILER: source_str = "Shader Compiler"
        case gl.DEBUG_SOURCE_THIRD_PARTY:     source_str = "Third Party"
        case gl.DEBUG_SOURCE_APPLICATION:     source_str = "Application"
        case gl.DEBUG_SOURCE_OTHER:           source_str = "Other"
    }

    type_str: string
    switch type
    {
        case gl.DEBUG_TYPE_ERROR:               type_str = "Error"
        case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: type_str = "Deprecated Behaviour"
        case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  type_str = "Undefined Behaviour"
        case gl.DEBUG_TYPE_PORTABILITY:         type_str = "Portability"
        case gl.DEBUG_TYPE_PERFORMANCE:         type_str = "Performance"
        case gl.DEBUG_TYPE_MARKER:              type_str = "Marker"
        case gl.DEBUG_TYPE_PUSH_GROUP:          type_str = "Push Group"
        case gl.DEBUG_TYPE_POP_GROUP:           type_str = "Pop Group"
        case gl.DEBUG_TYPE_OTHER:               type_str = "Other"
    }
    
    severity_str: string
    switch severity
    {
        case gl.DEBUG_SEVERITY_HIGH:         severity_str = "high"
        case gl.DEBUG_SEVERITY_MEDIUM:       severity_str = "medium"
        case gl.DEBUG_SEVERITY_LOW:          severity_str = "low"
        case gl.DEBUG_SEVERITY_NOTIFICATION: severity_str = "notification"
    }

    log.warn("OpenGL Debug Messenger:")
    log.warnf("\tSource: %v", source_str)
    log.warnf("\tType: %v", type_str)
    log.warnf("\tSeverity: %v", severity_str)
    log.warnf("\tMessage: %v", message)
}

setup_imgui_style :: proc() {
    // Fork of Future Dark style from ImThemes
    style := imgui.GetStyle()
    
    style.Alpha                     = 1.0
    style.DisabledAlpha             = 1.0
    style.WindowPadding             = vec2{12.0, 12.0}
    style.WindowRounding            = 5.0
    style.WindowBorderSize          = 1.0
    style.WindowMinSize             = vec2{20.0, 20.0}
    style.WindowTitleAlign          = vec2{0.5, 0.5}
    style.WindowMenuButtonPosition  = .None;
    style.ChildRounding             = 2.0
    style.ChildBorderSize           = 1.0
    style.PopupRounding             = 3.0
    style.PopupBorderSize           = 1.0
    style.FramePadding              = vec2{4.0, 3.0}
    style.FrameRounding             = 3.0
    style.FrameBorderSize           = 0.0
    style.ItemSpacing               = vec2{12.0, 6.0}
    style.ItemInnerSpacing          = vec2{6.0, 3.0}
    style.CellPadding               = vec2{12.0, 6.0}
    style.IndentSpacing             = 20.0
    style.ColumnsMinSpacing         = 6.0
    style.ScrollbarSize             = 12.0
    style.ScrollbarRounding         = 0.0
    style.GrabMinSize               = 12.0
    style.GrabRounding              = 0.0
    style.TabRounding               = 0.0
    style.TabBorderSize             = 0.0
    style.TabMinWidthForCloseButton = 0.0
    style.ColorButtonPosition       = .Right;
    style.ButtonTextAlign           = vec2{0.5, 0.5}
    style.SelectableTextAlign       = vec2{0.0, 0.0}

    style.Colors[imgui.Col.Text]                  = vec4{1.0,                 1.0,                 1.0,                 1.0}
    style.Colors[imgui.Col.TextDisabled]          = vec4{0.2745098173618317,  0.3176470696926117,  0.4509803950786591,  1.0}
    style.Colors[imgui.Col.WindowBg]              = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.ChildBg]               = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.PopupBg]               = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.Border]                = vec4{0.1568627506494522,  0.168627455830574,   0.1921568661928177,  1.0}
    style.Colors[imgui.Col.BorderShadow]          = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.FrameBg]               = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.FrameBgHovered]        = vec4{0.1568627506494522,  0.168627455830574,   0.1921568661928177,  1.0}
    style.Colors[imgui.Col.FrameBgActive]         = vec4{0.2352941185235977,  0.2156862765550613,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.TitleBg]               = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TitleBgActive]         = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TitleBgCollapsed]      = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.MenuBarBg]             = vec4{0.09803921729326248, 0.105882354080677,   0.1215686276555061,  1.0}
    style.Colors[imgui.Col.ScrollbarBg]           = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.ScrollbarGrab]         = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.ScrollbarGrabHovered]  = vec4{0.1568627506494522,  0.168627455830574,   0.1921568661928177,  1.0}
    style.Colors[imgui.Col.ScrollbarGrabActive]   = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.CheckMark]             = vec4{0.4980392158031464,  0.5137255191802979,  1.0,                 1.0}
    style.Colors[imgui.Col.SliderGrab]            = vec4{0.4980392158031464,  0.5137255191802979,  1.0,                 1.0}
    style.Colors[imgui.Col.SliderGrabActive]      = vec4{0.5372549295425415,  0.5529412031173706,  1.0,                 1.0}
    style.Colors[imgui.Col.Button]                = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.ButtonHovered]         = vec4{0.196078434586525,   0.1764705926179886,  0.5450980663299561,  1.0}
    style.Colors[imgui.Col.ButtonActive]          = vec4{0.2352941185235977,  0.2156862765550613,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.Header]                = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.HeaderHovered]         = vec4{0.196078434586525,   0.1764705926179886,  0.5450980663299561,  1.0}
    style.Colors[imgui.Col.HeaderActive]          = vec4{0.2352941185235977,  0.2156862765550613,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.Separator]             = vec4{0.1568627506494522,  0.1843137294054031,  0.250980406999588,   1.0}
    style.Colors[imgui.Col.SeparatorHovered]      = vec4{0.1568627506494522,  0.1843137294054031,  0.250980406999588,   1.0}
    style.Colors[imgui.Col.SeparatorActive]       = vec4{0.1568627506494522,  0.1843137294054031,  0.250980406999588,   1.0}
    style.Colors[imgui.Col.ResizeGrip]            = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.ResizeGripHovered]     = vec4{0.196078434586525,   0.1764705926179886,  0.5450980663299561,  1.0}
    style.Colors[imgui.Col.ResizeGripActive]      = vec4{0.2352941185235977,  0.2156862765550613,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.Tab]                   = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TabHovered]            = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.TabActive]             = vec4{0.09803921729326248, 0.105882354080677,   0.1215686276555061,  1.0}
    style.Colors[imgui.Col.TabUnfocused]          = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TabUnfocusedActive]    = vec4{0.0784313753247261,  0.08627451211214066, 0.1019607856869698,  1.0}
    style.Colors[imgui.Col.PlotLines]             = vec4{0.5215686559677124,  0.6000000238418579,  0.7019608020782471,  1.0}
    style.Colors[imgui.Col.PlotLinesHovered]      = vec4{0.03921568766236305, 0.9803921580314636,  0.9803921580314636,  1.0}
    style.Colors[imgui.Col.PlotHistogram]         = vec4{1.0,                 0.2901960909366608,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.PlotHistogramHovered]  = vec4{0.9960784316062927,  0.4745098054409027,  0.6980392336845398,  1.0}
    style.Colors[imgui.Col.TableHeaderBg]         = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TableBorderStrong]     = vec4{0.0470588244497776,  0.05490196123719215, 0.07058823853731155, 1.0}
    style.Colors[imgui.Col.TableBorderLight]      = vec4{0.0,                 0.0,                 0.0,                 1.0}
    style.Colors[imgui.Col.TableRowBg]            = vec4{0.1176470592617989,  0.1333333402872086,  0.1490196138620377,  1.0}
    style.Colors[imgui.Col.TableRowBgAlt]         = vec4{0.09803921729326248, 0.105882354080677,   0.1215686276555061,  1.0}
    style.Colors[imgui.Col.TextSelectedBg]        = vec4{0.2352941185235977,  0.2156862765550613,  0.5960784554481506,  1.0}
    style.Colors[imgui.Col.DragDropTarget]        = vec4{0.4980392158031464,  0.5137255191802979,  1.0,                 1.0}
    style.Colors[imgui.Col.NavHighlight]          = vec4{0.4980392158031464,  0.5137255191802979,  1.0,                 1.0}
    style.Colors[imgui.Col.NavWindowingHighlight] = vec4{0.4980392158031464,  0.5137255191802979,  1.0,                 1.0}
    style.Colors[imgui.Col.NavWindowingDimBg]     = vec4{0.196078434586525,   0.1764705926179886,  0.5450980663299561,  0.501960813999176}
    style.Colors[imgui.Col.ModalWindowDimBg]      = vec4{0.196078434586525,   0.1764705926179886,  0.5450980663299561,  0.501960813999176}
}

Frame_Buffer :: struct {
    handle:         u32,
    texture:        u32,
    depth_stencil:  u32,
}

gen_framebuffer :: proc(width, height: i32, samples: i32 = 1, pure_depth := false, format: u32 = gl.RGB8) -> (buffer: Frame_Buffer) {
    gl.CreateFramebuffers(1, &buffer.handle)
    id: u32

    if samples == 1 {
        gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.texture)
        gl.TextureStorage2D(buffer.texture, 1, format, width, height)

        gl.TextureParameteri(buffer.texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TextureParameteri(buffer.texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    } else {
        gl.CreateTextures(gl.TEXTURE_2D_MULTISAMPLE, 1, &buffer.texture)
        gl.TextureStorage2DMultisample(buffer.texture, samples, format, width, height, true)
    }
    // gl.TextureParameteri(buffer.texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.NamedFramebufferTexture(buffer.handle, gl.COLOR_ATTACHMENT0, buffer.texture, 0)

    // gl.CreateRenderbuffers(1, &buffer.depth_stencil)

    if samples == 1 {
        gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.depth_stencil)
        format := gl.DEPTH_COMPONENT32F if pure_depth else gl.DEPTH24_STENCIL8
        gl.TextureStorage2D(buffer.depth_stencil, 1, u32(format), width, height)
        // gl.NamedRenderbufferStorage(buffer.depth_stencil, gl.DEPTH24_STENCIL8, width, height)
        gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
        gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
    } else {
        gl.CreateTextures(gl.TEXTURE_2D_MULTISAMPLE, 1, &buffer.depth_stencil)
        gl.TextureStorage2DMultisample(buffer.depth_stencil, samples, gl.DEPTH24_STENCIL8, width, height, true)
        // gl.NamedRenderbufferStorageMultisample(buffer.depth_stencil, samples, gl.DEPTH24_STENCIL8, width, height)
    }
    if !pure_depth {

        gl.TextureParameteri(buffer.depth_stencil, gl.DEPTH_STENCIL_TEXTURE_MODE, gl.STENCIL_INDEX)
        // gl.NamedFramebufferRenderbuffer(buffer.handle, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, buffer.depth_stencil)
        gl.NamedFramebufferTexture(buffer.handle, gl.DEPTH_STENCIL_ATTACHMENT, buffer.depth_stencil, 0)
    } else {
        // Probably it's just the shadow map, so we might as well clamp the texture.
        gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
        gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
        col := []f32{1, 1, 1, 1}
        gl.TextureParameterfv(buffer.depth_stencil, gl.TEXTURE_BORDER_COLOR, &col[0])

        gl.NamedFramebufferTexture(buffer.handle, gl.DEPTH_ATTACHMENT, buffer.depth_stencil, 0)
    }

    assert(gl.CheckNamedFramebufferStatus(buffer.handle, gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
    return
}

gen_color_framebuffer :: proc(width, height: i32) -> (buffer: Frame_Buffer) {
    gl.CreateFramebuffers(1, &buffer.handle)
    id: u32
    gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.texture)

    gl.TextureStorage2D(buffer.texture, 1, gl.RGB8, width, height)
    gl.TextureParameteri(buffer.texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TextureParameteri(buffer.texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.NamedFramebufferTexture(buffer.handle, gl.COLOR_ATTACHMENT0, buffer.texture, 0)

    assert(gl.CheckNamedFramebufferStatus(buffer.handle, gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
    return
}

gen_depth_framebuffer :: proc(width, height: i32) -> (buffer: Frame_Buffer) {
    gl.CreateFramebuffers(1, &buffer.handle)

    gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.depth_stencil)
    gl.TextureStorage2D(buffer.depth_stencil, 1, gl.DEPTH24_STENCIL8, width, height)
    // gl.NamedRenderbufferStorage(buffer.depth_stencil, gl.DEPTH24_STENCIL8, width, height)
    gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
    gl.TextureParameteri(buffer.depth_stencil, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)

    gl.TextureParameteri(buffer.depth_stencil, gl.DEPTH_STENCIL_TEXTURE_MODE, gl.STENCIL_INDEX)
    // gl.NamedFramebufferRenderbuffer(buffer.handle, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, buffer.depth_stencil)
    gl.NamedFramebufferTexture(buffer.handle, gl.DEPTH_STENCIL_ATTACHMENT, buffer.depth_stencil, 0)

    assert(gl.CheckNamedFramebufferStatus(buffer.handle, gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
    return
}

destroy_framebuffer :: proc(fb: Frame_Buffer) {
    fb := fb
    gl.DeleteTextures(1, &fb.texture)
    gl.DeleteTextures(1, &fb.depth_stencil)
    gl.DeleteFramebuffers(1, &fb.handle)
}


GBuffer :: struct {
    handle: u32,

    position: u32,
    normal: u32,
    albedo_specular: u32,
}

gen_gbuffer :: proc(width, height: i32) -> (buffer: GBuffer) {
    width, height := i32(width), i32(height)
    gl.CreateFramebuffers(1, &buffer.handle)

    gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.position)
    gl.TextureStorage2D(buffer.position, 1, gl.RGBA16F, width, height)
    gl.TextureParameteri(buffer.position, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TextureParameteri(buffer.position, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.NamedFramebufferTexture(buffer.handle, gl.COLOR_ATTACHMENT0, buffer.position, 0)

    gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.normal)
    gl.TextureStorage2D (buffer.normal, 1, gl.RGBA16F, width, height)
    gl.TextureParameteri(buffer.normal, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TextureParameteri(buffer.normal, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.NamedFramebufferTexture(buffer.handle, gl.COLOR_ATTACHMENT1, buffer.normal, 0)

    gl.CreateTextures(gl.TEXTURE_2D, 1, &buffer.albedo_specular)
    gl.TextureStorage2D (buffer.albedo_specular, 1, gl.RGBA, width, height)
    gl.TextureParameteri(buffer.albedo_specular, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TextureParameteri(buffer.albedo_specular, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.NamedFramebufferTexture(buffer.handle, gl.COLOR_ATTACHMENT2, buffer.albedo_specular, 0)
    return
}

destroy_gbuffer :: proc(g: ^GBuffer) {
    gl.DeleteTextures(1, &g.position)
    gl.DeleteTextures(1, &g.normal)
    gl.DeleteTextures(1, &g.albedo_specular)
    gl.DeleteFramebuffers(1, &g.handle)
}

get_frustum_corners_world_space :: proc(proj, view: mat4) -> (corners: [8]vec4) {
    inv := linalg.inverse(proj * view)

    i := 0
    for x in 0..<2 {
        for y in 0..<2 {
            for z in 0..<2 {
                pt := inv * vec4{
                    2 * f32(x) - 1,
                    2 * f32(y) - 1,
                    2 * f32(z) - 1,
                    1.0}

                corners[i] = pt / pt.w

                i += 1
            }
        }
    }
    return
}

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
import "core:math/rand"
import "core:intrinsics"
import "core:fmt"
import "core:reflect"
import "core:os"

g_engine: ^Engine

GL_DEBUG_CONTEXT :: ODIN_DEBUG

CAMERA_DEFAULT_POSITION :: vec3{0, 3, 10}

SHADOW_MAP_RES :: 4096

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

    light_entity: int,
    box_entity: int,

    previouse_mouse:   vec2,
    editor:            Editor,
    // camera:          EditorCamera,
    camera_projection: mat4,
    camera_view:       mat4,
    camera_position:   vec3,
    camera_rotation:   quaternion128,
    game:              Game,
    run_mode:          EngineMode,

    world: World,

    shader_monitor: monitor.Monitor,

    dbg_draw: DebugDrawContext,
    asset_manager: AssetManager,

    width, height: i32,
}

engine_init :: proc(e: ^Engine) -> Engine_Error {
    g_engine = e
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

    gl.Enable(gl.BLEND)
    gl.BlendEquation(gl.FUNC_ADD)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    asset_manager_init(&e.asset_manager)

    editor_init(&e.editor, e)
    context.logger = e.editor.logger

    game_init(&e.game, e)

    e.width = 800
    e.height = 800

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

    if !deserialize_world(&e.world, "assets/scenes/New World.world") {
        log.debug("Failed to deserialize 'New World.world")
    }

    return {}
}

// This is its own separate proc, so it can be called from
// the editor during viewport resize.
engine_resize :: proc(e: ^Engine, width, height: int) {
    // destroy_framebuffer(e.viewport_fb)
    // destroy_framebuffer(e.viewport_resolved_fb)
    // destroy_framebuffer(e.scene_fb)

    // e.viewport_fb.spec.samples = int(g_msaa_level)
    // resize_framebuffer(&e.viewport_fb, width, height)
    // resize_framebuffer(&e.viewport_resolved_fb, width, height)
    // resize_framebuffer(&e.scene_fb, width, height)

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

        // {
        //     copy := e.triangle_shader
        //     if shader_reload(&copy) {
        //         e.triangle_shader = copy
        //     }
        // }

        // {
        //     copy := e.outline_shader
        //     if shader_reload(&copy) {
        //         e.outline_shader = copy
        //     }
        // }

        // {
        //     copy := e.grid_shader
        //     if shader_reload(&copy) {
        //         e.grid_shader = copy
        //     }
        // }
    }

    if is_key_just_released(.F1) {
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
    }

    engine_draw(e)

    flush_input()
    free_all(context.temp_allocator)
}

engine_draw :: proc(e: ^Engine) {
    tracy.Zone()
    i: int

    /*
    // Collect all meshes
    mesh_components := make([dynamic]^MeshRenderer, allocator = context.temp_allocator)
    {
        tracy.ZoneN("Mesh Collection")
        for handle, &go in e.world.objects do if go.enabled && has_component(&e.world, handle, MeshRenderer) {
            mr := get_component(&e.world, handle, MeshRenderer)
            if mr.model != nil && is_model_valid(mr.model^) {
                append(&mesh_components, mr)
            }
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

        // camera_view := linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
        // camera_proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(e.width) / f32(e.height), 0.1, 20.0)
        corners := get_frustum_corners_world_space(e.camera_projection, e.camera_view)

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
    // e.camera.projection = linalg.matrix4_perspective_f32(math.to_radians(f32(45.0)), f32(e.width) / f32(e.height), 0.1, 1000.0)
    gl.NamedBufferSubData(e.ubo, 0, size_of(mat4), &e.camera_projection)

    e.scene_data.view_position.xyz = e.camera_position
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
        view := linalg.matrix4_from_quaternion(e.camera_rotation)
        gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &view)

        gl.UseProgram(cubemap.shader.program)
        gl.BindTextureUnit(6, cubemap.texture.handle)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }
    gl.Enable(gl.DEPTH_TEST)

    gl.NamedBufferSubData(e.ubo, size_of(mat4), size_of(mat4), &e.camera_view)

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
        gl.Uniform1i(uniform(&e.triangle_shader, "gameobject_id"), i32(go.local_id))

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
    blit_framebuffer(e.viewport_fb, e.viewport_resolved_fb, {{0, 0}, {width, height}}, {{0, 0}, {width, height}}, 0)
    */

    /*
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

        // #partial switch e.run_mode {
        // case .Editor:
        //     gl.UseProgram(e.outline_shader.program)
        //     gl.BindTextureUnit(0, get_depth_attachment(e.viewport_resolved_fb))
        //     gl.BindTextureUnit(1, get_color_attachment(e.viewport_resolved_fb))
        //     gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))
        // }

        // if !blend do gl.Disable(gl.BLEND)
        gl.Enable(gl.DEPTH_TEST)
    }
    */

    // nk_render()

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
    destroy_world(&e.world)

    editor_deinit(&e.editor)

    dbg_deinit(e.dbg_draw)

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

UUID :: distinct u64

g_rand_device := rand.create(u64(intrinsics.read_cycle_counter()))

generate_uuid :: proc() -> UUID {
    return UUID(rand.uint64(&g_rand_device))
}

get_cwd :: proc() -> string {
    return os.get_current_directory()
}

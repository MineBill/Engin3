package engine
import "core:fmt"
import "core:intrinsics"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:reflect"
import "core:runtime"
import "core:sys/windows"
import "core:thread"
import "packages:odin-imgui/imgui_impl_glfw"
import "packages:odin-imgui/imgui_impl_opengl3"
import "vendor:glfw"
import gl "vendor:OpenGL"
import imgui "packages:odin-imgui"
import nk "packages:odin-nuklear"
import tracy "packages:odin-tracy"

EngineInstance: ^Engine

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

    dbg_draw: DebugDrawContext,

    asset_manager: AssetManager,

    scripting_engine: ScriptingEngine,
    renderer: Renderer,
    physics: Physics,

    screen_size: vec2,
    width, height: i32,
}

engine_init :: proc(e: ^Engine) -> Engine_Error {
    EngineInstance = e
    tracy.SetThreadName("main")
    tracy.Zone()

    engine_setup_window(e) or_return

    editor_open_project(&e.editor)

    asset_manager_init(&e.asset_manager)

    renderer_init(&e.renderer)
    renderer_set_instance(&e.renderer)

    editor_init(&e.editor, e)
    context.logger = e.editor.logger
    e.ctx = context

    physics_init(&e.physics)

    e.scripting_engine = create_scripting_engine()

    game_init(&e.game, e)

    e.width = 800
    e.height = 800

    nk_init(e.window)
    atlas: ^nk.Font_Atlas
    nk_font_stash_begin(&atlas)
    nk_font_stash_end()

    dbg_init(&e.dbg_draw)
    g_dbg_context = &e.dbg_draw

    e.run_mode = .Editor

    if !deserialize_world(&e.world, "assets/scenes/New World.world") {
        log_debug(LC.Engine, "Failed to deserialize 'New World.world")
    }

    return {}
}

engine_resize :: proc(e: ^Engine, width, height: int) {
    e.width = i32(width)
    e.height = i32(height)

    e.screen_size = vec2{f32(width), f32(height)}
}

engine_update :: proc(e: ^Engine, _delta: f64) {
    context.logger = e.editor.logger

    @static CAMERA_SPEED := f32(2)
    defer tracy.FrameMark()
    tracy.Zone()
    delta := f32(_delta)
    glfw.PollEvents()

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

    physics_deinit(&e.physics)

    editor_deinit(&e.editor)

    dbg_deinit(e.dbg_draw)

    renderer_deinit(&e.renderer)
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

engine_set_window_title :: proc(engine: ^Engine, title: string) {
    glfw.SetWindowTitle(engine.window, cstr(title))
}

UUID :: distinct u64

@(private = "file")
g_rand_device := rand.create(u64(intrinsics.read_cycle_counter()))

generate_uuid :: proc() -> UUID {
    return UUID(rand.uint64(&g_rand_device))
}

get_cwd :: proc() -> string {
    return os.get_current_directory()
}

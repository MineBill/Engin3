package engine
import "core:fmt"
import "base:intrinsics"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:reflect"
import "base:runtime"
import "core:sys/windows"
import "core:thread"
import "packages:odin-imgui/imgui_impl_glfw"
import "packages:odin-imgui/imgui_impl_vulkan"
import "vendor:glfw"
import imgui "packages:odin-imgui"
import nk "packages:odin-nuklear"
import tracy "packages:odin-tracy"
import "gpu"

EngineInstance: ^Engine

SHADOW_MAP_RES :: 4096

EngineMode :: enum {
    Game,
    Editor,
}

Engine :: struct {
    ctx:    runtime.Context,
    window: glfw.WindowHandle,
    quit:   bool,

    previouse_mouse:   vec2,
    editor:            Editor,

    game:              Game,
    run_mode:          EngineMode,

    world: ^World,
    dbg_draw: DebugDrawContext,
    asset_manager: AssetManager,
    scripting_engine: ScriptingEngine,
    renderer: Renderer3D,
    physics: Physics,

    screen_size: vec2,

    delta: f32,
}

engine_init :: proc(e: ^Engine) -> Engine_Error {
    EngineInstance = e
    g_dbg_context = &e.dbg_draw

    tracy.SetThreadName("main")
    tracy.Zone()

    engine_setup_window(e) or_return

    editor_open_project(&e.editor)

    // NOTE(minebill): Call setup first to create the device which is needed by the material loader (from the asset manager).
    // There are alternative ways but this is simple right now.
    // Possible alternatives:
    // - Defer loading until the renderer is initialized. Probably needs a whole system refactor.
    r3d_setup(&e.renderer)

    asset_manager_init(&e.asset_manager)

    r3d_init(&e.renderer)

    editor_init(&e.editor, e)
    context.logger = e.editor.logger
    e.ctx = context

    physics_init(&e.physics)

    e.scripting_engine = create_scripting_engine()

    game_init(&e.game, e)

    // nk_init(e.window)
    // atlas: ^nk.Font_Atlas
    // nk_font_stash_begin(&atlas)
    // nk_font_stash_end()

    e.run_mode = .Editor

    return {}
}

engine_resize :: proc(e: ^Engine, size: vec2) {
    r3d_on_resize(&e.renderer, size)
    e.screen_size = size
}

engine_update :: proc(e: ^Engine, _delta: f64) {
    context.logger = e.editor.logger

    defer tracy.FrameMark()
    tracy.Zone()
    delta := f32(_delta)
    e.delta = delta
    glfw.PollEvents()

    // nk_new_frame()

    switch e.run_mode {
    case .Game:
        game_update(&e.game, _delta)

    case .Editor:

        imgui_impl_vulkan.NewFrame()
        imgui_impl_glfw.NewFrame()
        imgui.NewFrame()

        editor_update(&e.editor, _delta)
    }

    engine_draw(e)

    flush_input()
    free_all(context.temp_allocator)
}

engine_draw :: proc(e: ^Engine) {
    tracy.Zone()
    blk: {
        // cmd, error := renderer_begin_rendering(RendererInstance)
        // r3d_draw_frame()

        switch e.run_mode {
        case .Game:
        case .Editor:
            // gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
            editor_draw(&e.editor)
            // imgui.EndFrame()

        }
        // renderer_end_rendering(RendererInstance, cmd)
    }

    if .ViewportsEnable in imgui.GetIO().ConfigFlags {
        ctx := glfw.GetCurrentContext()
        imgui.UpdatePlatformWindows()
        imgui.RenderPlatformWindowsDefault()
        glfw.MakeContextCurrent(ctx)
    }
    // glfw.SwapBuffers(e.window)
}

engine_deinit :: proc(e: ^Engine) {
    destroy_world(e.world)

    physics_deinit(&e.physics)

    editor_deinit(&e.editor)

    dbg_deinit(e.dbg_draw)

    r3d_deinit(&e.renderer)
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
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

    when GL_DEBUG_CONTEXT {
        glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, true)
    }
    e.window = glfw.CreateWindow(1280, 720, "Engin3", nil, nil)
    if e.window == nil do return .GLFW_Failed_Window

    e.screen_size.x = 1280
    e.screen_size.y = 720

    when ODIN_OS == .Windows {
        handle := glfw.GetWin32Window(e.window)
        value: windows.BOOL = true
        _ = windows.DwmSetWindowAttribute(handle, 20, &value, size_of(value))
    }

    glfw.SetInputMode(e.window, glfw.RAW_MOUSE_MOTION, 1)

    glfw.MakeContextCurrent(e.window)
    // gl.load_up_to(4, 6, glfw.gl_set_proc_address)

    // // HACK(minebill): Try force clearing the background to black, otherwise you get a flashbang.
    // gl.ClearColor(0, 0, 0, 1)
    // gl.Clear(gl.COLOR_BUFFER_BIT)
    // glfw.SwapBuffers(e.window)

    // glfw.SwapInterval(1)

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

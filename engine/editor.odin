package engine
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:runtime"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sync"
import "packages:odin-imgui/imgui_impl_glfw"
import "packages:odin-imgui/imgui_impl_opengl3"
import "vendor:glfw"
import gl "vendor:OpenGL"
import imgui "packages:odin-imgui"
import tracy "packages:odin-tracy"
import stbi "vendor:stb/image"
import fs "filesystem"
import "core:io"
import "core:thread"
import "core:container/small_array"

DEFAULT_EDITOR_CAMERA_POSITION :: vec3{0, 3, 5}
USE_EDITOR :: true

EditorInstance: ^Editor

EditorState :: enum {
    Edit,
    Play,
    Paused,
}

EditorIcon :: enum {
    PlayButton,
    PauseButton,
    StopButton,
}

EditorCamera :: struct {
    position:       vec3,
    rotation:       quaternion128,
    euler_angles:   vec3,
    fov:            f32,
    near_plane, far_plane: f32,

    projection, view: mat4,
}

EditorFont :: enum {
    Light,
    Normal,
    Bold,
}

Editor :: struct {
    active_project: Project,

    engine: ^Engine,
    state: EditorState,
    camera: EditorCamera,

    entity_selection: map[EntityHandle]bool,
    selected_entity: Maybe(EntityHandle),

    viewport_size: vec2,

    capture_mouse:   bool,
    is_viewport_focused: bool,
    was_viewport_focused: bool,
    is_asset_window_focused: bool,
    was_asset_window_focused: bool,
    viewport_position: vec2,

    log_entries: [dynamic]LogEntry,
    logger: log.Logger,

    force_show_fields: bool,
    show_asset_manager: bool,
    show_undo_redo: bool,

    allocator: mem.Allocator,

    content_browser: ContentBrowser,

    renderer: WorldRenderer,
    editor_world: World,
    runtime_world: World,
    icons: [EditorIcon]Texture2D,
    fonts: [EditorFont]^imgui.Font,

    texture_previews: map[UUID]Texture2D,
    preview_cubemap_texture: Texture2D,

    outline_frame_buffer: FrameBuffer,

    outline_shader: Shader,
    grid_shader: Shader,

    editor_va: RenderHandle,

    // Texture view to visualize individual layers of the shadow map texture array.
    shadow_map_texture_view: TextureView,

    style: EditorStyle,
    undo: Undo,

    asset_windows: map[AssetHandle]AssetWindow,

    shaders_watcher: fs.Watcher,

    target_frame_buffer: ^FrameBuffer,
    target_color_attachment: int,

    asset_manager_sorted_keys: []AssetHandle,
}

editor_open_project :: proc(e: ^Editor) {
    ok: bool
    project_file := open_file_dialog("Engin3 Project (*.engin3)", "*.engin3")
    e.active_project, ok = load_project(project_file)
    fmt.assertf(ok, "Could not load project file")

    EditorInstance = e
}

editor_init :: proc(e: ^Editor, engine: ^Engine) {
    tracy.ZoneN("Editor Init")

    // Located in the engine folder, NOT a project thing(yet?).
    fs.watcher_init(&e.shaders_watcher, "assets/shaders")

    engine_set_window_title(EngineInstance, fmt.tprintf("Engin3 - %v", e.active_project.name))

    undo_init(&e.undo)
    e.engine = engine
    e.state = .Edit
    // TODO(minebill):  Save the editor camera for each scene in a cache somewhere
    //                  so that we can open the editor in that location/rotation next time.
    e.camera = EditorCamera {
        position = DEFAULT_EDITOR_CAMERA_POSITION,
        fov = f32(60.0),
        near_plane = 0.1,
        far_plane = 1000.0,
    }

    gl.CreateVertexArrays(1, &e.editor_va)

    e.logger = create_capture_logger(&e.log_entries)
    context.logger = e.logger

    e.content_browser.root_dir = project_get_assets_folder(e.active_project)
    cb_navigate_to_folder(&e.content_browser, e.content_browser.root_dir)

    // NOTE(minebill):  Since this is the editor, it's OK to not go through an asset manager and just
    //                  load any textures directly from a path, since we'll never run in a "cooked" mode.
    err: AssetImportError
    e.content_browser.textures[.Generic], err    = import_texture_from_path("assets/textures/ui/file.png")
    e.content_browser.textures[.Folder], err     = import_texture_from_path("assets/textures/ui/folder.png")
    e.content_browser.textures[.FolderBack], err = import_texture_from_path("assets/textures/ui/folder_back.png")
    e.content_browser.textures[.Scene], err      = import_texture_from_path("assets/textures/ui/world.png")
    e.content_browser.textures[.Script], err     = import_texture_from_path("assets/editor/icons/lua.png")
    e.content_browser.textures[.Material], err   = import_texture_from_path("assets/editor/icons/material.png")
    e.content_browser.textures[.Model]           = e.content_browser.textures[.Unknown]

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

        w, h, c: i32
        raw_image := stbi.load(cstr(image_path), &w, &h, &c, 4)
        if raw_image == nil {
        }

        if !created {
            spec := TextureSpecification {
                format = .RGBA8,
                width = int(w),
                height = int(h),
                type = .CubeMap,
            }
            // texture := get_asset(&EngineInstance.asset_manager, cube.texture, Texture2D)
            e.preview_cubemap_texture = create_texture2d(spec)
            created = true
        }

        BYTES_PER_CHANNEL :: 1
        // TODO: What about floating point images?
        size := w * h * c * BYTES_PER_CHANNEL
        set_texture2d_data(e.preview_cubemap_texture, raw_image[:size], layer = i)
    }

    e.icons[.PlayButton], err  = import_texture_from_path("assets/editor/icons/play_button.png")
    e.icons[.PauseButton], err = import_texture_from_path("assets/editor/icons/pause_button.png")
    e.icons[.StopButton], err  = import_texture_from_path("assets/editor/icons/stop_button.png")
    log.debugf("Err: %v", err)

    ok: bool
    e.outline_shader, ok = shader_load_from_file(
        "assets/shaders/screen.vert.glsl",
        "assets/shaders/outline.frag.glsl",
    )
    assert(ok == true, "Failed to read outline shader.")
    e.grid_shader, ok = shader_load_from_file(
        "assets/shaders/grid.vert.glsl",
        "assets/shaders/grid.frag.glsl",
    )
    assert(ok == true, "Failed to read grid shader.")

    imgui.CreateContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += {.DockingEnable, .ViewportsEnable, .IsSRGB, .NavEnableKeyboard}
    io.IniFilename = nil
    imgui.LoadIniSettingsFromDisk("editor_layout.ini")

    e.style = default_style()
    apply_style(e.style)

    // imgui.FontAtlas_AddFont(io.Fonts, )
    // inter_font :: #load("../assets/fonts/inter/Inter-Regular.ttf")
    // imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(inter_font), cast(i32)len(inter_font), 16, nil, nil)

    imgui_impl_glfw.InitForOpenGL(e.engine.window, true)
    imgui_impl_opengl3.Init("#version 450 core")

    LIGHT_FONT  :: #load("../assets/fonts/inter/Inter-Light.ttf")
    NORMAL_FONT :: #load("../assets/fonts/inter/Inter-Regular.ttf")
    BOLD_FONT   :: #load("../assets/fonts/inter/Inter-Bold.ttf")
    e.fonts[.Light]  = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(LIGHT_FONT), i32(len(LIGHT_FONT)), 14)
    e.fonts[.Normal] = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(NORMAL_FONT), i32(len(NORMAL_FONT)), 16)
    e.fonts[.Bold]   = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(BOLD_FONT), i32(len(BOLD_FONT)), 16)

    io.FontDefault = e.fonts[.Normal]

    world_renderer_init(&e.renderer)
    e.target_frame_buffer = &e.renderer.final_frame_buffer
    e.target_color_attachment = 0
    e.shadow_map_texture_view = create_texture_view(e.renderer.shadow_map)
}

editor_deinit :: proc(e: ^Editor) {
    // TODO(minebill):  This is to silence the tracking allocator. Figure out a better
    //                  way of clearing all the entries, possible by using a small arena allocator,
    for entry in e.log_entries {
        delete(entry.text)
    }
    delete(e.log_entries)
    cb_deinit(&e.content_browser)
    asset_manager_deinit(&EngineInstance.asset_manager)
    free_project(&e.active_project)
    destroy_texture_view(e.shadow_map_texture_view)

    destroy_capture_logger(e.logger)
}

editor_update :: proc(e: ^Editor, _delta: f64) {
    tracy.ZoneN("Editor Update")
    @(static) show_imgui_demo := false
    @(static) CAMERA_SPEED := f32(2)
    delta := f32(_delta)

    // Check for shader changes
    {
        sync.mutex_lock(&e.shaders_watcher.mutex)
        defer sync.mutex_unlock(&e.shaders_watcher.mutex)

        if e.shaders_watcher.triggered {
            file := &e.shaders_watcher.changed_file
            log.debugf("File changed: %v", file^)
            for name, &shader in e.renderer.shaders {
                if strings.contains(shader.vertex, file^) || strings.contains(shader.fragment, file^) {
                    log.debug("pepe")
                    shader_reload(&shader)
                }
            }

            e.shaders_watcher.triggered = false
        }
    }

    for event in g_event_ctx.events {
        #partial switch ev in event {
        case WindowResizedEvent:
            gl.Viewport(0, 0, i32(ev.size.x), i32(ev.size.y))
        case MouseButtonEvent:
            if ev.button == .right {
                if ev.state == .pressed && e.is_viewport_focused || e.is_asset_window_focused {
                    e.capture_mouse = true
                    e.was_viewport_focused = e.is_viewport_focused
                    e.was_asset_window_focused = e.is_asset_window_focused
                } else if ev.state == .released {
                    e.capture_mouse = false
                }

                if e.capture_mouse {
                    glfw.SetInputMode(e.engine.window, glfw.CURSOR, glfw.CURSOR_DISABLED)

                    io := imgui.GetIO()
                    io.ConfigFlags += {.NoMouse}
                } else {
                    glfw.SetInputMode(e.engine.window, glfw.CURSOR, glfw.CURSOR_NORMAL)

                    io := imgui.GetIO()
                    io.ConfigFlags -= {.NoMouse}
                }
            } else if ev.button == .left {
                if ev.state == .pressed && e.is_viewport_focused && e.state == .Edit {
                    mouse := g_event_ctx.mouse + g_event_ctx.window_position - e.viewport_position
                    color, ok := read_pixel(e.renderer.world_frame_buffer, int(mouse.x), int(e.viewport_size.y) - int(mouse.y), 2)
                    if ok {
                        id := color[0]
                        handle := e.engine.world.local_id_to_uuid[int(id)]
                        select_entity(e, handle, !is_key_pressed(.LeftShift))
                    }
                }
            }
        case MouseWheelEvent:
            CAMERA_SPEED += ev.delta.y
            CAMERA_SPEED = math.clamp(CAMERA_SPEED, 1, 100)
        case KeyEvent:
            if ev.state == .pressed {
                if e.capture_mouse do break

                if .Control in ev.mods {
                    #partial switch ev.key {
                    case .S:
                        log.debug("Saving world!")
                        serialize_world(e.engine.world, e.engine.world.file_path)
                        e.engine.world.modified = false
                    case .D:
                        // Create a local copy before reseting the selection
                        selection :=  clone_map(e.entity_selection)
                        defer delete(selection)
                        reset_selection(e)
                        for entity, _ in selection {
                            new_entity := duplicate_entity(&e.engine.world, entity)
                            select_entity(e, new_entity)
                        }
                    case .Z:
                        undo_undo(&e.undo)
                    case .Y:
                        undo_redo(&e.undo)
                    }
                }

                if ev.key == .Delete {
                    for entity, _ in e.entity_selection {
                        delete_object(&e.engine.world, entity)
                    }
                }
            }
        }
    }

    {
        #partial switch e.state {
        case .Edit:
            engine := e.engine
            if e.capture_mouse && e.was_viewport_focused {
                e.camera.euler_angles.xy += get_mouse_delta().yx * 25 * delta
                e.camera.euler_angles.x = math.clamp(e.camera.euler_angles.x, -80, 80)
            }

            if e.capture_mouse && e.was_viewport_focused {
                input := get_vector(.D, .A, .W, .S) * CAMERA_SPEED
                up_down := get_axis(.Space, .LeftControl) * CAMERA_SPEED
                e.camera.position.xz += ( vec4{input.x, 0, -input.y, 0} * linalg.matrix4_from_quaternion(e.camera.rotation)).xz * f32(delta)
                e.camera.position.y += up_down * f32(delta)
            }

            euler := e.camera.euler_angles
            e.camera.rotation = linalg.quaternion_from_euler_angles(
                euler.x * math.RAD_PER_DEG,
                euler.y * math.RAD_PER_DEG,
                euler.z * math.RAD_PER_DEG,
                .XYZ)

            e.camera.view              = linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
            e.camera.projection        = linalg.matrix4_perspective_f32(math.to_radians(f32(e.camera.fov)), f32(e.engine.width) / f32(e.engine.height), e.camera.near_plane, e.camera.far_plane)

            editor_render_scene(e)
        case .Play:
            runtime_render_scene(e)
        }
    }

    @(static) show_depth_buffer := false
    @(static) show_gbuffer := false
    if imgui.BeginMainMenuBar() {

        if imgui.BeginMenu("Scene") {
            if imgui.MenuItem("Save") {
                serialize_world(e.engine.world, e.engine.world.file_path)
            }

            if imgui.MenuItem("Load") {
                deserialize_world(&e.engine.world, e.engine.world.file_path)
            }

            imgui.EndMenu()
        }

        if imgui.BeginMenu("Options") {
            @(static) top_most := false
            if imgui.MenuItem("Top Most", nil, top_most, true) {
                top_most = !top_most
                glfw.SetWindowAttrib(e.engine.window, glfw.FLOATING, i32(top_most))
            }
            imgui.Checkbox("Show Demo", &show_imgui_demo)
            imgui.EndMenu()
        }

        if imgui.BeginMenu("Preferences") {
            if imgui.MenuItem("Save Layout") {
                imgui.SaveIniSettingsToDisk("editor_layout.ini")
            }
            imgui.EndMenu()
        }

        if imgui.BeginMenu("Windows") {
            if imgui.MenuItem("Asset Manager Stats") {
                e.show_asset_manager = true
            }

            if imgui.MenuItem("Undo/Redo Stack") {
                e.show_undo_redo = true
            }

            imgui.EndMenu()
        }

        imgui.Checkbox("Show Depth Buffer", &show_depth_buffer)
        imgui.Checkbox("Show G-Buffer", &show_gbuffer)
    }
    imgui.EndMainMenuBar()

    if show_imgui_demo {
        imgui.ShowDemoWindow(&show_imgui_demo)
    }

    imgui.DockSpaceOverViewport(imgui.GetMainViewport(), {.PassthruCentralNode})

    if show_depth_buffer && imgui.Begin("Shadow Map", &show_depth_buffer, {}) {
        @(static) active_image := i32(0)
        if imgui.SliderInt("ShadowMap Layer", &active_image, 0, 3) {
            destroy_texture_view(e.shadow_map_texture_view)
            e.shadow_map_texture_view = create_texture_view(e.renderer.shadow_map, u32(active_image))
        }

        size := imgui.GetContentRegionAvail()

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}
        imgui.Image(transmute(rawptr)u64(e.shadow_map_texture_view.handle), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})
        imgui.End()
    }

    if show_gbuffer && imgui.Begin("Show G-Buffer", &show_gbuffer) {
        fb := e.renderer.g_buffer

        @(static) index := i32(0)
        imgui.SliderInt("Attachment", &index, 0, cast(i32) small_array.len(fb.color_attachments) - 1)
        texture := get_color_attachment(fb, int(index))
        size := imgui.GetContentRegionAvail()

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}
        imgui.Image(transmute(rawptr)u64(texture), size, uv0, uv1, vec4{1, 1, 1, 1})
        imgui.End()
    }

    if e.state == .Play {
        physics_update(PhysicsInstance, _delta)
    }
    world_update(&e.engine.world, _delta, e.state == .Play)

    editor_env_panel(e)
    editor_entidor(e)
    editor_viewport(e)
    editor_gameobjects(e)
    editor_log_window(e)
    editor_content_browser(e)
    editor_ui_toolstrip(e)

    for handle, &window in e.asset_windows {
        asset_window_render(&window)

        if !window.opened {
            // Remove from map
            delete_key(&e.asset_windows, handle)
        }
    }

    editor_asset_manager(e)
    editor_undo_redo_window(e)

    reset_draw_stats()

    undo_commit(&e.undo)
}

editor_render_scene :: proc(e: ^Editor) {
    packet := RenderPacket{
        world = &e.engine.world,
        size = vec2i{i32(e.viewport_size.x), i32(e.viewport_size.y)},
        camera = RenderCamera {
            projection = e.camera.projection,
            view       = e.camera.view,
            position   = e.camera.position,
            rotation   = e.camera.rotation,
            near       = e.camera.near_plane,
            far        = e.camera.far_plane,
        },
        clear_color = COLOR_BLACK,
    }
    for id, &obj in e.engine.world.objects {
        if id in e.entity_selection {
            for type, component in obj.components {
                component->debug_draw(g_dbg_context)
            }
        }
    }

    // Render world normally
    render_world(&e.renderer, packet)

    dbg_render(g_dbg_context)

    // Render editor stuff (grid, outlines, gizmo)
    gl.BindFramebuffer(gl.FRAMEBUFFER, e.renderer.final_frame_buffer.handle)
    gl.BindVertexArray(e.editor_va)
    // Grid
    {
        gl.UseProgram(e.grid_shader.program)
        draw_arrays(gl.TRIANGLES, 0, 6)
    }

    gl.Disable(gl.DEPTH_TEST)
    // Mesh Outline
    {
        gl.UseProgram(e.outline_shader.program)
        gl.BindTextureUnit(0, get_depth_attachment(e.renderer.resolved_frame_buffer))
        draw_arrays(gl.TRIANGLES, 0, 6)
    }
    gl.Enable(gl.DEPTH_TEST)
}

runtime_render_scene :: proc(e: ^Editor) {
    if camera := find_first_component(&e.engine.world, Camera); camera != nil {
        go := get_object(&e.engine.world, camera.owner)
        e.engine.camera_position   = go.transform.position

        euler := go.transform.local_rotation
        rotation := linalg.quaternion_from_euler_angles(
            euler.x * math.RAD_PER_DEG,
            euler.y * math.RAD_PER_DEG,
            euler.z * math.RAD_PER_DEG,
            .XYZ)

        camera_view       := linalg.matrix4_from_quaternion(rotation) * linalg.inverse(linalg.matrix4_translate(go.transform.position))
        camera_projection := linalg.matrix4_perspective_f32(math.to_radians(f32(camera.fov)), f32(e.engine.width) / f32(e.engine.height), camera.near_plane, camera.far_plane)
        camera_rotation   := rotation

        packet := RenderPacket{
            world = &e.engine.world,
            size = vec2i{i32(e.viewport_size.x), i32(e.viewport_size.y)},
            camera = RenderCamera {
                projection = camera_projection,
                view       = camera_view,
                position   = go.transform.local_position,
                rotation   = rotation,
                near       = camera.near_plane,
                far        = camera.far_plane,
            },
            clear_color = COLOR_BLACK,
        }
        // Render world normally
        render_world(&e.renderer, packet)
    }

}

editor_on_scene_play :: proc(e: ^Editor) {
    e.state = .Play
    log.debug("On Scene Play")

    // Save first
    serialize_world(e.engine.world, e.engine.world.file_path)

    deserialize_world(&e.runtime_world, e.engine.world.file_path)
    e.editor_world = e.engine.world
    e.engine.world = e.runtime_world

    world_init_components(&e.engine.world)
}

editor_on_scene_stop :: proc(e: ^Editor) {
    e.state = .Edit
    log.debug("On Scene Stop")

    destroy_world(&e.runtime_world)
    e.engine.world = e.editor_world
}

editor_env_panel :: proc(e: ^Editor) {
    using imgui
    if Begin("Environment", nil, {}) {
        @(static) clear_color: vec3
        if ColorEdit3("Clear Color", &clear_color, {}) {
            gl.ClearColor(expand_values(clear_color), 1.0)
        }

        ColorEdit4("Ambent Color", cast(^vec4)&e.engine.world.ambient_color, {})

        if CollapsingHeader("Post Processing") {
            Indent()
            if CollapsingHeader("SSAO") {
                DragFloat("Radius", &e.renderer.ssao_data.params.x, 0.01)
                DragFloat("Bias", &e.renderer.ssao_data.params.y, 0.001)
            }
        }
    }
    End()
}

ViewportImage :: enum {
    Normal,
    GBufferPosition,
    GBufferNormal,
}

editor_viewport :: proc(e: ^Editor) {
    @(static) viewport_image: ViewportImage = .Normal
    imgui.PushStyleVarImVec2(.WindowPadding, vec2{0, 0})
    if imgui.Begin("Viewport", nil, {.MenuBar}) {
        e.is_viewport_focused = imgui.IsWindowHovered({})
        if imgui.BeginMenuBar() {
            if imgui_enum_combo_id("MSAA Level", g_msaa_level, type_info_of(MSAA_Level)) {
                width, height := int(e.viewport_size.x), int(e.viewport_size.y)
                engine_resize(e.engine, width, height)
                world_renderer_resize(&e.renderer, width, height)
            }

            if imgui_enum_combo_id("View Type", viewport_image, type_info_of(ViewportImage)) {
                switch viewport_image {
                case .Normal:
                    e.target_frame_buffer = &e.renderer.final_frame_buffer
                    e.target_color_attachment = 0
                case .GBufferPosition:
                    e.target_frame_buffer = &e.renderer.g_buffer
                    e.target_color_attachment = 0
                case .GBufferNormal:
                    e.target_frame_buffer = &e.renderer.g_buffer
                    e.target_color_attachment = 1
                }
            }

            imgui.EndMenuBar()
        }

        size := imgui.GetContentRegionAvail()
        window_pos := imgui.GetWindowPos()
        window_size := imgui.GetWindowSize()
        e.viewport_position = imgui.GetCursorScreenPos()

        if size != e.viewport_size {
            e.viewport_size = size

            width, height := int(size.x), int(size.y)
            engine_resize(e.engine, width, height)
            world_renderer_resize(&e.renderer, width, height)
        }

        // is this the correct place?
        gl.Viewport(0, 0, i32(size.x), i32(size.y))

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}

        texture_handle := get_color_attachment(e.target_frame_buffer^, e.target_color_attachment)
        imgui.Image(rawptr(uintptr(texture_handle)), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})

        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Scene], {}); payload != nil {
                data := transmute(^byte)payload.Data
                path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                deserialize_world(&e.engine.world, path)
            }

            if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Model], {}); payload != nil {
                data := transmute(^AssetHandle)payload.Data
                // path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                // log.debug("Load model from", path)

                if is_asset_handle_valid(&EngineInstance.asset_manager, data^) {
                    entity := new_object(&e.engine.world, "New Mesh")
                    mesh_component := get_or_add_component(&e.engine.world, entity, MeshRenderer)
                    mesh_renderer_set_mesh(mesh_component, data^)
                }
            }
            imgui.EndDragDropTarget()
        }

        flags := imgui.WindowFlags_NoDecoration
        flags += imgui.WindowFlags_NoNav
        flags += {.NoDocking, .NoMove, .AlwaysAutoResize, .NoSavedSettings, .NoFocusOnAppearing}
        offset := imgui.GetItemRectMin()
        imgui.SetNextWindowPos(offset + vec2{20, 20}, .Always)

        imgui.SetNextWindowBgAlpha(0.35)

        imgui.PushStyleVarImVec2(.WindowPadding, vec2{10, 10})
        if imgui.Begin("Render Stats", flags = flags) {
            imgui.TextUnformatted(fmt.ctprintf("MSAA Level: %v", g_msaa_level))
            imgui.TextUnformatted(fmt.ctprintf("Viewport Size: %v", e.viewport_size))
            imgui.TextUnformatted(fmt.ctprintf("Viewport Position: %v", e.viewport_position))
            global_mouse := g_event_ctx.mouse + g_event_ctx.window_position
            imgui.TextUnformatted(fmt.ctprintf("Mouse Position(global): %v", global_mouse))
            imgui.TextUnformatted(fmt.ctprintf("Editor State: %v", e.state))
            imgui.TextUnformatted(fmt.ctprintf("Draw calls: %v", g_render_stats.draw_calls))
            imgui.Separator()
            @(static) show_camera_stats := false
            imgui.Checkbox("Editor Camera Stats", &show_camera_stats)
            if show_camera_stats {
                imgui.TextUnformatted(fmt.ctprintf("Editor Camera: %#v", e.camera))
            }
            imgui.End()
        }
        imgui.PopStyleVar()
    }
    imgui.End()
    imgui.PopStyleVar()
}

editor_entidor :: proc(e: ^Editor) {
    window: if imgui.Begin("Properties") {
        // selected_handle, ok := e.selected_entity.(Handle)
        if len(e.entity_selection) == 0 {
            imgui.TextUnformatted("No entity selected")
            break window
        }

        // Single selection
        if len(e.entity_selection) == 1 {
            for handle, _ in e.entity_selection {
                go := get_object(&e.engine.world, handle)
                if go == nil {
                    // Entity selection is invalide, reset it
                    e.selected_entity = nil
                    break window
                }

                // imgui.AlignTextToFramePadding()
                // imgui.TextUnformatted(ds_to_cstring(go.name))
                imgui_text("Name", &go.name, {})

                imgui.PushFont(e.fonts[.Light])
                imgui.TextDisabled(fmt.ctprintf("UUID: %v", go.handle))
                imgui.TextDisabled(fmt.ctprintf("Local ID: %v", go.local_id))
                imgui.TextDisabled(fmt.ctprintf("Parent UUID: %v", go.parent))
                imgui.PopFont()

                undo_push(&e.undo, &go.flags, tag = "Change Flags")
                imgui_flags_box("Flags", &go.flags)

                imgui.SameLine()

                undo_push(&e.undo, &go.enabled, tag = "Enabled")
                imgui.Checkbox("Enabled", &go.enabled)

                imgui.Separator()

                modified := false
                opened := imgui.CollapsingHeader("Transform", {.Framed, .DefaultOpen}) 
                // help_marker("The Transfrom component is a special component that is included by default" + 
                //     " in every gameobject and as such, it has special drawing code.")

                if opened {
                    imgui.Indent()
                    if imgui.BeginChild("Transformm", vec2{}, {.AutoResizeY}, {}) {
                        // TOOD(minebill):  Add some kind of 'debug' view to view global position as well?

                        // Push on start edit, commit on stop edit

                        imgui.TextUnformatted("Position")
                        modified_position, pos_activated, pos_deactivated := imgui_vec3("position", &go.transform.local_position)
                        if pos_activated {
                            undo_push_single(&e.undo, &go.transform.local_position, tag = "Position")
                        }

                        if pos_deactivated {
                            undo_commit_single(&e.undo, tag = "Position")
                        }

                        imgui.TextUnformatted("Rotation")
                        rot_modified, rot_activated, rot_deactivated := imgui_vec3("rotation", &go.transform.local_rotation)
                        if rot_activated {
                            undo_push_single(&e.undo, &go.transform.local_position, tag = "LocalRotation")
                        }

                        if rot_deactivated {
                            undo_commit_single(&e.undo, tag = "LocalRotation")
                        }

                        imgui.TextUnformatted("Scale")
                        scale_modified, scale_activated, scale_deactivated := imgui_vec3("scale", &go.transform.local_scale)
                        if scale_activated {
                            undo_push_single(&e.undo, &go.transform.local_scale, tag = "LocalScale")
                        }

                        if scale_deactivated {
                            undo_commit_single(&e.undo, tag = "LocalScale")
                        }

                        modified |= modified_position | rot_modified | scale_modified
                    }
                    imgui.EndChild()
                    imgui.Unindent()
                }
                if modified {
                    go.world.modified = true
                }

                imgui.SeparatorText("Components")

                for id, component in go.components {
                    draw_component(e, id, component)
                    imgui.Separator()
                }

                if centered_button("Add Component") {
                    imgui.OpenPopup("component_popup", {})
                }
            
            }
        } else {
            imgui.TextUnformatted("Multiple selection")
        }

        // Draws a component to a popup and draws submenus for categories if neccessary.
        draw_submenu_or_component_selectable :: proc(e: ^Editor, paths: []string, level: int, component_id: typeid) {
            if level < 0 {
                info := type_info_of(component_id).variant.(reflect.Type_Info_Named)
                if imgui.Selectable(cstr(info.name)) {
                    handle, ok := e.selected_entity.?
                    if ok {
                        add_component(&e.engine.world, handle, component_id)
                    }
                }
            } else {
                if imgui.BeginMenu(cstr(paths[len(paths) - 1- level])) {
                    draw_submenu_or_component_selectable(e, paths, level - 1, component_id)
                    imgui.EndMenu()
                }
            }
        }

        imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
        imgui.SetNextWindowSize(vec2{200, 225}, .Always)
        mouse := imgui.GetMousePos()
        imgui.SetNextWindowPos(vec2{mouse.x - 100, mouse.y}, .Appearing)
        if imgui.BeginPopup("component_popup", {}) {

            @(static) search_text: [256]byte
            imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
            imgui.SetKeyboardFocusHere()
            @(static) search: string
            if imgui.InputTextWithHint("##search", "ComponentName", transmute(cstring)&search_text, len(search_text), {.AlwaysOverwrite}) {
                search = string(cstring(&search_text[0]))
            }
            if len(search) > 0 {
                if imgui.BeginChild("found_components") {
                    for id, name in COMPONENT_NAMES {
                        if name == "TransformComponent" do continue
                        if !strings.contains(name, search) do continue
                        if imgui.MenuItem(cstr(name)) {
                            handle, ok := e.selected_entity.?
                            if ok {
                                add_component(&e.engine.world, handle, id)
                            }
                        }
                    }
                }
                imgui.EndChild()

            } else {
                for category in COMPONENT_CATEGORIES {
                    paths, _ := strings.split(category.name, "/", allocator = context.temp_allocator)

                    level := len(paths) - 1
                    draw_submenu_or_component_selectable(e, paths, level, category.id)
                }
            }

            imgui.EndPopup()
        }
        imgui.PopStyleVar()
    }

    imgui.End()
}

editor_ui_toolstrip :: proc(e: ^Editor) {
    ImGuiDockNodeFlags_CentralNode              :: 1 << 11  // Local, Saved  // The central node has 2 main properties: stay visible when empty, only use "remaining" spaces from its neighbor.
    ImGuiDockNodeFlags_NoTabBar                 :: 1 << 12  // Local, Saved  // Tab bar is completely unavailable. No triangle in the corner to enable it back.
    ImGuiDockNodeFlags_HiddenTabBar             :: 1 << 13  // Local, Saved  // Tab bar is hidden, with a triangle in the corner to show it again (NB: actual tab-bar instance may be destroyed as this is only used for single-window tab bar)
    ImGuiDockNodeFlags_NoWindowMenuButton       :: 1 << 14  // Local, Saved  // Disable window/docking menu (that one that appears instead of the collapse button)
    ImGuiDockNodeFlags_NoCloseButton            :: 1 << 15  // Local, Saved  //
    ImGuiDockNodeFlags_NoDocking                :: 1 << 16  // Local, Saved  // Disable any form of docking in this dockspace or individual node. (On a whole dockspace, this pretty much defeat the purpose of using a dockspace at all). Note: when turned on, existing docked nodes will be preserved.
    ImGuiDockNodeFlags_NoDockingSplitMe         :: 1 << 17  // [EXPERIMENTAL] Prevent another window/node from splitting this node.
    ImGuiDockNodeFlags_NoDockingSplitOther      :: 1 << 18  // [EXPERIMENTAL] Prevent this node from splitting another window/node.
    ImGuiDockNodeFlags_NoDockingOverMe          :: 1 << 19  // [EXPERIMENTAL] Prevent another window/node to be docked over this node.
    ImGuiDockNodeFlags_NoDockingOverOther       :: 1 << 20  // [EXPERIMENTAL] Prevent this node to be docked over another window or non-empty node.
    ImGuiDockNodeFlags_NoDockingOverEmpty       :: 1 << 21  // [EXPERIMENTAL] Prevent this node to be docked over an empty node (e.g. DockSpace with no other windows)
    ImGuiDockNodeFlags_NoResizeX                :: 1 << 22  // [EXPERIMENTAL]
    ImGuiDockNodeFlags_NoResizeY                :: 1 << 23  // [EXPERIMENTAL]

    flags: i32 = 
        ImGuiDockNodeFlags_NoTabBar |
        ImGuiDockNodeFlags_HiddenTabBar |
        ImGuiDockNodeFlags_NoDockingSplitMe |
        ImGuiDockNodeFlags_NoDockingOverMe |
        ImGuiDockNodeFlags_NoDockingOverOther

    class: imgui.WindowClass
    class.DockNodeFlagsOverrideSet = transmute(imgui.DockNodeFlags)flags

    imgui.SetNextWindowClass(&class)

    y :: 4
    imgui.PushStyleVarImVec2(.WindowPadding, vec2{0, y})

    imgui.Begin("##toolbar", flags = imgui.WindowFlags_NoDecoration)

    icon := EditorIcon.StopButton if e.state == .Play else EditorIcon.PlayButton
    size := imgui.GetWindowHeight() - y * 2

    pos := imgui.GetWindowContentRegionMax().x * 0.5 - size * 0.5
    imgui.SetCursorPosX(pos)
    imgui.PushStyleVarImVec2(.FramePadding, vec2{0, 0})
    imgui.PushStyleColorImVec4(.Button, vec4{0, 0, 0, 0})
    if imgui.ImageButton("##play_button", transmute(rawptr)u64(e.icons[icon].handle), vec2{size, size}) {
        #partial switch e.state {
        case .Edit:
            editor_on_scene_play(e)
        case .Play:
            editor_on_scene_stop(e)
        }
    }

    imgui.SameLine()

    imgui.BeginDisabled()
    if imgui.ImageButton("##pause_button", transmute(rawptr)u64(e.icons[.PauseButton].handle), vec2{size, size}) {

    }
    imgui.EndDisabled()

    imgui.PopStyleVar(2)
    imgui.PopStyleColor(1)

    imgui.End()
}

Folder :: struct {
    path: string,
    opened: bool,
}

ContentItem :: struct {
    uuid: UUID,

    type: AssetType,
    is_folder: bool,
    asset: AssetHandle,

    absolute_path: string,
    relative_path: string,
    name: string,

    renaming: bool,
}

ContentBrowser :: struct {
    root_dir: string,
    current_dir: string,

    content_items: [dynamic]ContentItem,

    items: []os.File_Info,
    imported_items_view: []os.File_Info,

    textures: [ContentItemType]Texture2D,

    renaming_item: Maybe(int),

    selected_items: map[UUID]struct{
        asset: Maybe(AssetHandle),
    },
}

cb_deinit :: proc(cb: ^ContentBrowser) {
    delete(cb.root_dir)
    delete(cb.current_dir)
    os.file_info_slice_delete(cb.items[:])
}

cb_reset_selection :: proc(cb: ^ContentBrowser) {
    clear(&cb.selected_items)
}

cb_select_item :: proc(cb: ^ContentBrowser, item: ContentItem, should_reset_selection := true) {
    if should_reset_selection {
        cb_reset_selection(cb)
    }

    cb.selected_items[item.uuid] = {
        asset = item.asset if item.asset != 0 else nil,
    }
}

cb_navigate_to_folder :: proc(cb: ^ContentBrowser, folder: string, relative := false) {
    if relative {
        cb.current_dir = filepath.join({cb.root_dir, folder})
    } else {
        cb.current_dir = folder
    }
    log.debugf("New current dir is %v", cb.current_dir)

    cb_refresh(cb)
}

cb_refresh :: proc(cb: ^ContentBrowser) {
    cb.renaming_item= nil
    cb_reset_selection(cb)

    for item in cb.content_items {
        delete(item.name)
        delete(item.relative_path)
        delete(item.absolute_path)
    }
    clear(&cb.content_items)

    handle, err := os.open(cb.current_dir)
    defer os.close(handle)
    files, err2 := os.read_dir(handle, 100, context.temp_allocator)

    imported_items := slice.filter(files, proc(info: os.File_Info) -> bool {
        if info.is_dir {
            return true
        }
        rel, err := filepath.rel(EditorInstance.active_project.root, info.fullpath, context.temp_allocator)
        if err != nil {
            return false
        }

        return get_asset_handle_from_path(&EngineInstance.asset_manager, rel) != 0
    })

    for imported in imported_items {
        uuid := generate_uuid()
        if imported.is_dir {
            rel, _ := filepath.rel(cb.root_dir, imported.fullpath, context.temp_allocator)
            base := filepath.base(rel)

            item := ContentItem {
                is_folder = true,
                absolute_path = strings.clone(imported.fullpath),
                relative_path = strings.clone(rel),
                name = strings.clone(base),
                uuid = uuid,
            }

            append(&cb.content_items, item)
        } else {
            relative_to_content_browser, _ := filepath.rel(cb.root_dir, imported.fullpath, context.temp_allocator)
            relative_to_project_root, _ := filepath.rel(EditorInstance.active_project.root, imported.fullpath, context.temp_allocator)
            asset := get_asset_handle_from_path(&EngineInstance.asset_manager, relative_to_project_root)
            assert(is_asset_handle_valid(&EngineInstance.asset_manager, asset))
            name := filepath.stem(relative_to_content_browser)

            type := get_asset_type(&EngineInstance.asset_manager, asset)

            item := ContentItem {
                absolute_path = strings.clone(imported.fullpath),
                relative_path = strings.clone(relative_to_content_browser),
                name = strings.clone(name),
                asset = asset,
                type = type,
                uuid = uuid,
            }

            append(&cb.content_items, item)
        }

        slice.sort_by(cb.content_items[:], proc(i, j: ContentItem) -> bool {
            return i32(i.is_folder) > i32(j.is_folder)
        })
    }
}

editor_content_browser :: proc(e: ^Editor) {
    new_asset_menu :: proc(e: ^Editor) {
        if imgui.BeginMenu("New") {
            if imgui.MenuItem("Folder") {
                cb_refresh(&e.content_browser)
            }

            imgui.Separator()

            if imgui.MenuItem("Scene") {
                cb_refresh(&e.content_browser)
            }

            if imgui.MenuItem("PBR Material") {
                uuid := generate_uuid()

                dir, err := filepath.rel(e.active_project.root, e.content_browser.current_dir, context.temp_allocator)
                if err != nil {
                    log.errorf("%v", err)
                    return
                }

                path := filepath.join({dir, fmt.tprintf("%v.lua", uuid)}, context.temp_allocator)

                create_new_asset(&EngineInstance.asset_manager, .PbrMaterial, RelativePath(path))

                cb_refresh(&e.content_browser)
            }

            if imgui.MenuItem("Lua Script") {
                uuid := generate_uuid()
                path := filepath.join({e.content_browser.current_dir, fmt.tprintf("%v.lua", uuid)})
                defer delete(path)

                handle, err := os.open(path, os.O_CREATE | os.O_WRONLY)
                if err != 0 {
                    log.errorf("Error opening file %v: %v", path, err)
                    return
                }
                defer os.close(handle)
                fmt.fprint(handle,
`---@class NewScript
---@field entity LuaEntity
NewScript = {
    Properties = {
        Name = "NewScript"
    },
    Export = {}
}

function NewScript:on_init()
end

function NewScript:on_update(delta)
end

return NewScript
`)
                os.flush(handle)

                register_asset(&EngineInstance.asset_manager, path)

                cb_refresh(&e.content_browser)
            }
            imgui.EndMenu()
        }

        if imgui.MenuItem("Open in Explorer") {
            fs.open_file_explorer(e.content_browser.current_dir)
        }
    }

    browser := &e.content_browser

    imgui.PushStyleVarImVec2(.WindowPadding, vec2{5, 5})
    opened := imgui.Begin("Content Browser", nil, {})

    {
        imgui.BeginChild("folder side view", vec2{150, 0}, {.Border, .ResizeX}, {})
        imgui.EndChild()
    }

    imgui.SameLine()

    {
        imgui.PushStyleVarImVec2(.WindowPadding, vec2{2, 2})
        if imgui.BeginChild("content view root", vec2{0, 0}, {.Border}, {}) {
            relative, _ := filepath.rel(e.content_browser.root_dir, e.content_browser.current_dir, allocator = context.temp_allocator)
            relative, _ = filepath.to_slash(relative, allocator = context.temp_allocator)
            imgui.TextUnformatted(fmt.ctprintf("%v:%v", e.active_project.name, relative))

            if imgui.Button("Import") {
                file := open_file_dialog("Any supported asset file", "*.png;*.glb;*.jpg")
                if file != "" {
                    register_asset(&EngineInstance.asset_manager, file)
                    cb_refresh(&e.content_browser)
                }
            }

            imgui.SameLine(imgui.GetContentRegionAvail().x - 80)
            if imgui.Button("Options") {
                imgui.OpenPopup("ContentBrowserSettings", {})
            }

            @(static) padding := i32(8)
            @(static) thumbnail_size := i32(64)

            imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
            if imgui.BeginPopup("ContentBrowserSettings", {}) {
                imgui.DragInt("Padding", &padding)
                imgui.DragInt("Thumbnail Size", &thumbnail_size)
                imgui.EndPopup()
            }
            imgui.PopStyleVar()

            imgui.PushStyleVarImVec2(.ItemSpacing, vec2{})
            if imgui.BeginChild("content view", vec2{0, 0}, {.FrameStyle} ,{}) {
                frame_padding := imgui.GetStyle().FramePadding

                item_size := padding + thumbnail_size + i32(frame_padding.x)
                width := imgui.GetContentRegionAvail().x
                columns := i32(width) / item_size
                if columns < 1 {
                    columns = 1
                }

                imgui.Columns(columns, "awd", false)

                imgui.PushStyleColorImVec4(.Button, vec4{0, 0, 0, 0})

                size := vec2{f32(thumbnail_size), f32(thumbnail_size)}
                if e.content_browser.current_dir != e.content_browser.root_dir {
                    imgui.ImageButton(cstr("back"), transmute(rawptr)u64(e.content_browser.textures[.FolderBack].handle), size)
                    if imgui.IsItemHovered({}) && imgui.IsMouseDoubleClicked(.Left) {
                        cb_navigate_to_folder(
                            &e.content_browser,
                            filepath.dir(e.content_browser.current_dir))
                    }
                    imgui.TextUnformatted("..")
                    imgui.NextColumn()
                }

                imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
                if imgui.BeginPopupContextWindow() {
                    new_asset_menu(e)
                    imgui.EndPopup()
                }
                imgui.PopStyleVar()

                for &item, i in e.content_browser.content_items {
                    content_type: ContentItemType
                    if item.is_folder {
                        content_type = .Folder
                    } else {
                        #partial switch item.type {
                        case .Mesh:
                            content_type = .Generic
                        case .Shader:
                            content_type = .Generic
                        case .LuaScript:
                            content_type = .Script
                        case .PbrMaterial:
                            content_type = .Material
                        }
                    }
                    cname := cstr(item.name)

                    is_this_selected := item.uuid in e.content_browser.selected_items
                    if is_this_selected {
                        color := imgui.GetStyleColorVec4(.ButtonActive)
                        imgui.PushStyleColorImVec4(.Button, color^)
                    }

                    clicked := imgui.ImageButton(
                                 cname,
                                 transmute(rawptr)u64(e.content_browser.textures[content_type].handle),
                                 size)

                    if clicked {
                        cb_select_item(browser, item, !is_key_pressed(.LeftControl))
                    }

                    if is_this_selected {
                        imgui.PopStyleColor()
                    }

                    if imgui.IsItemHovered() {
                        if imgui.IsMouseDoubleClicked(.Left) {
                            if item.is_folder {
                                cb_navigate_to_folder(browser, item.relative_path, relative = true)
                            } else {
                                e.asset_windows[item.asset] = create_asset_window(item.asset)
                            }
                        }

                        if imgui.IsMouseClicked(.Right) {
                            cb_select_item(browser, item)
                        }
                    }

                    if imgui.BeginDragDropSource() {
                        imgui.TextUnformatted(cstr(item.name))
                        imgui.SetDragDropPayload("CONTENT_ITEM_ASSET", &item.asset, size_of(AssetHandle), .Once)
                        imgui.EndDragDropSource()
                    }

                    // TODO(minebill): This string should probably be stored per item.
                    @(static) rename_string: DynamicString

                    imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
                    if imgui.BeginPopupContextItem() {
                        if imgui.MenuItem("Rename") {
                            item.renaming = true
                            delete_ds(rename_string)
                            rename_string = make_ds(item.name)
                        }
                        imgui.Separator()

                        imgui.PushStyleColorImVec4(.Text, cast(vec4)COLOR_ROSE)
                        if imgui.MenuItem("Delete") {
                        }
                        imgui.PopStyleColor()

                        imgui.EndPopup()
                    }
                    imgui.PopStyleVar()

                    imgui.PushFont(e.fonts[.Light])
                    imgui.PushStyleColorImVec4(.Text, cast(vec4)COLOR_TURQUOISE)

                    if item.renaming {
                        imgui.PushStyleColorImVec4(.FrameBg, cast(vec4) COLOR_PLUM)
                        imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
                        if imgui_text("##rename_input", &rename_string, {.AutoSelectAll, .EnterReturnsTrue, .EscapeClearsAll}) {
                            item.renaming = false

                            new_name := ds_to_string(rename_string)
                            if item.name != new_name {
                                if item.is_folder {
                                    rename_folder(&EngineInstance.asset_manager, item.absolute_path, new_name)
                                } else {
                                    rename_asset(&EngineInstance.asset_manager, item.asset, new_name)
                                }
                                cb_refresh(browser)
                            }
                        }
                        imgui.PopStyleColor()

                        if imgui.IsItemDeactivated() {
                            item.renaming = false
                        }
                        // if imgui.IsItemDeactivatedAfterEdit() {
                        //     if item.renaming {
                        //         item.renaming = false
                        //     }
                        // }
                    } else {
                        imgui.TextWrapped(cname)
                    }

                    imgui.PopStyleColor()
                    imgui.PopFont()

                    imgui.NextColumn()
                }

                imgui.PopStyleColor()

            }
            imgui.EndChild()
            imgui.PopStyleVar()

        }
        imgui.EndChild()

        imgui.PopStyleVar()
    }

    imgui.PopStyleVar()
    imgui.End()
}

editor_log_window :: proc(e: ^Editor) {
    opened := imgui.Begin("Log", nil, {})
    if opened {
        if imgui.Button("Clear") {
            clear(&e.log_entries)
        }

        imgui.SameLine()

        @(static) auto_scroll := true
        imgui.Checkbox("Auto Scroll", &auto_scroll)

        imgui.SameLine()

        @(static) filter_backing: [100]byte
        imgui.InputText("Filter", transmute(cstring)&filter_backing, 100, {})
        filter := cast(string)(transmute(cstring)&filter_backing)

        child_opened := imgui.BeginChild("scrolling_region", vec2{0, 0}, {.FrameStyle}, {.HorizontalScrollbar})
        if child_opened {
            width := imgui.GetContentRegionAvail().x
            for entry, i in e.log_entries {
                if !strings.contains(entry.text, filter) || entry.text == "" {
                    continue
                }
                text := raw_data(entry.text)
                start := cstring(&text[0])
                end := cstring(&text[len(entry.text)])
                imgui.PushIDInt(i32(i))
                imgui.PushStyleVarImVec2(.FramePadding, vec2{1, 1})
                imgui.PushStyleVarImVec2(.ItemSpacing, vec2{1, 1})
                switch entry.level {
                case .Debug:
                    imgui.PushStyleColor(.Text, 0xff888888)
                case .Info:
                    imgui.PushStyleColor(.Text, 0xffffffff)
                case .Warning:
                    imgui.PushStyleColor(.Text, 0xff00ffff)
                case .Error:
                    imgui.PushStyleColor(.Text, 0xff0000ff)
                case .Fatal:
                    imgui.PushStyleColor(.Text, 0xff0000ff)
                }

                imgui.PushItemWidth(width)
                imgui.InputText("##", start, len(entry.text), {.ReadOnly})
                imgui.PopStyleColor()
                imgui.PopStyleVar(2)
                imgui.PopID()

                if auto_scroll && imgui.GetScrollY() >= imgui.GetScrollMaxY() {
                    imgui.SetScrollHereY(1.0)
                }
            }
            imgui.EndChild()
        }
    }
    imgui.End()
}

editor_gameobjects :: proc(e: ^Editor) {
    entity_create_menu :: proc(e: ^Editor, parent: EntityHandle) {
        if imgui.BeginMenu("New") {
            if imgui.MenuItem("Empty Entity") {
                new_object(&e.engine.world, parent = parent)
            }
            if imgui.MenuItem("Point Light") {
                go := new_object(&e.engine.world, "Point Light", parent)
                add_component(&e.engine.world, go, PointLightComponent)
            }
            if imgui.MenuItem("Camera") {
                go := new_object(&e.engine.world, "Camera", parent)
                add_component(&e.engine.world, go, Camera)
            }
            if imgui.MenuItem("Sky") {
                go := new_object(&e.engine.world, "Sky", parent)
                add_component(&e.engine.world, go, CubemapComponent)
            }
            imgui.EndMenu()
        }
    }
    tree_node_gameobject :: proc(e: ^Editor, handle: EntityHandle) {
        flags := imgui.TreeNodeFlags{}
        flags += {.SpanAvailWidth, .FramePadding, .OpenOnDoubleClick, .OpenOnArrow}
        children := &get_object(&e.engine.world, handle).children

        slice.sort_by_key(children[:], proc(a: EntityHandle) -> EntityHandle {
            return a
        })

        if len(children) == 0 {
            flags += {.Leaf}
        }

        go, ok := &e.engine.world.objects[handle]
        if !ok do return

        // if e.selected_entity == handle {
        //     flags += {.Selected}
        // }
        if handle in e.entity_selection {
            flags += {.Selected}
        }

        imgui.PushIDInt(i32(handle))

        if !go.enabled {
            imgui.PushStyleColorImVec4(.Text, vec4{0.3, 0.3, 0.3, 1})
            imgui.PushStyleColorImVec4(.TextSelectedBg, vec4{0.5, 0.5, 0.5, 1})
        }

        opened := imgui.TreeNodeEx(ds_to_cstring(go.name), flags)

        if !go.enabled {
            imgui.PopStyleColor(2)
        }

        // NOTE(minebill): The context menu needs to be created before drawing the children tree nodes
        imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
        if imgui.BeginPopupContextItem() {
            entity_create_menu(e, handle)

            imgui.Separator()

            if imgui.MenuItem(fmt.ctprintf("Destroy '%v'", ds_to_string(go.name))) {
                delete_object(&e.engine.world, handle)
            }
            imgui.EndPopup()
        }
        imgui.PopStyleVar()

        imgui.PopID()

        if imgui.IsItemClicked() {
            shift := imgui.IsKeyDown(.LeftShift)
            select_entity(e, handle, !shift)
        }

        if imgui.BeginDragDropSource() {
            imgui.SetDragDropPayload("WORLD_TREENODE", &go.handle, size_of(go.handle))
            imgui.TextUnformatted(ds_to_cstring(go.name))
            imgui.EndDragDropSource()
        }

        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload("WORLD_TREENODE"); payload != nil {
                id := (cast(^EntityHandle)payload.Data)^
                reparent_entity(&e.engine.world, id, go.handle)
            }
            imgui.EndDragDropTarget()
        }

        if opened {
            for child in children {
                tree_node_gameobject(e, child)
            }
            imgui.TreePop()
        }

    }

    flags: imgui.WindowFlags
    if e.engine.world.modified {
        flags += {.UnsavedDocument}
    }
    if imgui.Begin("Entities", flags = flags) {
        imgui.TextUnformatted(cstr(e.engine.world.name))
        imgui.Separator()

        go := e.engine.world.root

        children := &get_object(&e.engine.world, go).children

        imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
        if imgui.BeginPopupContextWindow() {
            entity_create_menu(e, 0)
            imgui.EndPopup()
        }
        imgui.PopStyleVar()
        for child in children {
            tree_node_gameobject(e, child)
        }

        if len(children) == 0 {
            imgui.TextWrapped("No entities. Right click to create a new one.")
        }

        imgui.Dummy(imgui.GetContentRegionAvail())
        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload("WORLD_TREENODE"); payload != nil {
                id := (cast(^EntityHandle)payload.Data)^
                reparent_entity(&e.engine.world, id, 0)
            }
            imgui.EndDragDropTarget()
        }
    }
    imgui.End()
}

editor_asset_manager :: proc(e: ^Editor) {
    if e.show_asset_manager {
        if imgui.Begin("Asset Manager", &e.show_asset_manager) {
            flags := imgui.TableFlags_Borders | imgui.TableFlags_Sortable | imgui.TableFlags_ScrollY
            if imgui.BeginChild("Asset Registry") {
                if imgui.BeginTable("asset_manager_entries", 4, flags) {
                    imgui.TableSetupColumn("Asset Handle", {.DefaultSort})
                    imgui.TableSetupColumn("Path", {.DefaultSort})
                    imgui.TableSetupColumn("Type", {.DefaultSort})
                    imgui.TableSetupColumn("Virtual", {.DefaultSort})

                    if sort_specs := imgui.TableGetSortSpecs();
                        sort_specs != nil && sort_specs.SpecsDirty {

                        delete(e.asset_manager_sorted_keys)
                        e.asset_manager_sorted_keys, _ = slice.map_keys(EngineInstance.asset_manager.registry)

                        SortData :: struct {
                            e: ^Editor,
                            sort_specs: ^imgui.TableSortSpecs,
                        }
                        data: SortData
                        data.e = e
                        data.sort_specs = sort_specs
                        context.user_ptr = &data

                        slice.sort_by(e.asset_manager_sorted_keys, proc(i, j: AssetHandle) -> bool {
                            data := cast(^SortData) context.user_ptr
                            registry := &EngineInstance.asset_manager.registry

                            switch data.sort_specs.Specs.ColumnIndex {
                            case 0:
                                #partial switch data.sort_specs.Specs.SortDirection {
                                case .Ascending:
                                    return i > j
                                case .Descending:
                                    return i < j
                                }
                            case 1:
                                #partial switch data.sort_specs.Specs.SortDirection {
                                case .Ascending:
                                    return registry[i].path > registry[j].path
                                case .Descending:
                                    return registry[i].path < registry[j].path
                                }
                            case 2:
                                #partial switch data.sort_specs.Specs.SortDirection {
                                case .Ascending:
                                    return registry[i].type > registry[j].type
                                case .Descending:
                                    return registry[i].type < registry[j].type
                                }
                            case 3:
                                #partial switch data.sort_specs.Specs.SortDirection {
                                case .Ascending:
                                    return int(registry[i].is_virtual) > int(registry[j].is_virtual)
                                case .Descending:
                                    return int(registry[i].is_virtual) < int(registry[j].is_virtual)
                                }
                            }
                            return false
                        })

                        sort_specs.SpecsDirty = false
                    }

                    imgui.TableHeadersRow()


                    imgui.PushFont(e.fonts[.Light])
                    for handle in e.asset_manager_sorted_keys {
                        metadata := EngineInstance.asset_manager.registry[handle]
                        imgui.TableNextColumn()
                        imgui.TextWrapped(fmt.ctprintf("%v", handle))

                        if metadata.type == .Texture2D {
                            if imgui.IsItemHovered() && imgui.BeginTooltip() {
                                texture := get_asset(&EngineInstance.asset_manager, handle, Texture2D)
                                size := vec2{256, 256}

                                draw_texture(texture^, size)
                                imgui.EndTooltip()
                            }
                        }

                        imgui.TableNextColumn()
                        imgui.TextWrapped(fmt.ctprintf("%v", metadata.path))
                        imgui.TableNextColumn()
                        imgui.TextWrapped(fmt.ctprintf("%v", metadata.type))
                        imgui.TableNextColumn()
                        imgui.TextWrapped(fmt.ctprintf("%v", metadata.is_virtual))
                    }
                    imgui.PopFont()
                    imgui.EndTable()
                }
            }
            imgui.EndChild()

            // if imgui.BeginChild("Loaded Assets") {
            //     if imgui.BeginTable("loaded_assets_entries", 2, flags) {
            //         imgui.TableSetupColumn("Asset Handle")
            //         imgui.TableSetupColumn("Type")
            //         imgui.TableHeadersRow()

            //         for handle, asset in EngineInstance.asset_manager.loaded_assets {
            //             imgui.TableNextColumn()
            //             imgui.TextWrapped(fmt.ctprintf("%v", handle))
            //             imgui.TableNextColumn()
            //             imgui.TextWrapped(fmt.ctprintf("%v", asset.type))
            //         }
            //         imgui.EndTable()
            //     }

            // }
            // imgui.EndChild()
        }
        imgui.End()
    }
}

editor_undo_redo_window :: proc(e: ^Editor) {
    if e.show_undo_redo {
        if imgui.Begin("Undo/Redo Stack", &e.show_undo_redo) {
            size := imgui.GetContentRegionAvail()

            flags := imgui.TableFlags_Borders
            child_flags: imgui.ChildFlags = {.FrameStyle, .Border}
            imgui.BeginChild("##undo_stack", vec2{0, size.y / 2.0}, child_flags)
                if imgui.BeginTable("##__undo_stack", 3, flags) {
                    imgui.TableSetupColumn("Tag")
                    imgui.TableSetupColumn("Size")
                    imgui.TableSetupColumn("LOC")
                    imgui.TableHeadersRow()

                    for item in e.undo.undo_items {
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(cstr(item.tag) if item.tag != "" else "None")
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(fmt.ctprintf("%v bytes", item.size))
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(fmt.ctprintf("%v", item.loc))
                    }
                    imgui.EndTable()
                }
            imgui.EndChild()

            imgui.BeginChild("##redo_stack", vec2{0, size.y / 2.0}, child_flags)
                if imgui.BeginTable("##__redo_stack", 3, flags) {
                    imgui.TableSetupColumn("Tag")
                    imgui.TableSetupColumn("Size")
                    imgui.TableSetupColumn("LOC")
                    imgui.TableHeadersRow()

                    for item in e.undo.redo_items {
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(cstr(item.tag) if item.tag != "" else "None")
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(fmt.ctprintf("%v bytes", item.size))
                        imgui.TableNextColumn()
                        imgui.TextUnformatted(fmt.ctprintf("%v", item.loc))
                    }
                    imgui.EndTable()
                }
            imgui.EndChild()
        }
        imgui.End()
    }
}

reset_selection :: proc(e: ^Editor) {
    for entity, _ in e.entity_selection {
        if go := get_object(&e.engine.world, entity); go != nil {
            go.flags -= {.Outlined}
        }
    }
    clear(&e.entity_selection)
}

select_entity :: proc(e: ^Editor, entity: EntityHandle, should_reset_selection := false) {
    selected_handle, ok := e.selected_entity.?

    if should_reset_selection {
        reset_selection(e)
    }

    e.selected_entity = nil
    if entity != 0 {
        e.selected_entity = entity
        e.entity_selection[entity] = true
        get_object(&e.engine.world, entity).flags += {.Outlined}
    }
}

draw_component :: proc(e: ^Editor, id: typeid, component: ^Component) {
    name: cstring
    info := type_info_of(id).variant.(reflect.Type_Info_Named)
    name = cstr(COMPONENT_NAMES[id]) if id in COMPONENT_NAMES else cstr(info.name)

    if id == typeid_of(ScriptComponent) {
        script_component := cast(^ScriptComponent)component

        script := get_asset(&EngineInstance.asset_manager, script_component.script, LuaScript)
        if script != nil && script.properties.name != "" {
            name = fmt.ctprintf("Script[%s]", script.properties.name)
        }
    }

    imgui.PushStyleVarImVec2(.FramePadding, {4, 4})
    opened := imgui.TreeNodeExPtr(transmute(rawptr)id, {.AllowOverlap, .DefaultOpen, .Framed, .FramePadding, .SpanAvailWidth}, name)

    width := imgui.GetContentRegionMax().x

    line_height := imgui.GetFont().FontSize + imgui.GetStyle().FramePadding.y * 2.0
    imgui.PopStyleVar()

    imgui.SameLine(width - line_height * 0.75)
    imgui.PushIDPtr(component)
    if imgui.Button("+", vec2{line_height, line_height}) {
        imgui.OpenPopup("ComponentSettings", {})
    }

    imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
    if imgui.BeginPopup("ComponentSettings") {
        if imgui.MenuItem("Copy Component") {
            // TODO
        }

        if imgui.MenuItem("Remove Component") {
            handle, ok := e.selected_entity.(EntityHandle)
            if ok {
                remove_component(&e.engine.world, handle, id)
            }
        }
        imgui.EndPopup()
    }
    imgui.PopStyleVar()
    imgui.PopID()

    if opened {
        imgui_draw_component(e, any{component, id})
        imgui.TreePop()
    }

}

centered_button :: proc(label: cstring, alignment := f32(0.5)) -> bool {
    style := imgui.GetStyle();

    size := imgui.CalcTextSize(label).x + style.FramePadding.x * 2.0
    avail := imgui.GetContentRegionAvail().x

    off := (avail - size) * alignment
    if off > 0.0 {
        imgui.SetCursorPosX(imgui.GetCursorPosX() + off)
    }

    return imgui.Button(label)
}

draw_texture :: proc(texture: Texture2D, size: vec2, uv0 := vec2{0, 1}, uv1 := vec2{1, 0}) {
    imgui.Image(transmute(rawptr)u64(texture.handle), size, uv0, uv1, vec4{1, 1, 1, 1})
}

imgui_enum_combo :: proc(name: string, selection: ^$E, flags: imgui.ComboFlags = {.WidthFitPreview}) -> (ret: bool) {
    return imgui_enum_combo_id(name, selection, type_info_of(E), flags)
}

imgui_enum_combo_id :: proc(name: string, selection: any, enum_type_info: ^reflect.Type_Info, flags: imgui.ComboFlags = {.WidthFitPreview}) -> (ret: bool) {
    enum_string := cstr(reflect.enum_string(selection))
    if named, ok := enum_type_info.variant.(reflect.Type_Info_Named); ok {
        if imgui.BeginCombo(cstr(name), enum_string, flags) {
            loop: for field in reflect.enum_fields_zipped(selection.id) {
                value, ok := reflect.enum_from_name_any(enum_type_info.id, field.name)
                assert(ok)

                if imgui.Selectable(
                    cstr(field.name),
                    value == (cast(^reflect.Type_Info_Enum_Value)selection.data)^,
                    {}, vec2{}) {
                    (cast(^reflect.Type_Info_Enum_Value)selection.data)^ = value
                    ret = true
                    break loop
                }
            }
            imgui.EndCombo()
        }
    }
    return
}

imgui_union_combo :: proc(name: string, selection: ^$E, flags: imgui.ComboFlags = {.WidthFitPreview}) -> (ret: bool) {
    enum_string := cstr(reflect.enum_string(selection^))

    if imgui.BeginCombo(cstr(name), enum_string, flags) {
        loop: for field in reflect.enum_fields_zipped(E) {
            a := reflect.type_info_base(type_info_of(E)).variant.(reflect.Type_Info_Union)
            _ = a.variants
        }
        imgui.EndCombo()
    }
    return
}

imgui_flags_box :: proc(name: string,  flags: ^$B/bit_set[$E]) {
    if imgui.BeginCombo(cstr(name), "", {.NoPreview}) {
        loop: for field in reflect.enum_fields_zipped(E) {
            value := E(field.value)
            has_flag := value in flags
            if imgui.Selectable(
                cstr(field.name),
                has_flag,
                {.DontClosePopups}, vec2{}) {
                if has_flag {
                    flags^ -= {value}
                } else {
                    flags^ += {value}
                }
            }
        }

        imgui.EndCombo()
    }
}

imgui_vec3 :: proc(id: cstring, v: ^vec3) -> (modified: bool, activated, deactivated: bool) {
    X_COLOR :: vec4{0.92, 0.24, 0.27, 1.0}
    X_COLOR_HOVER :: vec4{0.76, 0.20, 0.22, 1.0}
    Y_COLOR :: vec4{0.20, 0.67, 0.32, 1.0}
    Y_COLOR_HOVER :: vec4{0.15, 0.52, 0.25, 1.0}
    Z_COLOR :: vec4{0.18, 0.49, 0.74, 1.0}
    Z_COLOR_HOVER :: vec4{0.14, 0.39, 0.60, 1.0}
    SPACE_COUNT :: 5
    ITEM_COUNT :: 3

    imgui.PushID(id)

    spacing := imgui.GetStyle().ItemSpacing.x
    width := (imgui.GetContentRegionAvail().x - spacing * SPACE_COUNT - imgui.CalcTextSize("X").x * 3) / ITEM_COUNT

    imgui.AlignTextToFramePadding()

    pos := imgui.GetWindowPos()

    imgui.PushStyleColorImVec4(.Text, X_COLOR)
    imgui.TextUnformatted("X")
    imgui.PopStyleColor()


    imgui.SameLine()
    imgui.SetNextItemWidth(width)
    imgui.PushStyleColorImVec4(.FrameBg, X_COLOR)
    imgui.PushStyleColorImVec4(.FrameBgHovered, X_COLOR_HOVER)
    modified |= imgui.DragFloat("##x", &v.x, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColor(2)

    activated |= imgui.IsItemActivated()
    deactivated |= imgui.IsItemDeactivated()

    imgui.SameLine()

    imgui.PushStyleColorImVec4(.Text, Y_COLOR)
    imgui.TextUnformatted("Y")
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.SetNextItemWidth(width)
    imgui.PushStyleColorImVec4(.FrameBg, Y_COLOR)
    imgui.PushStyleColorImVec4(.FrameBgHovered, Y_COLOR_HOVER)
    modified |= imgui.DragFloat("##y", &v.y, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColor(2)

    activated |= imgui.IsItemActivated()
    deactivated |= imgui.IsItemDeactivated()

    imgui.SameLine()

    imgui.PushStyleColorImVec4(.Text, Z_COLOR)
    imgui.TextUnformatted("Z")
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.SetNextItemWidth(width)
    imgui.PushStyleColorImVec4(.FrameBg, Z_COLOR)
    imgui.PushStyleColorImVec4(.FrameBgHovered, Z_COLOR_HOVER)
    modified |= imgui.DragFloat("##z", &v.z, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColor(2)

    activated |= imgui.IsItemActivated()
    deactivated |= imgui.IsItemDeactivated()

    imgui.PopID()
    return
}

imgui_draw_component :: proc(e: ^Editor, s: any) -> (modified: bool) {
    base := cast(^Component)s.data
    base->editor_ui(e, s)

    return
}

imgui_draw_struct :: proc(e: ^Editor, s: any) -> (modified: bool) {
    mod_count := 0
    imgui.PushIDPtr(s.data)
    fields := reflect.struct_fields_zipped(s.id)
    for field in fields {
        if field.name == "base" do continue

        meta, ok := reflect.struct_tag_lookup(field.tag, "hide")
        if ok {
            continue
        }

        is_struct := reflect.is_struct(field.type)
        if false && is_struct && !field.is_using {
            switch field.type.id {
            case:
            if imgui.TreeNodeEx(cstr(field.name), {.FramePadding}) {
                if draw_struct_field(e, reflect.struct_field_value(s, field), field) {
                    if s.id in COMPONENT_INDICES {
                        base := cast(^Component)s.data
                        if base.prop_changed != nil {
                            base->prop_changed(field)
                        }
                    }
                    mod_count += 1
                }
                imgui.TreePop()
            } 
            }
        } else {
            if draw_struct_field(e, reflect.struct_field_value(s, field), field) {
                if s.id in COMPONENT_INDICES {
                    base := cast(^Component)s.data
                    if base.prop_changed != nil {
                        base->prop_changed(field)
                    }
                }
                mod_count += 1
            }
        }
    }

    modified = mod_count > 0
    imgui.PopID()
    return
}

draw_struct_field :: proc(e: ^Editor, value: any, field: reflect.Struct_Field) -> (modified: bool) {
    switch {
    case typeid_of(EntityHandle) == field.type.id:
        handle := &value.(EntityHandle)
        go := get_object(&e.engine.world, handle^)
        name := ds_to_cstring(go.name) if go != nil else "None"
        if imgui.BeginCombo(cstr(field.name), name, {}) {
            for h, &obj in e.engine.world.objects {
                name := ds_to_cstring(obj.name)
                if imgui.Selectable(name) {
                    handle^ = h
                }
            }
            imgui.EndCombo()
        }

    case typeid_of(AssetHandle) == field.type.id:
        handle := &value.(AssetHandle)

        value, ok := reflect.struct_tag_lookup(field.tag, "asset")
        if !ok {
            break
        }

        metadata := get_asset_metadata(&EngineInstance.asset_manager, handle^)
        if metadata.type != .Invalid {
            imgui.Button(fmt.ctprintf("%v - %v", field.name, metadata.type))
        } else {
            imgui.Button(cstr(field.name))
        }
        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
                asset_handle := cast(^AssetHandle)payload.Data

                log.debug("Setting field %v to %v", field.name, asset_handle^)
                handle^ = asset_handle^
            }
        }

        imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
        if imgui.BeginPopupContextItem() {
            if imgui.MenuItem("Clear") {
                handle^ = 0
            }
            imgui.EndPopup()
        }
        imgui.PopStyleVar()

    case reflect.is_boolean(field.type):
        b := &value.(bool)
        modified = imgui.Checkbox(cstr(field.name), b)

    case reflect.is_float(field.type):
        fallthrough
    case reflect.is_integer(field.type):
        if min, max, ok := parse_range_tag(field.tag); ok {
            if reflect.is_integer(field.type) {
                // We use the biggest integer type to cover all cases.
                min, max := i128(min), i128(max)
                modified = imgui.SliderScalar(
                    cstr(field.name),
                    number_to_imgui_scalar(value),
                    value.data,
                    &min, &max)
            } else {
                modified = imgui.SliderScalar(
                    cstr(field.name),
                    number_to_imgui_scalar(value),
                    value.data,
                    &min, &max)
            }
        } else {
            modified = imgui.DragScalar(
                cstr(field.name),
                number_to_imgui_scalar(value),
                value.data)
        }

    case reflect.is_enum(field.type):
        modified = imgui_enum_combo_id(field.name, value, field.type)

    case reflect.is_array(field.type):
        array := reflect.type_info_base(field.type).variant.(reflect.Type_Info_Array)
        switch field.type.id {
        case typeid_of(vec3):
            imgui.TextUnformatted(fmt.ctprintf("%v", field.name))
            imgui_vec3(fmt.ctprintf("##_field_%v", field.name), &value.(vec3))
        case typeid_of(vec4):
            imgui.TextUnformatted(fmt.ctprintf("%v", field.name))
            modified = imgui.DragFloat4(fmt.ctprintf("##_field_%v", field.name), &value.(vec4))
        case typeid_of(Color):
            imgui.TextUnformatted(fmt.ctprintf("%v", field.name))
            color := cast(^vec4)&value.(Color)
            modified = imgui.ColorEdit4(fmt.ctprintf("##_field_%v", field.name), color, {})
        case:
            imgui_draw_array(field.name, value)
        }
    case reflect.is_slice(field.type):
        modified = imgui_draw_slice(field.name, value)
    case reflect.is_struct(field.type):
        switch field.type.id {

        case:
            if imgui.TreeNodeEx(cstr(field.name), {.FramePadding}) {
                modified = imgui_draw_struct(e, value)
                imgui.TreePop()
            }
        }
    case reflect.is_pointer(field.type):
        pointer := reflect.type_info_base(field.type).variant.(runtime.Type_Info_Pointer)

        /*
        switch pointer.elem.id {
        case typeid_of(Model):
            model := &value.(^Model)

            imgui.Button(cstr(model^.path) if model^ != nil else "nil")

            if imgui.BeginDragDropTarget() {
                if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Model], {}); payload != nil {
                    data := transmute(^byte)payload.Data
                    path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                    log.debug("Load model from", path)

                    if m := get_asset(&e.engine.asset_manager, path, Model); m != nil {
                        model^ = m
                        modified = true
                    }
                }
                imgui.EndDragDropTarget()
            }
        case typeid_of(Image):
            MIN_IMAGE_SIZE :: vec2{128, 128}
            // imgui
            image := &value.(^Image)

            if image^ == nil {
                imgui.Button("Empty Image", MIN_IMAGE_SIZE)
            } else {
                texture: Texture2D = editor_get_preview_texture(e, image^)
                if texture.type == .CubeMap do break
                aspect := f32(texture.height) / f32(texture.width)
                region := imgui.GetContentRegionAvail()
                region.y = aspect * region.x

                region = linalg.min(region, MIN_IMAGE_SIZE)

                uv0 := vec2{0, 1}
                uv1 := vec2{1, 0}
                imgui.Image(
                    transmute(rawptr)u64(texture.handle), region, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})
            }

            if imgui.BeginDragDropTarget() {
                if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Texture]); payload != nil {
                    data := transmute(^byte)payload.Data
                    path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                    log.debug(path)

                    if asset := get_asset(&e.engine.asset_manager, path, Image); asset != nil {
                        image^ = asset
                        modified = true
                    }
                }
                imgui.EndDragDropTarget()
            }
        case typeid_of(LuaScript):
            script := &value.(^LuaScript)

            imgui.Button(cstr(script^.path) if script^ != nil else "nil")

            if imgui.BeginDragDropTarget() {
                if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Script]); payload != nil {
                    data := transmute(^byte)payload.Data
                    path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                    log.debug(path)

                    if asset := get_asset(&e.engine.asset_manager, path, LuaScript); asset != nil {
                        script^ = asset
                        modified = true
                    }
                }
                imgui.EndDragDropTarget()
            }
        }
        */

    case reflect.is_string(field.type):
        imgui.TextUnformatted(fmt.ctprintf("%v", value.(string)))
    }

    return
}

editor_get_preview_texture :: proc(e: ^Editor, image: ^Image) -> Texture2D {
    if image.id in e.texture_previews {
        return e.texture_previews[image.id]
    }

    spec := TextureSpecification {
        width = image.width,
        height = image.height,
        format = .RGBA8,
        anisotropy = 4,
    }
    e.texture_previews[image.id] = create_texture2d(spec)
    set_texture2d_data(e.texture_previews[image.id], image.data)

    return e.texture_previews[image.id]
}

import "core:intrinsics"

number_to_imgui_scalar :: proc(number: any) -> imgui.DataType {
    switch _ in number {
    case u8:  return .U8
    case u16: return .U16
    case u32: return .U32
    case u64: return .U64
    case i8:  return .S8
    case i16: return .S16
    case i32: return .S32
    case i64: return .S64
    case f32: return .Float
    case f64: return .Double
    case int: return .S64
    case uint: return .U64
    }
    unreachable()
}

imgui_draw_array :: proc(name: string, array: any) {
    if imgui.TreeNodeEx(fmt.ctprintf("%s", name), {.DefaultOpen, .FramePadding}) {

        type := type_info_of(array.id).variant.(reflect.Type_Info_Array)
        // imgui.TextUnformatted(fmt.ctprintf("%v", name))
        it := 0
        for elem in reflect.iterate_array(array, &it) {
            #partial switch elem_type in type.elem.variant {
            case reflect.Type_Info_Integer:
                imgui.InputScalar(
                    fmt.ctprintf("##elem_%v_%v_", name, it),
                    number_to_imgui_scalar(elem),
                    elem.data)
            case reflect.Type_Info_Float:
                imgui.InputScalar(
                    fmt.ctprintf("##elem_%v_%v_", name, it),
                    number_to_imgui_scalar(elem),
                    elem.data)
            }
        }
        imgui.TreePop()
    }
}

imgui_draw_slice :: proc(name: string, slice: any) -> (changed: bool) {
    if imgui.TreeNodeEx(fmt.ctprintf("%s", name), {.DefaultOpen, .FramePadding}) {
        type := type_info_of(slice.id).variant.(reflect.Type_Info_Slice)
        it := 0
        for elem in reflect.iterate_array(slice, &it) {
            #partial switch elem_type in type.elem.variant {
            case reflect.Type_Info_Integer:
                changed = imgui.InputScalar(
                    fmt.ctprintf("##elem_%v_%v_", name, it),
                    number_to_imgui_scalar(elem),
                    elem.data)
            case reflect.Type_Info_Float:
                changed = imgui.InputScalar(
                    fmt.ctprintf("##elem_%v_%v_", name, it),
                    number_to_imgui_scalar(elem),
                    elem.data)
            }
        }
        imgui.TreePop()
    }
    return
}

parse_range_tag :: proc(tag: reflect.Struct_Tag) -> (min: f32, max: f32, ok: bool) {
    range_str: string
    range_str, ok = reflect.struct_tag_lookup(tag, "range")
    if ok {
        limits, _ := strings.split(range_str, ",", allocator = context.temp_allocator)
        if len(limits) == 2 {
            min, ok = strconv.parse_f32(strings.trim_space(limits[0]))
            if !ok {
                help_marker("Failed to parse lower bound of range tag", .Warning)
                return
            }

            max, ok = strconv.parse_f32(strings.trim_space(limits[1]))
            if !ok {
                help_marker("Failed to parse upper bound of range tag", .Warning)
                return
            }
        } else {
            help_marker("Missing upper bound in range tag", .Warning)
        }
    }
    return
}

// TODO(minebill):  This is pretty much a wrapper around a dynamic byte array.
//                  Probably shouldn't exist.
DynamicString :: struct {
    data: [dynamic]byte,
}

delete_ds :: proc(ds: DynamicString) {
    delete(ds.data)
}

make_ds :: proc(s := "", allocator := context.allocator) -> DynamicString {
    data := make([dynamic]byte, len(s) + 1, allocator = allocator)
    if len(s) > 0 {
        copy(data[:len(s)], s[:])
    }
    return {
        data = data,
    }
}

ds_append :: proc(ds: ^DynamicString, s: string) {
    // This works because there is an append_elem_string for [dynamic]u8 overload.
    append(&ds.data, s)
}

ds_resize :: proc(ds: ^DynamicString, size: int) {
    resize(&ds.data, size + 1)
    // ds.data[len(ds.data) - 1] = 0
}

ds_to_string :: proc(ds: DynamicString) -> string {
    return string(ds.data[:len(ds.data) - 1])
}

ds_to_cstring :: proc(ds: DynamicString) -> cstring {
    return strings.unsafe_string_to_cstring(string(ds.data[:]))
}

ds_len :: proc(ds: DynamicString) -> int {
    return len(ds.data)
}

imgui_text :: proc(label: cstring, ds: ^DynamicString, flags : imgui.InputTextFlags = {}, allocator := context.allocator) -> bool {
    assert(.CallbackResize not_in flags)
    flags := flags
    flags += {.CallbackResize}

    UserData :: struct {
        str: ^DynamicString,
        ctx: runtime.Context,
    }

    text_callback :: proc "c" (data: ^imgui.InputTextCallbackData) -> i32 {
        user_data := cast(^UserData)data.UserData
        context = user_data.ctx
        if .CallbackResize in data.EventFlag {
            new_len := int(data.BufTextLen)

            ds_resize(user_data.str, new_len)
            data.Buf = ds_to_cstring(user_data.str^)
            data.BufTextLen = i32(ds_len(user_data.str^))
            data.BufDirty = true
        }
        return 0
    }

    data := UserData {
        str = ds,
        ctx = context,
    }

    c := ds_to_cstring(ds^)
    return imgui.InputText(label, c, uint(ds_len(ds^) + 1), flags, text_callback, &data)
}

HelpMode :: enum {
    Info,
    Warning,
    Error,
}

// Displays a (?) and opens a tooltip when hovered. Useful for inline docs.
help_marker :: proc(message: string, help_mode: HelpMode = .Info) {
    switch help_mode {
    case .Info:
        imgui.PushStyleColorImVec4(.Text, vec4{0.8, 0.8, 0.8, 1})
        imgui.Text("(?)")
    case .Warning:
        imgui.PushStyleColorImVec4(.Text, vec4{1, 1, 0, 1})
        imgui.Text("(?)")
    case .Error:
        imgui.PushStyleColorImVec4(.Text, vec4{1, 0, 0, 1})
        imgui.Text("(!)")
    }

    if imgui.BeginItemTooltip() {
        imgui.PushTextWrapPos(imgui.GetFontSize() * 25.0)
        imgui.TextUnformatted(cstr(message))
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    }

    imgui.PopStyleColor()
}

LogEntry :: struct {
    level: log.Level,
    text: string,
    options: log.Options,
    locations: runtime.Source_Code_Location,
}

CaptureLogger :: struct {
    base_logger: log.Logger,
    log_entries: ^[dynamic]LogEntry,
    arena: mem.Arena,
    allocator: mem.Allocator,
}

// Creates a new CaptureLoggler. A CaptureLogger requires a pointer to a dynamic array, where
// new log entries will be added.
create_capture_logger :: proc(
    log_entries: ^[dynamic]LogEntry,
    base_logger := context.logger,
    base_allocator := context.allocator,
    level: log.Level = .Debug,
    options := log.Options{.Level, .Short_File_Path, .Line, .Procedure},
) -> log.Logger {
    capture_logger := new(CaptureLogger)

    capture_logger^ = {
        base_logger,
        log_entries,
        {}, {},
    }
    // _ = mem.init_arena()
    // capture_logger.allocator = virtual.arena_allocator(&capture_logger.arena)

    return log.Logger {
        capture_logger_proc,
        capture_logger,
        level,
        options,
    }
}

destroy_capture_logger :: proc(logger: log.Logger) {
    free(logger.data)
}

capture_logger_proc :: proc(
    logger_data: rawptr,
    level: log.Level,
    text: string,
    options: log.Options,
    location := #caller_location,
) {
    capture_logger := cast(^CaptureLogger)logger_data

    // Ensure to call the base logger (file, console, etc.)
    capture_logger.base_logger.procedure(capture_logger.base_logger.data, level, text, options, location)

    append(capture_logger.log_entries, LogEntry{level, strings.clone(text), options, location})
}

ContentItemType :: enum {
    Unknown,

    Generic,
    Folder,
    FolderBack,
    Scene,
    Script,
    Model,
    Texture,
    Material,
}

CONTENT_ITEM_TYPES : [ContentItemType]cstring = {
    .Unknown    = "CONTENT_ITEM_UNKNOWN",
    .Generic    = "CONTENT_ITEM_GENERIC",
    .Folder     = "CONTENT_ITEM_FOLDER",
    .FolderBack = "CONTENT_ITEM_FOLDER",
    .Scene      = "CONTENT_ITEM_SCENE",
    .Script     = "CONTENT_ITEM_SCRIPT",
    .Model      = "CONTENT_ITEM_MODEL",
    .Texture    = "CONTENT_ITEM_TEXTURE",
    .Material   = "CONTENT_ITEM_MATERIAL",
}

AssetWindow :: struct {
    asset: AssetHandle,
    opened: bool,
    size: vec2,

    euler_angles: vec3,

    cube_mesh: ^Mesh,
    preview_camera: EditorCamera,
    preview_framebuffer: FrameBuffer,
}

create_asset_window :: proc(asset: AssetHandle) -> (window: AssetWindow) {
    window.asset = asset
    window.opened = true

    spec := FrameBufferSpecification {
        width = 300,
        height = 300,
        samples = 1,
        attachments = attachment_list(.RGBA16F, .DEPTH),
    }
    window.preview_framebuffer = create_framebuffer(spec)

    window.preview_camera = EditorCamera {
        position = vec3{0, 0, 3},
        fov = f32(60.0),
        near_plane = 0.1,
        far_plane = 1000.0,
    }
    window.preview_camera.euler_angles = vec3{25, 0, 0}

    window.cube_mesh = nil
    return
}

asset_window_render :: proc(window: ^AssetWindow) {
    imgui.SetNextWindowSize(vec2{550, 300}, .Appearing)
    if imgui.Begin(fmt.ctprintf("Asset View##%d", window.asset), &window.opened, {.MenuBar}) {
        type := get_asset_type(&EngineInstance.asset_manager, window.asset)
        asset := get_asset(&EngineInstance.asset_manager, window.asset, type)

        if asset != nil {
            metadata := get_asset_metadata(&EngineInstance.asset_manager, window.asset)

            if imgui.BeginMenuBar() {
                if imgui.Button("Save!") {
                    save_asset(&EngineInstance.asset_manager, window.asset)
                }
                imgui.EndMenuBar()
            }

            imgui.SeparatorText(fmt.ctprintf("%v", metadata.path))

            #partial switch metadata.type {
            case .PbrMaterial:
                material := cast(^PbrMaterial)asset
                pbr_material_asset_window(window, material)
            case .Texture2D:
                texture := cast(^Texture2D)asset
                texture2d_asset_window(window, texture)
            }
        }
    }

    imgui.End()
}

pbr_material_asset_window :: proc(window: ^AssetWindow, material: ^PbrMaterial) {
    {
        imgui.BeginChild("material_properties", vec2{250, 0}, {.Border, .ResizeX}, {})

        imgui.PushStyleVarImVec2(.FramePadding, {4, 4})
        if imgui.TreeNodeEx("Properties", {.Framed, .FramePadding, .SpanFullWidth}) {
            imgui.ColorEdit4("Albedo Color", cast(^vec4)&material.block.albedo_color)
            imgui.SliderFloat("Metallic Factor", &material.block.metallic_factor, 0.0, 1.0)
            imgui.SliderFloat("Roughness", &material.block.roughness_factor, 0.0, 1.0)

            imgui.Button("Albedo Texture")
            if imgui.BeginDragDropTarget() {
                if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
                    asset_handle := cast(^AssetHandle)payload.Data

                    material.albedo_texture = asset_handle^
                }

                imgui.EndDragDropTarget()
            }

            imgui.Button("Normal Texture")
            if imgui.BeginDragDropTarget() {
                if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
                    asset_handle := cast(^AssetHandle)payload.Data

                    material.normal_texture = asset_handle^
                }

                imgui.EndDragDropTarget()
            }

            imgui.TreePop()
        }
        imgui.PopStyleVar()

        imgui.EndChild()
    }

    imgui.SameLine()

    preview: {
        imgui.BeginChild("material_preview", {}, {.Border})

        // Render Something
        size := imgui.GetContentRegionAvail()
        if size.x <= 0 || size.y <= 0 || window.cube_mesh == nil {
            imgui.EndChild()
            break preview
        }
        if size != window.size {
            window.size = size
            resize_framebuffer(&window.preview_framebuffer, int(size.x), int(size.y))
        }

        euler := window.euler_angles
        window.preview_camera.rotation = linalg.quaternion_from_euler_angles(
            euler.y * math.RAD_PER_DEG,
            euler.x * math.RAD_PER_DEG,
            euler.z * math.RAD_PER_DEG,
            .YXZ)

        parent := linalg.matrix4_translate(vec3{0, 0, 0}) * linalg.matrix4_from_quaternion(window.preview_camera.rotation) * linalg.matrix4_scale(vec3{1, 1, 1})
        child := parent * linalg.matrix4_translate(window.preview_camera.position) * linalg.matrix4_from_euler_angles_xyz(f32(0), f32(0), f32(0)) * linalg.matrix4_scale(vec3{1, 1, 1})

        position := vec3{child[0, 3], child[1, 3], child[2, 3]}

        quat := linalg.quaternion_look_at(position, vec3{0, 0, 0}, vec3{0, 1, 0})

        window.preview_camera.view       = linalg.matrix4_from_quaternion(quat) * linalg.inverse(linalg.matrix4_translate(position))

        window.preview_camera.projection = linalg.matrix4_perspective_f32(
            math.to_radians(f32(window.preview_camera.fov)),
            f32(size.x) / f32(size.y),
            window.preview_camera.near_plane,
            window.preview_camera.far_plane)

        packet := RenderPacket {
            camera = RenderCamera {
                position = position,
                rotation = quat,
                projection = window.preview_camera.projection,
                view = window.preview_camera.view,
                near = window.preview_camera.near_plane,
                far = window.preview_camera.far_plane,
            },
            size = vec2i{i32(size.x), i32(size.y)},
            clear_color = COLOR_LAVENDER,
        }
        render_material_preview(packet, &window.preview_framebuffer, material, window.cube_mesh, &EditorInstance.renderer, &EditorInstance.preview_cubemap_texture)

        uv0 :: vec2{0, 1}
        uv1 :: vec2{1, 0}
        texture := get_color_attachment(window.preview_framebuffer, 0)
        imgui.Image(transmute(rawptr)u64(texture), size, uv0, uv1)

        EditorInstance.is_asset_window_focused = imgui.IsWindowHovered()

        imgui.EndChild()
    }

    if imgui.BeginDragDropTarget() {
        if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
            asset_handle := cast(^AssetHandle)payload.Data

            window.cube_mesh = get_asset(&EngineInstance.asset_manager, asset_handle^, Mesh)
        }
        imgui.EndDragDropTarget()
    }

    editor := EditorInstance
    if editor.capture_mouse && editor.was_asset_window_focused {
        window.euler_angles.y -= get_mouse_delta().x * 0.25
        window.euler_angles.x -= get_mouse_delta().y * 0.25
        if window.euler_angles.x > 80 {
            window.euler_angles.x = 80
        }
        if window.euler_angles.x < -80 {
            window.euler_angles.x = -80
        }

        // input := get_vector(.D, .A, .W, .S) * 2
        // up_down := get_axis(.Space, .LeftControl) * 2
        // window.preview_camera.position.xz += ( vec4{input.x, 0, -input.y, 0} * linalg.matrix4_from_quaternion(window.preview_camera.rotation)).xz * f32(0.001)
        // window.preview_camera.position.y += up_down * f32(0.001)
    }

    if editor.is_asset_window_focused {
        camera := &window.preview_camera

        if delta := get_mouse_wheel_delta(); delta != 0.0 {
            camera.position.z += delta * 2
        }
    }
}

texture2d_asset_window :: proc(window: ^AssetWindow, texture: ^Texture2D) {
    {
        imgui.BeginChild("texture_properties", vec2{250, 0}, {.Border, .ResizeX}, {})

        imgui.PushStyleVarImVec2(.FramePadding, {4, 4})
        if imgui.TreeNodeEx("Properties", {.Framed, .FramePadding, .SpanFullWidth}) {

            imgui.TreePop()
        }
        imgui.PopStyleVar()

        imgui.EndChild()
    }

    imgui.SameLine()

    preview: {
        imgui.BeginChild("texture_preview", {}, {.Border})

        // Render Something
        size := imgui.GetContentRegionAvail()
        if size.x <= 0 || size.y <= 0 {
            imgui.EndChild()
            break preview
        }
        aspect := f32(texture.spec.height) / f32(texture.spec.width)
        size.y = aspect * size.x

        // size = linalg.min(size, 128)

        @static uv0 := vec2{0, 1}
        @static uv1 := vec2{1, 0}
        @static zoom := f32(1.0)
        ZOOM_SPEED :: 0.04
        @static zoom_speed := f32(ZOOM_SPEED)

        editor := EditorInstance
        if editor.capture_mouse && editor.was_asset_window_focused {
            delta := get_mouse_delta() * 0.0025 * (1.0 / zoom)
            delta.y *= -1

            uv0 -= delta
            uv1 -= delta
        }

        zoom += get_mouse_wheel_delta() * zoom_speed
        zoom = max(zoom, 0.5)
        zoom = min(zoom, 4.0)

        zoom_speed = ZOOM_SPEED * zoom

        texture := texture.handle
        s := size * zoom

        center_uv := (uv0 + uv1) * 0.5
        half_size_uv := (uv1 - uv0) * 0.5
        _uv0 := center_uv - half_size_uv * (1.0 / zoom)
        _uv1 := center_uv + half_size_uv * (1.0 / zoom)
        imgui.Image(transmute(rawptr)u64(texture), size, _uv0, _uv1)

        EditorInstance.is_asset_window_focused = imgui.IsWindowHovered()

        imgui.EndChild()
    }

    if imgui.BeginDragDropTarget() {
        if payload := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); payload != nil {
            asset_handle := cast(^AssetHandle)payload.Data

            window.cube_mesh = get_asset(&EngineInstance.asset_manager, asset_handle^, Mesh)
        }
        imgui.EndDragDropTarget()
    }

    editor := EditorInstance
    if editor.capture_mouse && editor.was_asset_window_focused {
        window.euler_angles.y -= get_mouse_delta().x * 0.025
        window.euler_angles.x -= get_mouse_delta().y * 0.025

        window.euler_angles.x = linalg.min(window.euler_angles.x, 1.0)
        window.euler_angles.x = linalg.max(window.euler_angles.x, 0.0)

        window.euler_angles.y = linalg.min(window.euler_angles.y, 1.0)
        window.euler_angles.y = linalg.max(window.euler_angles.y, 0.0)
    }

    if editor.is_asset_window_focused {
        camera := &window.preview_camera

        if delta := get_mouse_wheel_delta(); delta != 0.0 {
            camera.position.z += delta * 2
        }
    }
}

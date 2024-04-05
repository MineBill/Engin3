package engine
import imgui "packages:odin-imgui"
import "packages:odin-imgui/imgui_impl_glfw"
import "packages:odin-imgui/imgui_impl_opengl3"
import gl "vendor:OpenGL"
import tracy "packages:odin-tracy"
import "core:strings"
import "core:math/linalg"
import "vendor:glfw"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:math"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:strconv"
import "core:os"
import "core:path/filepath"

DEFAULT_EDITOR_CAMERA_POSITION :: vec3{0, 3, 5}
USE_EDITOR :: true

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

    projection, view: mat4,
}

EditorFont :: enum {
    Light,
    Normal,
    Bold,
}

Editor :: struct {
    engine: ^Engine,
    state: EditorState,
    camera: EditorCamera,

    entity_selection: map[UUID]bool,
    selected_entity: Maybe(Handle),

    viewport_size: vec2,

    capture_mouse:   bool,
    is_viewport_focused: bool,
    viewport_position: vec2,

    log_entries: [dynamic]LogEntry,
    logger: log.Logger,

    force_show_fields: bool,
    show_asset_manager: bool,

    allocator: mem.Allocator,

    content_browser: ContentBrowser,

    renderer: WorldRenderer,
    editor_world: World,
    runtime_world: World,
    icons: [EditorIcon]Texture2D,
    fonts: [EditorFont]^imgui.Font,

    texture_previews: map[UUID]Texture2D,

    outline_frame_buffer: FrameBuffer,

    outline_shader: Shader,
    grid_shader: Shader,

    editor_va: RenderHandle,

    scripting_engine: ScriptingEngine,

    style: EditorStyle,
}

editor_init :: proc(e: ^Editor, engine: ^Engine) {
    tracy.ZoneN("Editor Init")
    e.engine = engine
    e.state = .Edit
    // TODO(minebill):  Save the editor camera for each scene in a cache somewhere
    //                  so that we can open the editor in that location/rotation next time.
    e.camera = EditorCamera {
        position = DEFAULT_EDITOR_CAMERA_POSITION,
        fov = f32(60.0),
    }

    gl.CreateVertexArrays(1, &e.editor_va)

    e.logger = create_capture_logger(&e.log_entries)
    context.logger = e.logger

    e.content_browser.root_dir = filepath.join({os.get_current_directory(allocator = context.temp_allocator), "assets"})
    cb_navigate_to_folder(&e.content_browser, e.content_browser.root_dir)

    e.content_browser.textures[.Unknown] = load_texture_from_file("assets/textures/ui/file.png")
    e.content_browser.textures[.Folder] = load_texture_from_file("assets/textures/ui/folder.png")
    e.content_browser.textures[.FolderBack] = load_texture_from_file("assets/textures/ui/folder_back.png")
    e.content_browser.textures[.Scene] = load_texture_from_file("assets/textures/ui/world.png")
    e.content_browser.textures[.Script] = load_texture_from_file("assets/editor/icons/lua.png")
    e.content_browser.textures[.Model] = e.content_browser.textures[.Unknown]

    e.icons[.PlayButton] = load_texture_from_file("assets/editor/icons/play_button.png")
    e.icons[.PauseButton] = load_texture_from_file("assets/editor/icons/pause_button.png")
    e.icons[.StopButton] = load_texture_from_file("assets/editor/icons/stop_button.png")

    ok: bool
    e.outline_shader, ok = shader_load_from_file(
        "assets/shaders/screen.vert.glsl",
        "assets/shaders/outline.frag.glsl",
    )
    assert(ok)
    e.grid_shader, ok = shader_load_from_file(
        "assets/shaders/grid.vert.glsl",
        "assets/shaders/grid.frag.glsl",
    )
    assert(ok)

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

    LIGHT_FONT :: #load("../assets/fonts/inter/Inter-Light.ttf")
    NORMAL_FONT :: #load("../assets/fonts/inter/Inter-Regular.ttf")
    BOLD_FONT :: #load("../assets/fonts/inter/Inter-Bold.ttf")
    e.fonts[.Light] = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(LIGHT_FONT), i32(len(LIGHT_FONT)), 14)
    e.fonts[.Normal] = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(NORMAL_FONT), i32(len(NORMAL_FONT)), 16)
    e.fonts[.Bold] = imgui.FontAtlas_AddFontFromMemoryTTF(io.Fonts, raw_data(BOLD_FONT), i32(len(BOLD_FONT)), 16)

    io.FontDefault = e.fonts[.Normal]

    world_renderer_init(&e.renderer)

    e.scripting_engine = create_scripting_engine()
}

editor_deinit :: proc(e: ^Editor) {
    // TODO(minebill):  This is to silence the tracking allocator. Figure out a better
    //                  way of clearing all the entries, possible by using a small arena allocator,
    for entry in e.log_entries {
        delete(entry.text)
    }
    delete(e.log_entries)
    destroy_capture_logger(e.logger)

    delete(e.content_browser.root_dir)
    delete(e.content_browser.current_dir)
    delete(e.content_browser.items)
}

editor_update :: proc(e: ^Editor, _delta: f64) {
    tracy.ZoneN("Editor Update")
    @(static) show_imgui_demo := false
    @(static) CAMERA_SPEED := f32(2)
    delta := f32(_delta)

    for event in g_event_ctx.events {
        #partial switch ev in event {
        case WindowResizedEvent:
            gl.Viewport(0, 0, i32(ev.size.x), i32(ev.size.y))
        case MouseButtonEvent:
            if ev.button == .right {
                if ev.state == .pressed && e.is_viewport_focused {
                    e.capture_mouse = true
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
                    color := read_pixel(e.renderer.world_frame_buffer, int(mouse.x), int(e.viewport_size.y) - int(mouse.y), 1)

                    id := color[0]
                    handle := e.engine.world.local_id_to_uuid[int(id)]
                    select_entity(e, handle, !is_key_pressed(.LeftShift))
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
            if e.capture_mouse {
                e.camera.euler_angles.xy += get_mouse_delta().yx * 25 * delta
                e.camera.euler_angles.x = math.clamp(e.camera.euler_angles.x, -80, 80)
            }

            if e.capture_mouse {
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

            // e.engine.camera_position   = e.camera.position
            e.camera.view              = linalg.matrix4_from_quaternion(e.camera.rotation) * linalg.inverse(linalg.matrix4_translate(e.camera.position))
            // e.engine.camera_view       = e.camera.view
            e.camera.projection        = linalg.matrix4_perspective_f32(math.to_radians(f32(e.camera.fov)), f32(e.engine.width) / f32(e.engine.height), 0.1, 200.0)
            // e.engine.camera_rotation   = e.camera.rotation

            editor_render_scene(e)
        case .Play:
            runtime_render_scene(e)
        }
    }

    @(static) show_depth_buffer := false
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

            imgui.EndMenu()
        }

        imgui.Checkbox("Show Depth Buffer", &show_depth_buffer)
    }
    imgui.EndMainMenuBar()

    if show_imgui_demo {
        imgui.ShowDemoWindow(&show_imgui_demo)
    }

    imgui.DockSpaceOverViewport(imgui.GetMainViewport(), {.PassthruCentralNode})

    if show_depth_buffer && imgui.Begin("Depth Buffer", &show_depth_buffer, {}) {
        size := imgui.GetContentRegionAvail()

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}
        imgui.Image(transmute(rawptr)u64(get_depth_attachment(e.renderer.depth_frame_buffer)), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})
        imgui.End()
    }

    world_update(&e.engine.world, _delta, e.state == .Play)

    editor_env_panel(e)
    editor_entidor(e)
    editor_viewport(e)
    editor_gameobjects(e)
    editor_log_window(e)
    editor_content_browser(e)
    editor_ui_toolstrip(e)

    editor_asset_manager(e)

    reset_draw_stats()
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
        },
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
            },
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
    if imgui.Begin("Environment", nil, {}) {
        @(static) clear_color: vec3
        if imgui.ColorEdit3("Clear Color", &clear_color, {}) {
            gl.ClearColor(expand_values(clear_color), 1.0)
        }

        @(static) ambient_color := vec3{0.1, 0.1, 0.1}
        if imgui.ColorEdit4("Ambent Color", &e.engine.scene_data.ambient_color, {}) {
            gl.NamedBufferSubData(e.engine.scene_data.ubo, int(offset_of(Scene_Data, ambient_color)), size_of(vec4), &e.engine.scene_data.ambient_color)
        }
    }
    imgui.End()
}

MSAA_Level :: enum {
    x1 = 1,
    x2 = 2,
    x4 = 4,
    x8 = 8,
}
g_msaa_level: MSAA_Level = .x2

editor_viewport :: proc(e: ^Editor) {
    imgui.PushStyleVarImVec2(.WindowPadding, vec2{0, 0})
    if imgui.Begin("Viewport", nil, {.MenuBar}) {
        e.is_viewport_focused = imgui.IsWindowHovered({})
        if imgui.BeginMenuBar() {
            if imgui_enum_combo_id("MSAA Level", g_msaa_level, type_info_of(MSAA_Level)) {

                width, height := int(e.viewport_size.x), int(e.viewport_size.y)
                engine_resize(e.engine, width, height)
                world_renderer_resize(&e.renderer, width, height)
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

        texture_handle := get_color_attachment(e.renderer.final_frame_buffer, 0)
        imgui.Image(rawptr(uintptr(texture_handle)), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})

        if imgui.BeginDragDropTarget() {
            if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Scene], {}); payload != nil {
                data := transmute(^byte)payload.Data
                path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                deserialize_world(&e.engine.world, path)
            }

            if payload := imgui.AcceptDragDropPayload(CONTENT_ITEM_TYPES[.Model], {}); payload != nil {
                data := transmute(^byte)payload.Data
                path := strings.string_from_ptr(data, int(payload.DataSize / size_of(byte)))

                log.debug("Load model from", path)

                if model := get_asset(&e.engine.asset_manager, path, Model); model != nil {
                    entity := new_object(&e.engine.world, "New Model")
                    mesh_component := get_or_add_component(&e.engine.world, entity, MeshRenderer)
                    mesh_renderer_set_model(mesh_component, model)
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
                imgui.TextDisabled(fmt.ctprintf("UUID: %v", go.id))
                imgui.TextDisabled(fmt.ctprintf("Local ID: %v", go.local_id))
                imgui.PopFont()

                imgui_flags_box("Flags", &go.flags)

                imgui.SameLine()
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
                        imgui.TextUnformatted("Position")
                        modified |= imgui_vec3("position", &go.transform.local_position)

                        imgui.TextUnformatted("Rotation")
                        modified |= imgui_vec3("rotation", &go.transform.local_rotation)

                        imgui.TextUnformatted("Scale")
                        modified |= imgui_vec3("scale", &go.transform.local_scale)
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

ContentBrowser :: struct {
    root_dir: string,
    current_dir: string,

    items: []os.File_Info,

    textures: [ContentItemType]Texture2D,

    renaming_item: Maybe(int),
}

cb_navigate_to_folder :: proc(cb: ^ContentBrowser, folder: string) {
    cb.renaming_item = nil
    os.file_info_slice_delete(cb.items[:])

    // clear(&cb.items)
    handle, err := os.open(folder)
    defer os.close(handle)
    files, err2 := os.read_dir(handle, 100)

    cb.items = files
    slice.sort_by(cb.items, proc(i, j: os.File_Info) -> bool {
        return int(i.is_dir) > int(j.is_dir)
    })
    cb.current_dir = folder
}

editor_content_browser :: proc(e: ^Editor) {
    opened := imgui.Begin("Content Browser", nil, {})
    {
        imgui.BeginChild("folder side view", vec2{150, 0}, {.Border, .ResizeX}, {})
        imgui.EndChild()
    }
    imgui.SameLine()
    {
        imgui.BeginChild("content view root", vec2{0, 0}, {.Border}, {})
        relative, _ := filepath.rel(e.content_browser.root_dir, e.content_browser.current_dir, allocator = context.temp_allocator)
        relative, _ = filepath.to_slash(relative, allocator = context.temp_allocator)
        imgui.TextUnformatted(fmt.ctprintf("Project://%v", relative))

        imgui.SameLine(imgui.GetContentRegionAvail().x - 80)
        if imgui.Button("Options") {
            imgui.OpenPopup("ContentBrowserSettings", {})
        }

        imgui.SameLine()

        if imgui.Button("New") {
            imgui.OpenPopup("ContentBrowserNewItem", {})
        }

        @(static) padding := i32(8)
        @(static) thumbnail_size := i32(64)

        imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
        if imgui.BeginPopup("ContentBrowserSettings", {}) {
            imgui.DragInt("Padding", &padding)
            imgui.DragInt("Thumbnail Size", &thumbnail_size)
            imgui.EndPopup()
        }

        if imgui.BeginPopup("ContentBrowserNewItem") {
            if imgui.BeginMenu("Create") {
                if imgui.MenuItem("New World") {
                    world: World
                    create_world(&world, "New World")
                    path := filepath.join({e.content_browser.current_dir, "New World.world"})
                    defer delete(path)
                    serialize_world(world, path)
                }
                imgui.EndMenu()
            }
            imgui.EndPopup()
        }
        imgui.PopStyleVar()

        imgui.BeginChild("content view", vec2{0, 0}, {.FrameStyle} ,{})

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

        for i in 0..<len(e.content_browser.items) {
            item := e.content_browser.items[i]

            texture: ContentItemType = .Unknown
            switch {
            case item.is_dir:
                texture = .Folder
            case:
                switch filepath.ext(item.name) {
                case ".scen3": fallthrough
                case ".world":
                    texture = .Scene
                case ".lua":
                    texture = .Script
                case ".glb":
                    texture = .Model
                }
            }
            imgui.ImageButton(cstr(item.name), transmute(rawptr)u64(e.content_browser.textures[texture].handle), size)

            if imgui.BeginDragDropSource({}) {
                path := item.fullpath

                imgui.SetDragDropPayload(CONTENT_ITEM_TYPES[texture], raw_data(path), len(path) * size_of(byte), .Once)

                imgui.TextUnformatted(cstr(item.name))

                imgui.EndDragDropSource()
            }

            if imgui.IsItemHovered({}) && imgui.IsMouseDoubleClicked(.Left) {
                if item.is_dir {
                    cb_navigate_to_folder(&e.content_browser, strings.clone(item.fullpath))
                }
            }

            open_popup := false
            imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
            if imgui.BeginPopupContextItem() {
                if imgui.MenuItem("Delete") {
                    open_popup = true
                } 
                if imgui.MenuItem("Rename") {
                    e.content_browser.renaming_item = i
                }
                imgui.EndPopup()
            }
            imgui.PopStyleVar()

            if open_popup {
                imgui.OpenPopup("ConfirmDeletion")
            }

            center := imgui.Viewport_GetCenter(imgui.GetMainViewport())
            imgui.SetNextWindowPos(center, .Appearing, vec2{0.5, 0.5})
            imgui.PushStyleVarImVec2(.WindowPadding, e.style.popup_padding)
            if imgui.BeginPopupModal("ConfirmDeletion", nil, {.AlwaysAutoResize}) {
                if imgui.Button("Yes") {
                    imgui.CloseCurrentPopup()
                }
                if imgui.Button("No") {
                    imgui.CloseCurrentPopup()
                }
                imgui.EndPopup()
            }
            imgui.PopStyleVar()

            if item_index, ok := e.content_browser.renaming_item.?; ok && item_index == i {
                @(static) buffer: [256]byte

                // imgui.SetKeyboardFocusHere(0)
                input: if imgui.InputText("##rename_label", cstring(&buffer[0]), size_of(buffer), {.EnterReturnsTrue, .EscapeClearsAll}) {
                    new_name := string(buffer[:])
                    if new_name == "" do break input

                    dir := filepath.dir(item.fullpath, context.temp_allocator)
                    new_path := filepath.join({dir, new_name}, context.temp_allocator)

                    err := os.rename(item.fullpath, new_path)
                    if err != 0 {
                        log.errorf("Failed to rename content item: '%v'", err)
                    }

                    e.content_browser.renaming_item = nil
                    cb_navigate_to_folder(&e.content_browser, e.content_browser.current_dir)

                    buffer = {}
                }

                if imgui.IsItemActive() {
                    log.debug("FUCK")
                } else {
                    log.debug("NO FUCK")
                }
            } else {
                imgui.TextWrapped(cstr(item.name))
            }

            imgui.NextColumn()
        }
        imgui.PopStyleColor()



        imgui.EndChild()
        imgui.EndChild()

    }

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
    entity_create_menu :: proc(e: ^Editor, parent: Handle) {
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
    tree_node_gameobject :: proc(e: ^Editor, handle: Handle) {
        flags := imgui.TreeNodeFlags{}
        flags += {.SpanAvailWidth, .FramePadding, .OpenOnDoubleClick, .OpenOnArrow}
        children := &get_object(&e.engine.world, handle).children

        slice.sort_by_key(children[:], proc(a: Handle) -> Handle {
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
                id := (cast(^UUID)payload.Data)^
                reparent_entity(&e.engine.world, id, go.id)
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
                id := (cast(^UUID)payload.Data)^
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
            flags := imgui.TableFlags_Borders
            if imgui.BeginTable("asset_manager_entries", 1, flags) {
                for path, asset in g_engine.asset_manager.assets {
                    imgui.TextWrapped(fmt.ctprintf("%v", path))
                    imgui.TextWrapped(fmt.ctprintf("%v", asset.id))

                    imgui.TableNextColumn()
                }
                imgui.EndTable()
            }
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

select_entity :: proc(e: ^Editor, entity: Handle, should_reset_selection := false) {
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
        script := cast(^ScriptComponent)component

        if script.script != nil && script.script.properties.name != "" {
            name = fmt.ctprintf("Script - %s", script.script.properties.name)
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
            handle, ok := e.selected_entity.(Handle)
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

imgui_vec3 :: proc(id: cstring, v: ^vec3) -> (modified: bool) {
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
    case typeid_of(Handle) == field.type.id:
        handle := &value.(Handle)
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

    case reflect.is_boolean(field.type):
        b := &value.(bool)
        modified = imgui.Checkbox(cstr(field.name), b)

    case reflect.is_float(field.type):
        fallthrough
    case reflect.is_integer(field.type):

        range_str, ok := reflect.struct_tag_lookup(field.tag, "range")
        if ok {
            limits, _ := strings.split(range_str, ",", allocator = context.temp_allocator)
            if len(limits) == 2 {
                min, min_ok := strconv.parse_f32(strings.trim_space(limits[0]))
                if !min_ok {
                    help_marker("Failed to parse lower bound of range tag", .Warning)
                    return
                }

                max, max_ok := strconv.parse_f32(strings.trim_space(limits[1]))
                if !max_ok {
                    help_marker("Failed to parse upper bound of range tag", .Warning)
                    return
                }

                modified = imgui.SliderScalar(
                    cstr(field.name),
                    number_to_imgui_scalar(value),
                    value.data,
                    &min, &max)
            } else {
                help_marker("Missing upper bound in range tag", .Warning)
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

    case reflect.is_string(field.type):
        imgui.TextUnformatted(fmt.ctprintf("%v", value.(string)))
    }

    return
}

editor_get_preview_texture :: proc(e: ^Editor, image: ^Image) -> Texture2D {
    if image.id in e.texture_previews {
        return e.texture_previews[image.id]
    }

    params := DEFAULT_TEXTURE_PARAMS
    params.format = gl.RGBA8
    e.texture_previews[image.id] = create_texture(image.width, image.height, params)
    set_texture_data(e.texture_previews[image.id], image.data)

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

// TODO(minebill):  This is pretty much a wrapper around a dynamic byte array.
//                  Probably shouldn't exist.
DynamicString :: struct {
    data: [dynamic]byte,
    allocator: mem.Allocator,
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
        allocator = allocator,
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
        allocator: mem.Allocator,
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
        allocator = allocator,
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
        imgui.Text("(?) Warning")
    case .Error:
        imgui.PushStyleColorImVec4(.Text, vec4{1, 0, 0, 1})
        imgui.Text("(!) Error")
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
    Folder,
    FolderBack,
    Scene,
    Script,
    Model,
    Texture,
}

CONTENT_ITEM_TYPES : [ContentItemType]cstring = {
    .Unknown    = "CONTENT_ITEM_UNKNOWN",
    .Folder     = "CONTENT_ITEM_FOLDER",
    .FolderBack = "CONTENT_ITEM_FOLDER",
    .Scene      = "CONTENT_ITEM_SCENE",
    .Script     = "CONTENT_ITEM_SCRIPT",
    .Model      = "CONTENT_ITEM_MODEL",
    .Texture    = "CONTENT_ITEM_TEXTURE",
}

// snake_case_to_pascal :: proc(s: string, allocator := context.temp_allocator) -> string {
//     strings.split
// }

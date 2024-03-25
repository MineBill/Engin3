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

USE_EDITOR :: true

POPUP_PADDING :: vec2{6, 6}

Editor :: struct {
    engine: ^Engine,
    selected_entity: Maybe(Handle),

    viewport_size: vec2,

    capture_mouse:   bool,
    is_viewport_focused: bool,
    viewport_position: vec2,

    log_entries: [dynamic]LogEntry,
    logger: log.Logger,

    force_show_fields: bool,

    allocator: mem.Allocator,
    test_string: DynamicString,
}

editor_init :: proc(e: ^Editor, engine: ^Engine) {
    tracy.ZoneN("Editor Init")
    e.engine = engine

    e.logger = create_capture_logger(&e.log_entries)
    backing := make([]byte, 1)
    backing[len(backing) - 1] = 0
    e.test_string = make_ds()
}

editor_deinit :: proc(e: ^Editor) {
    // TODO(minebill):  This is to silence the tracking allocator. Figure out a better
    //                  way of clearing all the entries, possible by using a small arena allocator,
    for entry in e.log_entries {
        delete(entry.text)
    }
    delete(e.log_entries)
    destroy_capture_logger(e.logger)
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
                if ev.state == .pressed && e.is_viewport_focused {
                    mouse := g_event_ctx.mouse + g_event_ctx.window_position - e.viewport_position
                    color := read_pixel(e.engine.viewport_fb, int(mouse.x), int(e.viewport_size.y) - int(mouse.y), 1)

                    id := color[0]
                    // if id != 0 {
                        select_entity(e, Handle(id))
                    // }
                }
            }
        case MouseWheelEvent:
            CAMERA_SPEED += ev.delta.y
            CAMERA_SPEED = math.clamp(CAMERA_SPEED, 1, 100)
        }
    }

    {
        d := &e.engine.dbg_draw
        dbg_draw_line(d, vec3{0, 0, 0}, vec3{0, 3, 0}, color = color_hex(0x86cd82FF))
        dbg_draw_line(d, vec3{0, 3, 0}, vec3{1, 3, 0}, color = color_hex(0x86cd82FF))
        dbg_draw_line(d, vec3{1, 3, 0}, vec3{0, 2, 1}, color = color_hex(0x86cd82FF))

        dbg_draw_cube(d, vec3{0, 0.5, 0}, vec3{1, 1, 1}, color = COLOR_BLUE)

        engine := e.engine
        if e.capture_mouse {
            engine.camera.euler_angles.xy += get_mouse_delta().yx * 25 * delta
            engine.camera.euler_angles.x = math.clamp(engine.camera.euler_angles.x, -80, 80)
        }

        if is_key_just_pressed(.escape) {
            engine.quit = true
            return
        }

        if is_key_just_pressed(.p) {
            i := 0
            for entity in entities_iter(&i, PointLight) {
                log.debugf("%v\n", entity)
            }
        }

        if e.capture_mouse {
            input := get_vector(.d, .a, .w, .s) * CAMERA_SPEED
            up_down := get_axis(.space, .left_control) * CAMERA_SPEED
            e.engine.camera.position.xz += ( vec4{input.x, 0, -input.y, 0} * linalg.matrix4_from_quaternion(e.engine.camera.rotation)).xz * f32(delta)
            e.engine.camera.position.y += up_down * f32(delta)
        }

        euler := e.engine.camera.euler_angles
        e.engine.camera.rotation = linalg.quaternion_from_euler_angles(
            euler.x * math.RAD_PER_DEG,
            euler.y * math.RAD_PER_DEG,
            euler.z * math.RAD_PER_DEG,
            .XYZ)
    }

    @(static) show_depth_buffer := false
    if imgui.BeginMainMenuBar() {
        imgui.Checkbox("Show Demo", &show_imgui_demo)

        if imgui.BeginMenu("Options") {
            @(static) top_most := false
            if imgui.MenuItemEx("Top Most", nil, top_most, true) {
                top_most = !top_most
                glfw.SetWindowAttrib(e.engine.window, glfw.FLOATING, i32(top_most))
            }
            imgui.EndMenu()
        }

        if imgui.BeginMenu("Preferences") {
            if imgui.MenuItem("Save Layout") {
                imgui.SaveIniSettingsToDisk("editor_layout.ini")
            }
            imgui.EndMenu()
        }

        imgui.Checkbox("Show Depth Buffer", &show_depth_buffer)
    }
    imgui.EndMainMenuBar()

    if show_imgui_demo {
        imgui.ShowDemoWindow(&show_imgui_demo)
    }

    imgui.DockSpaceOverViewportEx(imgui.GetMainViewport(), {.PassthruCentralNode}, nil)

    if show_depth_buffer && imgui.Begin("Depth Buffer", &show_depth_buffer, {}) {
        size := imgui.GetContentRegionAvail()

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}
        imgui.ImageEx(transmute(rawptr)u64(get_depth_attachment(e.engine.depth_fb)), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})
        imgui.End()
    }

    editor_env_panel(e)
    editor_scene_tree(e)
    editor_entidor(e)
    editor_viewport(e)
    editor_gameobjects(e)
    editor_log_window(e)
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

        if imgui_text("String", &e.test_string) {
            s := ds_to_string(e.test_string)
            log.debugf("'%v' len: %v", s, len(s))
        }
    }
    imgui.End()
}

editor_scene_tree :: proc(e: ^Editor) {
    // if imgui.Begin("Scene", nil, {}) {
    //     // @(static) test: string
    //     // imgui_text("Test", &test)

    //     @(static) selection: EntityType
    //     // imgui_union_combo("Type", &selection)
    //     imgui_enum_combo("Type", &selection)
    //     if imgui.Button("Add Entity") {
    //         // v := reflect.get_union_variant(selection)
    //         // add_entity(v)
    //         add_entity("New Entity", selection)
    //         // a := add_entity("Test", Test_Entity)
    //         // get_entity(a, Test_Entity).array_of_stuff = [5]i32 {1, 1, 2, 3, 1}
    //     }

    //     imgui.Separator()

    //     for &en, i in g_entities[:g_entity_count] {
    //         en := cast(^Entity)&en

    //         if len(en.name.s) == 0 do continue
    //         flags := imgui.TreeNodeFlags{}
    //         flags += {.SpanAvailWidth, .FramePadding, .OpenOnArrow}
    //         if e.selected_entity == i {
    //             flags += {.Selected}
    //         }

    //         opened := imgui.TreeNodeEx(cstr(en.name.s), flags)

    //         if imgui.IsItemClicked() {
    //             e.selected_entity = i
    //         }

    //         if opened {
    //             imgui.TreePop()
    //         }
    //     }

    //     imgui.PushID("##$$")
    //     if imgui.BeginPopupContextItem() {

    //         imgui.Text("hmm")
    //         imgui.EndPopup()
    //     }
    //     imgui.PopID()
    // }
    // imgui.End()
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
        }

        // is this the correct place?
        gl.Viewport(0, 0, i32(size.x), i32(size.y))

        uv0 := vec2{0, 1}
        uv1 := vec2{1, 0}
        imgui.ImageEx(transmute(rawptr)u64(get_color_attachment(e.engine.scene_fb, 0)), size, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})

        flags := imgui.WindowFlags_NoDecoration
        flags += imgui.WindowFlags_NoNav
        flags += {.NoDocking, .NoMove, .AlwaysAutoResize, .NoSavedSettings, .NoFocusOnAppearing}
        offset := imgui.GetItemRectMin()
        imgui.SetNextWindowPos(offset + vec2{20, 20}, .Always)

        imgui.SetNextWindowBgAlpha(0.35)

        imgui.PushStyleVarImVec2(.WindowPadding, vec2{10, 10})
        if imgui.Begin("Render Stats", nil, flags) {
            imgui.TextUnformatted(fmt.ctprintf("MSAA Level: %v", g_msaa_level))
            imgui.TextUnformatted(fmt.ctprintf("Viewport Size: %v", e.viewport_size))
            imgui.TextUnformatted(fmt.ctprintf("Viewport Position: %v", e.viewport_position))
            global_mouse := g_event_ctx.mouse + g_event_ctx.window_position
            imgui.TextUnformatted(fmt.ctprintf("Mouse Position(global): %v", global_mouse))
            imgui.TextUnformatted(fmt.ctprintf("Item Rect Min: %v", global_mouse - e.viewport_position))
            imgui.End()
        }
        imgui.PopStyleVar()
    }
    imgui.End()
    imgui.PopStyleVar()
}

editor_entidor :: proc(e: ^Editor) {
    window: if imgui.Begin("Properties", nil, {}) {
        // go := get_gameobject(&e.engine.world, e.selected_entity)
        selected_handle, ok := e.selected_entity.(Handle)
        if !ok {
            imgui.TextUnformatted("No entity selected")
            break window
        }
        go := get_object(&e.engine.world, selected_handle)
        if go == nil {
            // Entity selection is invalide, reset it
            e.selected_entity = nil
            break window
        }

        // imgui.AlignTextToFramePadding()
        // imgui.TextUnformatted(ds_to_cstring(go.name))
        imgui_text("Name", &go.name, {})

        imgui_flags_box("Flags", &go.flags)

        imgui.SameLine()
        imgui.Checkbox("Enabled", &go.enabled)

        imgui.Separator()

        // help_marker("The Transfrom component is a special component that is included by default" + 
        //     " in every gameobject and as such, it has special drawing code.")
        if imgui.CollapsingHeader("Transform", {.Framed, .DefaultOpen}) {
            imgui.Indent()
            if imgui.BeginChild("Transformm", vec2{}, {.AutoResizeY}, {}) {
                // TOOD(minebill):  Add some kind of 'debug' view to view global position as well?
                imgui.TextUnformatted("Position")
                imgui_vec3("position", &go.transform.local_position)

                imgui.TextUnformatted("Rotation")
                imgui_vec3("rotation", &go.transform.local_rotation)

                imgui.TextUnformatted("Scale")
                imgui_vec3("scale", &go.transform.local_scale)
            }
            imgui.EndChild()
            imgui.Unindent()
        }

        imgui.SeparatorText("Components")

        for id, component in go.components {
            draw_component(e, id, component)
        }

        imgui.Separator()

        if centered_button("Add Component") {
            imgui.OpenPopup("component_popup", {})
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

        imgui.PushStyleVarImVec2(.WindowPadding, POPUP_PADDING)
        if imgui.BeginPopup("component_popup", {}) {
            imgui.SeparatorText("Components")

            // NOTE(minebill):  It seems like the menu items are not always ordered?
            //                  It's annoying.
            for category in COMPONENT_CATEGORIES {
                paths, _ := strings.split(category.name, "/", allocator = context.temp_allocator)

                level := len(paths) - 1
                draw_submenu_or_component_selectable(e, paths, level, category.id)
            }

            imgui.EndPopup()
        }
        imgui.PopStyleVar()
    }

    imgui.End()
}

editor_log_window :: proc(e: ^Editor) {
    if imgui.Begin("Log", nil, {}) {
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

        if imgui.BeginChild("scrolling_region", vec2{0, 0}, {.FrameStyle}, {.HorizontalScrollbar}) {
            width := imgui.GetContentRegionAvail().x
            for entry, i in e.log_entries {
                if !strings.contains(entry.text, filter) {
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
                imgui.PopStyleVarEx(2)
                imgui.PopID()

                if auto_scroll && imgui.GetScrollY() >= imgui.GetScrollMaxY() {
                    imgui.SetScrollHereY(1.0)
                }
            }
            imgui.EndChild()
        }
        imgui.End()
    }
}

editor_gameobjects :: proc(e: ^Editor) {
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

        if e.selected_entity == handle {
            flags += {.Selected}
        }

        imgui.PushIDInt(i32(handle))
        opened := imgui.TreeNodeEx(ds_to_cstring(go.name), flags)

        // NOTE(minebill): The context menu needs to be created before drawing the children tree nodes
        imgui.PushStyleVarImVec2(.WindowPadding, POPUP_PADDING)
        if imgui.BeginPopupContextItem() {
            if imgui.BeginMenu("Create") {
                if imgui.MenuItem("New empty object") {
                    new_object(&e.engine.world, parent = handle)
                }

                imgui.EndMenu()
            }
            if imgui.MenuItem(fmt.ctprintf("Destroy '%v'", ds_to_string(go.name))) {
                delete_object(&e.engine.world, handle)
            }
            imgui.EndPopup()
        }
        imgui.PopStyleVar()

        imgui.PopID()

        if imgui.IsItemClicked() {
            select_entity(e, handle)
        }

        if opened {
            for child in children {
                tree_node_gameobject(e, child)
            }
            imgui.TreePop()
        }

    }

    if imgui.Begin("Game Objects", nil, {}) {
        imgui.Separator()

        go := e.engine.world.root

        children := &get_object(&e.engine.world, go).children

        if imgui.BeginPopupContextWindow() {
            if imgui.Selectable("New Object") {
                new_object(&e.engine.world)
            }
            if imgui.Selectable("New Point Light") {
                go := new_object(&e.engine.world, "Point Light")
                add_component(&e.engine.world, go, PointLightComponent)
            }
            imgui.EndPopup()
        }
        for child in children {
            tree_node_gameobject(e, child)
        }

        if len(children) == 0 {
            imgui.TextUnformatted("No game objects. Right click to create a new one.")
        }
    }
    imgui.End()
}

select_entity :: proc(e: ^Editor, entity: Handle) {
    selected_handle, ok := e.selected_entity.?

    if ok {
        get_object(&e.engine.world, selected_handle).flags -= {.Outlined}
    }

    e.selected_entity = nil
    if entity != 0 {
        e.selected_entity = entity
        get_object(&e.engine.world, entity).flags += {.Outlined}
    }
}

draw_component :: proc(e: ^Editor, id: typeid, component: ^Component) {
    info := type_info_of(id).variant.(reflect.Type_Info_Named)
    name := cstr(COMPONENT_NAMES[id]) if id in COMPONENT_NAMES else cstr(info.name)
    opened := imgui.CollapsingHeader(name, {.AllowOverlap})

    // ImGui::SameLine(ImGui::GetWindowContentRegionWidth() - ImGui::CalcTextSize("(?)").x);
    width := imgui.GetWindowContentRegionMax().x - imgui.GetWindowContentRegionMin().x
    imgui.SameLineEx(width + imgui.CalcTextSize(name).x, 0)
    imgui.Checkbox("Enabled", &component.enabled)

    imgui.PushStyleVarImVec2(.WindowPadding, POPUP_PADDING)
    if imgui.BeginPopupContextItem() {
        if imgui.Selectable("Copy Component") {
            // TODO
        }

        if imgui.Selectable("Remove Component") {
            handle, ok := e.selected_entity.(Handle)
            if ok {
                remove_component(&e.engine.world, handle, id)
            }
        }
        imgui.EndPopup()
    }
    imgui.PopStyleVar()

    if opened {
        imgui_draw_component(e, any{component, id})
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

                if imgui.SelectableEx(
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
            // value := E(field.value)
            // if imgui.SelectableEx(
            //     cstr(field.name),
            //     value == selection^,
            //     {}, vec2{}) {
            //     selection^ = value
            //     ret = true
            //     break loop
            // }
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
            if imgui.SelectableEx(
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

imgui_vec3 :: proc(id: cstring, v: ^vec3) {
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
    imgui.DragFloatEx("##x", &v.x, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColorEx(2)

    imgui.SameLine()

    imgui.PushStyleColorImVec4(.Text, Y_COLOR)
    imgui.TextUnformatted("Y")
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.SetNextItemWidth(width)
    imgui.PushStyleColorImVec4(.FrameBg, Y_COLOR)
    imgui.PushStyleColorImVec4(.FrameBgHovered, Y_COLOR_HOVER)
    imgui.DragFloatEx("##y", &v.y, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColorEx(2)

    imgui.SameLine()

    imgui.PushStyleColorImVec4(.Text, Z_COLOR)
    imgui.TextUnformatted("Z")
    imgui.PopStyleColor()

    imgui.SameLine()
    // imgui.PushItemWidth()
    imgui.SetNextItemWidth(width)
    imgui.PushStyleColorImVec4(.FrameBg, Z_COLOR)
    imgui.PushStyleColorImVec4(.FrameBgHovered, Z_COLOR_HOVER)
    imgui.DragFloatEx("##z", &v.z, 0.01, min(f32), max(f32), "%.2f", {})
    imgui.PopStyleColorEx(2)

    // imgui.DrawList_ChannelsMerge(list)

    imgui.PopID()
}

imgui_draw_entity :: proc(e: ^Editor, en: ^EntitySlot) {
    v := reflect.get_union_variant(en^)
    imgui_draw_struct(e, v)
}

imgui_draw_component :: proc(e: ^Editor, s: any) -> (modified: bool) {
    modified = imgui_draw_struct(e, s)

    base := cast(^Component)s.data
    base->editor_ui()

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
        if is_struct && !field.is_using {
            switch field.type.id {
            case:
            if imgui.TreeNodeEx(cstr(field.name), {.FramePadding}) {
                if imgui_draw_struct_field(e, s, field) {
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
            if imgui_draw_struct_field(e, s, field) {
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

imgui_draw_struct_field :: proc(e: ^Editor, s: any, field: reflect.Struct_Field) -> (modified: bool) {
    value := reflect.struct_field_value(s, field)
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
            modified = imgui.InputScalar(
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
        case typeid_of(color):
            imgui.TextUnformatted(fmt.ctprintf("%v", field.name))
            color := cast(^vec4)&value.(color)
            modified = imgui.ColorEdit4(fmt.ctprintf("##_field_%v", field.name), color, {})
        case:
            imgui_draw_array(field.name, value)
        }
    case reflect.is_slice(field.type):
        modified = imgui_draw_slice(field.name, value)
    case reflect.is_struct(field.type):
        switch field.type.id {
        case typeid_of(Texture2D):
            // imgui
            texture := value.(Texture2D)
            aspect := f32(texture.height) / f32(texture.width)
            region := imgui.GetContentRegionAvail()
            region.y = aspect * region.x

            MIN_IMAGE_SIZE :: vec2{128, 128}
            region = linalg.min(region, MIN_IMAGE_SIZE)

            uv0 := vec2{0, 1}
            uv1 := vec2{1, 0}
            imgui.ImageEx(
                transmute(rawptr)u64(texture.handle), region, uv0, uv1, vec4{1, 1, 1, 1}, vec4{})
        case:
            modified = imgui_draw_struct(e, value)
        }
    case reflect.is_string(field.type):
        imgui.TextUnformatted(fmt.ctprintf("String len: %v", len(value.(string))))
    }

    if modified {
        // if vtable, ok := s.(^Component); ok {
        //     log.debug(s)
        //     if vtable.prop_changed != nil {
        //         vtable->prop_changed(field)
        //     }
        // }
    }
    return
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
    return imgui.InputTextEx(label, c, uint(ds_len(ds^) + 1), flags, text_callback, &data)
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

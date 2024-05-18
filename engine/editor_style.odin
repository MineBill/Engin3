package engine
import imgui "packages:odin-imgui"
import "core:reflect"

ACCENT_COLOR :: 0x3C3798FF

EditorStyle :: struct {
    button_styles:       [ButtonStyles]ButtonStyle,
    image_button_styles: [ImageButtonStyles]ImageButtonStyle,
    check_box_styles:    [CheckBoxStyles]CheckBoxStyle,
    popup_styles:        [PopupStyles]PopupStyle,
    window_styles:       [WindowStyles]WindowStyle,
}

default_style :: proc() -> (editor_style: EditorStyle) {
    setup_button_styles(&editor_style.button_styles)
    setup_image_button_styles(&editor_style.image_button_styles)
    setup_checkbox_styles(&editor_style.check_box_styles)
    setup_popup_styles(&editor_style.popup_styles)
    setup_window_styles(&editor_style.window_styles)
    return
}

setup_button_styles :: proc(styles: ^[ButtonStyles]ButtonStyle) {
    styles[.Generic] = default_button_style()
}

setup_image_button_styles :: proc(styles: ^[ImageButtonStyles]ImageButtonStyle) {
    styles[.Generic] = default_image_button_style()

    // GENERIC ROUNDED
    generic_rounded := &styles[.GenericRounded]
    generic_rounded^ = default_image_button_style()
    generic_rounded.rounding = 5.0

    // DISABLED STYLE
    disabled := &styles[.Disabled]
    disabled^ = default_image_button_style()

    disabled.normal_color = COLOR_TRANSPARENT
    disabled.hover_color = COLOR_TRANSPARENT
    disabled.pressed_color = COLOR_TRANSPARENT
    disabled.tint = Color{0.5, 0.5, 0.5, 1.0}
    // disabled.tint = COLOR_TRANSPARENT

    // ASSET REFERENCE
    ar := &styles[.AssetReference]
    ar^ = default_image_button_style()
    ar.rounding = 5.0
    // ar.border_color = cast(Color) imgui.GetStyleColorVec4(.FrameBg)^
    ar.border_color = COLOR_TRANSPARENT
    ar.border_shadow_color = COLOR_BLACK
    ar.border = true
}

setup_checkbox_styles :: proc(styles: ^[CheckBoxStyles]CheckBoxStyle) {
    styles[.Generic] = default_checkbox_style()

    // DISABLED STYLE
    disabled := &styles[.Disabled]
    disabled^ = default_checkbox_style()

    disabled.normal_color  = Color{0.2, 0.2, 0.2, 1.0}
    disabled.hover_color   = Color{0.2, 0.2, 0.2, 1.0}
    disabled.pressed_color = Color{0.2, 0.2, 0.2, 1.0}

    // MENUBAR STYLE
    menubar := &styles[.MenuBar]
    menubar^ = default_checkbox_style()

    menubar.padding = vec2{0, 0}
}

setup_popup_styles :: proc(styles: ^[PopupStyles]PopupStyle) {
    styles[.Generic] = default_popup_style()
}

setup_window_styles :: proc(styles: ^[WindowStyles]WindowStyle) {
    styles[.Generic] = default_window_style()
}

do_button :: proc(label: string, size := vec2{0, 0}, alignment := f32(0.0)) -> bool {
    clabel := cstr(label)
    style := EditorInstance.style.button_styles[.Generic]

    imgui.PushStyleVarImVec2(.FramePadding, style.padding)
    imgui.PushStyleVar(.FrameRounding, style.rounding)
    imgui.PushStyleVar(.FrameBorderSize, 1 if style.border else 0)

    imgui.PushStyleColorImVec4(.Button, cast(vec4) style.color)
    imgui.PushStyleColorImVec4(.ButtonHovered, cast(vec4) style.hover_color)
    imgui.PushStyleColorImVec4(.ButtonActive, cast(vec4) style.pressed_color)

    imgui.PushStyleColorImVec4(.Text, cast(vec4) style.text_color)
    imgui.PushStyleColorImVec4(.Border, cast(vec4) style.border_color)
    imgui.PushStyleColorImVec4(.BorderShadow, cast(vec4) style.border_shadow_color)
    defer {
        imgui.PopStyleVar(3)
        imgui.PopStyleColor(6)
    }

    s := imgui.CalcTextSize(clabel).x + style.padding.x * 2.0
    available := imgui.GetContentRegionAvail().x
    off := (available - s) * alignment
    if off > 0.0 {
        imgui.SetCursorPosX(imgui.GetCursorPosX() + off)
    }

    return imgui.Button(clabel, size)
}

do_image_button :: proc(id: cstring, texture: Texture2D, size: vec2, style := ImageButtonStyles.Generic, disabled := false) -> bool {
    if disabled {
        imgui.BeginDisabled()
    }
    style := EditorInstance.style.image_button_styles[style]

    imgui.PushStyleVarImVec2(.FramePadding, style.padding)
    imgui.PushStyleVar(.FrameRounding, style.rounding)
    imgui.PushStyleVar(.FrameBorderSize, 1 if style.border else 0)

    imgui.PushStyleColorImVec4(.Button, cast(vec4) style.normal_color)
    imgui.PushStyleColorImVec4(.ButtonHovered, cast(vec4) style.hover_color)
    imgui.PushStyleColorImVec4(.ButtonActive, cast(vec4) style.pressed_color)

    imgui.PushStyleColorImVec4(.Border, cast(vec4) style.border_color)
    imgui.PushStyleColorImVec4(.BorderShadow, cast(vec4) style.border_shadow_color)

    defer {
        imgui.PopStyleVar(3)
        imgui.PopStyleColor(5)
        if disabled {
            imgui.EndDisabled()
        }
    }

    return imgui.ImageButton(id, tex(texture.handle), size, tint_col = cast(vec4) style.tint)
}

do_checkbox :: proc(label: string, value: ^bool, style := CheckBoxStyles.Generic) -> bool {
    clabel := cstr(label)
    style := EditorInstance.style.check_box_styles[style]

    imgui.PushStyleVarImVec2(.FramePadding, style.padding)
    imgui.PushStyleColorImVec4(.FrameBg, cast(vec4) style.normal_color)
    imgui.PushStyleColorImVec4(.FrameBgActive, cast(vec4) style.pressed_color)
    imgui.PushStyleColorImVec4(.FrameBgHovered, cast(vec4) style.hover_color)
    defer {
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(3)
    }

    return imgui.Checkbox(clabel, value)
}

@(deferred_out=end_popup)
do_context_menu_item :: proc(flags := imgui.PopupFlags(0), style := PopupStyles.Generic) -> bool {
    with_popup_style(style)
    return imgui.BeginPopupContextItem()
}

@(deferred_out=end_popup)
begin_popup :: proc(label: string, flags := imgui.WindowFlags{}, style := PopupStyles.Generic) -> bool {
    with_popup_style(style)
    return imgui.BeginPopup(cstr(label), flags)
}

end_popup :: proc(opened: bool) {
    if opened {
        imgui.EndPopup()
    }
}

@(deferred_out=end_popup_style)
with_popup_style :: proc(style := PopupStyles.Generic) {
    style := EditorInstance.style.popup_styles[style]
    imgui.PushStyleVarImVec2(.WindowPadding, style.padding)
}

end_popup_style :: proc() {
    imgui.PopStyleVar(1)
}

draw_texture :: proc(texture: Texture2D, size: vec2, uv0 := vec2{0, 1}, uv1 := vec2{1, 0}) {
    imgui.Image(tex(texture.handle), size, uv0, uv1, vec4{1, 1, 1, 1})
}

@(deferred_none=end_window)
do_window :: proc(
    title: string,
    opened: ^bool = nil,
    flags := imgui.WindowFlags{},
    style := WindowStyles.Generic,
    style_override: Maybe(WindowStyle) = nil,
) -> bool {
    style := EditorInstance.style.window_styles[style]

    imgui.PushStyleVarImVec2(.WindowPadding, style.padding)
    imgui.PushStyleVar(.WindowRounding, style.rounding)
    imgui.PushStyleVar(.WindowBorderSize, 1.0 if style.border else 0.0)
    defer {
        imgui.PopStyleVar(3)
    }

    return imgui.Begin(cstr(title), opened, flags)
}

end_window :: proc() {
    imgui.End()
}

// ======
// STYLES
// ======

CommonStyle :: struct {
    padding: vec2,
    rounding: f32,
    border: bool,
}

default_common_style :: proc() -> CommonStyle {
    return CommonStyle {
        padding = vec2{2, 2},
        rounding = 1.0,
        border = false,
    }
}

// =================
// Interactive Style
// =================

InteractiveStyle :: struct {
    normal_color, hover_color, pressed_color: Color,
}

default_interactive_style :: proc() -> InteractiveStyle {
    accent := color_hex(ACCENT_COLOR)
    return {
        normal_color = accent,
        hover_color = color_lighten(accent, 0.1),
        pressed_color = color_darken(accent, 0.1),
    }
}

// ===========
// Popup Style
// ===========

PopupStyles :: enum {
    Generic,
}

PopupStyle :: struct {
    using common: CommonStyle,
}

default_popup_style :: proc() -> (style: PopupStyle) {
    style = PopupStyle {
        common = default_common_style(),
    }
    style.padding = vec2{5, 5}
    return
}

// ============
// Button Style
// ============

ButtonStyles :: enum {
    Generic,
    Disabled,
}

ButtonStyle :: struct {
    using common:      CommonStyle,
    using interactive: InteractiveStyle,

    color: Color,
    text_color: Color,
    border_color: Color,
    border_shadow_color: Color,
}

default_button_style :: proc() -> ButtonStyle {
    style := imgui.GetStyle()
    return {
        common = default_common_style(),
        interactive = default_interactive_style(),

        padding = vec2{3, 3},
        color = color_hex(ACCENT_COLOR),
        text_color = cast(Color) style.Colors[imgui.Col.Text],
        border_color = COLOR_WHITE,
        border_shadow_color = COLOR_BLACK,
        rounding = 2.0,
    }
}

// ==================
// Image Button Style
// ==================

ImageButtonStyles :: enum {
    Generic,
    GenericRounded,
    Disabled,
    AssetReference,
}

ImageButtonStyle :: struct {
    using common:      CommonStyle,
    using interactive: InteractiveStyle,

    tint: Color,
    border_color: Color,
    border_shadow_color: Color,
}

default_image_button_style :: proc() -> ImageButtonStyle {
    style := ImageButtonStyle {
        common = default_common_style(),
        interactive = default_interactive_style(),

        tint = COLOR_WHITE,
        border_color = COLOR_WHITE,
        border_shadow_color = COLOR_BLACK,
    }
    style.padding = vec2{0, 0}
    style.normal_color  = COLOR_TRANSPARENT
    return style
}

// ==============
// Checkbox Style
// ==============

CheckBoxStyles :: enum {
    Generic,
    Disabled,
    MenuBar,
}

CheckBoxStyle :: struct {
    using common:      CommonStyle,
    using interactive: InteractiveStyle,
}

default_checkbox_style :: proc() -> CheckBoxStyle {
    style := CheckBoxStyle {
        common = default_common_style(),
        interactive = default_interactive_style(),
    }

    style.padding = vec2{2, 2}
    return style
}

// ==========
// Tree Style
// ==========

TreeNodeStyles :: enum {
    Generic,
}

TreeNodeStyle :: struct {

}

@(deferred_out=end_treenode)
do_treenode :: proc(label: string, flags := imgui.TreeNodeFlags{}, style := TreeNodeStyles.Generic) -> bool {
    return imgui.TreeNodeEx(cstr(label), flags)
}

end_treenode :: proc(opened: bool) {
    if opened {
        imgui.TreePop()
    }
}

// ============
// Window Style
// ============

WindowStyles :: enum {
    Generic,
}

WindowStyle :: struct {
    using common: CommonStyle,
}

default_window_style :: proc() -> (style: WindowStyle) {
    style.common = default_common_style()
    style.border = true
    style.rounding = 3.0
    return
}

// ========================
// Property drawing helpers
// ========================

PROPERTY_TABLE_FLAGS :: imgui.TableFlags_BordersInnerV |
    imgui.TableFlags_Resizable |
    imgui.TableFlags_NoSavedSettings |
    imgui.TableFlags_SizingStretchSame

@(deferred_out=end_property)
do_property :: proc(id: string, flags := PROPERTY_TABLE_FLAGS) -> bool {
    imgui.PushStyleVarImVec2(.CellPadding, vec2{1, 1})
    return imgui.BeginTable(cstr(id), 2, flags)
}

end_property :: proc(opened: bool) {
    if opened {
        imgui.EndTable()
    }
    imgui.PopStyleVar(1)
}

do_property_name :: proc(name: string) {
    cname := cstr(name)
    imgui.TableNextColumn()
    // size := imgui.CalcTextSize(cname)
    // imgui.SetNextItemWidth(size.x)
    imgui.TextUnformatted(cname)
}

do_property_value :: proc(value: any, tag: reflect.Struct_Tag = "") -> (modified: bool) {
    ti := (type_info_of(value.id))
    imgui.PushIDPtr(value.data)
    defer imgui.PopID()

    imgui.TableNextColumn()
    imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)

    // if named, ok := ti.variant.(reflect.Type_Info_Named); ok {
    //     return
    // }

    switch {
    case ti.id == typeid_of(AssetHandle):
        handle := &value.(AssetHandle)

        if do_image_button("##asset_handle", EditorInstance.icons[.AssetReferene], vec2{48, 48}, .AssetReference) {}

        if imgui.IsItemHovered() && imgui.IsMouseDoubleClicked(.Left) {
            // Ask the content browser to navigate to this asset
        }

        if imgui.BeginPopupContextItem() {
            if imgui.MenuItem("Unset handle") {
                handle^ = 0
            }
            imgui.EndPopup()
        }

        if imgui.BeginDragDropTarget() {

            if type_name, ok := reflect.struct_tag_lookup(tag, "asset"); ok {
                type, _ := reflect.enum_from_name(AssetType, type_name)

                if payload := imgui.GetDragDropPayload(); payload != nil {
                    new_handle := cast(^AssetHandle) payload.Data

                    new_type := get_asset_type(&EngineInstance.asset_manager, new_handle^)
                    if new_type == type {
                        if p := imgui.AcceptDragDropPayload("CONTENT_ITEM_ASSET"); p != nil {
                            handle^ = new_handle^
                        }
                    }
                }
            }
            imgui.EndDragDropTarget()
        }

        if asset := get_asset_metadata(&EngineInstance.asset_manager, handle^); asset.type != .Invalid {
            imgui.TextUnformatted(cstr(asset.path))
        }

    case reflect.is_boolean(ti):
        b := &value.(bool)
        modified = do_checkbox("##checkbox", b)

    case reflect.is_float(ti):
        fallthrough
    case reflect.is_integer(ti):
        if min, max, ok := parse_range_tag(tag); ok {
            if reflect.is_integer(ti) {
                // We use the biggest integer type to cover all cases.
                min, max := i128(min), i128(max)
                modified = imgui.SliderScalar(
                    "##slider_scalar",
                    number_to_imgui_scalar(value),
                    value.data,
                    &min, &max, flags = {.AlwaysClamp})
            } else {
                modified = imgui.SliderScalar(
                    "##slider_scalar",
                    number_to_imgui_scalar(value),
                    value.data,
                    &min, &max, flags = {.AlwaysClamp})
            }
        } else {
            modified = imgui.DragScalar(
                "##drag_scalar",
                number_to_imgui_scalar(value),
                value.data, 0.01, flags = {.AlwaysClamp})
        }

    case reflect.is_enum(ti):
        modified = imgui_enum_combo_id("##enum_combo", value, ti)

    case reflect.is_array(ti):
        array := reflect.type_info_base(ti).variant.(reflect.Type_Info_Array)
        switch value.id {
        case typeid_of(vec3):
            modified = imgui.DragFloat3("##vec3", &value.(vec3), 0.01)
        case typeid_of(vec4):
            modified = imgui.DragFloat4("##vec4", &value.(vec4), 0.01)
        case typeid_of(Color):
            color := cast(^vec4)&value.(Color)
            modified = imgui.ColorEdit4("##Color", color, {})
        case:
            // imgui_draw_array(field.name, value)
        }
    case reflect.is_slice(ti):
        // modified = imgui_draw_slice(field.name, value)
    case reflect.is_struct(ti):
        for field in reflect.struct_fields_zipped(ti.id) {
            if do_property(field.name) {
                do_property_name(field.name)
                value := reflect.struct_field_value(value, field)
                do_property_value(value, field.tag)
            }
        }
        // switch ti.id {
        // case:
        //     if imgui.TreeNodeEx(cstr(field.name), {.FramePadding}) {
        //         modified = imgui_draw_struct(e, value)
        //         imgui.TreePop()
        //     }
        // }
    case reflect.is_pointer(ti):
        // pointer := reflect.type_info_base(ti).variant.(runtime.Type_Info_Pointer)

    case reflect.is_string(ti):
        imgui.TextUnformatted(cstr(value.(string)))
    }
    return
}

color_to_abgr :: proc(color: Color) -> u32 {
    r := u8(color.r * 255)
    g := u8(color.g * 255)
    b := u8(color.b * 255)
    a := u8(color.a * 255)
    return (u32(a) << 24) | (u32(b) << 16) | (u32(g) << 8) | u32(r)
}

apply_style :: proc(style: EditorStyle) {
    // Fork of Future Dark style from ImThemes
    style := imgui.GetStyle()

    style.Alpha                     = 1.0
    style.DisabledAlpha             = 1.0
    style.WindowPadding             = vec2{12.0, 12.0}
    style.WindowRounding            = 3.0
    style.WindowBorderSize          = 1.0
    style.WindowMinSize             = vec2{20.0, 20.0}
    style.WindowTitleAlign          = vec2{0.5, 0.5}
    style.WindowMenuButtonPosition  = .None;
    style.ChildRounding             = 3.0
    style.ChildBorderSize           = 1.0
    style.PopupRounding             = 3.0
    style.PopupBorderSize           = 1.0
    style.FramePadding              = vec2{2.0, 1.0}
    style.FrameRounding             = 3.0
    style.FrameBorderSize           = 0.0
    style.ItemSpacing               = vec2{6.0, 3.0}
    style.ItemInnerSpacing          = vec2{6.0, 3.0}
    style.CellPadding               = vec2{12.0, 6.0}
    style.IndentSpacing             = 0.0
    style.ColumnsMinSpacing         = 6.0
    style.ScrollbarSize             = 12.0
    style.ScrollbarRounding         = 3.0
    style.GrabMinSize               = 12.0
    style.GrabRounding              = 3.0
    style.TabRounding               = 3.0
    style.TabBorderSize             = 0.0
    style.TabMinWidthForCloseButton = 0.0
    style.ColorButtonPosition       = .Left;
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

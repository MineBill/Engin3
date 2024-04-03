package engine
import imgui "packages:odin-imgui"

EditorStyle :: struct {
    popup_padding: vec2,
    popup_color: Color,
}

default_style :: proc() -> (style: EditorStyle) {
    style.popup_color = COLOR_RED
    style.popup_padding = vec2{4, 4}

    return
}

apply_style :: proc(style: EditorStyle) {
    // Fork of Future Dark style from ImThemes
    style := imgui.GetStyle()
    
    style.Alpha                     = 1.0
    style.DisabledAlpha             = 1.0
    style.WindowPadding             = vec2{12.0, 12.0}
    style.WindowRounding            = 2.0
    style.WindowBorderSize          = 1.0
    style.WindowMinSize             = vec2{20.0, 20.0}
    style.WindowTitleAlign          = vec2{0.5, 0.5}
    style.WindowMenuButtonPosition  = .None;
    style.ChildRounding             = 0.0
    style.ChildBorderSize           = 1.0
    style.PopupRounding             = 0.0
    style.PopupBorderSize           = 1.0
    style.FramePadding              = vec2{2.0, 1.0}
    style.FrameRounding             = 0.0
    style.FrameBorderSize           = 0.0
    style.ItemSpacing               = vec2{6.0, 3.0}
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

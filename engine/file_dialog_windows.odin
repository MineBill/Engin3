package engine
import glfw "vendor:glfw"
import win32 "core:sys/windows"
import "core:strings"

open_file_dialog :: proc(filter: ..string) -> string {
    window := glfw.GetWin32Window(EngineInstance.window)

    file := [260]win32.WCHAR {}

    sb: strings.Builder
    strings.builder_init(&sb)
    for item in filter {
        strings.write_string(&sb, item)
        strings.write_byte(&sb, 0)
    }

    arg := win32.OPENFILENAMEW {}
    arg.lStructSize = size_of(win32.OPENFILENAMEW)
    arg.hwndOwner = window
    arg.lpstrFile = win32.wstring(raw_data(file[:]))
    arg.nMaxFile = size_of(file)
    arg.lpstrFilter = win32.utf8_to_wstring(strings.to_string(sb), context.temp_allocator)
    arg.nFilterIndex = 1
    arg.Flags = win32.OFN_PATHMUSTEXIST | win32.OFN_FILEMUSTEXIST | win32.OFN_NOCHANGEDIR

    if win32.GetOpenFileNameW(&arg) {
        N := 0
        for i in 0..<260 {
            if arg.lpstrFile[i] == 0 {
                N = i
                break
            }
        }
        s, _ := win32.wstring_to_utf8(arg.lpstrFile, N)
        return s
    }
    return ""
}

show_popup :: proc(title: string, message: string, type: PopupType) {
    message := win32.utf8_to_utf16(message)
    caption := win32.utf8_to_utf16(title)

    win_type: u32
    switch type {
    case .Info:
        win_type = win32.MB_ICONINFORMATION
    case .Warning:
        win_type = win32.MB_ICONWARNING
    case .Error:
        win_type = win32.MB_ICONERROR
    }
    win_type |= win32.MB_OK

    hwnd := glfw.GetWin32Window(EngineInstance.window)
    win32.MessageBoxW(
        hwnd,
        raw_data(message),
        raw_data(caption),
        win_type,
    )
}

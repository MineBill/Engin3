package engine

import "vendor:glfw"
import "core:log"
import "core:runtime"

Event :: union {
    KeyEvent,
    CharEvent,
    MouseButtonEvent,
    MouseWheelEvent,
    MousePositionEvent,
    WindowResizedEvent,
    WindowPositionEvent,
}

KeyMod :: enum {
    Alt,
    Super,
    Control,
    CapsLock,
    Shift,
}

KeyMods :: bit_set[KeyMod]

glfw_mod_to_key_mod :: proc(mods: i32) -> (key_mods: KeyMods) {
    switch {
    case mods & glfw.MOD_ALT != 0:
        key_mods += {.Alt}
    case mods & glfw.MOD_SUPER != 0:
        key_mods += {.Super}
    case mods & glfw.MOD_CAPS_LOCK != 0:
        key_mods += {.CapsLock}
    case mods & glfw.MOD_CONTROL != 0:
        key_mods += {.Control}
    case mods & glfw.MOD_SHIFT != 0:
        key_mods += {.Shift}
    }
    return
}

KeyEvent :: struct {
    key: Key,
    state: InputState,
    mods: KeyMods,
}

CharEvent :: struct {
    char: rune,
}

MouseButtonEvent :: struct {
    button: MouseButton,
    state: InputState,
}

MouseWheelEvent :: struct {
    delta: [2]f32,
}

MousePositionEvent :: struct {
    pos: [2]f32,
}

WindowResizedEvent :: struct {
    size: [2]f32,
}

WindowPositionEvent :: struct {
    position: [2]f32,
}

KeyState :: enum {
    none,
    just_pressed,
    just_released,
    held,
}

Event_Context :: struct {
    odin_context: runtime.Context,
    events:       [dynamic]Event,
    characters:   [dynamic]rune,

    mouse, previous_mouse: [2]f32,
    window_position: [2]f32,
}

g_event_ctx := Event_Context{}

@(private = "file")
mouse: map[MouseButton]InputState

@(private = "file")
keys, prev_keys: map[Key]KeyState

setup_glfw_callbacks :: proc(window: glfw.WindowHandle, parent_context := context) {
    g_event_ctx.odin_context = parent_context
    glfw.SetWindowUserPointer(window, &g_event_ctx)

    glfw.SetCharCallback(window, glfw_char_callback)
    glfw.SetWindowSizeCallback(window, glfw_window_size_callback)
    glfw.SetKeyCallback(window, glfw_key_callback)
    glfw.SetMouseButtonCallback(window, glfw_mouse_button_callback)
    glfw.SetCursorPosCallback(window, glfw_cursor_pos_callback)
    glfw.SetScrollCallback(window, glfw_scroll_callback)
    glfw.SetWindowPosCallback(window, glfw_window_pos_callback)

    x, y := glfw.GetWindowPos(window)
    g_event_ctx.window_position = {f32(x), f32(y)}
}


glfw_scroll_callback :: proc "c" (win: glfw.WindowHandle, x, y: f64) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context

    append(&state.events, MouseWheelEvent {delta = [2]f32{f32(x), f32(y)}})
}

glfw_window_size_callback :: proc "c" (win: glfw.WindowHandle, width, height: i32) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context

    append(&state.events, WindowResizedEvent{size = [2]f32{f32(width), f32(height)}})
}

glfw_window_pos_callback :: proc "c" (win: glfw.WindowHandle, x, y: i32) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context
    state.window_position = [2]f32{f32(x), f32(y)}

    append(&state.events, WindowPositionEvent{position = state.window_position})
}

glfw_key_callback :: proc "c" (win: glfw.WindowHandle, key, scancode, action, mods: i32) {
    game := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = game.odin_context

    key := glfw_key_to_mine(key)
    state := glfw_action_to_state(action)
    append(&game.events, KeyEvent{
        key = key,
        state = state,
        mods = glfw_mod_to_key_mod(mods),
    })
    #partial switch (state) {
        case .pressed:
        keys[key] = .just_pressed
        case .released:
        keys[key] = .just_released
        case .repeat:
        keys[key] = .held
    }
}

glfw_char_callback :: proc "c" (win: glfw.WindowHandle, codepoint: rune) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context

    append(&state.characters, codepoint)
    append(&state.events, CharEvent{char = codepoint})
}

glfw_mouse_button_callback :: proc "c" (win: glfw.WindowHandle, button, action, mods: i32) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context

    btn := glfw_mouse_to_mine(button)
    key_state := glfw_action_to_state(action)
    append(&state.events, MouseButtonEvent{
        button = btn,
        state = key_state,
    })
    mouse[btn] = key_state
}

glfw_cursor_pos_callback :: proc "c" (win: glfw.WindowHandle, x, y: f64) {
    state := (cast(^Event_Context)(glfw.GetWindowUserPointer(win)))
    context = state.odin_context

    state.mouse = {f32(x), f32(y)}
    append(&state.events, MousePositionEvent{state.mouse})
}

flush_input :: proc() {
    clear(&g_event_ctx.events)
    clear(&g_event_ctx.characters)
    for key, state in keys {
        #partial switch state {
            case .just_released:
                keys[key] = .none
            case .just_pressed:
                keys[key] = .held
        }
    }
    g_event_ctx.previous_mouse = g_event_ctx.mouse
}

get_mouse_delta :: proc() -> [2]f32 {
    return g_event_ctx.mouse - g_event_ctx.previous_mouse
}

is_mouse_down :: proc(button: MouseButton) -> bool {
    return mouse[button] == .pressed
}

is_mouse_up :: proc(button: MouseButton) -> bool {
    return mouse[button] == .released
}

is_key_pressed :: proc(key: Key) -> bool {
    return keys[key] == .just_pressed || keys[key] == .held
}

is_any_key_pressed :: proc(keys: ..Key) -> bool {
    for key in keys {
        if is_key_pressed(key) do return true
    }
    return false
}

is_key_released :: proc(key: Key) -> bool {
    return keys[key] == .just_released || keys[key] == .none
}

is_key_just_released :: proc(key: Key) -> bool {
    return keys[key] == .just_released
}

is_key_just_pressed :: proc(key: Key) -> bool {
    return keys[key] == .just_pressed
}

is_any_key_just_pressed :: proc(keys: ..Key) -> bool {
    for key in keys {
        if is_key_just_pressed(key) do return true
    }
    return false
}

get_axis :: proc(positive, negative: Key) -> f32 {
    return f32(int(is_key_pressed(positive))) - f32(int(is_key_pressed(negative)))
}

get_vector :: proc(positive_x, negative_x, positive_y, negative_y: Key) -> [2]f32 {
    x := get_axis(positive_x, negative_x)
    y := get_axis(positive_y, negative_y)
    return {x, y}
}

InputState :: enum {
    none,
    pressed,
    released,
    repeat,
}

glfw_action_to_state :: proc(action: i32) -> InputState {
    switch(action) {
        case glfw.PRESS:
            return .pressed
        case glfw.RELEASE:
            return .released
        case glfw.REPEAT:
            return .repeat
    }
    unreachable()
}

MouseButton :: enum {
    left,
    middle,
    right,
    mouse4,
    mouse5,
}

glfw_mouse_to_mine :: proc(mouse: i32) -> MouseButton {
    switch(mouse) {
        case glfw.MOUSE_BUTTON_1:
            return .left
        case glfw.MOUSE_BUTTON_2:
            return .right
        case glfw.MOUSE_BUTTON_3:
            return .middle
        case glfw.MOUSE_BUTTON_4:
            return .mouse4
        case glfw.MOUSE_BUTTON_5:
            return .mouse5
    }
    unreachable()
}

Key :: enum {
    _1,
    _2,
    _3,
    _4,
    _5,
    _6,
    _7,
    _8,
    _9,
    _0,

    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    escape,
    enter,
    tab,
    backspace,
    space,
    insert,
    delete,
    right,
    left,
    down,
    up,
    page_up,
    page_down,
    home,
    end,
    caps_lock,
    scroll_lock,
    num_lock,
    print_screen,
    pause,

    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    f25,

    left_shift,
    left_control,
    left_alt,
    left_super,
    right_shift,
    right_control,
    right_alt,
    right_super,
    menu,

    minus,
    equal,
    period,
    slash,
}

glfw_key_to_mine :: proc(key: i32) -> Key
{
    using glfw
    switch(key)
    {
        case KEY_1:
            return ._1
        case KEY_2:
            return ._2
        case KEY_3:
            return ._3
        case KEY_4:
            return ._4
        case KEY_5:
            return ._5
        case KEY_6:
            return ._6
        case KEY_7:
            return ._7
        case KEY_8:
            return ._8
        case KEY_9:
            return ._9
        case KEY_0:
            return ._0
        case KEY_A:
            return .a
        case KEY_B:
            return .b
        case KEY_C:
            return .c
        case KEY_D:
            return .d
        case KEY_E:
            return .e
        case KEY_F:
            return .f
        case KEY_G:
            return .g
        case KEY_H:
            return .h
        case KEY_I:
            return .i
        case KEY_J:
            return .j
        case KEY_K:
            return .k
        case KEY_L:
            return .l
        case KEY_M:
            return .m
        case KEY_N:
            return .n
        case KEY_O:
            return .o
        case KEY_P:
            return .p
        case KEY_Q:
            return .q
        case KEY_R:
            return .r
        case KEY_S:
            return .s
        case KEY_T:
            return .t
        case KEY_U:
            return .u
        case KEY_V:
            return .v
        case KEY_W:
            return .w
        case KEY_X:
            return .x
        case KEY_Y:
            return .y
        case KEY_Z:
            return .z
        case KEY_ESCAPE:
            return .escape
        case KEY_ENTER:
            return .enter
        case KEY_TAB:
            return .tab
        case KEY_BACKSPACE:
            return .backspace
        case KEY_SPACE:
            return .space
        case KEY_INSERT:
            return .insert
        case KEY_DELETE:
            return .delete
        case KEY_RIGHT:
            return .right
        case KEY_LEFT:
            return .left
        case KEY_DOWN:
            return .down
        case KEY_UP:
            return .up
        case KEY_PAGE_UP:
            return .page_up
        case KEY_PAGE_DOWN:
            return .page_down
        case KEY_HOME:
            return .home
        case KEY_END:
            return .end
        case KEY_CAPS_LOCK:
            return .caps_lock
        case KEY_SCROLL_LOCK:
            return .scroll_lock
        case KEY_NUM_LOCK:
            return .num_lock
        case KEY_PRINT_SCREEN:
            return .print_screen
        case KEY_PAUSE:
            return .pause
        case KEY_F1:
            return .f1
        case KEY_F2:
            return .f2
        // all of them
        case KEY_F3:
            return .f3
        case KEY_F4:
            return .f4
        case KEY_F5:
            return .f5
        case KEY_F6:
            return .f6
        case KEY_F7:
            return .f7
        case KEY_F8:
            return .f8
        case KEY_F9:
            return .f9
        case KEY_F10:
            return .f10
        case KEY_F11:
            return .f11
        case KEY_F12:
            return .f12
        case KEY_F13:
            return .f13
        case KEY_F14:
            return .f14
        case KEY_F15:
            return .f15
        case KEY_F16:
            return .f16
        case KEY_F17:
            return .f17
        case KEY_F18:
            return .f18
        case KEY_F19:
            return .f19
        case KEY_F20:
            return .f20
        case KEY_F21:
            return .f21
        case KEY_F22:
            return .f22
        case KEY_F23:
                return .f23
        case KEY_F24:
            return .f24
        case KEY_F25:
            return .f25
        case KEY_LEFT_SHIFT:
            return .left_shift
        case KEY_LEFT_CONTROL:
            return .left_control
        case KEY_LEFT_ALT:
            return .left_alt
        case KEY_LEFT_SUPER:
            return .left_super
        case KEY_RIGHT_SHIFT:
            return .right_shift
        case KEY_RIGHT_CONTROL:
            return .right_control
        case KEY_RIGHT_ALT:
            return .right_alt
        case KEY_RIGHT_SUPER:
            return .right_super
        case KEY_MENU:
            return .menu
        case KEY_MINUS:
            return .minus
        case KEY_EQUAL:
            return .equal
        case KEY_PERIOD:
            return .period
        case KEY_SLASH:
            return .slash
    }
    unreachable()
}

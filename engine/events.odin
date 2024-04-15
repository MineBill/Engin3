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

    mouse_wheel: f32,
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

    state.mouse_wheel = f32(y)

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
    g_event_ctx.mouse_wheel = 0
}

get_mouse_wheel_delta :: proc() -> f32 {
    return g_event_ctx.mouse_wheel
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

@(LuaExport = {
    Name = "Keys",
})
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

    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    Escape,
    Enter,
    Tab,
    Backspace,
    Space,
    Insert,
    Delete,
    Right,
    Left,
    Down,
    Up,
    Page_up,
    Page_down,
    Home,
    End,
    Caps_lock,
    Scroll_lock,
    Num_lock,
    Print_screen,
    Pause,

    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    F13,
    F14,
    F15,
    F16,
    F17,
    F18,
    F19,
    F20,
    F21,
    F22,
    F23,
    F24,
    F25,

    LeftShift,
    LeftControl,
    LeftAlt,
    LeftSuper,
    RightShift,
    RightControl,
    RightAlt,
    RightSuper,
    Menu,

    Minus,
    Equal,
    Period,
    Slash,
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
            return .A
        case KEY_B:
            return .B
        case KEY_C:
            return .C
        case KEY_D:
            return .D
        case KEY_E:
            return .E
        case KEY_F:
            return .F
        case KEY_G:
            return .G
        case KEY_H:
            return .H
        case KEY_I:
            return .I
        case KEY_J:
            return .J
        case KEY_K:
            return .K
        case KEY_L:
            return .L
        case KEY_M:
            return .M
        case KEY_N:
            return .N
        case KEY_O:
            return .O
        case KEY_P:
            return .P
        case KEY_Q:
            return .Q
        case KEY_R:
            return .R
        case KEY_S:
            return .S
        case KEY_T:
            return .T
        case KEY_U:
            return .U
        case KEY_V:
            return .V
        case KEY_W:
            return .W
        case KEY_X:
            return .X
        case KEY_Y:
            return .Y
        case KEY_Z:
            return .Z
        case KEY_ESCAPE:
            return .Escape
        case KEY_ENTER:
            return .Enter
        case KEY_TAB:
            return .Tab
        case KEY_BACKSPACE:
            return .Backspace
        case KEY_SPACE:
            return .Space
        case KEY_INSERT:
            return .Insert
        case KEY_DELETE:
            return .Delete
        case KEY_RIGHT:
            return .Right
        case KEY_LEFT:
            return .Left
        case KEY_DOWN:
            return .Down
        case KEY_UP:
            return .Up
        case KEY_PAGE_UP:
            return .Page_up
        case KEY_PAGE_DOWN:
            return .Page_down
        case KEY_HOME:
            return .Home
        case KEY_END:
            return .End
        case KEY_CAPS_LOCK:
            return .Caps_lock
        case KEY_SCROLL_LOCK:
            return .Scroll_lock
        case KEY_NUM_LOCK:
            return .Num_lock
        case KEY_PRINT_SCREEN:
            return .Print_screen
        case KEY_PAUSE:
            return .Pause
        case KEY_F1:
            return .F1
        case KEY_F2:
            return .F2
        // all of them
        case KEY_F3:
            return .F3
        case KEY_F4:
            return .F4
        case KEY_F5:
            return .F5
        case KEY_F6:
            return .F6
        case KEY_F7:
            return .F7
        case KEY_F8:
            return .F8
        case KEY_F9:
            return .F9
        case KEY_F10:
            return .F10
        case KEY_F11:
            return .F11
        case KEY_F12:
            return .F12
        case KEY_F13:
            return .F13
        case KEY_F14:
            return .F14
        case KEY_F15:
            return .F15
        case KEY_F16:
            return .F16
        case KEY_F17:
            return .F17
        case KEY_F18:
            return .F18
        case KEY_F19:
            return .F19
        case KEY_F20:
            return .F20
        case KEY_F21:
            return .F21
        case KEY_F22:
            return .F22
        case KEY_F23:
            return .F23
        case KEY_F24:
            return .F24
        case KEY_F25:
            return .F25
        case KEY_LEFT_SHIFT:
            return .LeftShift
        case KEY_LEFT_CONTROL:
            return .LeftControl
        case KEY_LEFT_ALT:
            return .LeftAlt
        case KEY_LEFT_SUPER:
            return .LeftSuper
        case KEY_RIGHT_SHIFT:
            return .RightShift
        case KEY_RIGHT_CONTROL:
            return .RightControl
        case KEY_RIGHT_ALT:
            return .RightAlt
        case KEY_RIGHT_SUPER:
            return .RightSuper
        case KEY_MENU:
            return .Menu
        case KEY_MINUS:
            return .Minus
        case KEY_EQUAL:
            return .Equal
        case KEY_PERIOD:
            return .Period
        case KEY_SLASH:
            return .Slash
    }
    unreachable()
}

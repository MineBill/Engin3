package engine
import imgui "packages:odin-imgui"
import "core:fmt"
import tracy "packages:odin-tracy"
import gl "vendor:OpenGL"
import "core:math"
import "core:log"
import "core:math/linalg"
import nk "packages:odin-nuklear"

Game :: struct {
    engine: ^Engine,
    counter: int,
}

game_init :: proc(g: ^Game, engine: ^Engine) {
    g^ = {
        engine = engine,
    }
}

game_update :: proc(g: ^Game, _delta: f64) {
    tracy.ZoneN("Game Update")
    delta := f32(_delta)
    @(static) CAMERA_SPEED := f32(2)

    for event in g_event_ctx.events {
        #partial switch ev in event {
        case WindowResizedEvent:
            gl.Viewport(0, 0, i32(ev.size.x), i32(ev.size.y))
            width, height := int(ev.size.x), int(ev.size.y)
            engine_resize(g.engine, width, height)
        case MouseButtonEvent:
            // if ev.button == .right {
            //     if ev.state == .pressed && e.is_viewport_focused {
            //         e.capture_mouse = true
            //     } else if ev.state == .released {
            //         e.capture_mouse = false
            //     }

            //     if e.capture_mouse {
            //         glfw.SetInputMode(e.engine.window, glfw.CURSOR, glfw.CURSOR_DISABLED)
            //     } else {
            //         glfw.SetInputMode(e.engine.window, glfw.CURSOR, glfw.CURSOR_NORMAL)
            //     }
            // }
        case MouseWheelEvent:
            CAMERA_SPEED += ev.delta.y
            CAMERA_SPEED = math.clamp(CAMERA_SPEED, 1, 100)
        }
    }

    {
        // d := &g.engine.dbg_draw
        // dbg_draw_line(d, vec3{0, 0, 0}, vec3{0, 3, 0}, color = color_hex(0x86cd82FF))
        // dbg_draw_line(d, vec3{0, 3, 0}, vec3{1, 3, 0}, color = color_hex(0x86cd82FF))
        // dbg_draw_line(d, vec3{1, 3, 0}, vec3{0, 2, 1}, color = color_hex(0x86cd82FF))

        // dbg_draw_cube(d, vec3{0, 0.5, 0}, vec3{1, 1, 1}, color = COLOR_BLUE)

        engine := g.engine
        // if e.capture_mouse {
        //     engine.camera.euler_angles.xy += get_mouse_delta().yx * 25 * delta
        //     engine.camera.euler_angles.x = math.clamp(engine.camera.euler_angles.x, -80, 80)
        // }

        if is_key_just_pressed(.escape) {
            engine.quit = true
            return
        }

        input := get_vector(.d, .a, .w, .s) * CAMERA_SPEED
        up_down := get_axis(.space, .left_control) * CAMERA_SPEED
        g.engine.camera.position.xz += ( vec4{input.x, 0, -input.y, 0} * linalg.matrix4_from_quaternion(g.engine.camera.rotation)).xz * delta
        g.engine.camera.position.y += up_down * f32(delta)

        euler := g.engine.camera.euler_angles
        g.engine.camera.rotation = linalg.quaternion_from_euler_angles(
            euler.x * math.RAD_PER_DEG,
            euler.y * math.RAD_PER_DEG,
            euler.z * math.RAD_PER_DEG,
            .XYZ)
    }

    n := &nk_context.ctx
    if nk.begin(n, "Window", nk.rect(0, 0, f32(g.engine.width), 150), {}) {
        nk.layout_row_dynamic(n, 30, 2)
        if nk.button_string(n, "Button") {
            log.debug("Button!")
        }
        nk.label_string(n, "Label!", {.Centered})
        nk.end(n)
    }
}

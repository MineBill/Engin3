package engine
import nk "packages:odin-nuklear"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "core:log"

MAX_VERTEX_BUFFER :: 512 * 1024
MAX_ELEMENT_BUFFER :: 128 * 1024

MAX_TEXTURES :: 256
TEXT_MAX :: 256

Nk_Vertex :: struct {
    position:   vec2,
    uv:         vec2,
    col:        [4]u8,
}

Nk_Device :: struct {
    cmds: nk.Buffer,
    null_texture: nk.Draw_Null_Texture,
    vbo, vao, ebo: u32,
    shader: Shader,

    font_tex_index: u32,
    vertex_buffer: [^]Nk_Vertex,
    index_buffer: [^]i32,

    buffer_sync: gl.sync_t, // ?

    // tex_ids: [MAX_TEXTURES]u32,
    // tex_handles: [MAX_TEXTURES]u64,
}

Nk_Context :: struct {
    window: glfw.WindowHandle,
    width, height: i32,
    display_width, display_height: i32,
    device: Nk_Device,
    ctx: nk.Context,
    atlas: nk.Font_Atlas,
    fb_scale: vec2,
    text: [TEXT_MAX]u32,
    text_len: i32,
    scroll: vec2,
    last_button_click: f64,
    is_double_click_down: bool,
    double_click_pos: vec2,
}

nk_context: Nk_Context

nk_device_create :: proc() -> (ok: bool) {
    dev := &nk_context.device
    nk.buffer_init_default(&dev.cmds)

    VERTEX_SRC   :: #load("../assets/shaders/nuklear.vert.glsl")
    FRAGMENT_SRC :: #load("../assets/shaders/nuklear.frag.glsl")

    log.debug(dev.shader)
    dev.shader = shader_load_from_memory(VERTEX_SRC, FRAGMENT_SRC) or_return
    
    shader_cache_uniforms(&dev.shader, {
        "Texture",
        "ProjMtx",
    })

    pos := u32(0)
    uv := u32(1)
    color := u32(2)

    gl.CreateVertexArrays(1, &dev.vao)
    gl.CreateBuffers(1, &dev.vbo)
    gl.CreateBuffers(1, &dev.ebo)


    gl.EnableVertexArrayAttrib(dev.vao, pos)
    gl.EnableVertexArrayAttrib(dev.vao, uv)
    gl.EnableVertexArrayAttrib(dev.vao, color)

    gl.VertexArrayAttribBinding(dev.vao, pos, 0)
    gl.VertexArrayAttribBinding(dev.vao, uv, 0)
    gl.VertexArrayAttribBinding(dev.vao, color, 0)

    gl.VertexArrayAttribFormat(
        dev.vao, pos, 2, gl.FLOAT, false, cast(u32)offset_of(Nk_Vertex, position))
    gl.VertexArrayAttribFormat(
        dev.vao, uv, 2, gl.FLOAT, false, cast(u32)offset_of(Nk_Vertex, uv))
    gl.VertexArrayAttribFormat(
        dev.vao, color, 4, gl.UNSIGNED_BYTE, false, cast(u32)offset_of(Nk_Vertex, col))

    gl.VertexArrayElementBuffer(dev.vao, dev.ebo)
    gl.VertexArrayVertexBuffer(dev.vao, 0, dev.vbo, 0, size_of(Nk_Vertex))

    flags := gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT
    gl.NamedBufferStorage(dev.vbo, MAX_VERTEX_BUFFER, nil, u32(flags))
    gl.NamedBufferStorage(dev.ebo, MAX_ELEMENT_BUFFER, nil, u32(flags))

    dev.vertex_buffer = cast([^]Nk_Vertex)gl.MapNamedBufferRange(dev.vbo, 0, MAX_VERTEX_BUFFER, u32(flags))
    dev.index_buffer = cast([^]i32)gl.MapNamedBufferRange(dev.ebo, 0, MAX_ELEMENT_BUFFER, u32(flags))

    return true
}

// nk_get_available_tex_index :: proc() -> u32 {
//     for i := 0; i < MAX_TEXTURES; i += 1 {
//         if nk_context.device.tex_ids[i] == 0 {
//             return u32(i)
//         }
//     }
//     panic("Max textures reached")
// }

// nk_get_tex_ogl_id :: proc(index: i32) -> u32 {
//     assert(index >= 0 && index < MAX_TEXTURES)
//     return nk_context.device.tex_ids[index]
// }

// nk_get_tex_ogl_handle :: proc(index: i32) -> u64 {
//     assert(index >= 0 && index < MAX_TEXTURES)
//     return nk_context.device.tex_handles[index]
// }

// nk_create_texture :: proc(data: rawptr, width, height: int) -> u32 {
//     tex_index := nk_get_available_tex_index()

//     id: u32
//     gl.CreateTextures(gl.TEXTURE_2D, 1, &id)

//     nk_context.device.tex_ids[tex_index] = id

//     gl.TextureParameteri(id, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
//     gl.TextureParameteri(id, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
//     gl.TextureParameteri(id, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
//     gl.TextureParameteri(id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
//     gl.TextureStorage2D(id, 1, gl.RGBA8, i32(width), i32(height))
//     if data != nil {
//         gl.TextureSubImage2D(id, 0, 0, 0, i32(width), i32(height), gl.RGBA, gl.UNSIGNED_BYTE, data);
//     }
//     else {
//         gl.ClearTexImage(id, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
//     }
//     handle := gl.GetTextureHandleARB(id)
//     gl.MakeTextureHandleResidentARB(handle)
//     nk_context.device.tex_handles[tex_index] = handle
//     return tex_index
// }

// nk_destroy_texture :: proc(index: i32) {
//     id := nk_get_tex_ogl_id(index)
//     if id == 0 do return

//     handle := nk_get_tex_ogl_handle(index)
//     gl.MakeTextureHandleNonResidentARB(handle)
//     gl.DeleteTextures(1, &id)

//     nk_context.device.tex_ids[index] = 0
//     nk_context.device.tex_handles[index] = 0
// }

nk_device_upload_atlas :: proc(image: rawptr, width, height: int) {
    // nk_context.device.font_tex_index = nk_create_texture(image, width, height)
    id: u32
    gl.CreateTextures(gl.TEXTURE_2D, 1, &id)
    gl.TextureParameteri(id, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TextureParameteri(id, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TextureParameteri(id, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TextureParameteri(id, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TextureStorage2D(id, 1, gl.RGBA8, i32(width), i32(height))
    gl.TextureSubImage2D(id, 0, 0, 0, i32(width), i32(height), gl.RGBA, gl.UNSIGNED_BYTE, image)
    nk_context.device.font_tex_index = id
}

nk_wait_for_buffer_unlock :: proc() {
    if nk_context.device.buffer_sync == nil do return

    for {
        wait := gl.ClientWaitSync(nk_context.device.buffer_sync, gl.SYNC_FLUSH_COMMANDS_BIT, 1)
        if wait == gl.ALREADY_SIGNALED || wait == gl.CONDITION_SATISFIED {
            return
        }
    }
}

nk_lock_buffer :: proc() {
    if nk_context.device.buffer_sync != nil {
        gl.DeleteSync(nk_context.device.buffer_sync)
    }
    nk_context.device.buffer_sync = gl.FenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)
}

nk_render :: proc() {
    dev := &nk_context.device
    ortho := mat4 {
        2.0, 0.0, 0.0, -1.0,
        0.0,-2.0, 0.0, 1.0,
        0.0, 0.0,-1.0, 0.0,
        0.0,0.0, 0.0, 1.0,
    }
    ortho[0][0] /= f32(nk_context.width)
    ortho[1][1] /= f32(nk_context.height)

    gl.Enable(gl.BLEND)
    gl.BlendEquation(gl.FUNC_ADD)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Disable(gl.CULL_FACE)
    gl.Disable(gl.DEPTH_TEST)
    gl.Enable(gl.SCISSOR_TEST)

    gl.UseProgram(dev.shader.program)
    gl.UniformMatrix4fv(dev.shader.uniforms["ProjMtx"], 1, false, &ortho[0][0])
    gl.Viewport(0, 0, nk_context.display_width, nk_context.display_height)
    {
        gl.BindVertexArray(dev.vao)
        {
            nk_wait_for_buffer_unlock()
            {
                config: nk.Convert_Config
                vertex_layout := []nk.Draw_Vertex_Layout_Element {
                    {.Position, .Float, cast(i64)offset_of(Nk_Vertex, position)},
                    {.Texcoord, .Float, cast(i64)offset_of(Nk_Vertex, uv)},
                    {.Color, .R8G8B8A8, cast(i64)offset_of(Nk_Vertex, col)},
                    {max(nk.Draw_Vertex_Layout_Attribute), nk.Draw_Vertex_Layout_Format(19), 0},
                }

                config.vertex_layout = raw_data(vertex_layout)
                config.vertex_size = size_of(Nk_Vertex)
                config.vertex_alignment = align_of(Nk_Vertex)
                config.tex_null = dev.null_texture
                config.circle_segment_count = 22
                config.curve_segment_count = 22
                config.arc_segment_count = 22
                config.global_alpha = 1.0
                config.shape_aa = .On
                config.line_aa = .On

                vbuf: nk.Buffer
                nk.buffer_init_fixed(&vbuf, dev.vertex_buffer, MAX_VERTEX_BUFFER)

                ibuf: nk.Buffer
                nk.buffer_init_fixed(&ibuf, dev.index_buffer, MAX_ELEMENT_BUFFER)

                _ = nk.convert(&nk_context.ctx, &dev.cmds, &vbuf, &ibuf, &config)
            }
        }
        offset: uintptr
        for command := nk._draw_begin(&nk_context.ctx, &dev.cmds);
            command != nil; command = nk._draw_next(command, &dev.cmds, &nk_context.ctx) {
            if command.elem_count == 0 do continue

            // handle := nk_get_tex_ogl_handle(command.texture.id)

            // if !gl.IsTextureHandleResidentARB(handle) {
            //     gl.MakeTextureHandleResidentARB(handle)
            // }

            // gl.Uniform2ui(dev.shader.uniforms["Texture"], u32(handle), u32(handle >> 32))
            gl.BindTexture(gl.TEXTURE_2D, u32(command.texture.id))

            gl.Scissor(
                i32(command.clip_rect.x * nk_context.fb_scale.x),
                i32(f32(nk_context.height - i32(command.clip_rect.y + command.clip_rect.h)) * nk_context.fb_scale.y),
                i32(command.clip_rect.w * nk_context.fb_scale.x),
                i32(command.clip_rect.h * nk_context.fb_scale.y),
            )

            gl.DrawElements(gl.TRIANGLES, i32(command.elem_count), gl.UNSIGNED_SHORT, rawptr(offset))
            offset += uintptr(command.elem_count * size_of(u16))
        }
        nk.clear(&nk_context.ctx)
        nk.buffer_clear(&dev.cmds)
    }

    gl.UseProgram(0)
    gl.BindVertexArray(0)
    gl.Disable(gl.BLEND)
    gl.Disable(gl.SCISSOR_TEST)

    nk_lock_buffer()
}

nk_init :: proc(window: glfw.WindowHandle) {
    nk.init_default(&nk_context.ctx, nil)

    nk_context.window = window
    nk_device_create()
}

nk_font_stash_begin :: proc(atlas: ^^nk.Font_Atlas) {
    nk.font_atlas_init_default(&nk_context.atlas)
    nk.font_atlas_begin(&nk_context.atlas)
    atlas^ = &nk_context.atlas
}

nk_font_stash_end :: proc() {
    w, h: i32
    image := nk.font_atlas_bake(&nk_context.atlas, &w, &h, nk.Font_Atlas_Format.RGBA32)
    nk_device_upload_atlas(image, int(w), int(h))
    nk.font_atlas_end(&nk_context.atlas, nk.handle_id(i32(nk_context.device.font_tex_index)), &nk_context.device.null_texture)
    if nk_context.atlas.default_font != nil {
        nk.style_set_font(&nk_context.ctx, &nk_context.atlas.default_font.handle)
    }
}

nk_new_frame :: proc() {
    nk_c := &nk_context
    c := &nk_context.ctx
    w := nk_context.window

    nk_c.width, nk_c.height = glfw.GetWindowSize(w)
    nk_c.display_width, nk_c.display_height = glfw.GetFramebufferSize(w)

    nk_c.fb_scale.x = f32(nk_c.display_width) / f32(nk_c.width)
    nk_c.fb_scale.y = f32(nk_c.display_height) / f32(nk_c.height)

    nk.input_begin(c)
    for i := 0; i < int(nk_c.text_len); i += 1 {
        nk.input_unicode(c, rune(nk_c.text[i]))
    }

    if c.input.mouse.grab != 0 {
        glfw.SetInputMode(w, glfw.CURSOR, glfw.CURSOR_HIDDEN)
    } else if c.input.mouse.ungrab != 0 {
        glfw.SetInputMode(w, glfw.CURSOR, glfw.CURSOR_NORMAL)
    }

    nk.input_key(c, .Del,           b32(is_key_just_pressed(.Delete)))
    nk.input_key(c, .Enter,         b32(is_key_just_pressed(.Enter)))
    nk.input_key(c, .Tab,           b32(is_key_just_pressed(.Tab)))
    nk.input_key(c, .Backspace,     b32(is_key_just_pressed(.Backspace)))
    nk.input_key(c, .Up,            b32(is_key_just_pressed(.Up)))
    nk.input_key(c, .Down,          b32(is_key_just_pressed(.Down)))
    nk.input_key(c, .Text_End,      b32(is_key_just_pressed(.End)))
    nk.input_key(c, .Text_Start,    b32(is_key_just_pressed(.Home)))
    nk.input_key(c, .Scroll_Start,  b32(is_key_just_pressed(.Home)))
    nk.input_key(c, .Scroll_End,    b32(is_key_just_pressed(.End)))
    nk.input_key(c, .Scroll_Down,   b32(is_key_just_pressed(.Page_down)))
    nk.input_key(c, .Scroll_Up,     b32(is_key_just_pressed(.Page_up)))
    nk.input_key(c, .Shift,         b32(is_any_key_just_pressed(.LeftShift, .RightShift)))

    if is_any_key_just_pressed(.LeftControl, .RightControl) {
        nk.input_key(c, .Copy,              b32(is_key_just_pressed(.C)))
        nk.input_key(c, .Paste,             b32(is_key_just_pressed(.V)))
        nk.input_key(c, .Cut,               b32(is_key_just_pressed(.X)))
        nk.input_key(c, .Text_Undo,         b32(is_key_just_pressed(.Z)))
        nk.input_key(c, .Text_Redo,         b32(is_key_just_pressed(.R)))
        nk.input_key(c, .Text_Word_Left,    b32(is_key_just_pressed(.Left)))
        nk.input_key(c, .Text_Word_Right,   b32(is_key_just_pressed(.Right)))
        nk.input_key(c, .Text_Line_Start,   b32(is_key_just_pressed(.B)))
        nk.input_key(c, .Text_Line_End,     b32(is_key_just_pressed(.E)))
        nk.input_key(c, .Text_Select_All,   b32(is_key_just_pressed(.A)))
    } else {
        nk.input_key(c, .Left,  b32(is_key_just_pressed(.Left)))
        nk.input_key(c, .Right, b32(is_key_just_pressed(.Right)))
        nk.input_key(c, .Copy,  b32(false))
        nk.input_key(c, .Paste, b32(false))
        nk.input_key(c, .Cut,   b32(false))
        nk.input_key(c, .Shift, b32(false))
    }

    x, y := glfw.GetCursorPos(w)
    nk.input_motion(c, i32(x), i32(y))

    if c.input.mouse.grabbed != 0 {
        glfw.SetCursorPos(w, f64(c.input.mouse.prev.x), f64(c.input.mouse.prev.y))
        c.input.mouse.pos.x = c.input.mouse.prev.x
        c.input.mouse.pos.y = c.input.mouse.prev.y
    }

    nk.input_button(c, .Left, i32(x), i32(y), b32(is_mouse_down(.left)))
    nk.input_button(c, .Right, i32(x), i32(y), b32(is_mouse_down(.right)))
    nk.input_button(c, .Middle, i32(x), i32(y), b32(is_mouse_down(.middle)))
    nk.input_button(c, .Double, i32(nk_c.double_click_pos.x), i32(nk_c.double_click_pos.y), b32(nk_c.is_double_click_down))
    nk.input_scroll(c, nk_c.scroll)
    nk.input_end(c)

    nk_c.text_len = 0
    nk_c.scroll = {}
}

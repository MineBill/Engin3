package engine
import gl "vendor:OpenGL"
import array "core:container/small_array"
import "core:log"
_ :: log

MSAA_Level :: enum {
    x1 = 1,
    x2 = 2,
    x4 = 4,
    x8 = 8,
}

g_msaa_level: MSAA_Level = .x2

RenderStats :: struct {
    draw_calls: int,
}

g_render_stats: RenderStats

reset_draw_stats :: proc() {
    g_render_stats = {}
}

// Simple wrapper, mostly used to collect stats.
draw_elements :: proc(mode: u32, count: i32, type: u32) {
    g_render_stats.draw_calls += 1
    gl.DrawElements(mode, count, type, nil)
}

draw_arrays :: proc(mode: u32, first, count: int) {
    g_render_stats.draw_calls += 1
    gl.DrawArrays(mode, i32(first), i32(count))
}

UniformBuffer :: struct($T: typeid) {
    handle: RenderHandle,

    using data : T,

    bind_index: u32,
}

create_uniform_buffer :: proc($T: typeid, bind_index: int) -> (buffer: UniformBuffer(T)) {
    buffer.bind_index = u32(bind_index)
    gl.CreateBuffers(1, &buffer.handle)

    gl.NamedBufferStorage(buffer.handle, size_of(T), nil, gl.DYNAMIC_STORAGE_BIT)

    gl.BindBufferBase(gl.UNIFORM_BUFFER, u32(bind_index), buffer.handle)
    return
}

uniform_buffer_upload :: proc(buffer: ^UniformBuffer($T), offset := uintptr(0), size := size_of(T)) {
    gl.NamedBufferSubData(buffer.handle, 0, size_of(buffer.data), &buffer.data)
}

uniform_buffer_set_data :: proc(buffer: ^UniformBuffer($T), offset := uintptr(0), size := size_of(T)) {
    data := uintptr(&buffer.data) + offset
    gl.NamedBufferSubData(buffer.handle, int(offset), int(size), rawptr(data))
}

uniform_buffer_rebind :: proc(buffer: ^UniformBuffer($T)) {
    gl.BindBufferBase(gl.UNIFORM_BUFFER, buffer.bind_index, buffer.handle)
}

Box :: struct {
    pos, size: vec2,
}

RenderHandle :: u32

FrameBufferTextureFormat :: enum {
    None,
    RGBA8,
    RGBA16F,

    RED_INTEGER,

    DEPTH24_STENCIL8,
    DEPTH32F,

    DEPTH = DEPTH24_STENCIL8,
}

FrameBufferSpecification :: struct {
    width, height: int,
    samples: int,
    attachments: array.Small_Array(MAX_FRAMEBUFFER_ATTACHMENTS, FrameBufferTextureFormat),
}

MAX_FRAMEBUFFER_ATTACHMENTS :: 4

FrameBuffer :: struct {
    handle: RenderHandle,
    color_attachments: array.Small_Array(MAX_FRAMEBUFFER_ATTACHMENTS, RenderHandle),
    color_formats: array.Small_Array(MAX_FRAMEBUFFER_ATTACHMENTS, FrameBufferTextureFormat),
    depth_attachment: RenderHandle,
    depth_format: FrameBufferTextureFormat,

    spec: FrameBufferSpecification,
}

@(private="file")
is_depth_format :: proc(format: FrameBufferTextureFormat) -> bool {
    #partial switch format {
    case .DEPTH24_STENCIL8:
        fallthrough
    case .DEPTH32F:
        return true
    }
    return false
}

create_framebuffer :: proc(spec: FrameBufferSpecification) -> (fb: FrameBuffer) {
    spec := spec
    fb.spec = spec

    for format in array.slice(&spec.attachments) {
        if is_depth_format(format) {
            fb.depth_format = format
        } else {
            array.append(&fb.color_formats, format)
        }
    }

    invalidate_framebuffer(&fb)

    return
}

destroy_framebuffer :: proc(fb: FrameBuffer) {
    fb := fb
    gl.DeleteTextures(cast(i32)array.len(fb.color_attachments), raw_data(array.slice(&fb.color_attachments)))
    gl.DeleteTextures(1, &fb.depth_attachment)
    gl.DeleteFramebuffers(1, &fb.handle)
}

invalidate_framebuffer :: proc(fb: ^FrameBuffer) {
    destroy_framebuffer(fb^)

    gl.CreateFramebuffers(1, &fb.handle)

    texture_target :: proc(multisampled: bool) -> u32 {
        return gl.TEXTURE_2D_MULTISAMPLE if multisampled else gl.TEXTURE_2D
    }

    attach_color_texture :: proc(fb: RenderHandle, texture: RenderHandle, samples: int, internal_format: uint, width, height: int, index: int) {
        multisampled := samples > 1

        if multisampled {
            gl.TextureStorage2DMultisample(texture, i32(samples), u32(internal_format), i32(width), i32(height), true)
        } else {
            gl.TextureStorage2D(texture, 1, u32(internal_format), i32(width), i32(height))

            gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
            gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
        }

        gl.NamedFramebufferTexture(fb, u32(gl.COLOR_ATTACHMENT0 + index), texture, 0)
    }

    attach_depth_texture :: proc(fb: RenderHandle, texture: RenderHandle, samples: int, internal_format: uint, width, height: int) {
        multisampled := samples > 1

        if multisampled {
            gl.TextureStorage2DMultisample(texture, i32(samples), u32(internal_format), i32(width), i32(height), true)
        } else {
            gl.TextureStorage2D(texture, 1, u32(internal_format), i32(width), i32(height))

            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_BORDER)
        }

        if internal_format == gl.DEPTH24_STENCIL8 {
            gl.TextureParameteri(texture, gl.DEPTH_STENCIL_TEXTURE_MODE, gl.STENCIL_INDEX)
            gl.NamedFramebufferTexture(fb, gl.DEPTH_STENCIL_ATTACHMENT, texture, 0)
        } else {

            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
            gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
            col := []f32{1, 1, 1, 1}
            gl.TextureParameterfv(texture, gl.TEXTURE_BORDER_COLOR, &col[0])
            gl.NamedFramebufferTexture(fb, gl.DEPTH_ATTACHMENT, texture, 0)
        }
    }

    if array.len(fb.color_formats) > 0 {
        array.resize(&fb.color_attachments, array.len(fb.color_formats))
        gl.CreateTextures(texture_target(fb.spec.samples > 1), cast(i32)array.len(fb.color_formats), raw_data(array.slice(&fb.color_attachments)))

        for format, i in array.slice(&fb.color_formats) {
            texture_handle := fb.color_attachments.data[i]

            #partial switch format {
            case .RGBA8:
            attach_color_texture(fb.handle, texture_handle, fb.spec.samples, gl.RGBA8, fb.spec.width, fb.spec.height, i)
            case .RGBA16F:
            attach_color_texture(fb.handle, texture_handle, fb.spec.samples, gl.RGBA16F, fb.spec.width, fb.spec.height, i)
            case .RED_INTEGER:
            attach_color_texture(fb.handle, texture_handle, fb.spec.samples, gl.R32I, fb.spec.width, fb.spec.height, i)
            }
        }
    }

    if fb.depth_format != .None {
        gl.CreateTextures(texture_target(fb.spec.samples > 1), 1, &fb.depth_attachment)
        #partial switch fb.depth_format {
        case .DEPTH24_STENCIL8:
            attach_depth_texture(fb.handle, fb.depth_attachment, fb.spec.samples, gl.DEPTH24_STENCIL8, fb.spec.width, fb.spec.height)
        case .DEPTH32F:
            attach_depth_texture(fb.handle, fb.depth_attachment, fb.spec.samples, gl.DEPTH_COMPONENT32F, fb.spec.width, fb.spec.height)
        }
    }

    if array.len(fb.color_attachments) > 1 {
        buffers := [4]u32{gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1, gl.COLOR_ATTACHMENT2, gl.COLOR_ATTACHMENT4}

        gl.NamedFramebufferDrawBuffers(fb.handle, i32(array.len(fb.color_attachments)), raw_data(buffers[:]))
    } else if array.len(fb.color_attachments) == 0 {
        gl.NamedFramebufferDrawBuffer(fb.handle, gl.NONE)
    }

    assert(gl.CheckNamedFramebufferStatus(fb.handle, gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
}

get_color_attachment :: proc(fb: FrameBuffer, index := 0) -> RenderHandle {
    assert(index < array.len(fb.color_attachments))
    return fb.color_attachments.data[index]
}

get_depth_attachment :: proc(fb: FrameBuffer) -> RenderHandle {
    return fb.depth_attachment
}

blit_framebuffer :: proc(from, to: FrameBuffer, src_box, dst_box: Box, index := 0, index2 := 0) {
    gl.NamedFramebufferReadBuffer(from.handle, u32(gl.COLOR_ATTACHMENT0 + index))
    gl.NamedFramebufferDrawBuffer(to.handle, u32(gl.COLOR_ATTACHMENT0 + index2))

    gl.BlitNamedFramebuffer(
        from.handle,
        to.handle,
        i32(src_box.pos.x), i32(src_box.pos.y), i32(src_box.size.x), i32(src_box.size.y),
        i32(dst_box.pos.x), i32(dst_box.pos.y), i32(dst_box.size.x), i32(dst_box.size.y),
        gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT, gl.NEAREST)
}

blit_framebuffer_depth :: proc(from, to: FrameBuffer, src_box, dst_box: Box) {
    gl.BlitNamedFramebuffer(
        from.handle,
        to.handle,
        i32(src_box.pos.x), i32(src_box.pos.y), i32(src_box.size.x), i32(src_box.size.y),
        i32(dst_box.pos.x), i32(dst_box.pos.y), i32(dst_box.size.x), i32(dst_box.size.y),
        gl.DEPTH_BUFFER_BIT, gl.NEAREST)
}

resize_framebuffer :: proc(fb: ^FrameBuffer, width, height: int) {
    fb.spec.width = width
    fb.spec.height = height

    invalidate_framebuffer(fb)
}

read_pixel :: proc(fb: FrameBuffer, x, y: int, attachment := 0) -> [4]byte {
    spec := fb.spec
    spec.attachments = attachment_list(.RED_INTEGER)
    spec.samples = 1

    temp_fb := create_framebuffer(spec)
    defer destroy_framebuffer(temp_fb)

    box := Box{{0, 0}, {f32(spec.width), f32(spec.height)}}
    blit_framebuffer(fb, temp_fb, box, box, attachment)

    size := spec.width * spec.height
    gl_format: u32 = ---
    #partial switch array.get(temp_fb.color_formats, 0) {
    case .RGBA8:
        gl_format = gl.RGBA
        size *= 4
    case .RGBA16F:
        gl_format = gl.RGBA
        size *= 8
    case .RED_INTEGER:
        gl_format = gl.RED_INTEGER
    }

    pixel: [4]byte

    gl.GetTextureSubImage(get_color_attachment(temp_fb, 0), 0, i32(x), i32(y), 0, 1, 1, 1, gl_format, gl.UNSIGNED_BYTE, size_of(pixel), raw_data(pixel[:]))

    return pixel
}

attachment_list :: proc(formats: ..FrameBufferTextureFormat) -> (arr: array.Small_Array(MAX_FRAMEBUFFER_ATTACHMENTS, FrameBufferTextureFormat)) {
    assert(len(formats) <= 4)

    for format in formats {
        array.push_back(&arr, format)
    }
    return arr
}

_fb_usage :: proc() {
    spec := FrameBufferSpecification {
        width = 1000,
        height = 200,
        attachments = attachment_list(.RGBA8, .DEPTH),
        samples = 1,
    }

    fb := create_framebuffer(spec)


    resized := true
    if resized {
        invalidate_framebuffer(&fb)
    }

    get_color_attachment(fb, 0)
}

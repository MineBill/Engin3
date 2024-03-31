package engine
import gl "vendor:OpenGL"
import array "core:container/small_array"
import "core:log"
_ :: log

Box :: struct {
    pos, size: vec2,
}

// read_pixel :: proc(framebuffer: Frame_Buffer, attachment: int, x, y: i32) -> u32 {
//     gl.ReadPixels()
// }

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

        // gl.TextureStorage2D(fb.depth_attachment, 1, gl_format, i32(fb.spec.width), i32(fb.spec.height))
        // gl.TextureParameteri(fb.depth_attachment, gl.DEPTH_STENCIL_TEXTURE_MODE, gl.STENCIL_INDEX)

        // // Attach
        // gl.NamedFramebufferTexture(fb.handle, gl.DEPTH_STENCIL_ATTACHMENT, fb.depth_attachment, 0)

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

blit_framebuffer :: proc(from, to: FrameBuffer, src_box, dst_box: Box, index := 0) {
    gl.NamedFramebufferReadBuffer(from.handle, u32(gl.COLOR_ATTACHMENT0 + index))

    gl.BlitNamedFramebuffer(
        from.handle,
        to.handle,
        i32(src_box.pos.x), i32(src_box.pos.y), i32(src_box.size.x), i32(src_box.size.y),
        i32(dst_box.pos.x), i32(dst_box.pos.y), i32(dst_box.size.x), i32(dst_box.size.y),
        gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT, gl.NEAREST)
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
    // data := make([]byte, size)
    // defer delete(data)

    // gl.GetTextureImage(get_color_attachment(temp_fb, 0), 0, gl_format, gl.UNSIGNED_BYTE, i32(size), raw_data(data))

    // pixel := x + y * spec.width

    // return {data[pixel], data[pixel + 1], data[pixel + 2], data[pixel + 3]}

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

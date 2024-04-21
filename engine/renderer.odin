package engine
import gl "vendor:OpenGL"
import array "core:container/small_array"
import "core:math"
import "packages:back"
import "core:io"

GL_DEBUG_CONTEXT :: ODIN_DEBUG

RendererInstance: ^Renderer

Renderer :: struct {
    white_texture:  AssetHandle,
    normal_texture: AssetHandle,
    height_texture: AssetHandle,
}

renderer_init :: proc(r: ^Renderer) {
    when GL_DEBUG_CONTEXT {
        flags: i32
        gl.GetIntegerv(gl.CONTEXT_FLAGS, &flags)
        if flags & gl.CONTEXT_FLAG_DEBUG_BIT != 0 {
            gl.Enable(gl.DEBUG_OUTPUT)
            gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
            gl.DebugMessageCallback(opengl_debug_callback, r)
            gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, true)
        }
    }

    vendor   := gl.GetString(gl.VENDOR)
    renderer := gl.GetString(gl.RENDERER)
    version  := gl.GetString(gl.VERSION)
    log_info(LC.Renderer, "Vendor %v", vendor)
    log_info(LC.Renderer, "\tUsing %v", renderer)
    log_info(LC.Renderer, "\tVersion %v", version)

    data: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &data)
    log_debug(LC.Renderer, "Max texture anistotropy: %v", data)

    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)
    gl.FrontFace(gl.CW)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.FRONT)

    gl.Enable(gl.STENCIL_TEST)
    gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)

    gl.Enable(gl.BLEND)
    gl.BlendEquation(gl.FUNC_ADD)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    spec := TextureSpecification {
        width = 1,
        height = 1,
        samples = 1,
        anisotropy = 1,
        filter = .Nearest,
        format = .RGBA8,
    }

    manager := &EngineInstance.asset_manager

    white_data := []byte {255, 255, 255, 255}
    r.white_texture = create_virtual_asset(manager, new_texture2d(spec, white_data), "Default White Texture")

    normal_data := []byte {128, 128, 255, 255}
    r.normal_texture = create_virtual_asset(manager, new_texture2d(spec, normal_data), "Default Normal Texture")
}

renderer_deinit :: proc(r: ^Renderer) {

}

renderer_set_instance :: proc(r: ^Renderer) {
    RendererInstance = r
}

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
    print_stack_trace_on_error()
}

draw_arrays :: proc(mode: u32, first, count: int) {
    g_render_stats.draw_calls += 1
    gl.DrawArrays(mode, i32(first), i32(count))
    print_stack_trace_on_error()
}

@(private = "file")
print_stack_trace_on_error :: proc() {
    if gl.GetError() != gl.NO_ERROR {
        lines, err := back.lines(back.trace())
        if err == nil {

            log_warning(LC.Renderer, "Stack Trace Begin:")
            for line in lines {
                log_warning(LC.Renderer, "\t%s - %s", line.symbol, line.location)
            }
            log_warning(LC.Renderer, "Stack Trace End")
        }
    }
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
    RED_FLOAT,

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

texture_target :: proc(multisampled: bool, type: TextureType = .Normal) -> u32 {
    switch type {
    case .Normal:
        return gl.TEXTURE_2D_MULTISAMPLE if multisampled else gl.TEXTURE_2D
    case .CubeMap:
        return gl.TEXTURE_CUBE_MAP
    }
    unreachable()
}

invalidate_framebuffer :: proc(fb: ^FrameBuffer) {
    destroy_framebuffer(fb^)

    gl.CreateFramebuffers(1, &fb.handle)

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
            case .RED_FLOAT:
            attach_color_texture(fb.handle, texture_handle, fb.spec.samples, gl.R32F, fb.spec.width, fb.spec.height, i)
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

read_pixel :: proc(fb: FrameBuffer, x, y: int, attachment := 0) -> (pixel: [4]byte, ok: bool) {
    if x < 0 || y < 0 || x >= fb.spec.width || y >= fb.spec.height {
        return {}, false
    }
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
    case .RED_FLOAT:
        gl_format = gl.RED_INTEGER
    }

    gl.GetTextureSubImage(get_color_attachment(temp_fb, 0), 0, i32(x), i32(y), 0, 1, 1, 1, gl_format, gl.UNSIGNED_BYTE, size_of(pixel), raw_data(pixel[:]))

    return pixel, true
}

attachment_list :: proc(formats: ..FrameBufferTextureFormat) -> (arr: array.Small_Array(MAX_FRAMEBUFFER_ATTACHMENTS, FrameBufferTextureFormat)) {
    assert(len(formats) <= 4)

    for format in formats {
        array.push_back(&arr, format)
    }
    return arr
}

Texture2DArray :: struct {
    handle: RenderHandle,
    layers: i32,
    width, height: i32,
    format: u32,
}

create_texture_array :: proc(width, height: i32, format: u32, layers: i32 = 1) -> (texture: Texture2DArray) {
    texture.layers = layers
    texture.width = width
    texture.height = height
    texture.format = format

    gl.CreateTextures(gl.TEXTURE_2D_ARRAY, 1, &texture.handle)
    gl.TextureStorage3D(texture.handle, 1, format, width, height, layers)

    gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    border_color := []f32 { 1.0, 1.0, 1.0, 1.0 }
    gl.TextureParameterfv(texture.handle, gl.TEXTURE_BORDER_COLOR, raw_data(border_color))

    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
    return
}

destroy_texture_array :: proc(texture: Texture2DArray) {
    texture := texture
    gl.DeleteTextures(1, &texture.handle)
}

TextureView :: struct {
    handle: RenderHandle,
}

create_texture_view :: proc(array: Texture2DArray, layer: u32 = 0) -> (view: TextureView) {
    gl.GenTextures(1, &view.handle)
    gl.TextureView(view.handle, gl.TEXTURE_2D, array.handle, array.format, 0, 1, layer, 1)
    return
}

destroy_texture_view :: proc(view: TextureView) {
    view := view
    gl.DeleteTextures(1, &view.handle)
}

TextureFilter :: enum {
    Linear,
    Nearest,
}

texture_filter_to_opengl :: proc(filter: TextureFilter) -> i32 {
    switch filter {
    case .Linear: return gl.LINEAR
    case .Nearest: return gl.NEAREST
    }
    unreachable()
}

TextureFormat :: enum {
    None,

    RGBA8,
    RGB8,

    RGBA16F,
}

texture_format_to_opengl_internal :: proc(format: TextureFormat) -> u32 {
    switch format {
    case .None:
        panic("Forgot to specify texture format")
    case .RGBA8:
        return gl.RGBA8
    case .RGB8:
        return gl.RGB8
    case .RGBA16F:
        return gl.RGBA16F
    }
    unreachable()
}

texture_format_to_opengl :: proc(format: TextureFormat) -> u32 {
    switch format {
    case .None:
        panic("Forgot to specify texture format")
    case .RGBA16F: fallthrough
    case .RGBA8:
        return gl.RGBA
    case .RGB8:
        return gl.RGB
    }
    unreachable()
}

TextureType :: enum {
    Normal,
    CubeMap,
}

TextureWrap :: enum {
    Repeat,
    MirroredRepeat,
    ClampToEdge,
    ClampToBorder,
}

texture_wrap_to_opengl :: proc(wrap: TextureWrap) -> i32 {
    switch wrap {
    case .Repeat:
        return gl.REPEAT
    case .MirroredRepeat:
        return gl.MIRRORED_REPEAT
    case .ClampToEdge:
        return gl.CLAMP_TO_EDGE
    case .ClampToBorder:
        return gl.CLAMP_TO_BORDER
    }
    unreachable()
}

TexturePixelType :: enum {
    None,

    Float,
    Unsigned,
}

texture_pixel_type_to_open :: proc(type: TexturePixelType) -> u32 {
    switch type {
    case .None:
        unreachable()
    case .Float:
        return gl.FLOAT
    case .Unsigned:
        return gl.UNSIGNED_BYTE
    }
    unreachable()
}

TextureSpecification :: struct {
    width, height: int,
    samples: int,
    anisotropy: int,
    filter: TextureFilter,
    format, desired_format: TextureFormat,
    type: TextureType,
    wrap: TextureWrap,
    pixel_type: TexturePixelType,
}

@(asset)
Texture :: struct {
    using base: Asset,

    handle: RenderHandle,
    spec: TextureSpecification,
}

@(asset = {
    ImportFormats = ".png,.jpg,.jpeg",
})
Texture2D :: struct {
    using texture_base: Texture,
}

create_texture2d :: proc(spec: TextureSpecification, data: []byte = {}) -> (texture: Texture2D) {
    spec := spec
    spec.samples = 1 if spec.samples <= 0 else spec.samples
    spec.anisotropy = 1 if spec.anisotropy <= 0 else spec.anisotropy
    spec.desired_format = spec.format if spec.desired_format == nil else spec.desired_format
    spec.pixel_type = .Unsigned if spec.pixel_type == nil else spec.pixel_type

    texture.spec = spec
    multisampled := spec.samples > 1
    gl.CreateTextures(texture_target(multisampled, spec.type), 1, &texture.handle)

    min_image_count := i32(math.floor(math.log2(f32(math.max(spec.width, spec.height))))) + 1
    format := texture_format_to_opengl_internal(spec.desired_format)
    switch spec.type {
    case .CubeMap: fallthrough
    case .Normal:
        if !multisampled {
            gl.TextureStorage2D(texture.handle, min_image_count, format, i32(spec.width), i32(spec.height))

            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, texture_wrap_to_opengl(spec.wrap))
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, texture_wrap_to_opengl(spec.wrap))
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_R, texture_wrap_to_opengl(spec.wrap))
        } else {
            gl.TextureStorage2DMultisample(texture.handle, i32(spec.samples), format, i32(spec.width), i32(spec.height), true)
        }

        gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, texture_filter_to_opengl(spec.filter))
        gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, texture_filter_to_opengl(spec.filter))
        gl.TextureParameteri(texture.handle, gl.TEXTURE_MAX_ANISOTROPY, i32(spec.anisotropy))
        // gl.TextureStorage3D(texture.handle, min_image_count, format, i32(spec.width), i32(spec.height), 6)
    }

    if len(data) > 0 {
        set_texture2d_data(texture, data)
    }

    return
}

new_texture2d :: proc(spec: TextureSpecification, data: []byte = {}) -> (texture: ^Texture2D) {
    texture = new(Texture2D)
    texture^ = create_texture2d(spec, data)
    return
}

set_texture2d_data :: proc(texture: Texture2D, data: []byte, level: i32 = 0, layer := 0) {
    switch texture.spec.type {
    case .Normal:
        gl.TextureSubImage2D(
            texture.handle,
            level,
            0, 0,
            i32(texture.spec.width), i32(texture.spec.height),
            texture_format_to_opengl(texture.spec.format), texture_pixel_type_to_open(texture.spec.pixel_type),
            raw_data(data),
        )
    case .CubeMap:
        gl.TextureSubImage3D(
            texture.handle, 0,
            0, 0, i32(layer),
            i32(texture.spec.width),
            i32(texture.spec.height),
            1,
            texture_format_to_opengl(texture.spec.format), gl.UNSIGNED_BYTE, raw_data(data))
    }

    gl.GenerateTextureMipmap(texture.handle)
}

// CubemapTexture :: struct {
//     using texture_base: Texture,
// }

// create_cubemap_texture :: proc(spec: TextureSpecification) -> (texture: CubemapTexture) {
//     texture.spec = spec

//     gl.CreateTextures(gl.TEXTURE_CUBE_MAP, 1, &texture.handle)

//     gl.TextureStorage2D(texture.handle, 1, params.format, width, height)

//     gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, i32(params.min_filter))
//     gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, i32(params.mag_filter))
//     gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
//     gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
//     gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);

//     return
// }


opengl_debug_callback :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
    // if id == 131169 || id == 131185 || id == 131218 || id == 131204 do return
    e := cast(^Renderer)userParam
    context = EngineInstance.ctx

    source_str: string
    switch source
    {
        case gl.DEBUG_SOURCE_API:             source_str = "API"
        case gl.DEBUG_SOURCE_WINDOW_SYSTEM:   source_str = "Window System"
        case gl.DEBUG_SOURCE_SHADER_COMPILER: source_str = "Shader Compiler"
        case gl.DEBUG_SOURCE_THIRD_PARTY:     source_str = "Third Party"
        case gl.DEBUG_SOURCE_APPLICATION:     source_str = "Application"
        case gl.DEBUG_SOURCE_OTHER:           source_str = "Other"
    }

    type_str: string
    switch type
    {
        case gl.DEBUG_TYPE_ERROR:               type_str = "Error"
        case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: type_str = "Deprecated Behaviour"
        case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  type_str = "Undefined Behaviour"
        case gl.DEBUG_TYPE_PORTABILITY:         type_str = "Portability"
        case gl.DEBUG_TYPE_PERFORMANCE:         type_str = "Performance"
        case gl.DEBUG_TYPE_MARKER:              type_str = "Marker"
        case gl.DEBUG_TYPE_PUSH_GROUP:          type_str = "Push Group"
        case gl.DEBUG_TYPE_POP_GROUP:           type_str = "Pop Group"
        case gl.DEBUG_TYPE_OTHER:               type_str = "Other"
    }

    severity_str: string
    switch severity
    {
        case gl.DEBUG_SEVERITY_HIGH:         severity_str = "high"
        case gl.DEBUG_SEVERITY_MEDIUM:       severity_str = "medium"
        case gl.DEBUG_SEVERITY_LOW:          severity_str = "low"
        case gl.DEBUG_SEVERITY_NOTIFICATION: severity_str = "notification"
    }

    log_warning(LC.Renderer, "OpenGL Debug Messenger:")
    log_warning(LC.Renderer, "\tSource: %v", source_str)
    log_warning(LC.Renderer, "\tType: %v", type_str)
    log_warning(LC.Renderer, "\tSeverity: %v", severity_str)
    log_warning(LC.Renderer, "\tMessage: %v", message)
}

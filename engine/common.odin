package engine
import gl "vendor:OpenGL"
import "core:strings"
import "core:math"
import "core:mem"

vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Color :: distinct vec4

COLOR_RED   :: Color{1, 0, 0, 1}
COLOR_GREEN :: Color{0, 1, 0, 1}
COLOR_BLUE  :: Color{0, 0, 1, 1}
COLOR_BLACK :: Color{0, 0, 0, 1}
COLOR_WHITE :: Color{1, 1, 1, 1}

color_hex :: proc(hex: int) -> Color {
    r: f32 = f32(hex >> 24) / 255
    g: f32 = f32((hex  >> 16) & 0x00FF) / 255
    b: f32 = f32((hex  >> 8) & 0x0000FF) / 255
    a: f32 = f32(hex & 0x000000FF) / 255
    return {r, g, b, a}
}

vec2i :: [2]i32
vec3i :: [3]i32
vec4i :: [4]i32

mat3 :: matrix[3, 3]f32
mat4 :: matrix[4, 4]f32

Engine_Error :: union #shared_nil {
    enum {
        None,
        GLFW_Failed_Init,
        GLFW_Failed_Window,
        Shader,
    }
}

Uniform :: struct {
    projection: mat4,
    view:       mat4,
}

Vertex :: struct {
    position:   vec3,
    normal:     vec3,
    tangent:    vec3,
    uv:         vec2,
    color:      vec3,
}

Texture_Filter :: enum {
    Linear = gl.LINEAR,
    Nearest = gl.NEAREST,
    MipMapLinear = gl.LINEAR_MIPMAP_LINEAR,
    MipMapNearest = gl.NEAREST_MIPMAP_NEAREST,
}

Texture_Wrap :: enum {
    Clamp,
    
}

Texture2D :: struct {
    handle: u32,
    width, height: i32,
    params: Texture_Params,
}

Texture_Params :: struct {
    samples:    i32,
    format:     u32,
    min_filter:     Texture_Filter,
    mag_filter:     Texture_Filter,
    anisotropy: i32,
}

DEFAULT_TEXTURE_PARAMS :: Texture_Params {
    samples = 1,
    format = gl.RGBA,
    min_filter = .Linear,
    mag_filter = .Linear,
}

create_texture :: proc(width, height: int, params := DEFAULT_TEXTURE_PARAMS) -> (texture: Texture2D) {
    width, height := i32(width), i32(height)
    texture.width = width
    texture.height = height
    texture.params = params
    using params

    min_image_count := i32(math.floor(math.log2(f32(math.max(width, height))))) + 1

    if samples == 1 {
        gl.CreateTextures(gl.TEXTURE_2D, 1, &texture.handle)
        gl.TextureStorage2D(texture.handle, min_image_count, format, width, height)
    } else {
        gl.CreateTextures(gl.TEXTURE_2D_MULTISAMPLE, 1, &texture.handle)
        gl.TextureStorage2DMultisample(texture.handle, samples, format, width, height, true)
    }

    gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, i32(min_filter))
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, i32(mag_filter))

    // gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
    // gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)

    // gl.TextureParameteri(texture.handle, gl.TEXTURE_MAX_LEVEL, 10)
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAX_ANISOTROPY, anisotropy)
    return
}

set_texture_data :: proc(texture: Texture2D, data: rawptr, level: i32 = 0) {
    gl.TextureSubImage2D(
        texture.handle,
        level,
        0, 0,
        texture.width, texture.height,
        gl.RGBA, gl.UNSIGNED_BYTE,
        data,
    )

    gl.GenerateTextureMipmap(texture.handle)
}

// params.samples is ignored.
create_cubemap_texture :: proc(width, height: int, params := DEFAULT_TEXTURE_PARAMS) -> (texture: Texture2D) {
    width, height := i32(width), i32(height)
    texture.width = width
    texture.height = height
    texture.params = params

    gl.CreateTextures(gl.TEXTURE_CUBE_MAP, 1, &texture.handle)

    gl.TextureStorage2D(texture.handle, 1, params.format, width, height)

    gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, i32(params.min_filter))
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, i32(params.mag_filter))
    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);

    return
}

OwnedString :: struct {
    s: string,
    allocator: mem.Allocator,
}

// Clones the string and returns an owned string.
owned_string :: proc(s: string, allocator := context.allocator) -> OwnedString {
    return {
        s = strings.clone(s, allocator),
        allocator = allocator,
    }
}

free_owned_string :: proc(os: ^OwnedString) {
    delete(os.s)
}

cstr :: proc(s: string, allocator := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(s, allocator)
}

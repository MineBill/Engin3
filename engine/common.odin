package engine
import gl "vendor:OpenGL"
import "core:strings"
import "core:math"
import "core:mem"
import "core:path/filepath"

@(LuaExport = {
    Name = "vec2",
    Type = {Full, Light},
    SwizzleTypes = {vec3, vec4},
    Fields = xy,
    Metamethods = {
        __tostring = vec2_to_string,
    },
})
vec2 :: [2]f32
Vector2 :: [2]f32

VEC2_ONE :: vec2{1, 1}

@(LuaExport = {
    Name = "vec3",
    Type = {Full, Light},
    SwizzleTypes = {vec2, vec4},
    Fields = xyz,
    Metamethods = {
        __tostring = vec3_to_string,
    },
})
vec3 :: [3]f32
Vector3 :: [3]f32

VEC3_ONE :: vec3{1, 1, 1}

@(LuaExport = {
    Name = "vec4",
    Type = {Full, Light},
    SwizzleTypes = {vec2, vec3},
    Fields = xyzw,
    Metamethods = {
        __tostring = vec4_to_string,
    },
})
vec4 :: [4]f32
Vector4 :: [4]f32

VEC4_ONE :: vec4{1, 1, 1, 1}

Color :: distinct vec4

COLOR_RED       :: Color{1, 0, 0, 1}
COLOR_GREEN     :: Color{0, 1, 0, 1}
COLOR_BLUE      :: Color{0, 0, 1, 1}
COLOR_BLACK     :: Color{0, 0, 0, 1}
COLOR_WHITE     :: Color{1, 1, 1, 1}
COLOR_YELLOW    :: Color{1, 1, 0, 1}
COLOR_CYAN      :: Color{0, 1, 1, 1}
COLOR_MAGENTA   :: Color{1, 0, 1, 1}
COLOR_ORANGE    :: Color{1, 0.5, 0, 1}
COLOR_PURPLE    :: Color{0.5, 0, 1, 1}
COLOR_PINK      :: Color{1, 0.75, 0.8, 1}
COLOR_LIME      :: Color{0.75, 1, 0, 1}
COLOR_SKY_BLUE  :: Color{0.53, 0.81, 0.98, 1}
COLOR_LAVENDER  :: Color{0.71, 0.49, 0.86, 1}
COLOR_PEACH     :: Color{1, 0.8, 0.6, 1}
COLOR_MINT      :: Color{0.74, 0.99, 0.83, 1}
COLOR_CORAL     :: Color{1, 0.5, 0.31, 1}
COLOR_GOLD      :: Color{1, 0.84, 0, 1}
COLOR_SILVER    :: Color{0.75, 0.75, 0.75, 1}
COLOR_PLUM      :: Color{0.56, 0.27, 0.52, 1}
COLOR_TURQUOISE :: Color{0.25, 0.88, 0.82, 1}
COLOR_ROSE      :: Color{1, 0.3, 0.5, 1}

COLOR_TRANSPARENT :: Color{0, 0, 0, 0}

color_hex :: proc(hex: int) -> Color {
    r: f32 = f32(hex >> 24) / 255
    g: f32 = f32((hex  >> 16) & 0x00FF) / 255
    b: f32 = f32((hex  >> 8) & 0x0000FF) / 255
    a: f32 = f32(hex & 0x000000FF) / 255
    return {r, g, b, a}
}

color_lighten :: proc(color: Color, amount_percent: f32) -> Color {
    hsl := rgb_to_hsl(color)
    hsl.l += amount_percent
    return hsl_to_rgb(hsl)
}

color_darken :: proc(color: Color, amount_percent: f32) -> Color {
    hsl := rgb_to_hsl(color)
    hsl.l -= amount_percent
    return hsl_to_rgb(hsl)
}

HSL :: struct {
    h, s, l, a: f32,
}

rgb_to_hsl :: proc(color: Color) -> (hsl: HSL) {
    color := color
    hsl.a = color.a
    max := max(color.r, color.g, color.b)
    min := min(color.r, color.g, color.b)

    hsl.l = (min + max) / 2.0

    if max == min {
        return hsl
    }

    d := max - min
    
    hsl.s = (hsl.l > 0.5) ? d / (2.0 - max - min) : d / (max + min);

    if color.r > color.g && color.r > color.b {
        hsl.h = (color.g - color.b) / d + (color.g < color.b ? 6.0 : 0.0);
    }
    else if color.g > color.b {
        hsl.h = (color.b - color.r) / d + 2.0;
    }
    else {
        hsl.h = (color.r - color.g) / d + 4.0;
    }

    hsl.h /= 6.0;

    return
}

hsl_to_rgb :: proc(hsl: HSL) -> (color: Color) {
    color.a = hsl.a
    if hsl.s == 0 {
        return Color {hsl.l, hsl.l, hsl.l, hsl.a}
    } else {
        q := hsl.l < 0.5 ? hsl.l * (1 + hsl.s) : hsl.l + hsl.s - hsl.l * hsl.s
        p := 2 * hsl.l - q
        color.r = hue_to_rgb(p, q, hsl.h + 1./3.)
        color.g = hue_to_rgb(p, q, hsl.h)
        color.b = hue_to_rgb(p, q, hsl.h - 1./3.)
        color.a = hsl.a
    }
    return
}

hue_to_rgb :: proc(p, q, t: f32) -> f32 {
    t := t

    if t < 0 {
        t += 1
    }
    if t > 1 {
        t -= 1.
    }

    if (t < 1./6.) {
        return p + (q - p) * 6. * t;
    }
    if (t < 1./2.) {
        return q;
    }
    if t < 2./3. {
        return p + (q - p) * (2./3. - t) * 6.;
    }
    return p;
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

clone_map :: proc(m: map[$K]$V, allocator := context.allocator) -> map[K]V {
    r := make(map[K]V, len(m), allocator)
    for k, v in m {
        r[k] = v
    }
    return r
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

make_path :: proc(elements: ..string, allocator := context.allocator) -> string {
    return filepath.join(elements, allocator = allocator)
}

make_tpath :: proc(elements: ..string) -> string {
    return filepath.join(elements, allocator = context.temp_allocator)
}

concat :: proc(ss: ..string, allocator := context.allocator) -> string {
    return strings.concatenate(ss, allocator)
}
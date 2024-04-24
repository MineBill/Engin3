package gpu
import "core:strings"
import vk "vendor:vulkan"
import "core:log"

VALIDATION :: #config(GPU_VALIDATION, true)

make_version :: vk.MAKE_VERSION

Extent2D :: vk.Extent2D
Vector2 :: [2]f32
Vector3 :: [3]f32

check :: #force_inline proc(result: vk.Result, loc := #caller_location) {
    if result != .SUCCESS {
        log.errorf("Vulkan call failed with %v", result, location = loc)
    }
}

cstr :: proc(s: string, allocator := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(s, allocator)
}

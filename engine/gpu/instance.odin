package gpu
import vk "vendor:vulkan"
import glfw "vendor:glfw"
import "core:strings"
import "core:log"
import "base:runtime"
import "core:fmt"

Instance :: struct {
    handle: vk.Instance,

    surface: vk.SurfaceKHR,
    debug_context: ^DebugContext,
}

create_instance :: proc(
    application_name, engine_name: string,
    app_version, engine_version: u32,
    window: glfw.WindowHandle,
    logger := context.logger,
) -> (instance: Instance, error: Error) {
    instance.debug_context = new(DebugContext)

    instance.debug_context.logger = logger
    vk.load_proc_addresses_global(cast(rawptr) glfw.GetInstanceProcAddress)
 
    when VALIDATION {
        if !check_validation_layers() {
            return {}, .FailedValidationCheck
        }
    }

    extensions := get_required_extensions_from_glfw()

    instance_info := vk.InstanceCreateInfo {
        sType =.INSTANCE_CREATE_INFO,
        pApplicationInfo = &vk.ApplicationInfo {
            sType              = .APPLICATION_INFO,
            pApplicationName   = cstr(application_name),
            applicationVersion = app_version,
            pEngineName        = cstr(engine_name),
            engineVersion      = engine_version,
            apiVersion         = vk.API_VERSION_1_3,
        },
        ppEnabledExtensionNames = raw_data(extensions),
        enabledExtensionCount = cast(u32) len(extensions),
    }

    when VALIDATION {
        layers := REQUIRED_VULKAN_LAYERS
        debug_messenger := debug_messenger_create_info(instance.debug_context)
        instance_info.ppEnabledLayerNames = raw_data(layers)
        instance_info.enabledLayerCount = cast(u32) len(layers)
        instance_info.pNext = &debug_messenger
    }


    check(vk.CreateInstance(&instance_info, nil, &instance.handle))
    vk.load_proc_addresses_instance(instance.handle)

    check(glfw.CreateWindowSurface(instance.handle, window, nil, &instance.surface))
    return
}

destroy_instance :: proc(instance: Instance) {
    vk.DestroyInstance(instance.handle, nil)
}

@(private = "file")
get_required_extensions_from_glfw :: proc(allocator := context.temp_allocator) -> []cstring {
    extensions := make([dynamic]cstring)
    glfw_extensions := glfw.GetRequiredInstanceExtensions()
    for ext in glfw_extensions {
        append(&extensions, ext)
    }

    append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

    return extensions[:]
}

@(private = "file")
check_validation_layers :: proc() -> bool {
    log.info("Performing validation layer check")
    count: u32
    vk.EnumerateInstanceLayerProperties(&count, nil)

    properties := make([]vk.LayerProperties, count, context.temp_allocator)
    vk.EnumerateInstanceLayerProperties(&count, raw_data(properties))

    req: for required_layer in REQUIRED_VULKAN_LAYERS {
        found := false
        for &property in properties {
            if required_layer == cstring(raw_data(&property.layerName)) {
                found = true
            }
        }
        if !found {
            log.errorf("Required validation layer '%s' not found!", required_layer)
            return false
        } else {
            log.debugf("Found required validation layer: %v", required_layer)
            break req
        }
    }

    return true
}

@(private = "file")
debug_messenger_create_info :: proc(dbg: ^DebugContext) -> vk.DebugUtilsMessengerCreateInfoEXT {
    return vk.DebugUtilsMessengerCreateInfoEXT {
           sType = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
           messageSeverity = {.ERROR, .VERBOSE, .WARNING},
           messageType = {.DEVICE_ADDRESS_BINDING, .GENERAL, .PERFORMANCE, .VALIDATION},
           pfnUserCallback = debug_context_callback,
           pUserData = dbg,
    }
}

@(private)
create_debug_messenger :: proc(instance: Instance, dbg: ^DebugContext) -> (messenger: vk.DebugUtilsMessengerEXT) {
    info := debug_messenger_create_info(dbg)

    check(vk.CreateDebugUtilsMessengerEXT(instance.handle, &info, nil, &messenger))
    return
}

REQUIRED_VULKAN_LAYERS :: []cstring{
    "VK_LAYER_KHRONOS_validation",
}

DebugContext :: struct {
    logger: log.Logger,
}

@(private = "file")
debug_context_callback :: proc "system" (
    messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
    messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
    pUserData: rawptr,
) -> b32 {
    dbg := cast(^DebugContext)pUserData
    context = runtime.default_context()
    context.logger = dbg.logger

    if strings.contains(string(pCallbackData.pMessage), "deviceCoherentMemory feature") do return false

    switch (messageSeverity) {
    case {.ERROR}:
        log.error(pCallbackData.pMessage)
    case {.VERBOSE}:
    // log.debug(pCallbackData.pMessage)
    case {.INFO}:
        log.info(pCallbackData.pMessage)
    case {.WARNING}:
        log.warn(pCallbackData.pMessage)
    }
    return false
}

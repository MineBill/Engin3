package gpu
import vk "vendor:vulkan"
import "core:log"
import "core:strings"
import "vendor:glfw"
import vma "packages:odin-vma"

Device :: struct {
    handle: vk.Device,
    instance: Instance,
    physical_device: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,

    command_pool: vk.CommandPool,
    properties: vk.PhysicalDeviceProperties,
    debug_messenger: vk.DebugUtilsMessengerEXT,

    allocator: vma.Allocator,
    callbacks: ImageCallbacks,
}

ImageCreateCallback  :: #type proc(user_data: rawptr, image: ^Image)
ImageDestroyCallback :: #type proc(user_data: rawptr, image: ^Image)

ImageCallbacks :: struct {
    user_data: rawptr,

    image_create:  ImageCreateCallback,
    image_destroy: ImageDestroyCallback,
}

create_device :: proc(instance: Instance, callbacks: ImageCallbacks = {}) -> (device: Device) {
    device.instance = instance
    device.callbacks = callbacks

    device.debug_messenger = create_debug_messenger(instance, device.instance.debug_context)
    device.surface = instance.surface

    device_find_suitable_device(&device)
    device_create_logical_device(&device)
    device_create_command_pool(&device)

    funcs := vma.create_vulkan_functions()
    allocator_create_info := vma.AllocatorCreateInfo {
        vulkanApiVersion = vk.API_VERSION_1_3,
        physicalDevice = device.physical_device,
        device = device.handle,
        instance = device.instance.handle,
        pVulkanFunctions = &funcs,
    }
    vma.CreateAllocator(&allocator_create_info, &device.allocator)

    return
}

destroy_device :: proc(#by_ptr device: Device) {
    vk.DestroyCommandPool(device.handle, device.command_pool, nil)

    when VALIDATION {
        vk.DestroyDebugUtilsMessengerEXT(device.instance.handle, device.debug_messenger, nil)
    }

    vk.DestroySurfaceKHR(device.instance.handle, device.surface, nil)
    vk.DestroyDevice(device.handle, nil)

    destroy_instance(device.instance)
}

device_get_name :: proc(device: Device, allocator := context.allocator) -> string {
    device := device
    return strings.clone(string(device.properties.deviceName[:]))
}

_vk_device_create_descriptor_pool :: proc(
    device: Device,
    count: u32,
    sizes: []vk.DescriptorPoolSize,
    flags := vk.DescriptorPoolCreateFlags{},
) -> (pool: vk.DescriptorPool) {
    pool_info := vk.DescriptorPoolCreateInfo {
        sType         = vk.StructureType.DESCRIPTOR_POOL_CREATE_INFO,
        poolSizeCount = u32(len(sizes)),
        pPoolSizes    = raw_data(sizes),
        maxSets       = count,
        flags = flags,
    }

    check(vk.CreateDescriptorPool(device.handle, &pool_info, nil, &pool))
    return
}

@(private)
device_create_image_view :: proc(
    device: Device,
    image: vk.Image,
    mip_levels: u32,
    format: vk.Format,
    aspect: vk.ImageAspectFlags,
    view_type: vk.ImageViewType,
    layer_count: u32 = 1,
) -> (view: vk.ImageView) {
    create_info := vk.ImageViewCreateInfo {
        sType = .IMAGE_VIEW_CREATE_INFO,
        image = image,
        viewType = view_type,
        format = format,
        subresourceRange = vk.ImageSubresourceRange {
            aspectMask = aspect,
            baseMipLevel = 0,
            levelCount = mip_levels,
            baseArrayLayer = 0,
            layerCount = layer_count,
        },
    }

    check(vk.CreateImageView(device.handle, &create_info, nil, &view))
    return
}

@(private)
device_begin_single_time_command :: proc(device: Device) -> CommandBuffer {
    spec := CommandBufferSpecification {tag = "Single Time Command", device = device}
    cmd := create_command_buffer(device, spec)

    cmd_begin(cmd, .SingleTime)
    return cmd
}

@(private)
device_end_single_time_command :: proc(device: Device, cmd: CommandBuffer) {
    cmd := cmd
    cmd_end(cmd, .SingleTime)

    submit_info := vk.SubmitInfo {
        sType              = vk.StructureType.SUBMIT_INFO,
        commandBufferCount = 1,
        pCommandBuffers    = &cmd.handle,
    }

    vk.QueueSubmit(device.graphics_queue, 1, &submit_info, 0)
    vk.QueueWaitIdle(device.graphics_queue)

    destroy_command_buffer(cmd)
}

@(private)
device_create_command_buffer :: proc(device: Device) -> (buffer: vk.CommandBuffer) {
    alloc_info := vk.CommandBufferAllocateInfo {
        sType              = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = device.command_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }

    check(vk.AllocateCommandBuffers(device.handle, &alloc_info, &buffer))
    return
}

@(private)
device_destroy_command_buffer :: proc(device: Device, buffer: vk.CommandBuffer) {
    buffers: []vk.CommandBuffer = {buffer}
    vk.FreeCommandBuffers(device.handle, device.command_pool, 1, raw_data(buffers))
}

@(private)
device_create_semaphore :: proc(device: Device) -> (semaphore: vk.Semaphore) {
    semaphore_info := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
    }

    check(vk.CreateSemaphore(device.handle, &semaphore_info, nil, &semaphore))
    return
}

@(private)
device_destroy_semaphore :: proc(device: Device, semaphore: vk.Semaphore) {
    vk.DestroySemaphore(device.handle, semaphore, nil)
}

@(private)
device_create_semaphores :: proc(device: Device, $count: int) -> (semaphores: [count]vk.Semaphore) {
    for i in 0..<count {
        semaphores[i] = device_create_semaphore(device)
    }
    return
}

@(private)
device_destroy_semaphores :: proc(device: Device, semaphores: []vk.Semaphore) {
    for sema in semaphores {
        device_destroy_semaphore(device, sema)
    }
}

@(private)
device_create_fence :: proc(device: Device, signaled: bool) -> (fence: vk.Fence) {
    fence_info := vk.FenceCreateInfo {
        sType = vk.StructureType.FENCE_CREATE_INFO,
    }

    if signaled {
        fence_info.flags += {.SIGNALED}
    }

    check(vk.CreateFence(device.handle, &fence_info, nil, &fence))
    return
}

@(private)
device_destroy_fence :: proc(device: Device, fence: vk.Fence) {
    vk.DestroyFence(device.handle, fence, nil)
}

@(private)
device_create_fences :: proc(device: Device, $count: int, signaled := true) -> (fences: [count]vk.Fence) {
    for i in 0..<count {
        fences[i] = device_create_fence(device, signaled)
    }
    return
}

@(private)
device_destroy_fences :: proc(device: Device, fences: []vk.Fence) {
    for fence in fences {
        device_destroy_fence(device, fence)
    }
}

@(private)
device_find_suitable_device :: proc(this: ^Device) {
    count: u32
    vk.EnumeratePhysicalDevices(this.instance.handle, &count, nil)

    devices := make([]vk.PhysicalDevice, count, context.temp_allocator)

    vk.EnumeratePhysicalDevices(this.instance.handle, &count, raw_data(devices))

    for dev in devices {
        if is_device_suitable(dev, this.surface) {
            this.physical_device = dev
            vk.GetPhysicalDeviceProperties(this.physical_device, &this.properties)
            return
        }
    }
    log.error("Failed to find a suitable GPU device")
    return
}

@(private)
device_create_logical_device :: proc(device: ^Device) {
    indices := get_queue_families(device.physical_device, device.surface)

    unique_families := get_unique_queue_families(indices)
    queue_info := make(
        [dynamic]vk.DeviceQueueCreateInfo,
        0,
        len(unique_families),
        context.temp_allocator,
    )

    for fam in unique_families {
        queue_priority := []f32{1.0}
        append(
            &queue_info,
            vk.DeviceQueueCreateInfo {
                sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO,
                queueFamilyIndex = fam,
                queueCount = 1,
                pQueuePriorities = raw_data(queue_priority),
            },
        )
    }

    device_features := vk.PhysicalDeviceFeatures {
        samplerAnisotropy = true,
        sampleRateShading = true,
    }

    create_info := vk.DeviceCreateInfo {
        sType                   = vk.StructureType.DEVICE_CREATE_INFO,
        pQueueCreateInfos       = raw_data(queue_info),
        queueCreateInfoCount    = cast(u32) len(queue_info),
        pEnabledFeatures        = &device_features,
        ppEnabledExtensionNames = raw_data(REQUIRED_DEVICE_EXTENSIONS),
        enabledExtensionCount   = cast(u32) len(REQUIRED_DEVICE_EXTENSIONS),
    }

    check(vk.CreateDevice(device.physical_device, &create_info, nil, &device.handle))

    vk.GetDeviceQueue(
        device.handle,
        cast(u32)indices.graphics_family.(int),
        0,
        &device.graphics_queue,
    )

    vk.GetDeviceQueue(
        device.handle,
        cast(u32)indices.present_family.(int),
        0,
        &device.present_queue,
    )
    return
}

@(private)
device_create_command_pool :: proc(device: ^Device) {
    indices := get_queue_families(device.physical_device, device.surface)
    pool_create_info := vk.CommandPoolCreateInfo {
        sType = vk.StructureType.COMMAND_POOL_CREATE_INFO,
        flags = {vk.CommandPoolCreateFlag.RESET_COMMAND_BUFFER},
        queueFamilyIndex = cast(u32)indices.graphics_family.(int),
    }

    check(vk.CreateCommandPool(device.handle, &pool_create_info, nil, &device.command_pool))
}

@(private)
is_device_suitable :: proc(device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> bool {
    indices := get_queue_families(device, surface)
    extensions_supported := check_device_extension_support(device)

    swapchain_good := false
    if extensions_supported {
        details := query_surface_support(device, surface, context.temp_allocator)
        swapchain_good = len(details.formats) > 0 && len(details.present_modes) > 0
    }
    props: vk.PhysicalDeviceFeatures
    vk.GetPhysicalDeviceFeatures(device, &props)

    return is_queue_family_complete(indices) &&
            extensions_supported &&
            swapchain_good &&
            props.samplerAnisotropy
}

@(private)
check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
    count: u32
    vk.EnumerateDeviceExtensionProperties(device, nil, &count, nil)

    properties := make([]vk.ExtensionProperties, count)
    defer delete(properties)
    vk.EnumerateDeviceExtensionProperties(device, nil, &count, raw_data(properties))

    req: for required_device_extension in REQUIRED_DEVICE_EXTENSIONS {
        found := false
        for &property in properties {
            if required_device_extension == cstring(raw_data(&property.extensionName)) {
                found = true
            }
        }
        if !found {
            log.errorf("Required device extention '%s' not found!", required_device_extension)
            return false
        } else {
            log.debug("Found required device extention: ", required_device_extension)
            break req
        }
    }

    return true
}

@(private)
device_get_max_usable_sample_count :: proc(device: ^Device) -> (flags: vk.SampleCountFlags) {
    counts := device.properties.limits.framebufferColorSampleCounts & device.properties.limits.framebufferDepthSampleCounts
    if ._64 in counts {
        return {._64}
    }
    if ._32 in counts {
        return {._32}
    }
    if ._16 in counts {
        return {._16}
    }
    if ._8 in counts {
        return {._8}
    }
    if ._4 in counts {
        return {._4}
    }
    if ._2 in counts {
        return {._2}
    }

    return {._1}
}

@(private)
Queue_Family_Indices :: struct {
    graphics_family: Maybe(int),
    present_family:  Maybe(int),
    compute_family:  Maybe(int),
}

@(private)
is_queue_family_complete :: proc(using family: Queue_Family_Indices) -> bool {
    _, ok := family.graphics_family.?
    _, ok2 := family.present_family.?
    _, ok3 := family.compute_family.?
    return ok && ok2 && ok3
}

@(private)
get_unique_queue_families :: proc(using indices: Queue_Family_Indices) -> [1]u32 {
    graphics, present, compute := cast(u32)graphics_family.(int), cast(u32)present_family.(int), cast(u32)compute_family.(int)
    if graphics == present {
        return {graphics}
    }
    log.error("Present and Graphics indices differe, do something")
    return {0}
}

@(private)
get_queue_families :: proc(
    device: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
) -> (
    indices: Queue_Family_Indices,
) {
    count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

    properties := make([]vk.QueueFamilyProperties, count)
    defer delete(properties)

    vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(properties))

    for property, i in properties {
        if vk.QueueFlag.GRAPHICS in property.queueFlags {
            indices.graphics_family = i
        }

        if vk.QueueFlag.COMPUTE in property.queueFlags {
            indices.compute_family = i
        }

        present_support: b32 = false
        vk.GetPhysicalDeviceSurfaceSupportKHR(device, cast(u32)i, surface, &present_support)
        if present_support {
            indices.present_family = i
        }

        if (is_queue_family_complete(indices)) {
            break
        }
    }
    return
}

REQUIRED_DEVICE_EXTENSIONS :: []cstring {
    vk.KHR_SWAPCHAIN_EXTENSION_NAME,
}

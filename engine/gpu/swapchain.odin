package gpu
import "core:log"
import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 1

Swapchain :: struct {
    handle: vk.SwapchainKHR,
    device: ^Device,
    renderpass: RenderPass,

    current_frame: int,
    images: [dynamic]Image,
    framebuffers: [dynamic]FrameBuffer,
    depth_image: Image,

    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,

    surface_support_details: SurfaceSupportDetails,
    image_count: u32,

    spec: SwapchainSpecification,
}

SwapchainSpecification :: struct {
    device:       ^Device,
    renderpass:   RenderPass,
    extent:       Extent2D,
    present_mode: SwapchainPresentMode,
    format:       ImageFormat,
}

create_swapchain :: proc(spec: SwapchainSpecification) -> (swapchain: Swapchain, error: Error) {
    swapchain.device = spec.device
    swapchain.spec = spec
    swapchain.renderpass = spec.renderpass

    swapchain.surface_support_details = query_surface_support(swapchain.device.physical_device, swapchain.device.instance.surface)

    capabilities := swapchain.surface_support_details.capabilities
    swapchain.image_count = capabilities.minImageCount + 1
    if capabilities.maxImageCount > 0 && swapchain.image_count > capabilities.maxImageCount {
        swapchain.image_count = capabilities.maxImageCount
    }

    swapchain_invalidate(&swapchain)
    return
}

destroy_swapchain :: proc(swapchain: ^Swapchain, keep_handle := false) {
    // for framebuffer in framebuffers {
    //     vk.DestroyFramebuffer(device.device, framebuffer, nil)
    // }
    // delete(framebuffers)

    // for view in swapchain_image_views {
    //     vk.DestroyImageView(device.device, view, nil)
    // }
    // delete(swapchain_image_views)

    // image_destroy(&swapchain.color_image)
    // image_destroy(&swapchain.depth_image)

    // vk.DestroySwapchainKHR(device.device, swapchain_handle, nil)
    // vk.DestroyRenderPass(device.device, renderpass, nil)

    // destroy_semaphores(device, image_available_semaphores)
    // destroy_semaphores(device, render_finished_semaphores)
    // destroy_fences(device, in_flight_fences)
    for &fb in swapchain.framebuffers {
        destroy_framebuffer(&fb)
    }
    delete(swapchain.framebuffers)

    for &image in swapchain.images {
        destroy_image(&image)
    }
    delete(swapchain.images)

    destroy_image(&swapchain.depth_image)

    device_destroy_fences(swapchain.device^, swapchain.in_flight_fences[:])
    device_destroy_semaphores(swapchain.device^, swapchain.image_available_semaphores[:])
    device_destroy_semaphores(swapchain.device^, swapchain.render_finished_semaphores[:])

    if !keep_handle {
        vk.DestroySwapchainKHR(swapchain.device.handle, swapchain.handle, nil)
        swapchain.handle = 0
    }
}

swapchain_resize :: proc(swapchain: ^Swapchain, new_size: Extent2D) {
    swapchain.spec.extent = new_size
    destroy_swapchain(swapchain, keep_handle = true)

    swapchain_invalidate(swapchain)
}

swapchain_invalidate :: proc(swapchain: ^Swapchain) -> (error: SwapchainCreationError) {
    swapchain.current_frame = 0

    details := query_surface_support(swapchain.device.physical_device, swapchain.device.instance.surface, context.temp_allocator)
    _ = details

    swapchain_create_info := vk.SwapchainCreateInfoKHR {
        sType = .SWAPCHAIN_CREATE_INFO_KHR,
        surface = swapchain.device.instance.surface,
        minImageCount = swapchain.image_count,
        imageFormat = image_format_to_vulkan(swapchain.spec.format),
        imageColorSpace = .SRGB_NONLINEAR,
        presentMode = present_mode_to_vulkan(swapchain.spec.present_mode),
        imageExtent = swapchain.spec.extent,
        imageArrayLayers = 1,
        imageUsage = {.COLOR_ATTACHMENT, .TRANSFER_SRC},
        imageSharingMode = .EXCLUSIVE,
        preTransform = swapchain.surface_support_details.capabilities.currentTransform,
        compositeAlpha = {.OPAQUE},
        clipped = true,
        oldSwapchain = swapchain.handle,
    }

    check(vk.CreateSwapchainKHR(swapchain.device.handle, &swapchain_create_info, nil, &swapchain.handle))

    // Get images.
    swapchain_get_images(swapchain)

    // Create image views.
    // swapchain_create_image_views(swapchain)

    // Create depth image.
    spec := ImageSpecification {
        device = swapchain.device,
        format = .D32_SFLOAT,
        width  = cast(int) swapchain.spec.extent.width,
        height = cast(int) swapchain.spec.extent.height,
        samples = 1,
        usage  = {.DepthStencilAttachment},
    }
    swapchain.depth_image = create_image(spec)

    swapchain_create_framebuffers(swapchain)

    swapchain.in_flight_fences = device_create_fences(swapchain.spec.device^, MAX_FRAMES_IN_FLIGHT, true)
    swapchain.image_available_semaphores = device_create_semaphores(swapchain.spec.device^, MAX_FRAMES_IN_FLIGHT)
    swapchain.render_finished_semaphores = device_create_semaphores(swapchain.spec.device^, MAX_FRAMES_IN_FLIGHT)
    return
}

swapchain_get_next_image :: proc(sw: ^Swapchain) -> (image: u32, error: SwapchainError) {
    vk.WaitForFences(sw.spec.device.handle, 1, &sw.in_flight_fences[sw.current_frame], true, max(u64))
    vk.ResetFences(sw.spec.device.handle, 1, &sw.in_flight_fences[sw.current_frame])

    vk_err := vk.AcquireNextImageKHR(sw.device.handle, sw.handle, max(u64), sw.image_available_semaphores[sw.current_frame], 0, &image)
    #partial switch vk_err {
    case .ERROR_OUT_OF_DATE_KHR:
        error = .SwapchainOutOfDate
    case .SUBOPTIMAL_KHR:
        error = .SwapchainSuboptimal
    }
    return
}

swapchain_cmd_submit :: proc(swapchain: ^Swapchain, cmds: []CommandBuffer) {
    wait_semaphores: []vk.Semaphore =  {
        swapchain.image_available_semaphores[swapchain.current_frame],
    }
    signal_semaphores: []vk.Semaphore =  {
        swapchain.render_finished_semaphores[swapchain.current_frame],
    }
    flags := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}

    buffers := make([dynamic]vk.CommandBuffer, 0, len(cmds), context.temp_allocator)
    for cmd in cmds {
        append(&buffers, cmd.handle)
    }

    submit_info := vk.SubmitInfo {
        sType                = .SUBMIT_INFO,
        waitSemaphoreCount   = u32(len(wait_semaphores)),
        pWaitSemaphores      = raw_data(wait_semaphores),
        pWaitDstStageMask    = &flags,
        commandBufferCount   = u32(len(buffers)),
        pCommandBuffers      = raw_data(buffers),
        signalSemaphoreCount = u32(len(signal_semaphores)),
        pSignalSemaphores    = raw_data(signal_semaphores),
    }

    check(
        vk.QueueSubmit(
            swapchain.device.graphics_queue,
            1,
            &submit_info,
            swapchain.in_flight_fences[swapchain.current_frame],
        ),
    )
}

swapchain_present :: proc(sw: ^Swapchain, image: u32) {
    image := image

    wait_semaphores: []vk.Semaphore =  {
        sw.image_available_semaphores[sw.current_frame],
    }
    signal_semaphores: []vk.Semaphore =  {
        sw.render_finished_semaphores[sw.current_frame],
    }

    swapchains: []vk.SwapchainKHR = {sw.handle}

    present_info := vk.PresentInfoKHR {
        sType              = .PRESENT_INFO_KHR,
        waitSemaphoreCount = u32(len(signal_semaphores)),
        pWaitSemaphores    = raw_data(signal_semaphores),
        swapchainCount     = u32(len(swapchains)),
        pSwapchains        = raw_data(swapchains),
        pImageIndices      = &image,
    }

    check(vk.QueuePresentKHR(sw.spec.device.present_queue, &present_info))
    sw.current_frame = (sw.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

@(private = "file")
swapchain_get_images :: proc(swapchain: ^Swapchain) {
    // Query for count first.
    swapchain_image_count: u32
    vk.GetSwapchainImagesKHR(swapchain.device.handle, swapchain.handle, &swapchain_image_count, nil)

    vk_images := make([dynamic]vk.Image, swapchain_image_count, context.temp_allocator)
    vk.GetSwapchainImagesKHR(swapchain.device.handle, swapchain.handle, &swapchain_image_count, raw_data(vk_images[:]))

    swapchain.images = make([dynamic]Image, 0, len(vk_images))
    for vk_image in vk_images {
        spec := ImageSpecification {
            device       = swapchain.spec.device,
            format       = swapchain.spec.format,
            width        = cast(int) swapchain.spec.extent.width,
            height       = cast(int) swapchain.spec.extent.height,
            samples      = 1,
            usage        = {.TransferDst, .ColorAttachment},
            layout       = .Undefined,
        }

        image := create_image_from_existing_vk_image(vk_image, spec)
        append(&swapchain.images, image)
    }
}

// @(private = "file")
// swapchain_create_image_views :: proc(swapchain: ^Swapchain) {
//     swapchain.image_views = make([dynamic]vk.ImageView, 0, len(swapchain.images))

//     for image in swapchain.images {
//         view := device_create_image_view(
//                   swapchain.device^,
//                   image,
//                   1,
//                   swapchain_format_to_vulkan(swapchain.spec.format),
//                   {.COLOR},
//                   .D2)
//         append(&swapchain.image_views, view)
//     }
// }

@(private = "file")
swapchain_create_framebuffers :: proc(swapchain: ^Swapchain) {
    swapchain.framebuffers = make([dynamic]FrameBuffer, 0, len(swapchain.images))
    for i in 0..<len(swapchain.images) {
        // fb_create_info := vk.FramebufferCreateInfo {
        //     sType = vk.StructureType.FRAMEBUFFER_CREATE_INFO,
        //     renderPass = swapchain.spec.renderpass.handle,
        //     attachmentCount = 1,
        //     pAttachments = &swapchain.image_views[i],
        //     width = swapchain.spec.extent.width,
        //     height = swapchain.spec.extent.height,
        //     layers = 1,
        // }

        // check(vk.CreateFramebuffer(swapchain.spec.device.handle, &fb_create_info, nil, &swapchain.framebuffers[i]))
        spec := FrameBufferSpecification {
            device = swapchain.spec.device,
            renderpass = swapchain.spec.renderpass,
            width  = cast(int) swapchain.spec.extent.width,
            height = cast(int) swapchain.spec.extent.height,
        }

        images := []Image{swapchain.images[i], swapchain.depth_image}
        append(&swapchain.framebuffers, create_framebuffer_from_images(spec, images))
    }
}

// @(private = "file")
// choose_swapchain_format :: proc(available_formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
//     assert(len(available_formats) > 0)
//     for format in available_formats {
//         if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
//             return format
//         }
//     }

//     log.errorf("Could not find an SRGB surface format for the swapchain. Using %v", available_formats[0])
//     return available_formats[0]
// }

// @(private = "file")
// choose_swapchain_present_mode :: proc(available_present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
//     for mode in available_present_modes {
//         if mode == .MAILBOX {
//             return .MAILBOX
//         }
//     }
//     return .FIFO
// }

SwapchainPresentMode :: enum {
    Fifo,
    Mailbox,
}

@(private = "file")
present_mode_to_vulkan :: proc(mode: SwapchainPresentMode) -> vk.PresentModeKHR {
    switch mode {
    case .Fifo:
        return .FIFO
    case .Mailbox:
        return .MAILBOX
    }
    unreachable()
}

@(private)
SurfaceSupportDetails :: struct {
    capabilities:  vk.SurfaceCapabilitiesKHR,
    formats:       []vk.SurfaceFormatKHR,
    present_modes: []vk.PresentModeKHR,
}

@(private)
delete_surface_support_details :: proc(details: ^SurfaceSupportDetails) {
    delete(details.formats)
    delete(details.present_modes)
}

@(private)
query_surface_support :: proc(
    device: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    allocator := context.allocator,
) -> (
    details: SurfaceSupportDetails,
) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities)

    format_count: u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, nil)

    if format_count != 0 {
        details.formats = make([]vk.SurfaceFormatKHR, format_count, allocator)
        vk.GetPhysicalDeviceSurfaceFormatsKHR(
            device,
            surface,
            &format_count,
            raw_data(details.formats),
        )
    }

    present_mode_count: u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, nil)
    if present_mode_count != 0 {
        details.present_modes = make([]vk.PresentModeKHR, present_mode_count, allocator)
        vk.GetPhysicalDeviceSurfacePresentModesKHR(
            device,
            surface,
            &present_mode_count,
            raw_data(details.present_modes),
        )
    }
    return
}


SwapchainCreationError :: enum {
    None,
}

SwapchainError :: enum {
    None,
    SwapchainOutOfDate,
    SwapchainSuboptimal
}

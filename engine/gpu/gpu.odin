package gpu

import vk "vendor:vulkan"
import array "core:container/small_array"
import vma "packages:odin-vma"

MAX_FRAMEBUFFER_ATTACHMENTS :: 4

FrameBuffer :: struct {
    handle: vk.Framebuffer,

    color_attachments: [dynamic]Image,
    color_formats: [dynamic]ImageFormat,

    depth_attachment: Image,
    depth_format: ImageFormat,

    spec: FrameBufferSpecification,
}

FrameBufferSpecification :: struct {
    device: ^Device,
    renderpass: RenderPass,
    width, height: int,
    samples: int,
    attachments: [dynamic]ImageFormat,
    dont_create_images: bool,
}

@(private = "file")
assert_spec :: proc(spec: FrameBufferSpecification) {
    assert(len(spec.attachments) <= MAX_FRAMEBUFFER_ATTACHMENTS)
    assert(spec.samples <= 1 || spec.samples == 4)
    return
}

// This constructor is used to create a framebuffer. The framebuffer will create
// the required images from the attachments.
create_framebuffer :: proc(spec: FrameBufferSpecification) -> (framebuffer: FrameBuffer) {
    assert_spec(spec)
    framebuffer.spec = spec

    // Sort through the spec attachements and figure which is which.
    for format in spec.attachments {
        if is_depth_format(format) {
            framebuffer.depth_format = format
        } else {
            append(&framebuffer.color_formats, format)
        }
    }

    framebuffer_invalidate(&framebuffer)
    return
}

destroy_framebuffer :: proc(fb: ^FrameBuffer) {
    if !fb.spec.dont_create_images {
        for &image in fb.color_attachments {
            destroy_image(&image)
        }
        destroy_image(&fb.depth_attachment)
    }

    vk.DestroyFramebuffer(fb.spec.device.handle, fb.handle, nil)
}

// This constructor is used to create a framebuffer from an existing image.
@(private)
create_framebuffer_from_images :: proc(spec: FrameBufferSpecification, images: []Image) -> (framebuffer: FrameBuffer) {
    assert_spec(spec)
    framebuffer.spec = spec
    framebuffer.spec.dont_create_images = true

    // Since we have the image only here, we need to do the work now:
    // append(&framebuffer.color_formats, image.spec.format)
    // framebuffer.depth_format = image.spec.format
    for image in images {
        if is_depth_format(image.spec.format) {
            framebuffer.depth_attachment = image
        } else {
            append(&framebuffer.color_attachments, image)
        }
    }

    framebuffer_invalidate(&framebuffer)
    return
}

framebuffer_resize :: proc(fb: ^FrameBuffer, new_size: Vector2) {
    vk.DeviceWaitIdle(fb.spec.device.handle)
    fb.spec.width = int(new_size.x)
    fb.spec.height = int(new_size.y)

    destroy_framebuffer(fb)
    framebuffer_invalidate(fb)
}

framebuffer_invalidate :: proc(fb: ^FrameBuffer) {
    // Check if the spec has attachments and create the required images.
    if !fb.spec.dont_create_images  {
        if len(fb.color_formats) > 0 {
            fb.color_attachments = make([dynamic]Image, 0, len(fb.color_formats))

            for format in fb.color_formats {
                spec := ImageSpecification {
                    device = fb.spec.device,
                    format = format,
                    width = fb.spec.width,
                    height = fb.spec.height,
                    samples = fb.spec.samples,
                    usage = {.Sampled, .TransferSrc, .TransferDst, .ColorAttachment},
                }

                append(&fb.color_attachments, create_image(spec))

                // image_create_info := vk.ImageCreateInfo {
                //     sType = .IMAGE_CREATE_INFO,
                //     imageType = .D2,
                //     format = image_format_to_vulkan(fb.spec.attachments[0]),
                //     extent = vk.Extent3D {
                //         width  = cast(u32) fb.spec.width,
                //         height = cast(u32) fb.spec.height,
                //         depth  = 1,
                //     },
                //     mipLevels = 1,
                //     arrayLayers = 1,
                //     samples = samples_to_vulkan(fb.spec.samples),
                //     tiling = .OPTIMAL,
                //     usage = image_usage_to_vulkan({.Sampled, .TransferSrc, .TransferDst}),
                //     sharingMode = .EXCLUSIVE,
                //     initialLayout = .UNDEFINED,
                // }

                // allocation_create_info := vma.AllocationCreateInfo {
                //     usage = .AUTO,
                //     flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
                // }

                // vma.CreateImage(fb.spec.device.allocator, &image_create_info, &allocation_create_info, &attachment.handle, &attachment.allocation, nil)
            }
        }

        if fb.depth_format != .None {
            spec := ImageSpecification {
                device = fb.spec.device,
                width = fb.spec.width,
                height = fb.spec.height,
                samples = fb.spec.samples,
                format = fb.depth_format,
                usage = {.Sampled, .TransferSrc, .TransferDst, .DepthStencilAttachment},
            }
            fb.depth_attachment = create_image(spec)
        }
    }

    // sType:           StructureType,
    // pNext:           rawptr,
    // flags:           FramebufferCreateFlags,
    // renderPass:      RenderPass,
    // attachmentCount: u32,
    // pAttachments:    [^]ImageView,
    // width:           u32,
    // height:          u32,
    // layers:          u32,

    attachments := make([dynamic]vk.ImageView)

    for attachment in fb.color_attachments {
        append(&attachments, attachment.view.handle)
    }

    if fb.depth_attachment.handle != 0 {
        append(&attachments, fb.depth_attachment.view.handle)
    }

    fb_create_info := vk.FramebufferCreateInfo {
        sType           = .FRAMEBUFFER_CREATE_INFO,
        renderPass      = fb.spec.renderpass.handle,
        attachmentCount = cast(u32) len(attachments),
        pAttachments    = raw_data(attachments),
        width           = cast(u32) fb.spec.width,
        height          = cast(u32) fb.spec.height,
        layers          = 1,
    }

    check(vk.CreateFramebuffer(fb.spec.device.handle, &fb_create_info, nil, &fb.handle))
}

@(private)
is_depth_format :: proc(format: ImageFormat) -> bool {
    #partial switch format {
    case .DEPTH24_STENCIL8: fallthrough
    case .DEPTH32_SFLOAT: fallthrough
    case .D32_SFLOAT: fallthrough
    case .D16_UNORM:
        return true
    }
    return false
}

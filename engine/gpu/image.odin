package gpu
import vk "vendor:vulkan"
import vma "packages:odin-vma"
import "core:fmt"

Image :: Texture
Texture :: struct {
    handle: vk.Image,
    allocation: vma.Allocation,
    view: ImageView,

    spec: ImageSpecification,
}

ImageSpecification :: struct {
    device: ^Device,
    width, height: int,
    samples: int,
    format: ImageFormat,
    usage: ImageUsageFlags,
    layout: ImageLayout,
}

create_image :: proc(spec: ImageSpecification) -> (image: Image) {
    image.spec = spec

    image_create_info := vk.ImageCreateInfo {
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        format = image_format_to_vulkan(spec.format),
        extent = vk.Extent3D {
            width  = cast(u32) spec.width,
            height = cast(u32) spec.height,
            depth  = 1,
        },
        mipLevels = 1,
        arrayLayers = 1,
        samples = samples_to_vulkan(spec.samples),
        tiling = .OPTIMAL,
        usage = image_usage_to_vulkan(spec.usage),
        sharingMode = .EXCLUSIVE,
        initialLayout = image_layout_to_vulkan(spec.layout),
    }

    allocation_create_info := vma.AllocationCreateInfo {
        usage = .AUTO,
        flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
    }

    check(vma.CreateImage(
        spec.device.allocator,
        &image_create_info,
        &allocation_create_info,
        &image.handle,
        &image.allocation,
        nil))

    image.view = create_image_view(spec.device^, image, ImageViewSpecification {
        format = spec.format,
        view_type = .D2,
    })
    return
}

@(private)
create_image_from_existing_vk_image :: proc(vk_image: vk.Image, spec: ImageSpecification) -> (image: Image) {
    image.spec = spec
    image.handle = vk_image

    image.view = create_image_view(spec.device^, image, ImageViewSpecification {
        format = spec.format,
        view_type = .D2,
    })
    return
}

ImageView :: struct {
    handle: vk.ImageView,
}

ImageViewSpecification :: struct {
    view_type: TextureViewType,
    format: ImageFormat,
}

create_image_view :: proc(device: Device, image: Image, spec: ImageViewSpecification) -> (view: ImageView) {
    aspect_mask: vk.ImageAspectFlag
    if is_depth_format(spec.format) {
        aspect_mask = .DEPTH
    } else {
        aspect_mask = .COLOR
    }

    image_view_create_info := vk.ImageViewCreateInfo {
        sType    = .IMAGE_VIEW_CREATE_INFO,
        viewType = texture_view_type_to_vulkan(spec.view_type),
        format   = image_format_to_vulkan(spec.format),
        image    = image.handle,
        subresourceRange = vk.ImageSubresourceRange {
            aspectMask     = {aspect_mask},
            baseMipLevel   = 0,
            levelCount     = 1,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
    }

    check(vk.CreateImageView(device.handle, &image_view_create_info, nil, &view.handle))
    return
}

transition_image_layout :: proc(device: Device, image: ^Image, new_layout: ImageLayout) {
    command_buffer := device_begin_single_time_command(device)
    defer device_end_single_time_command(device, command_buffer)
    old := image.spec.layout
    image.spec.layout = new_layout

    barrier := vk.ImageMemoryBarrier {
        sType = .IMAGE_MEMORY_BARRIER,
        oldLayout = image_layout_to_vulkan(image.spec.layout),
        newLayout = image_layout_to_vulkan(new_layout),
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image = image.handle,
        subresourceRange = vk.ImageSubresourceRange {
            aspectMask = {.COLOR},
            baseMipLevel = 0,
            levelCount = 1,
            baseArrayLayer = 0,
            layerCount = 1,
        },
    }

    srcStage: vk.PipelineStageFlags = {.TOP_OF_PIPE}
    dstStage: vk.PipelineStageFlags = {.TOP_OF_PIPE}

    if old == .Undefined && new_layout == .TransferDstOptimal {
        barrier.srcAccessMask = {}
        barrier.dstAccessMask = {.TRANSFER_WRITE}
        srcStage = {.HOST}
        dstStage = {.TRANSFER}
    } else if old == .TransferDstOptimal && new_layout == .ShaderReadOnlyOptimal {
        barrier.srcAccessMask = {.TRANSFER_WRITE}
        barrier.dstAccessMask = {.SHADER_READ}
        srcStage = {.TRANSFER}
        dstStage = {.FRAGMENT_SHADER}
    } else {
        fmt.panicf("Unsupported layout transition!")
    }

    vk.CmdPipelineBarrier(command_buffer.handle, srcStage, dstStage, {}, 0, nil, 0, nil, 1, &barrier)
}

TextureType :: enum {
    D2,
    D3,
}

@(private)
texture_type_to_vulkan :: proc(texture_type: TextureType) -> (view_type: vk.ImageType) {
    switch texture_type {
    case .D2:
        return .D2
    case .D3:
        return .D3
    }
    unreachable()
}

TextureViewType :: enum {
    D2,
    D3,
    CubeMap,
}

@(private)
texture_view_type_to_vulkan :: proc(texture_view_type: TextureViewType) -> (view_type: vk.ImageViewType) {
    switch texture_view_type {
    case .D2:
        return .D2
    case .D3:
        return .D3
    case .CubeMap:
        return .CUBE
    }
    unreachable()
}

TextureWrap :: enum {
    ClampToEdge,
    ClampToBorder,
    MirroredRepeat,
    Repeat,
}

@(private)
texture_wrap_to_vulkan :: proc(texture_wrap: TextureWrap) -> (wrap: vk.SamplerAddressMode) {
    switch texture_wrap {
    case .ClampToEdge:
        return .CLAMP_TO_EDGE
    case .ClampToBorder:
        return .CLAMP_TO_BORDER
    case .MirroredRepeat:
        return .MIRRORED_REPEAT
    case .Repeat:
        return .REPEAT
    }
    unreachable()
}

TextureFilter :: enum {
    Linear,
    Nearest,
}

@(private)
texture_filter_to_vulkan :: proc(texture_filter: TextureFilter) -> (filter: vk.Filter) {
    switch texture_filter {
    case .Linear:
        return .LINEAR
    case .Nearest:
        return .NEAREST
    }
    unreachable()
}

ImageUsage :: enum {
    None,
    ColorAttachment,
    DepthStencilAttachment,
    Sampled,
    Storage,
    TransferSrc,
    TransferDst,
    Input,
}

ImageUsageFlags :: bit_set[ImageUsage]

@(private)
image_usage_to_vulkan :: proc(image_usage: ImageUsageFlags) -> (usage: vk.ImageUsageFlags) {
    for u in image_usage {
        switch u {
        case .None:
            fmt.panicf("Cannot have .None as an ImageUsage; did you forget to choose one?")
        case .ColorAttachment:
            usage += {.COLOR_ATTACHMENT}
        case .DepthStencilAttachment:
            usage += {.DEPTH_STENCIL_ATTACHMENT}
        case .Sampled:
            usage += {.SAMPLED}
        case .Storage:
            usage += {.STORAGE}
        case .TransferSrc:
            usage += {.TRANSFER_SRC}
        case .TransferDst:
            usage += {.TRANSFER_DST}
        case .Input:
            usage += {.INPUT_ATTACHMENT}
        }
    }
    return usage
}

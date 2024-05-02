package gpu
import vk "vendor:vulkan"
import vma "packages:odin-vma"
import "core:fmt"
import "core:mem"

Image :: struct {
    id: UUID,
    _destroy_handle: bool,
    handle: vk.Image,
    allocation: vma.Allocation,
    view: ImageView,
    sampler: Sampler,

    spec: ImageSpecification,
}

ImageSpecification :: struct {
    tag: cstring,
    device: ^Device,
    width, height: int,
    samples: int,
    format: ImageFormat,
    usage: ImageUsageFlags,
    layout, final_layout: ImageLayout,
    sampler: SamplerSpecification,
}

create_image :: proc(spec: ImageSpecification) -> (image: Image) {
    image.id = new_id()
    image.spec = spec
    image._destroy_handle = true

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

    image.view = create_image_view(image, ImageViewSpecification {
        device = spec.device,
        format = spec.format,
        view_type = .D2,
    })

    image.sampler = create_sampler(spec.device^, spec.sampler)

    if spec.device.callbacks.image_create != nil {
        spec.device.callbacks.image_create(spec.device.callbacks.user_data, &image)
    }
    return
}

destroy_image :: proc(image: ^Image) {
    if image.handle == 0 do return
    if image._destroy_handle {
        // vk.DestroyImage(image.spec.device.handle, image.handle, nil)
        if image.spec.device.callbacks.image_destroy != nil {
            image.spec.device.callbacks.image_destroy(image.spec.device.callbacks.user_data, image)
        }
        vma.DestroyImage(image.spec.device.allocator, image.handle, image.allocation)
    }

    destroy_image_view(&image.view)
    destroy_sampler(image.spec.device^, image.sampler)
}

image_set_data :: proc(image: ^Image, data: []byte = {}) {
    // Create temp buffer
    spec := BufferSpecification {
        device = image.spec.device,
        name = "Staging Buffer",
        size = image.spec.width * image.spec.height * 4,
        usage = {.TransferSource},
        mapped = true,
    }
    buffer := create_buffer(spec)
    defer destroy_buffer(buffer)

    // Do we need to "flush" the copy?
    mem.copy(buffer.alloc_info.pMappedData, raw_data(data), len(data))

    image_transition_layout(image, .TransferDstOptimal)
    buffer_copy_to_image(buffer, image^)
    image_transition_layout(image, .ShaderReadOnlyOptimal)
}

@(private)
create_image_from_existing_vk_image :: proc(vk_image: vk.Image, spec: ImageSpecification) -> (image: Image) {
    image.spec = spec
    image.handle = vk_image

    image.view = create_image_view(image, ImageViewSpecification {
        device = spec.device,
        format = spec.format,
        view_type = .D2,
    })
    return
}

ImageView :: struct {
    id: UUID,
    handle: vk.ImageView,

    spec: ImageViewSpecification,
}

ImageViewSpecification :: struct {
    device: ^Device,

    view_type: TextureViewType,
    format: ImageFormat,
}

create_image_view :: proc(image: Image, spec: ImageViewSpecification) -> (view: ImageView) {
    view.id = new_id()
    view.spec = spec
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

    check(vk.CreateImageView(spec.device.handle, &image_view_create_info, nil, &view.handle))
    return
}

destroy_image_view :: proc(view: ^ImageView) {
    vk.DestroyImageView(view.spec.device.handle, view.handle, nil)
}

image_transition_layout :: proc(image: ^Image, new_layout: ImageLayout, old: Maybe(ImageLayout) = nil) {
    command_buffer := device_begin_single_time_command(image.spec.device^)
    defer device_end_single_time_command(image.spec.device^, command_buffer)

    old := image.spec.layout if old == nil else old.?
    if old == new_layout {
        return
    }
    image.spec.layout = new_layout

    barrier := vk.ImageMemoryBarrier {
        sType = .IMAGE_MEMORY_BARRIER,
        oldLayout = image_layout_to_vulkan(old),
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
    } else if old == .ShaderReadOnlyOptimal && new_layout == .TransferDstOptimal {
        barrier.srcAccessMask = {.SHADER_READ}
        barrier.dstAccessMask = {.TRANSFER_WRITE}
        srcStage = {.FRAGMENT_SHADER}
        dstStage = {.TRANSFER}
    } else if old == .ColorAttachmentOptimal && new_layout == .ShaderReadOnlyOptimal {
        barrier.srcAccessMask = {.COLOR_ATTACHMENT_WRITE}
        barrier.dstAccessMask = {.SHADER_READ}
        srcStage = {.COLOR_ATTACHMENT_OUTPUT}
        dstStage = {.FRAGMENT_SHADER}
    } else if old == .ColorAttachmentOptimal && new_layout == .TransferSrcOptimal {
        barrier.srcAccessMask = {.COLOR_ATTACHMENT_WRITE}
        barrier.dstAccessMask = {.TRANSFER_READ}
        srcStage = {.COLOR_ATTACHMENT_OUTPUT}
        dstStage = {.TRANSFER}
    } else if old == .TransferSrcOptimal && new_layout == .ColorAttachmentOptimal {
        barrier.srcAccessMask = {.TRANSFER_READ}
        barrier.dstAccessMask = {.COLOR_ATTACHMENT_WRITE}
        srcStage = {.TRANSFER}
        dstStage = {.COLOR_ATTACHMENT_OUTPUT}
    } else if old == .TransferDstOptimal && new_layout == .ColorAttachmentOptimal {
        // Complete this
    } else {
        fmt.panicf("Unsupported layout transition from '%v' to '%v'!", old, new_layout)
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

Sampler :: struct {
    id: UUID,
    handle: vk.Sampler,

    spec: SamplerSpecification,
}

SamplerSpecification :: struct {
    wrap:   TextureWrap,
    filter: TextureFilter,
    use_anisotropy: bool,
    use_depth_compare: bool,
    border_color: SamplerBorderColor,
}

SamplerBorderColor :: enum {
    Transparent,
    Black,
    White,
}

@(private)
sampler_border_color_to_vulkan :: proc(color: SamplerBorderColor) -> vk.BorderColor {
    switch color {
    case .Transparent:
        return .FLOAT_TRANSPARENT_BLACK
    case .Black:
        return .FLOAT_OPAQUE_BLACK
    case .White:
        return .FLOAT_OPAQUE_WHITE
    }
    unreachable()
}

create_sampler :: proc(device: Device, spec: SamplerSpecification) -> (sampler: Sampler) {
    sampler.id = new_id()
    sampler.spec = spec

    sampler_create_info := vk.SamplerCreateInfo {
        sType = .SAMPLER_CREATE_INFO,
        magFilter = texture_filter_to_vulkan(spec.filter),
        minFilter = texture_filter_to_vulkan(spec.filter),
        mipmapMode = .LINEAR,
        addressModeU = texture_wrap_to_vulkan(spec.wrap),
        addressModeV = texture_wrap_to_vulkan(spec.wrap),
        addressModeW = texture_wrap_to_vulkan(spec.wrap),
        mipLodBias = 0.0,
        anisotropyEnable = cast(b32) spec.use_anisotropy,
        maxAnisotropy = 1.0 if spec.use_anisotropy else 0.0,
        compareEnable = cast(b32) spec.use_depth_compare,
        compareOp = .ALWAYS,
        minLod = 0.0,
        maxLod = max(f32),
        borderColor = sampler_border_color_to_vulkan(spec.border_color),
        unnormalizedCoordinates = false,
    }

    vk.CreateSampler(device.handle, &sampler_create_info, nil, &sampler.handle)
    return
}

destroy_sampler :: proc(device: Device, sampler: Sampler) {
    vk.DestroySampler(device.handle, sampler.handle, nil)
}

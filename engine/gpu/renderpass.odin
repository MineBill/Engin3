package gpu
import vk "vendor:vulkan"
import array "core:container/small_array"
import "core:fmt"
import "core:log"

RenderPass :: struct {
    id: UUID,
    handle: vk.RenderPass,

    spec: RenderPassSpecification,
}

RenderPassSpecification :: struct {
    tag:         cstring,
    device:      ^Device,
    attachments: [dynamic]RenderPassAttachment,
    subpasses:   [dynamic]RenderPassSubpass,
}

create_render_pass :: proc(spec: RenderPassSpecification) -> (renderpass: RenderPass) {
    renderpass.id = new_id()
    renderpass.spec = spec

    attachments := [dynamic]vk.AttachmentDescription {}
    for &attachment in renderpass.spec.attachments {
        attachment.samples = 1 if attachment.samples == 0 else attachment.samples

        vk_attachment := vk.AttachmentDescription {
            format         = image_format_to_vulkan(attachment.format),
            samples        = samples_to_vulkan(attachment.samples),
            loadOp         = load_op_to_vulkan(attachment.load_op),
            storeOp        = store_op_to_vulkan(attachment.store_op),
            stencilLoadOp  = load_op_to_vulkan(attachment.stencil_load_op),
            stencilStoreOp = store_op_to_vulkan(attachment.stencil_store_op),
            initialLayout  = image_layout_to_vulkan(attachment.initial_layout),
            finalLayout    = image_layout_to_vulkan(attachment.final_layout),
        }

        append(&attachments, vk_attachment)
    }

    dependencies := make([dynamic]vk.SubpassDependency, 0, len(spec.subpasses), context.temp_allocator)
    subpasses    := make([dynamic]vk.SubpassDescription, 0, len(spec.subpasses), context.temp_allocator)

    for subpass, i in spec.subpasses {
        i := u32(i)

        colors_ref := make([dynamic]vk.AttachmentReference, context.temp_allocator)
        input_refs := make([dynamic]vk.AttachmentReference, context.temp_allocator)

        src_stage_mask, dst_stage_mask: vk.PipelineStageFlags
        src_access_mask, dst_access_mask: vk.AccessFlags
        for color_ref in subpass.color_attachments {
            append(&colors_ref, vk.AttachmentReference {
                attachment = cast(u32) color_ref.attachment,
                layout = image_layout_to_vulkan(color_ref.layout),
            })

            #partial switch spec.attachments[color_ref.attachment].final_layout {
            case .PresentSrc:
                fallthrough
            case .ColorAttachmentOptimal:
                flags := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}
                src_stage_mask += flags
                dst_stage_mask += flags
            }

            if color_ref.layout == .ColorAttachmentOptimal {
                dst_access_mask += {.COLOR_ATTACHMENT_WRITE}
            }
        }

        for input_ref in subpass.input_attachments {
            append(&input_refs, vk.AttachmentReference {
                attachment = cast(u32) input_ref.attachment,
                layout = image_layout_to_vulkan(input_ref.layout),
            })

            if spec.attachments[input_ref.attachment].final_layout == .ColorAttachmentOptimal {
                dst_stage_mask += {.FRAGMENT_SHADER}
                if input_ref.layout == .ShaderReadOnlyOptimal {
                    dst_access_mask += {.COLOR_ATTACHMENT_READ}
                }
            }
        }

        vk_depth_ref: ^vk.AttachmentReference
        if depth_ref, ok := subpass.depth_stencil_attachment.?; ok {
            vk_depth_ref = &vk.AttachmentReference {
                attachment = cast(u32) depth_ref.attachment,
                layout = image_layout_to_vulkan(depth_ref.layout),
            }
            src_stage_mask += {.EARLY_FRAGMENT_TESTS}
            dst_stage_mask += {.FRAGMENT_SHADER}

            #partial switch spec.attachments[depth_ref.attachment].final_layout {
            // case .DepthStencilAttachmentOptimal:
            //     dst_access_mask += {.DEPTH_STENCIL_ATTACHMENT_WRITE}
            case .DepthStencilReadOnlyOptimal:
                dst_access_mask += {.DEPTH_STENCIL_ATTACHMENT_READ}
            }
        }

        vk_subpass := vk.SubpassDescription {
            pipelineBindPoint = .GRAPHICS,
            colorAttachmentCount = cast(u32) len(subpass.color_attachments),
            pColorAttachments = raw_data(colors_ref),
            pDepthStencilAttachment = vk_depth_ref,
        }

        dep := vk.SubpassDependency {
            srcSubpass    = i - 1 if i > 0 else vk.SUBPASS_EXTERNAL,
            dstSubpass    = i,
            srcStageMask  = src_stage_mask,
            srcAccessMask = src_access_mask,
            dstStageMask  = dst_stage_mask,
            dstAccessMask = dst_access_mask,
        }

        log.debugf("Configured a subpass: %#v", vk_subpass)
        log.debugf("Configured a subpass dependency: %#v", dep)

        append(&subpasses, vk_subpass)
        append(&dependencies, dep)
    }

    renderpass_create_info := vk.RenderPassCreateInfo {
        sType           = .RENDER_PASS_CREATE_INFO,
        attachmentCount = cast(u32) len(attachments),
        pAttachments    = raw_data(attachments),
        subpassCount    = cast(u32) len(subpasses),
        pSubpasses      = raw_data(subpasses),
        dependencyCount = cast(u32) len(dependencies),
        pDependencies   = raw_data(dependencies),
    }

    check(vk.CreateRenderPass(spec.device.handle, &renderpass_create_info, nil, &renderpass.handle))
    return
}

@(deferred_in=render_pass_end)
do_render_pass :: proc(cmd_buffer: CommandBuffer, renderpass: RenderPass, framebuffer: FrameBuffer) -> bool {
    render_pass_begin(cmd_buffer, renderpass, framebuffer)
    return true
}

render_pass_begin :: proc(cmd_buffer: CommandBuffer, renderpass: RenderPass, framebuffer: FrameBuffer) {
    g_stats.renderpasses[renderpass.id] = {}

    clear_values := make([dynamic]vk.ClearValue, context.temp_allocator)
    for attachment in renderpass.spec.attachments {
        if is_depth_format(attachment.format) {
            append(&clear_values, vk.ClearValue {
                depthStencil = vk.ClearDepthStencilValue {
                    depth = attachment.clear_depth,
                    stencil = attachment.clear_stencil,
                },
            })
        } else {
            append(&clear_values, vk.ClearValue {
                color = vk.ClearColorValue {
                    float32 = attachment.clear_color,
                },
            })
        }
    }

    begin_info := vk.RenderPassBeginInfo {
        sType             = .RENDER_PASS_BEGIN_INFO,
        renderPass        = renderpass.handle,
        framebuffer       = framebuffer.handle,
        clearValueCount   = cast(u32) len(clear_values),
        pClearValues      = raw_data(clear_values),
        renderArea        = vk.Rect2D {
            offset = vk.Offset2D {
                x = 0,
                y = 0,
            },
            extent = vk.Extent2D {
                width  = cast(u32) framebuffer.spec.width,
                height = cast(u32) framebuffer.spec.height,
            },
        },
    }

    vk.CmdBeginRenderPass(cmd_buffer.handle, &begin_info, .INLINE)
}

render_pass_end :: proc(cmd: CommandBuffer, _: RenderPass, _: FrameBuffer) {
    vk.CmdEndRenderPass(cmd.handle)
}

RenderPassAttachment :: struct {
    tag: cstring,
    load_op: RenderPassAttachLoadOp,
    store_op: RenderPassAttachStoreOp,
    format: ImageFormat,
    samples: int,
    stencil_load_op: RenderPassAttachLoadOp,
    stencil_store_op: RenderPassAttachStoreOp,
    stencil_clear_value: int,
    stencil_format: ImageFormat,
    initial_layout: ImageLayout,
    final_layout: ImageLayout,

    clear_color: [4]f32,
    clear_depth: f32,
    clear_stencil: u32,
}

@(private)
samples_to_vulkan :: proc(samples: int) -> vk.SampleCountFlags {
    switch samples {
    case 1:
        return {._1}
    case 2:
        return {._2}
    case 4:
        return {._4}
    case 8:
        return {._8}
    case 16:
        return {._16}
    case 32:
        return {._32}
    case 64:
        return {._64}
    }
    unreachable()
}

RenderPassSubpass :: struct {
    color_attachments:        [dynamic]RenderPassAttachmentRef,
    depth_stencil_attachment: Maybe(RenderPassAttachmentRef),
    resolve_attachments:      [dynamic]RenderPassAttachmentRef,
    input_attachments:        [dynamic]RenderPassAttachmentRef,
}

RenderPassAttachmentRef :: struct {
    attachment: int,
    layout: ImageLayout,
}

make_list :: proc(items: []$T) -> (list: [dynamic]T) {
    for item in items {
        append(&list, item)
    }
    return
}

RenderPassAttachLoadOp :: enum {
    DontCare,
    Load,
    Clear,
}

RenderPassAttachStoreOp :: enum {
    DontCare,
    Store,
}

@(private = "file")
load_op_to_vulkan :: proc(mode: RenderPassAttachLoadOp) -> vk.AttachmentLoadOp {
    switch mode {
    case .DontCare:
        return .DONT_CARE
    case .Load:
        return .LOAD
    case .Clear:
        return .CLEAR
    }
    unreachable()
}

@(private = "file")
store_op_to_vulkan :: proc(mode: RenderPassAttachStoreOp) -> vk.AttachmentStoreOp {
    switch mode {
    case .DontCare:
        return .DONT_CARE
    case .Store:
        return .STORE
    }
    unreachable()
}

ImageLayout :: enum {
    Undefined,
    ColorAttachmentOptimal,
    DepthStencilAttachmentOptimal,
    DepthStencilReadOnlyOptimal,
    ShaderReadOnlyOptimal,
    TransferSrcOptimal,
    TransferDstOptimal,
    PresentSrc,
    AttachmentOptimal,
}

// @(private)
image_layout_to_vulkan :: proc(layout: ImageLayout, loc := #caller_location) -> vk.ImageLayout {
    switch layout {
    case .Undefined:
        return .UNDEFINED
        // fmt.panicf("Cannot have .Undefined as an ImageLayout; did you forget to choose one?", loc = loc)
    case .ColorAttachmentOptimal:
        return .COLOR_ATTACHMENT_OPTIMAL
    case .DepthStencilAttachmentOptimal:
        return .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
    case .DepthStencilReadOnlyOptimal:
        return .DEPTH_STENCIL_READ_ONLY_OPTIMAL
    case .ShaderReadOnlyOptimal:
        return .SHADER_READ_ONLY_OPTIMAL
    case .TransferSrcOptimal:
        return .TRANSFER_SRC_OPTIMAL
    case .TransferDstOptimal:
        return .TRANSFER_DST_OPTIMAL
    case .PresentSrc:
        return .PRESENT_SRC_KHR
    case .AttachmentOptimal:
        return .ATTACHMENT_OPTIMAL
    }
    unreachable()
}

ImageFormat :: enum {
    None,
    R8G8B8A8_SRGB,
    B8G8R8A8_SRGB,
    R8G8B8A8_UNORM,
    B8G8R8A8_UNORM,
    R16G16B16A16_SFLOAT,
    D16_UNORM,
    D32_SFLOAT,
    DEPTH24_STENCIL8,
    DEPTH32_SFLOAT,
}

@(private)
image_format_to_vulkan :: proc(format: ImageFormat, loc := #caller_location) -> vk.Format {
    switch format {
    case .None:
        fmt.panicf("Cannot have .None as an ImageForamt; did you forget to choose one?", loc = loc)
    case .R8G8B8A8_SRGB:
        return .R8G8B8A8_SRGB
    case .B8G8R8A8_SRGB:
        return .B8G8R8A8_SRGB
    case .R8G8B8A8_UNORM:
        return .R8G8B8A8_UNORM
    case .B8G8R8A8_UNORM:
        return .B8G8R8A8_UNORM
    case .R16G16B16A16_SFLOAT:
        return .R16G16B16A16_SFLOAT
    case .D16_UNORM:
        return .D16_UNORM
    case .D32_SFLOAT:
        return .D32_SFLOAT
    case .DEPTH24_STENCIL8:
        return .D24_UNORM_S8_UINT
    case .DEPTH32_SFLOAT:
        return .D32_SFLOAT
    }
    unreachable()
}

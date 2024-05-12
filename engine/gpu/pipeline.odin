package gpu
import vk "vendor:vulkan"

Pipeline :: struct {
    id: UUID,
    handle: vk.Pipeline,
    device: ^Device,

    spec: PipelineSpecification,
}

PipelineSpecification :: struct {
    tag:              cstring,
    layout:           PipelineLayout,
    attribute_layout: VertexAttributeLayout,
    renderpass:       RenderPass,
    config:           Maybe(PipelineConfig),

    shader:           Shader,
}
import "core:fmt"

create_pipeline :: proc(device: ^Device, spec: PipelineSpecification) -> (pipeline: Pipeline, error: PipelineCreationError) {
    pipeline.id = new_id()
    pipeline.device = device
    pipeline.spec = spec

    vert_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {vk.ShaderStageFlag.VERTEX},
        module = spec.shader.vertex_module,
        pName = "main",
    }

    frag_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {vk.ShaderStageFlag.FRAGMENT},
        module = spec.shader.fragment_module,
        pName = "main",
    }

    stages := []vk.PipelineShaderStageCreateInfo{vert_stage_create_info, frag_stage_create_info}

    binding_desc := vertex_vulkan_binding_description(spec.attribute_layout)
    attribute_desc := vertex_vulkan_attribute_description(spec.attribute_layout)

    vertex_input_state := vk.PipelineVertexInputStateCreateInfo {
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 1 if len(spec.attribute_layout.attributes) > 0 else 0,
        pVertexBindingDescriptions = &binding_desc if len(spec.attribute_layout.attributes) > 0 else nil,
        vertexAttributeDescriptionCount = cast(u32) len(attribute_desc),
        pVertexAttributeDescriptions = raw_data(attribute_desc) if len(attribute_desc) > 0 else nil,
    }

    viewport:= vk.Viewport {}
    scissor:= vk.Rect2D {}
    viewport_state_create_info := vk.PipelineViewportStateCreateInfo {
        sType         = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports    = &viewport,
        scissorCount  = 1,
        pScissors     = &scissor,
    }

    dynamic_states := []vk.DynamicState{vk.DynamicState.VIEWPORT, vk.DynamicState.SCISSOR}
    dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo {
        sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = cast(u32) len(dynamic_states),
        pDynamicStates    = raw_data(dynamic_states),
    }

    config := default_pipeline_config() if spec.config == nil else spec.config.?

    blend_attachments := make([dynamic]vk.PipelineColorBlendAttachmentState)
    for thing in spec.renderpass.spec.subpasses[0].color_attachments {
        append(&blend_attachments, config.colorblend_attachment_info)
    }
    config.colorblend_info.attachmentCount = u32(len(blend_attachments))
    config.colorblend_info.pAttachments = raw_data(blend_attachments)

    pipeline_create_info := vk.GraphicsPipelineCreateInfo {
        sType = .GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount          = 2,
        pStages             = raw_data(stages),
        pVertexInputState   = &vertex_input_state,
        pInputAssemblyState = &config.input_assembly_info,
        pViewportState      = &viewport_state_create_info,
        pRasterizationState = &config.rasterization_info,
        pMultisampleState   = &config.multisample_info,
        pDepthStencilState  = &config.depth_stencil_info,
        pColorBlendState    = &config.colorblend_info,
        pDynamicState       = &dynamic_state_create_info,
        layout              = spec.layout.handle,
        renderPass          = spec.renderpass.handle,
        subpass             = 0,
        basePipelineHandle  = 0,
        basePipelineIndex   = -1,
    }
    check(vk.CreateGraphicsPipelines(device.handle, 0, 1, &pipeline_create_info, nil, &pipeline.handle))

    set_handle_name(device, pipeline.handle, .PIPELINE, spec.tag)
    return
}

pipeline_bind :: proc(cmd: CommandBuffer, pipeline: Pipeline) {
    vk.CmdBindPipeline(cmd.handle, .GRAPHICS, pipeline.handle)
}

PipelineLayout :: struct {
    id: UUID,
    handle: vk.PipelineLayout,

    spec: PipelineLayoutSpecification,
}

PipelineLayoutSpecification :: struct {
    tag: cstring,
    device: ^Device,
    // descriptor_set_layout: ...
    layouts: [dynamic]ResourceLayout,
    use_push: bool,
}

create_pipeline_layout :: proc(spec: PipelineLayoutSpecification, T: Maybe(int) = {}) -> (layout: PipelineLayout) {
    layout.id = new_id()
    layout.spec = spec

    layouts := make([dynamic]vk.DescriptorSetLayout, 0, len(spec.layouts), context.temp_allocator)

    for l in spec.layouts {
        append(&layouts, l.handle)
    }

    range: vk.PushConstantRange
    if t, ok := T.?; ok {
        range = vk.PushConstantRange {
            size = u32(t),
            offset = 0,
            stageFlags = {.VERTEX, .FRAGMENT},
        }
    }

    pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = cast(u32) len(spec.layouts),
        pSetLayouts = raw_data(layouts),
        pushConstantRangeCount = 1 if spec.use_push else 0,
        pPushConstantRanges = &range,
    }

    check(vk.CreatePipelineLayout(spec.device.handle, &pipeline_layout_create_info, nil, &layout.handle))

    set_handle_name(spec.device, layout.handle, .PIPELINE_LAYOUT, spec.tag)
    return
}

PipelineConfig :: struct {
    input_assembly_info:        vk.PipelineInputAssemblyStateCreateInfo,
    rasterization_info:         vk.PipelineRasterizationStateCreateInfo,
    multisample_info:           vk.PipelineMultisampleStateCreateInfo,
    colorblend_attachment_info: vk.PipelineColorBlendAttachmentState,
    colorblend_info:            vk.PipelineColorBlendStateCreateInfo,
    depth_stencil_info:         vk.PipelineDepthStencilStateCreateInfo,
}

default_pipeline_config :: proc() -> (config: PipelineConfig) {
    config.input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo {
        sType                  = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology               = vk.PrimitiveTopology.TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    // Rasterizer
    config.rasterization_info = vk.PipelineRasterizationStateCreateInfo {
        sType = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthBiasEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = vk.PolygonMode.FILL,
        lineWidth = 1,
        cullMode = {vk.CullModeFlag.BACK},
        frontFace = vk.FrontFace.CLOCKWISE,
        depthClampEnable = false,
    }

    config.multisample_info = vk.PipelineMultisampleStateCreateInfo {
        sType = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable = false,
        rasterizationSamples = {vk.SampleCountFlag._1},
    }

    config.colorblend_attachment_info = vk.PipelineColorBlendAttachmentState {
        colorWriteMask =  {
            vk.ColorComponentFlag.R,
            vk.ColorComponentFlag.G,
            vk.ColorComponentFlag.B,
            vk.ColorComponentFlag.A,
        },
        blendEnable = false,
        srcColorBlendFactor = vk.BlendFactor.SRC_ALPHA,
        dstColorBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA,
        colorBlendOp = vk.BlendOp.ADD,
        srcAlphaBlendFactor = vk.BlendFactor.SRC_ALPHA,
        dstAlphaBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA,
        alphaBlendOp = vk.BlendOp.ADD,
    }

    config.colorblend_info = vk.PipelineColorBlendStateCreateInfo {
        sType           = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable   = false,
        attachmentCount = 1,
        pAttachments    = nil,
    }

    config.depth_stencil_info = vk.PipelineDepthStencilStateCreateInfo {
        sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        depthTestEnable       = true,
        depthWriteEnable      = true,
        depthCompareOp        = .LESS,
        depthBoundsTestEnable = false,
        stencilTestEnable     = false,
    }
    return
}

VertexElementType :: enum {
    None,
    Float,
    Float2,
    Float3,
    Float4,
    Int,
    Int2,
    Int3,
    Int4,
    Mat3,
    Mat4,
}

@(private)
vertex_element_type_to_vulkan :: proc(type: VertexElementType) -> vk.Format {
    switch type {
    case .None:
        return .UNDEFINED
    case .Int:
        return .R32_SINT
    case .Int2:
        return .R32G32_SINT
    case .Int3:
        return .R32G32B32_SINT
    case .Int4:
        return .R32G32B32A32_SINT
    case .Float:
        return .R32_SFLOAT
    case .Float2:
        return .R32G32_SFLOAT
    case .Float3:
        return .R32G32B32_SFLOAT
    case .Float4:
        return .R32G32B32A32_SFLOAT
    case .Mat3:
        return .R32G32B32_SFLOAT
    case .Mat4:
        return .R32G32B32A32_SFLOAT
    }
    unreachable()
}

// Returns size in bytes of a `VertexElementType`.
vertex_element_size :: proc(type: VertexElementType) -> int {
    return 4 * vertex_element_count(type)
}

vertex_element_count :: proc(type: VertexElementType) -> int {
    switch type {
    case .None:
        return 0
    case .Int, .Float:
        return 1
    case .Int2, .Float2:
        return 2
    case .Int3, .Float3:
        return 3
    case .Int4, .Float4:
        return 4
    case .Mat3:
        return 3 * 3
    case .Mat4:
        return 4 * 4
    }
    return 0
}

VertexAttribute :: struct {
    name: cstring,
    type: VertexElementType,

    offset: int,
}

VertexAttributeLayout :: struct {
    attributes: [dynamic]VertexAttribute,

    stride: int,
}

vertex_layout :: proc(attributes: ..VertexAttribute) -> (layout: VertexAttributeLayout) {
    layout.attributes = make([dynamic]VertexAttribute)
    attributes := attributes

    offset := 0
    for &attr in attributes {
        attr.offset = offset
        append(&layout.attributes, attr)

        offset += vertex_element_size(attr.type)
    }
    layout.stride = offset

    return
}

@(private)
vertex_vulkan_binding_description :: proc(layout: VertexAttributeLayout) -> vk.VertexInputBindingDescription {
    return {
        binding = 0,
        stride = cast(u32) layout.stride,
        inputRate = .VERTEX,
    }
}

@(private)
vertex_vulkan_attribute_description :: proc(
    layout: VertexAttributeLayout,
    allocator := context.allocator,
) -> (thing: [dynamic]vk.VertexInputAttributeDescription) {
    for attr, i in layout.attributes {
        description := vk.VertexInputAttributeDescription {
            binding = 0,
            location = u32(i),
            format = vertex_element_type_to_vulkan(attr.type),
            offset = cast(u32) attr.offset,
        }
        append(&thing, description)
    }
    return
}

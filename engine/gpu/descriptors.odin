package gpu
import vk "vendor:vulkan"

ResourcePool :: struct {
    id: UUID,
    handle: vk.DescriptorPool,

    spec: ResourcePoolSpecification,
}

ResourcePoolSpecification :: struct {
    device: ^Device,
    max_sets: int,
    resource_limits: [dynamic]ResourceLimit,
}

create_resource_pool :: proc(spec: ResourcePoolSpecification) -> (pool: ResourcePool) {
    pool.spec = spec

    limits := make([dynamic]vk.DescriptorPoolSize, 0, len(spec.resource_limits))
    for limit in spec.resource_limits {
        pool_size := vk.DescriptorPoolSize {
            type = resource_type_to_vulkan(limit.resource),
            descriptorCount = cast(u32) limit.limit,
        }
        append(&limits, pool_size)
    }

    pool_info := vk.DescriptorPoolCreateInfo {
        sType         = vk.StructureType.DESCRIPTOR_POOL_CREATE_INFO,
        poolSizeCount = cast(u32) len(spec.resource_limits),
        pPoolSizes    = raw_data(limits),
        maxSets       = cast(u32) spec.max_sets,
        flags = {.FREE_DESCRIPTOR_SET},
    }

    check(vk.CreateDescriptorPool(spec.device.handle, &pool_info, nil, &pool.handle))
    return
}

Resource :: struct {
    id: UUID,
    handle: vk.DescriptorSet,

    layout: ResourceLayout,
    spec: ResourceSpecification,
}

ResourceSpecification :: struct {

}

allocate_resource :: proc(pool: ResourcePool, layout: ResourceLayout) -> (resource: Resource, error: ResourceAllocationError) {
    // descriptorPool:     DescriptorPool,
    // descriptorSetCount: u32,
    // pSetLayouts:        [^]DescriptorSetLayout,
    a := layout.handle
    // resource.layout = layout.set_layout
    alloc_info := vk.DescriptorSetAllocateInfo {
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = pool.handle,
        descriptorSetCount = 1,
        pSetLayouts = &a,
    }

    result := vk.AllocateDescriptorSets(pool.spec.device.handle, &alloc_info, &resource.handle)
    #partial switch result {
    case .ERROR_OUT_OF_POOL_MEMORY:
        error = .OutOfMemory
    case:
        check(result)
    }
    return
}

resource_bind_buffer :: proc(resource: Resource, buffer: Buffer, type: ResourceType) {
    buffer_info := vk.DescriptorBufferInfo {
        buffer = buffer.handle,
        range = vk.DeviceSize(vk.WHOLE_SIZE),
        offset = {},
    }

    a := vk.WriteDescriptorSet {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = resource.handle,
        dstBinding = 0,
        pBufferInfo = &buffer_info,
        descriptorType = resource_type_to_vulkan(type),
        descriptorCount = 1,
        dstArrayElement = 0,
    }

    vk.UpdateDescriptorSets(buffer.spec.device.handle, 1, &a, 0, nil)
}

ResourceType :: enum {
    None,
    CombinedImageSampler,
    InputAttachment,
    UniformBuffer,
    StorageBuffer,
}

@(private)
resource_type_to_vulkan :: proc(type: ResourceType) -> vk.DescriptorType {
    switch type {
    case .None:
    case .UniformBuffer:
        return .UNIFORM_BUFFER
    case .StorageBuffer:
        return .STORAGE_BUFFER
    case .InputAttachment:
        return .INPUT_ATTACHMENT
    case .CombinedImageSampler:
        return .COMBINED_IMAGE_SAMPLER
    }
    unreachable()
}

ResourceLimit :: struct {
    resource: ResourceType,
    limit: int,
}

ResourceUsage :: struct {
    type: ResourceType,
    count: int,
    stage: ShaderStages,
}

ResourceLayout :: struct {
    handle: vk.DescriptorSetLayout,

}

create_resource_layout :: proc(device: Device, usages: ..ResourceUsage) -> (layout: ResourceLayout) {
    bindings := make([dynamic]vk.DescriptorSetLayoutBinding, 0, len(usages), context.temp_allocator)
    for resource, i in usages {
        a := vk.DescriptorSetLayoutBinding {
            binding = u32(i),
            descriptorType = resource_type_to_vulkan(resource.type),
            descriptorCount = cast(u32) resource.count,
            stageFlags = shader_stage_to_vulkan(resource.stage),
        }
        append(&bindings, a)
    }

    dslci := vk.DescriptorSetLayoutCreateInfo {
        sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        bindingCount = cast(u32) len(bindings),
        pBindings = raw_data(bindings),
    }

    check(vk.CreateDescriptorSetLayout(device.handle, &dslci, nil, &layout.handle))
    return
}

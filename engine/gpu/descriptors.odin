package gpu
import "core:fmt"
import vk "vendor:vulkan"
import tracy "packages:odin-tracy"

ResourcePool :: struct {
    id: UUID,
    handle: vk.DescriptorPool,

    spec: ResourcePoolSpecification,
}

ResourcePoolSpecification :: struct {
    tag: cstring,
    device: ^Device,
    max_sets: int,
    resource_limits: [dynamic]ResourceLimit,
}

create_resource_pool :: proc(spec: ResourcePoolSpecification) -> (pool: ResourcePool) {
    pool.id = new_id()
    pool.spec = spec

    limits := make([dynamic]vk.DescriptorPoolSize, 0, len(spec.resource_limits), context.temp_allocator)
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

destroy_resource_pool :: proc(pool: ^ResourcePool) {
    delete(pool.spec.resource_limits)

    vk.DestroyDescriptorPool(pool.spec.device.handle, pool.handle, nil)
}

pool_reset :: proc(pool: ResourcePool) {
    check(vk.ResetDescriptorPool(pool.spec.device.handle, pool.handle, {}))
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
    case .ERROR_FRAGMENTED_POOL:
        error = .FragmentedPool
    case:
        check(result)
    }
    return
}

resource_bind_image :: proc(resource: Resource, image: Image, type: ResourceType, binding := u32(0)) {
    image_info := vk.DescriptorImageInfo {
        sampler = image.sampler.handle,
        imageView = image.view.handle,
        imageLayout = image_layout_to_vulkan(image.spec.layout),
    }

    a := vk.WriteDescriptorSet {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = resource.handle,
        dstBinding = binding,
        pImageInfo = &image_info,
        descriptorType = resource_type_to_vulkan(type),
        descriptorCount = 1,
        dstArrayElement = 0,
    }

    vk.UpdateDescriptorSets(image.spec.device.handle, 1, &a, 0, nil)
}

resource_bind_buffer :: proc(resource: Resource, buffer: Buffer, type: ResourceType, binding := u32(0)) {
    buffer_info := vk.DescriptorBufferInfo {
        buffer = buffer.handle,
        range = vk.DeviceSize(vk.WHOLE_SIZE),
        offset = {},
    }

    a := vk.WriteDescriptorSet {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = resource.handle,
        dstBinding = binding,
        pBufferInfo = &buffer_info,
        descriptorType = resource_type_to_vulkan(type),
        descriptorCount = 1,
        dstArrayElement = 0,
    }

    vk.UpdateDescriptorSets(buffer.spec.device.handle, 1, &a, 0, nil)
}

resource_bind_buffers :: proc(resource: Resource, buffers: ..Buffer) {
    write_sets := make([]vk.WriteDescriptorSet, len(buffers))
    for buffer, i in buffers {
        buffer_info := vk.DescriptorBufferInfo {
            buffer = buffer.handle,
            range = vk.DeviceSize(vk.WHOLE_SIZE),
            offset = {},
        }

        write_sets[i] = vk.WriteDescriptorSet {
            sType = .WRITE_DESCRIPTOR_SET,
            dstSet = resource.handle,
            dstBinding = 0,
            pBufferInfo = &buffer_info,
            descriptorType = resource_type_to_vulkan(.UniformBuffer),
            descriptorCount = 1,
            dstArrayElement = 0,
        }
    }

    vk.UpdateDescriptorSets(buffers[0].spec.device.handle, cast(u32) len(write_sets), raw_data(write_sets), 0, nil)
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
    tag: cstring,
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

FrameAllocator :: struct {
    used_pools: [dynamic][dynamic]ResourcePool,
    free_pools: [dynamic][dynamic]ResourcePool,

    current_frame_pools: [dynamic]ResourcePool,

    current_frame: u32,

    spec: FrameAllocatorSpecification,
}

@(private = "file")
POOL_SIZE_MULTIPLIERS : map[ResourceType]f32 = {
    .CombinedImageSampler = 1.0,
    .InputAttachment = 1.0,
    .UniformBuffer = 1.0,
    .StorageBuffer = 1.0,
}

FrameAllocatorSpecification :: struct {
    device: ^Device,
    frames: u32,
}

create_frame_allocator :: proc(spec: FrameAllocatorSpecification) -> (allocator: FrameAllocator) {
    tracy.Zone()
    allocator.spec = spec
    for i in 0..<spec.frames {
        append(&allocator.current_frame_pools, ResourcePool {})
        append(&allocator.free_pools, make([dynamic]ResourcePool))
        append(&allocator.used_pools, make([dynamic]ResourcePool))
    }
    return
}

destroy_frame_allocator :: proc(allocator: FrameAllocator) {
    tracy.Zone()
}

frame_allocator_alloc :: proc(allocator: ^FrameAllocator, layout: ResourceLayout) -> (resource: Resource, error: ResourceAllocationError) {
    tracy.Zone()
    frame := allocator.current_frame

    if allocator.current_frame_pools[frame].id == 0 {
        // fmt.printfln("Current pool is nil, creating a new one")
        allocator.current_frame_pools[frame] = get_available_pool(allocator)
        append(&allocator.used_pools[frame], allocator.current_frame_pools[frame])
    }

    resource, error = allocate_resource(allocator.current_frame_pools[frame], layout)
    #partial switch error {
    case .OutOfMemory, .FragmentedPool:
        allocator.current_frame_pools[frame] = get_available_pool(allocator)
        append(&allocator.used_pools[frame], allocator.current_frame_pools[frame])

        resource, error = allocate_resource(allocator.current_frame_pools[frame], layout)
        fmt.assertf(error == nil, "Second allocation from pool failed: %v", error)
    }

    return
}

frame_allocator_reset :: proc(allocator: ^FrameAllocator) {
    tracy.Zone()
    frame := allocator.current_frame
    // fmt.printfln("Resetting have %v used pools", len(allocator.used_pools[frame]))

    for pool in allocator.used_pools[frame] {
        pool_reset(pool)
        append(&allocator.free_pools[frame], pool)
    }

    allocator.current_frame_pools[frame] = {}
    clear(&allocator.used_pools[frame])
    allocator.current_frame = (allocator.current_frame + 1) % allocator.spec.frames
}

@(private = "file")
get_available_pool :: proc(allocator: ^FrameAllocator) -> (pool: ResourcePool) {
    tracy.Zone()
    frame := allocator.current_frame

    // fmt.printfln("b: %v", len(allocator.free_pools[frame]))
    if len(allocator.free_pools[frame]) > 0 {
        pool = pop(&allocator.free_pools[frame])
    } else {
        pool = create_pool(allocator.spec.device, 20)
    }
    // fmt.printfln("a: %v", len(allocator.free_pools[frame]))
    return
}

@(private = "file")
create_pool :: proc(device: ^Device, max_resources: int) -> (pool: ResourcePool) {
    tracy.Zone()

    // fmt.printfln("New allocation")
    // This allocation is saved to the pool spec.
    limits := make([dynamic]ResourceLimit, 0, max_resources)
    for type, multiplier in POOL_SIZE_MULTIPLIERS {
        append(&limits, ResourceLimit {
            resource = type,
            limit = int(f32(max_resources) * multiplier),
        })
    }

    spec := ResourcePoolSpecification {
        tag =  "Frame Allocator Pool",
        device = device,
        max_sets = max_resources,
        resource_limits = limits,
    }
    return create_resource_pool(spec)
}

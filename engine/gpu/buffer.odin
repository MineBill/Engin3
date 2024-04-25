package gpu
import vk "vendor:vulkan"
import vma "packages:odin-vma"

Buffer :: struct {
    id: UUID,
    handle: vk.Buffer,

    device: ^Device,
    memory: vk.DeviceMemory,
    allocation: vma.Allocation,

    spec: BufferSpecification,
}

BufferUsage :: enum {
    Vertex,
    Index,
}

BufferUsageFlags :: bit_set[BufferUsage]

BufferSpecification :: struct {
    device: ^Device,
    name: cstring,
    usage: BufferUsageFlags,
    size: int,
}

create_buffer :: proc(spec: BufferSpecification) -> (buffer: Buffer) {
    buffer.id = new_id()
    buffer.spec = spec
    buffer_create_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        flags = {},
        size = vk.DeviceSize(spec.size),
        sharingMode = .EXCLUSIVE,
        usage = buffer_usage_to_vulkan(spec.usage),
    }

    allocation_info := vma.AllocationCreateInfo {
        usage = .AUTO,
        flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
    }

    check(vma.CreateBuffer(spec.device.allocator, &buffer_create_info, &allocation_info, &buffer.handle, &buffer.allocation, nil))
    vma.SetAllocationName(spec.device.allocator, buffer.allocation, spec.name)

    return
}

destroy_buffer :: proc(buffer: Buffer) {
    info: vma.AllocationInfo
    vma.GetAllocationInfo(buffer.spec.device.allocator, buffer.allocation, &info)

    if info.pMappedData != nil {
        buffer_unmap(buffer)
    }

    vma.DestroyBuffer(buffer.spec.device.allocator, buffer.handle, buffer.allocation)
}

buffer_map :: proc(buffer: Buffer, data: ^rawptr) {
    vma.MapMemory(buffer.spec.device.allocator, buffer.allocation, data)
}

buffer_unmap :: proc(buffer: Buffer)  {
    vma.UnmapMemory(buffer.spec.device.allocator, buffer.allocation)
}

@(private)
buffer_usage_to_vulkan :: proc(usages: BufferUsageFlags) -> (vk_usage: vk.BufferUsageFlags) {
    for usage in usages {
        switch usage {
        case .Index:
            vk_usage += {.INDEX_BUFFER}
        case .Vertex:
            vk_usage += {.VERTEX_BUFFER}
        }
    }
    return
}

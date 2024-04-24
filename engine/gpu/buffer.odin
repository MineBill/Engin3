package gpu
import vk "vendor:vulkan"
import vma "packages:odin-vma"

Buffer :: struct {
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

BufferSpecification :: struct {
    allocator: vma.Allocator,
    name: cstring,
    usage: BufferUsage,
    size: int,
}

create_buffer :: proc(spec: BufferSpecification) -> (buffer: Buffer) {
    buffer.spec = spec
    buffer_create_info := vk.BufferCreateInfo {
        sType = .BUFFER_CREATE_INFO,
        flags = {},
        size = vk.DeviceSize(spec.size),
        sharingMode = .EXCLUSIVE,
    }

    allocation_info := vma.AllocationCreateInfo {
        usage = .AUTO,
        flags = {.HOST_ACCESS_SEQUENTIAL_WRITE},
    }

    check(vma.CreateBuffer(spec.allocator, &buffer_create_info, &allocation_info, &buffer.handle, &buffer.allocation, nil))
    vma.SetAllocationName(spec.allocator, buffer.allocation, spec.name)

    return
}

destroy_buffer :: proc(buffer: Buffer) {
    info: vma.AllocationInfo
    vma.GetAllocationInfo(buffer.spec.allocator, buffer.allocation, &info)

    if info.pMappedData != nil {
        buffer_unmap(buffer)
    }

    vma.DestroyBuffer(buffer.spec.allocator, buffer.handle, buffer.allocation)
}

buffer_map :: proc(buffer: Buffer, data: ^rawptr) {
    vma.MapMemory(buffer.spec.allocator, buffer.allocation, data)
}

buffer_unmap :: proc(buffer: Buffer)  {
    vma.UnmapMemory(buffer.spec.allocator, buffer.allocation)
}

@(private)
buffer_usage_to_vulkan :: proc(usage: BufferUsage) -> vk.BufferUsageFlag {
    switch usage {
    case .Index:
        return .INDEX_BUFFER
    case .Vertex:
        return .VERTEX_BUFFER
    }
    unreachable()
}

package gpu
import vk "vendor:vulkan"
import vma "packages:odin-vma"
import "core:mem"

Buffer :: struct {
    id: UUID,
    handle: vk.Buffer,

    allocation: vma.Allocation,
    alloc_info: vma.AllocationInfo,

    spec: BufferSpecification,
}

BufferUsage :: enum {
    Vertex,
    Index,
    Uniform,

    TransferSource,
    TransferDest,
}

BufferUsageFlags :: bit_set[BufferUsage]

BufferSpecification :: struct {
    device: ^Device,
    name: cstring,
    usage: BufferUsageFlags,
    size: int,
    mapped: bool,
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
    if spec.mapped {
        allocation_info.flags += {.MAPPED}
    }

    check(vma.CreateBuffer(spec.device.allocator, &buffer_create_info, &allocation_info, &buffer.handle, &buffer.allocation, &buffer.alloc_info))
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

buffer_upload :: proc(buffer: Buffer, data: []byte) {
    ptr: rawptr
    buffer_map(buffer, &ptr)
    defer buffer_unmap(buffer)

    mem.copy(ptr, raw_data(data), len(data))
}

buffer_copy_to_image :: proc(buffer: Buffer, image: Image) {
    cmd := device_begin_single_time_command(buffer.spec.device^)
    defer device_end_single_time_command(buffer.spec.device^, cmd)

    region := vk.BufferImageCopy {
        bufferOffset = 0,
        bufferRowLength = 0,
        bufferImageHeight = 0,

        imageSubresource = vk.ImageSubresourceLayers {
            aspectMask = {.COLOR},
            mipLevel = 0,
            baseArrayLayer = 0,
            layerCount = 1,
        },

        imageOffset = {0, 0, 0},
        imageExtent = {
            cast(u32) image.spec.width,
            cast(u32) image.spec.height,
            1.0,
        },
    }

    vk.CmdCopyBufferToImage(cmd.handle, buffer.handle, image.handle, .TRANSFER_DST_OPTIMAL, 1, &region)
}

@(private)
buffer_usage_to_vulkan :: proc(usages: BufferUsageFlags) -> (vk_usage: vk.BufferUsageFlags) {
    for usage in usages {
        switch usage {
        case .Index:
            vk_usage += {.INDEX_BUFFER}
        case .Vertex:
            vk_usage += {.VERTEX_BUFFER}
        case .Uniform:
            vk_usage += {.UNIFORM_BUFFER}
        case .TransferSource:
            vk_usage += {.TRANSFER_SRC}
        case .TransferDest:
            vk_usage += {.TRANSFER_DST}
        }
    }
    return
}

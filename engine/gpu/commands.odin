package gpu
import vk "vendor:vulkan"
import tracy "packages:odin-tracy"

CommandBuffer :: struct {
    id: UUID,
    handle: vk.CommandBuffer,

    spec: CommandBufferSpecification,
}

CommandBufferSpecification :: struct {
    tag: cstring,
    device: Device,
}

create_command_buffer :: proc(device: Device, spec: CommandBufferSpecification) -> (cmd_buffer: CommandBuffer) {
    cmd_buffer.id = new_id()
    cmd_buffer.spec = spec

    cmd_buffer_create_info := vk.CommandBufferAllocateInfo {
        sType = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool = device.command_pool,
        level = .PRIMARY,
        commandBufferCount = 1,
    }

    check(vk.AllocateCommandBuffers(device.handle, &cmd_buffer_create_info, &cmd_buffer.handle))
    return
}

destroy_command_buffer :: proc(cmd_buffer: CommandBuffer) {
    cmd_buffer := cmd_buffer
    vk.FreeCommandBuffers(cmd_buffer.spec.device.handle, cmd_buffer.spec.device.command_pool, 1, &cmd_buffer.handle)
}

create_command_buffers :: proc(device: Device, spec: CommandBufferSpecification, $count: int) -> (cmd_buffers: [count]CommandBuffer) {
    for i in 0..<count {
        cmd_buffers[i] = create_command_buffer(device, spec)
    }
    return
}

CommandType :: enum {
    None,
    SingleTime,
}

cmd_begin :: proc(cmd_buffer: CommandBuffer, type: CommandType = .None) {
    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
    }
    if type == .SingleTime {
        begin_info.flags += {.ONE_TIME_SUBMIT}
    }
    vk.BeginCommandBuffer(cmd_buffer.handle, &begin_info)
}

@(deferred_in = cmd_end)
do_cmd :: proc(cmd_buffer: CommandBuffer, type: CommandType = .None) -> bool {
    cmd_begin(cmd_buffer, type)
    return true
}

cmd_end :: proc(cmd_buffer: CommandBuffer, _: CommandType) {
    if cmd_buffer.handle != nil {
        vk.EndCommandBuffer(cmd_buffer.handle)
    }
}

reset_command_buffer :: proc(cmd_buffer: CommandBuffer) {
    vk.ResetCommandBuffer(cmd_buffer.handle, {})
}

reset :: proc {
    reset_command_buffer,
}

set_viewport :: proc(cmd: CommandBuffer, size: Vector2) {
    viewport := vk.Viewport {
        x = 0,
        y = 0,
        width = size.x,
        height = size.y,
        minDepth = 0,
        maxDepth = 1,
    }

    vk.CmdSetViewport(cmd.handle, 0, 1, &viewport)
}

set_scissor :: proc(cmd: CommandBuffer, x, y, width, height: u32) {
    tracy.Zone()
    scissor := vk.Rect2D {
        offset = vk.Offset2D {
            i32(x), i32(y),
        },
        extent = vk.Extent2D {
            width, height,
        },
    }
    vk.CmdSetScissor(cmd.handle, 0, 1, &scissor)
}

draw :: proc(cmd: CommandBuffer, #any_int vertex_count, instance_count: u32, first_vertex: u32 = 0, first_instance: u32 = 0) {
    tracy.Zone()
    vk.CmdDraw(cmd.handle, vertex_count, instance_count, first_vertex, first_instance)
}

draw_indexed :: proc(cmd: CommandBuffer, #any_int index_count, instance_count: u32, first_index := u32(0), vertex_offset := i32(0), vertex_count := u32(0)) {
    tracy.Zone()
    vk.CmdDrawIndexed(cmd.handle, index_count, instance_count, first_index, vertex_offset, vertex_count)
}

bind_buffers :: proc(cmd: CommandBuffer, buffers: ..Buffer) {
    tracy.Zone()
    if .Index in buffers[0].spec.usage {
        vk.CmdBindIndexBuffer(cmd.handle, buffers[0].handle, 0, .UINT16)
        return
    }

    vk_buffer_handles := make([dynamic]vk.Buffer, len(buffers), context.temp_allocator)
    for buffer, i in buffers {
        vk_buffer_handles[i] = buffer.handle
    }

    offsets := vk.DeviceSize(0)
    vk.CmdBindVertexBuffers(cmd.handle, 0, cast(u32) len(buffers), raw_data(vk_buffer_handles), &offsets)
}

bind_resource :: proc(cmd: CommandBuffer, resource: Resource, pipeline: Pipeline, first_set: u32 = 0) {
    tracy.Zone()
    sets := []vk.DescriptorSet {
        resource.handle,
    }

    vk.CmdBindDescriptorSets(cmd.handle, .GRAPHICS, pipeline.spec.layout.handle, first_set, 1, raw_data(sets), 0, nil)
}

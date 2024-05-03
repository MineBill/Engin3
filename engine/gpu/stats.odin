package gpu
import vk "vendor:vulkan"

RenderStats :: struct {
    device: ^Device,
    time_pool: vk.QueryPool,

    time_begin, time_end: u64,

    _time_period: f32,
}

create_render_stats :: proc(device: ^Device) -> (stats: RenderStats) {
    stats.device = device

    stats._time_period = device.properties.limits.timestampPeriod

    ci := vk.QueryPoolCreateInfo {
        sType = .QUERY_POOL_CREATE_INFO,
        queryType = .TIMESTAMP,
        queryCount = 128,
    }

    check(vk.CreateQueryPool(device.handle, &ci, nil, &stats.time_pool))
    return
}

@(private)
g_stats: ^RenderStats

set_global_stats :: proc(stats: ^RenderStats) {
    g_stats = stats
}

@(private)
stats_reset :: proc(cmd: CommandBuffer) {
    vk.CmdResetQueryPool(cmd.handle, g_stats.time_pool, 0, 2)
}

stats_begin_frame :: proc(cmd: CommandBuffer) {
    stats_reset(cmd)

    vk.CmdWriteTimestamp(cmd.handle, {.TOP_OF_PIPE}, g_stats.time_pool, 0)
}

stats_end_frame :: proc(cmd: CommandBuffer) {
    vk.CmdWriteTimestamp(cmd.handle, {.BOTTOM_OF_PIPE}, g_stats.time_pool, 1)
}

stats_collect :: proc() {
    results: [2]u64

    vk.GetQueryPoolResults(
        g_stats.device.handle,
        g_stats.time_pool,
        0,
        len(results),
        size_of(u64) * len(results),
        &results,
        size_of(u64),
        {._64, .WAIT})

    g_stats.time_begin = results[0]
    g_stats.time_end   = results[1]
}

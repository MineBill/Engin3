package gpu

Stats :: struct {
    renderpasses: map[UUID]RenderPassStats,
}

@(private)
g_stats: Stats

stats_reset :: proc(stats: ^Stats) {
    clear(&stats.renderpasses)
}

RenderPassStats :: struct {
    draw_calls: int,
    bound_pipelines: int,
}

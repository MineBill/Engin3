package engine
import "core:log"
import "core:time"
import "core:mem"
import tracy "packages:odin-tracy"

main :: proc() {
    context.logger = create_custom_console_logger(opt = {
        .Level,
        .Terminal_Color,
    }, ident = "engine")

    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking)
    context.allocator = tracy.MakeProfiledAllocator(
        self              = &tracy.ProfiledAllocatorData{},
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = false,
    )

    defer {
        // for ptr, entry in tracking.allocation_map {
        //     log.warnf("Leak detected!")
        //     log.warnf("\t%v bytes at %v", entry.size, entry.location)
        // }
    }

    engine: Engine
    engine.ctx = context
    err := engine_init(&engine)
    if err != nil {
        log.errorf("Error initializing engine: %v", err)
        return
    }
    defer engine_deinit(&engine)

    start_time := time.now()
    for !engine_should_close(&engine) {
        now := time.now()
        delta := time.duration_seconds(time.diff(start_time, now))
        start_time = now
        engine_update(&engine, delta)
        if engine.quit do break
    }
}


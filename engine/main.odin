package engine
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"
import "packages:back"
import tracy "packages:odin-tracy"

main :: proc() {
    context.logger = create_custom_console_logger(opt = {
        .Level,
        .Terminal_Color,
    }, ident = "engine")

    back.register_segfault_handler()
    context.assertion_failure_proc = back.assertion_failure_proc

    tracy_allocator := tracy.MakeProfiledAllocator(
        self              = &tracy.ProfiledAllocatorData{},
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = false,
    )

    track: back.Tracking_Allocator
    back.tracking_allocator_init(&track, tracy_allocator)
    defer back.tracking_allocator_destroy(&track)

    context.allocator = back.tracking_allocator(&track)
    // defer back.tracking_allocator_print_results(&track)

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


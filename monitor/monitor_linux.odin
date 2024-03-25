package monitor

import inotify "packages:odin-inotify"
import "core:mem"
import "core:strings"
import "core:os"
import "core:log"
import "core:fmt"

Monitor :: struct {
    handle:     os.Handle,

    // Paths to look out for
    paths:      []string,

    triggered:  bool,
    path_index: int,
}

init :: proc(monitor: ^Monitor, directory: string, paths: []string) {
    monitor.handle = inotify.init()

    handle, err := inotify.add_watch(monitor.handle, directory, {
        .Modify})
    if err != os.ERROR_NONE {
        log.errorf("Error creating monitor watch: %v", err)
    }

    monitor.paths = make([]string, len(paths))
    copy(monitor.paths, paths)
}

deinit :: proc(monitor: ^Monitor) {
    delete(monitor.paths)
}

thread_proc :: proc(data: rawptr) {
    monitor := cast(^Monitor)data
    for {
        events := inotify.read_events(monitor.handle)
        event_loop: for event in events {
            for path, i in monitor.paths {
                if strings.contains(path, event.name) {
                    monitor.triggered = true
                    monitor.path_index = i
                    break event_loop
                }
            }
        }
    }
}

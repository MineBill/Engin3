package filesystem
import inotify "packages:odin-inotify"
import "core:mem"
import "core:strings"
import "core:os"
import "core:log"
import "core:fmt"

copy_file :: proc(from: string, to: string) {
    unimplemented()
}

Watcher :: struct {
    handle:     os.Handle,

    // // Paths to look out for
    // paths:      []string,

    triggered:  bool,
    path_index: int,
}

watcher_init :: proc(file_watcher: ^Watcher, directory: string) {
    file_watcher.handle = inotify.init()

    handle, err := inotify.add_watch(file_watcher.handle, directory, {
        .Modify})
    if err != os.ERROR_NONE {
        log.errorf("Error creating file_watcher watch: %v", err)
    }

    // file_watcher.paths = make([]string, len(paths))
    // copy(file_watcher.paths, paths)
}

watcher_deinit :: proc(file_watcher: ^Watcher) {
    delete(file_watcher.paths)
}

@(private = "file")
thread_proc :: proc(data: rawptr) {
    file_watcher := cast(^Watcher)data
    for {
        events := inotify.read_events(file_watcher.handle)
        event_loop: for event in events {
            for path, i in file_watcher.paths {
                if strings.contains(path, event.name) {
                    file_watcher.triggered = true
                    file_watcher.path_index = i
                    break event_loop
                }
            }
        }
    }
}

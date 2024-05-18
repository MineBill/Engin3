package filesystem
import inotify "packages:odin-inotify"
import "core:mem"
import "core:strings"
import "core:os"
import "core:log"
import "core:fmt"
import "core:sync"
import "core:sys/unix"

copy_file :: proc(from: string, to: string, overwrite: bool = false, allocator := context.temp_allocator) -> (ok: bool) {
    os.write_entire_file(to, os.read_entire_file(from) or_return) or_return
    return true
}

open_file_explorer :: proc(dir: string) {
    unimplemented()
}

Watcher :: struct {
    handle:     os.Handle,

    mutex: sync.Mutex,

    triggered:  bool,
    changed_file: string,

    user_data: rawptr,
    callback: WatchCallback,
}

watcher_init :: proc(watcher: ^Watcher, directory: string) {
    watcher.handle = inotify.init()

    handle, err := inotify.add_watch(watcher.handle, directory, {
        .Modify})
    if err != os.ERROR_NONE {
        log.errorf("Error creating watcher watch: %v", err)
    }
}

watcher_init_with_callback :: proc(watcher: ^Watcher, directory: string, data: rawptr, callback: WatchCallback) {
    watcher.handle = inotify.init()

    handle, err := inotify.add_watch(watcher.handle, directory, {
        .Modify})
    if err != os.ERROR_NONE {
        log.errorf("Error creating watcher watch: %v", err)
    }

    watcher.callback = callback
    watcher.user_data = data
}

watcher_deinit :: proc(watcher: ^Watcher) {
}

@(private = "file")
thread_proc :: proc(data: rawptr) {
    watcher := cast(^Watcher)data
    for {
        events := inotify.read_events(watcher.handle)
        event_loop: for event in events {
            sync.mutex_lock(&watcher.mutex)
            delete(watcher.changed_file)
            watcher.triggered = true
            watcher.changed_file = strings.clone(event.name)
            if watcher.callback != nil {
                watcher.callback(watcher.user_data, watcher.changed_file)
                watcher.triggered = false
            }
            sync.mutex_unlock(&watcher.mutex)
        }
    }
}
